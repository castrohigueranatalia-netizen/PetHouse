// ============================================================
// PETHOUSE API · Panel de administración
// GET /api/admin/solicitudes · POST /api/admin/solicitudes/:id/aprobar · /rechazar
// GET /api/admin/estadisticas
// GET /api/admin/usuarios · /usuarios/:id
// GET /api/admin/hospedajes
// GET /api/admin/reservas
// GET /api/admin/legal · PUT /api/admin/legal/entidad · PUT /api/admin/legal/:tipo
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

// ---- Usuarios (lista con búsqueda/filtros + detalle) ----

r.get('/usuarios', async (req, res, next) => {
  try {
    const { q, rol, esAnfitrion } = req.query
    const pagina = Math.max(1, parseInt(req.query.pagina, 10) || 1)
    const porPagina = Math.min(100, Math.max(1, parseInt(req.query.porPagina, 10) || 30))
    const offset = (pagina - 1) * porPagina

    const condiciones = []
    const params = []
    if (q) {
      params.push(`%${q}%`)
      condiciones.push(`(u.nombre ILIKE $${params.length} OR u.email ILIKE $${params.length})`)
    }
    if (rol) { params.push(rol); condiciones.push(`u.rol = $${params.length}`) }
    if (esAnfitrion !== undefined) {
      params.push(esAnfitrion === 'true')
      condiciones.push(`u.es_anfitrion = $${params.length}`)
    }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    params.push(porPagina, offset)
    const { rows } = await pool.query(
      // Los conteos van como subconsultas correlacionadas (una por usuario, resuelta por
      // Postgres en la misma consulta) — no es un loop de queries desde Node, así que no
      // hay problema real de N+1 aunque se vea "una consulta por fila".
      `SELECT u.id, u.nombre, u.email, u.telefono, u.rol, u.es_anfitrion, u.verificado, u.creado_en,
              COUNT(*) OVER() AS total_filtrado,
              (SELECT COUNT(*)::int FROM mascotas m WHERE m.usuario_id = u.id) AS num_mascotas,
              (SELECT COUNT(*)::int FROM reservas rs WHERE rs.usuario_id = u.id) AS num_reservas,
              (SELECT COUNT(*)::int FROM hospedajes h WHERE h.anfitrion_id = u.id) AS num_hospedajes
         FROM usuarios u
         ${where}
        ORDER BY u.creado_en DESC
        LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    )
    const total = rows[0]?.total_filtrado ?? 0
    res.json({
      usuarios: rows.map(({ total_filtrado, ...u }) => u),
      total: Number(total),
      pagina,
      porPagina
    })
  } catch (err) { next(err) }
})

r.get('/usuarios/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, nombre, email, telefono, rol, es_anfitrion, verificado, foto_url, creado_en
         FROM usuarios WHERE id = $1`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Usuario no encontrado.' })

    // Cédula y fotos de verificación NO van acá (ya existe GET /admin/solicitudes, con URLs
    // firmadas, para revisar eso) — este detalle es para tener una vista rápida de quién es
    // el usuario, no para repetir el flujo de aprobar/rechazar.
    const [mascotas, verificacion, hospedajes, reservas] = await Promise.all([
      pool.query(
        `SELECT id, nombre, especie, raza, edad, tamano, peso_kg, fotos
           FROM mascotas WHERE usuario_id = $1 ORDER BY nombre`,
        [req.params.id]
      ),
      pool.query(
        `SELECT id, nombre_legal, estado, creado_en FROM verificaciones_anfitrion WHERE usuario_id = $1`,
        [req.params.id]
      ),
      pool.query(
        `SELECT id, titulo, ciudad, localidad, precio_noche, activo
           FROM hospedajes WHERE anfitrion_id = $1 ORDER BY creado_en DESC`,
        [req.params.id]
      ),
      pool.query(
        `SELECT rs.id, rs.codigo, rs.estado, rs.total, rs.desde, rs.hasta, h.titulo AS hospedaje_titulo
           FROM reservas rs JOIN hospedajes h ON h.id = rs.hospedaje_id
          WHERE rs.usuario_id = $1
          ORDER BY rs.creado_en DESC LIMIT 20`,
        [req.params.id]
      )
    ])

    res.json({
      usuario: rows[0],
      mascotas: mascotas.rows,
      verificacion: verificacion.rows[0] || null,
      hospedajes: hospedajes.rows,
      reservas: reservas.rows
    })
  } catch (err) { next(err) }
})

// ---- Hospedajes (por ubicación y anfitrión) ----

r.get('/hospedajes', async (req, res, next) => {
  try {
    const { anfitrionId, ciudad, localidad } = req.query
    const pagina = Math.max(1, parseInt(req.query.pagina, 10) || 1)
    const porPagina = Math.min(100, Math.max(1, parseInt(req.query.porPagina, 10) || 30))
    const offset = (pagina - 1) * porPagina

    const condiciones = []
    const params = []
    if (anfitrionId) { params.push(anfitrionId); condiciones.push(`h.anfitrion_id = $${params.length}`) }
    if (ciudad) { params.push(ciudad); condiciones.push(`h.ciudad = $${params.length}`) }
    if (localidad) { params.push(localidad); condiciones.push(`h.localidad = $${params.length}`) }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    params.push(porPagina, offset)
    const { rows } = await pool.query(
      `SELECT h.id, h.titulo, h.tipo, h.ciudad, h.barrio, h.localidad, h.precio_noche, h.activo, h.creado_en,
              u.id AS anfitrion_id, u.nombre AS anfitrion_nombre,
              COUNT(*) OVER() AS total_filtrado,
              (SELECT COUNT(*)::int FROM reservas rs WHERE rs.hospedaje_id = h.id) AS num_reservas
         FROM hospedajes h JOIN usuarios u ON u.id = h.anfitrion_id
         ${where}
        ORDER BY h.creado_en DESC
        LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    )
    const total = rows[0]?.total_filtrado ?? 0
    res.json({
      hospedajes: rows.map(({ total_filtrado, ...h }) => h),
      total: Number(total),
      pagina,
      porPagina
    })
  } catch (err) { next(err) }
})

// ---- Reservas (activas/cumplidas/canceladas, con su valor) ----

const ESTADOS_RESERVA_VALIDOS = ['pendiente', 'confirmada', 'completada', 'cancelada', 'rechazada']

r.get('/reservas', async (req, res, next) => {
  try {
    await completarReservasVencidas()

    const { estado } = req.query
    const pagina = Math.max(1, parseInt(req.query.pagina, 10) || 1)
    const porPagina = Math.min(100, Math.max(1, parseInt(req.query.porPagina, 10) || 30))
    const offset = (pagina - 1) * porPagina

    const condiciones = []
    const params = []
    if (estado === 'activa') {
      condiciones.push(`rs.estado IN ('pendiente', 'confirmada')`)
    } else if (estado === 'canceladas') {
      // Atajo para la sección "Cancelaciones" del panel: reservas que NO se concretaron,
      // sea porque el huésped canceló o porque el anfitrión rechazó la solicitud.
      condiciones.push(`rs.estado IN ('cancelada', 'rechazada')`)
    } else if (estado) {
      if (!ESTADOS_RESERVA_VALIDOS.includes(estado)) return res.status(400).json({ error: 'Estado inválido.' })
      params.push(estado)
      condiciones.push(`rs.estado = $${params.length}`)
    }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    params.push(porPagina, offset)
    const { rows } = await pool.query(
      `SELECT rs.id, rs.codigo, rs.estado, rs.desde, rs.hasta, rs.noches, rs.mascotas, rs.total, rs.creado_en,
              u.id AS usuario_id, u.nombre AS usuario_nombre,
              h.id AS hospedaje_id, h.titulo AS hospedaje_titulo, h.ciudad, h.localidad,
              an.id AS anfitrion_id, an.nombre AS anfitrion_nombre,
              COUNT(*) OVER() AS total_filtrado
         FROM reservas rs
         JOIN usuarios u ON u.id = rs.usuario_id
         JOIN hospedajes h ON h.id = rs.hospedaje_id
         JOIN usuarios an ON an.id = h.anfitrion_id
         ${where}
        ORDER BY rs.creado_en DESC
        LIMIT $${params.length - 1} OFFSET $${params.length}`,
      params
    )
    const total = rows[0]?.total_filtrado ?? 0
    res.json({
      reservas: rows.map(({ total_filtrado, ...rs }) => rs),
      total: Number(total),
      pagina,
      porPagina
    })
  } catch (err) { next(err) }
})

// ---- Entidad legal + documentos legales (privacidad, términos) ----
// El lado de solo-lectura está en routes/legal.js (GET /api/legal/..., sin auth — la app
// y quien no tenga cuenta todavía necesitan poder leerlos). Acá solo la edición.

const TIPOS_DOCUMENTO_VALIDOS = ['privacidad', 'terminos']

r.get('/legal', async (_req, res, next) => {
  try {
    const [entidad, documentos] = await Promise.all([
      pool.query('SELECT * FROM entidad_legal WHERE id = 1'),
      pool.query('SELECT tipo, contenido, actualizado_en FROM documentos_legales ORDER BY tipo')
    ])
    res.json({ entidad: entidad.rows[0], documentos: documentos.rows })
  } catch (err) { next(err) }
})

r.put('/legal/entidad', async (req, res, next) => {
  try {
    const { nombreLegal, nit, domicilio, correoContacto, telefonoContacto } = req.body || {}
    const { rows } = await pool.query(
      `UPDATE entidad_legal
          SET nombre_legal = $1, nit = $2, domicilio = $3, correo_contacto = $4,
              telefono_contacto = $5, actualizado_en = now()
        WHERE id = 1
        RETURNING *`,
      [nombreLegal || null, nit || null, domicilio || null, correoContacto || null, telefonoContacto || null]
    )
    res.json({ entidad: rows[0] })
  } catch (err) { next(err) }
})

r.put('/legal/:tipo', async (req, res, next) => {
  try {
    if (!TIPOS_DOCUMENTO_VALIDOS.includes(req.params.tipo)) {
      return res.status(404).json({ error: 'Documento no encontrado.' })
    }
    const { contenido } = req.body || {}
    if (typeof contenido !== 'string') return res.status(400).json({ error: 'Falta el contenido.' })
    const { rows } = await pool.query(
      `UPDATE documentos_legales SET contenido = $1, actualizado_en = now()
        WHERE tipo = $2
        RETURNING tipo, contenido, actualizado_en`,
      [contenido, req.params.tipo]
    )
    res.json({ documento: rows[0] })
  } catch (err) { next(err) }
})

export default r
