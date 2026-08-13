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
    res.json({ total: rows.length, solicitudes: rows })
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
    await client.query('COMMIT')
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
    await client.query('COMMIT')
    res.json({ ok: true })
  } catch (err) {
    await client.query('ROLLBACK')
    next(err)
  } finally {
    client.release()
  }
})

// ---- Panel de control ----

r.get('/estadisticas', async (_req, res, next) => {
  try {
    const [usuarios, anfitriones, reservas, pendientes, porCiudad] = await Promise.all([
      pool.query('SELECT COUNT(*)::int AS total FROM usuarios'),
      pool.query('SELECT COUNT(*)::int AS total FROM usuarios WHERE es_anfitrion'),
      pool.query('SELECT COUNT(*)::int AS total FROM reservas'),
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
      totalReservas: reservas.rows[0].total,
      solicitudesPendientes: pendientes.rows[0].total,
      reservasPorCiudad: porCiudad.rows
    })
  } catch (err) { next(err) }
})

export default r
