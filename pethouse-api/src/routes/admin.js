// ============================================================
// PETHOUSE API · Panel de administración
// GET /api/admin/solicitudes · POST /api/admin/solicitudes/:id/aprobar · /rechazar
// GET /api/admin/estadisticas
//
// Todo bajo `soloAdmin` (rol = 'admin'). La aprobación/rechazo de una solicitud es la
// ÚNICA forma de activar usuarios.es_anfitrion — ver routes/anfitrion.js.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth, soloAdmin } from '../middleware/middleware.js'
import { crearNotificacion } from '../lib/notificaciones.js'
import { enviarPush } from '../lib/push.js'
import { firmarVerificacion } from '../lib/urlsPrivadas.js'
import { completarReservasVencidas } from '../lib/completarReservas.js'

const r = Router()
r.use(auth, soloAdmin)

const ESTADOS_VALIDOS = ['pendiente', 'aprobado', 'rechazado']

// ---- Solicitudes de anfitrión (verificaciones) ----

r.get('/solicitudes', async (req, res, next) => {
  try {
    const { estado } = req.query
    const condiciones = []
    const params = []
    if (estado) {
      if (!ESTADOS_VALIDOS.includes(estado)) return res.status(400).json({ error: 'Estado inválido.' })
      params.push(estado)
      condiciones.push(`v.estado = $${params.length}`)
    }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    const { rows } = await pool.query(
      `SELECT v.*, u.nombre AS usuario_nombre, u.email AS usuario_email, u.telefono AS usuario_telefono
         FROM verificaciones_anfitrion v
         JOIN usuarios u ON u.id = v.usuario_id
        ${where}
        ORDER BY v.creado_en DESC`,
      params
    )
    res.json({ total: rows.length, solicitudes: rows.map(firmarVerificacion) })
  } catch (err) { next(err) }
})

r.post('/solicitudes/:id/aprobar', async (req, res, next) => {
  const client = await pool.connect()
  try {
    await client.query('BEGIN')
    const { rows } = await client.query(
      `UPDATE verificaciones_anfitrion SET estado = 'aprobado', notificado = FALSE, actualizado_en = now()
        WHERE id = $1 RETURNING usuario_id`,
      [req.params.id]
    )
    if (!rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'Solicitud no encontrada.' }) }

    await client.query('UPDATE usuarios SET es_anfitrion = TRUE WHERE id = $1', [rows[0].usuario_id])
    await crearNotificacion(client, {
      usuarioId: rows[0].usuario_id,
      tipo: 'verificacion_resuelta',
      titulo: '¡Solicitud aprobada!',
      mensaje: 'Ya eres anfitrión en PetHouse. Publica tu primer hospedaje desde Perfil › Mis hospedajes.'
    })
    await client.query('COMMIT')
    enviarPush(rows[0].usuario_id, {
      titulo: '¡Solicitud aprobada!',
      mensaje: 'Ya eres anfitrión en PetHouse. Publica tu primer hospedaje desde Perfil › Mis hospedajes.'
    })
    res.json({ ok: true })
  } catch (err) {
    await client.query('ROLLBACK')
    next(err)
  } finally {
    client.release()
  }
})

r.post('/solicitudes/:id/rechazar', async (req, res, next) => {
  const client = await pool.connect()
  try {
    await client.query('BEGIN')
    const { rows } = await client.query(
      `UPDATE verificaciones_anfitrion SET estado = 'rechazado', notificado = FALSE, actualizado_en = now()
        WHERE id = $1 RETURNING usuario_id`,
      [req.params.id]
    )
    if (!rows.length) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'Solicitud no encontrada.' }) }

    // Revoca la capacidad por si ya la tenía (ej. se re-revisa una aprobación anterior).
    await client.query('UPDATE usuarios SET es_anfitrion = FALSE WHERE id = $1', [rows[0].usuario_id])
    await crearNotificacion(client, {
      usuarioId: rows[0].usuario_id,
      tipo: 'verificacion_resuelta',
      titulo: 'Solicitud rechazada',
      mensaje: 'Tu solicitud de anfitrión no fue aprobada esta vez. Puedes volver a intentarlo desde tu perfil.'
    })
    await client.query('COMMIT')
    enviarPush(rows[0].usuario_id, {
      titulo: 'Solicitud rechazada',
      mensaje: 'Tu solicitud de anfitrión no fue aprobada esta vez. Puedes volver a intentarlo desde tu perfil.'
    })
    res.json({ ok: true })
  } catch (err) {
    await client.query('ROLLBACK')
    next(err)
  } finally {
    client.release()
  }
})

// ---- Panel de control ----
// Campos originales (totalUsuarios/totalAnfitriones/totalReservas/solicitudesPendientes/
// reservasPorCiudad) SIN TOCAR — el panel web nuevo (ver admin-web/) y la app de iOS
// (EstadisticasAdmin.swift) leen esta misma respuesta; agregar campos es seguro (Swift
// ignora las claves que no conoce), pero quitar o renombrar uno rompería la app.
r.get('/estadisticas', async (_req, res, next) => {
  try {
    // Al día antes de contar — sin esto, una reserva 'confirmada' cuya fecha ya pasó
    // seguiría contando como activa hasta que alguien más la consultara (mismo patrón que
    // GET /reservas/mias y la búsqueda de hospedajes).
    await completarReservasVencidas()

    const [
      usuarios, anfitriones, hospedajes, reservas, reservasActivas,
      usuariosConReserva, porEstado, pendientes, porCiudad
    ] = await Promise.all([
      pool.query('SELECT COUNT(*)::int AS total FROM usuarios'),
      pool.query('SELECT COUNT(*)::int AS total FROM usuarios WHERE es_anfitrion'),
      pool.query('SELECT COUNT(*)::int AS total FROM hospedajes WHERE activo'),
      pool.query('SELECT COUNT(*)::int AS total FROM reservas'),
      pool.query("SELECT COUNT(*)::int AS total FROM reservas WHERE estado IN ('pendiente', 'confirmada')"),
      pool.query('SELECT COUNT(DISTINCT usuario_id)::int AS total FROM reservas'),
      pool.query('SELECT estado, COUNT(*)::int AS total FROM reservas GROUP BY estado ORDER BY total DESC'),
      pool.query("SELECT COUNT(*)::int AS total FROM verificaciones_anfitrion WHERE estado = 'pendiente'"),
      pool.query(
        `SELECT h.ciudad, COUNT(*)::int AS total
           FROM reservas r JOIN hospedajes h ON h.id = r.hospedaje_id
          GROUP BY h.ciudad
          ORDER BY total DESC`
      )
    ])
    res.json({
      totalUsuarios: usuarios.rows[0].total,
      totalAnfitriones: anfitriones.rows[0].total,
      totalHospedajes: hospedajes.rows[0].total,
      totalReservas: reservas.rows[0].total,
      reservasActivas: reservasActivas.rows[0].total,
      usuariosConReserva: usuariosConReserva.rows[0].total,
      reservasPorEstado: porEstado.rows,
      solicitudesPendientes: pendientes.rows[0].total,
      reservasPorCiudad: porCiudad.rows
    })
  } catch (err) { next(err) }
})

export default r
