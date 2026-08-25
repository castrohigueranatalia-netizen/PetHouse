// ============================================================
// PETHOUSE API · Panel de administración
// GET /api/admin/solicitudes · POST /api/admin/solicitudes/:id/aprobar · /rechazar
// GET /api/admin/estadisticas
// GET /api/admin/usuarios · /usuarios/:id
// GET /api/admin/hospedajes
// GET /api/admin/reservas
// GET /api/admin/legal · PUT /api/admin/legal/entidad · PUT /api/admin/legal/:tipo
// GET /api/admin/soporte · GET /api/admin/soporte/:id · POST /api/admin/soporte/:id/responder
// POST /api/admin/soporte/:id/resolver
// GET /api/admin/privacidad · GET /api/admin/privacidad/:id
// POST /api/admin/privacidad/:id/en-proceso · POST /api/admin/privacidad/:id/responder
// GET /api/admin/identidad · GET /api/admin/identidad/:id
// POST /api/admin/identidad/:id/aprobar · POST /api/admin/identidad/:id/rechazar
// GET /api/admin/reportes/resumen · /reportes/reservas.csv · /reportes/usuarios.csv
// GET /api/admin/reportes/por-anfitrion · /reportes/comisiones-por-anfitrion.csv
//
// Todo bajo `soloAdmin` (rol = 'admin'). La aprobación/rechazo de una solicitud es la
// ÚNICA forma de activar usuarios.es_anfitrion — ver routes/anfitrion.js.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth, soloAdmin } from '../middleware/middleware.js'
import { crearNotificacion } from '../lib/notificaciones.js'
import { enviarPush } from '../lib/push.js'
import { firmarVerificacion, firmarUrlPrivada } from '../lib/urlsPrivadas.js'
import { completarReservasVencidas } from '../lib/completarReservas.js'
import { generarCodigo, hashCodigo } from '../lib/codigos.js'
import { enviarCorreo } from '../lib/correo.js'
import { aCSV } from '../lib/csv.js'

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
      usuariosConReserva, porEstado, pendientes, porCiudad, porLocalidad, privacidadPendientes, identidadPendientes
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
      ),
      // La app opera solo en Bogotá (ver pethouse-api/src/routes/hospedajes.js), así que
      // "por ciudad" ya no dice mucho del negocio real — casi todo es Bogotá, salvo reservas
      // viejas de hospedajes de otras ciudades que quedaron del seed original. `localidad`
      // (las 20 del Distrito, ver db/08-localidades-bogota.sql) es el desglose que sí
      // importa hoy. Solo hospedajes de Bogotá tienen `localidad` (NULL en los de otras
      // ciudades), así que se filtra para no mezclar un "sin localidad" sin sentido.
      pool.query(
        `SELECT h.localidad, COUNT(*)::int AS total
           FROM reservas r JOIN hospedajes h ON h.id = r.hospedaje_id
          WHERE h.localidad IS NOT NULL
          GROUP BY h.localidad
          ORDER BY total DESC`
      ),
      pool.query("SELECT COUNT(*)::int AS total FROM solicitudes_privacidad WHERE estado != 'resuelta'"),
      pool.query("SELECT COUNT(*)::int AS total FROM solicitudes_identidad_password WHERE estado = 'pendiente'")
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
      reservasPorCiudad: porCiudad.rows,
      reservasPorLocalidad: porLocalidad.rows,
      solicitudesPrivacidadPendientes: privacidadPendientes.rows[0].total,
      solicitudesIdentidadPendientes: identidadPendientes.rows[0].total
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

    const { estado, anfitrionId, mes } = req.query
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
    if (anfitrionId) {
      params.push(anfitrionId)
      condiciones.push(`an.id = $${params.length}`)
    }
    if (mes) {
      // "AAAA-MM" del <input type="month"> del panel — filtra por el mes en que EMPIEZA la
      // estadía (rs.desde), no por cuándo se hizo la reserva: a un admin mirando la agenda
      // de un anfitrión le interesa qué estadías caen en ese mes, no cuándo se reservaron.
      if (!/^\d{4}-\d{2}$/.test(mes)) return res.status(400).json({ error: 'Mes inválido (formato AAAA-MM).' })
      params.push(`${mes}-01`)
      condiciones.push(`rs.desde >= $${params.length}::date AND rs.desde < ($${params.length}::date + interval '1 month')`)
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
    const { nombreLegal, nit, domicilio, correoContacto, telefonoContacto, comisionPorcentaje } = req.body || {}

    // Solo informativo por ahora (no hay pasarela conectada), pero igual debe ser un
    // número sano — entre 0 y 100 — para no dejar guardar algo sin sentido por accidente.
    let comision = 10
    if (comisionPorcentaje !== undefined && comisionPorcentaje !== null && comisionPorcentaje !== '') {
      comision = Number(comisionPorcentaje)
      if (!Number.isFinite(comision) || comision < 0 || comision > 100) {
        return res.status(400).json({ error: 'El % de comisión debe ser un número entre 0 y 100.' })
      }
    }

    const { rows } = await pool.query(
      `UPDATE entidad_legal
          SET nombre_legal = $1, nit = $2, domicilio = $3, correo_contacto = $4,
              telefono_contacto = $5, comision_porcentaje = $6, actualizado_en = now()
        WHERE id = 1
        RETURNING *`,
      [nombreLegal || null, nit || null, domicilio || null, correoContacto || null, telefonoContacto || null, comision]
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

// ---- Soporte (buzón) — el lado del usuario está en routes/soporte.js ----

r.get('/soporte', async (req, res, next) => {
  try {
    const { estado } = req.query
    const condiciones = []
    const params = []
    if (estado) {
      if (!['abierto', 'resuelto'].includes(estado)) return res.status(400).json({ error: 'Estado inválido.' })
      params.push(estado)
      condiciones.push(`t.estado = $${params.length}`)
    }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    const { rows } = await pool.query(
      `SELECT t.*, u.nombre AS usuario_nombre, u.email AS usuario_email,
              (SELECT COUNT(*)::int FROM mensajes_soporte m WHERE m.ticket_id = t.id) AS num_mensajes
         FROM tickets_soporte t
         JOIN usuarios u ON u.id = t.usuario_id
         ${where}
        ORDER BY t.actualizado_en DESC`,
      params
    )
    res.json({ total: rows.length, tickets: rows })
  } catch (err) { next(err) }
})

r.get('/soporte/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT t.*, u.nombre AS usuario_nombre, u.email AS usuario_email
         FROM tickets_soporte t JOIN usuarios u ON u.id = t.usuario_id
        WHERE t.id = $1`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Ticket no encontrado.' })
    const { rows: mensajes } = await pool.query(
      'SELECT id, es_admin, texto, creado_en FROM mensajes_soporte WHERE ticket_id = $1 ORDER BY creado_en ASC',
      [req.params.id]
    )
    res.json({ ticket: rows[0], mensajes })
  } catch (err) { next(err) }
})

r.post('/soporte/:id/responder', async (req, res, next) => {
  try {
    const { texto } = req.body || {}
    if (!texto || !String(texto).trim()) return res.status(400).json({ error: 'Escribe una respuesta.' })

    const { rows: ticket } = await pool.query('SELECT usuario_id, asunto FROM tickets_soporte WHERE id = $1', [req.params.id])
    if (!ticket.length) return res.status(404).json({ error: 'Ticket no encontrado.' })

    const { rows } = await pool.query(
      `INSERT INTO mensajes_soporte (ticket_id, es_admin, texto) VALUES ($1, TRUE, $2)
       RETURNING id, es_admin, texto, creado_en`,
      [req.params.id, String(texto).trim()]
    )
    await pool.query(`UPDATE tickets_soporte SET actualizado_en = now() WHERE id = $1`, [req.params.id])

    await crearNotificacion(pool, {
      usuarioId: ticket[0].usuario_id,
      tipo: 'soporte_respondido',
      titulo: 'Te respondieron en soporte',
      mensaje: `Hay una respuesta nueva en tu ticket "${ticket[0].asunto}".`
    })
    enviarPush(ticket[0].usuario_id, {
      titulo: 'Te respondieron en soporte',
      mensaje: `Hay una respuesta nueva en tu ticket "${ticket[0].asunto}".`
    })

    res.status(201).json({ mensaje: rows[0] })
  } catch (err) { next(err) }
})

r.post('/soporte/:id/resolver', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE tickets_soporte SET estado = 'resuelto', actualizado_en = now() WHERE id = $1 RETURNING id`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Ticket no encontrado.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Solicitudes de privacidad — el lado del usuario está en routes/privacidad.js ----
// Se ordenan por `vence_en` ascendente (la más urgente primero), no por fecha de creación,
// para que el panel muestre de una vez cuál se está por vencer.

const ESTADOS_PRIVACIDAD_VALIDOS = ['pendiente', 'en_proceso', 'resuelta']

r.get('/privacidad', async (req, res, next) => {
  try {
    const { estado } = req.query
    const condiciones = []
    const params = []
    if (estado) {
      if (!ESTADOS_PRIVACIDAD_VALIDOS.includes(estado)) return res.status(400).json({ error: 'Estado inválido.' })
      params.push(estado)
      condiciones.push(`s.estado = $${params.length}`)
    }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    const { rows } = await pool.query(
      `SELECT s.*, u.nombre AS usuario_nombre, u.email AS usuario_email
         FROM solicitudes_privacidad s
         JOIN usuarios u ON u.id = s.usuario_id
         ${where}
        ORDER BY s.vence_en ASC`,
      params
    )
    res.json({ total: rows.length, solicitudes: rows })
  } catch (err) { next(err) }
})

r.get('/privacidad/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT s.*, u.nombre AS usuario_nombre, u.email AS usuario_email
         FROM solicitudes_privacidad s JOIN usuarios u ON u.id = s.usuario_id
        WHERE s.id = $1`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada.' })
    res.json({ solicitud: rows[0] })
  } catch (err) { next(err) }
})

r.post('/privacidad/:id/en-proceso', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE solicitudes_privacidad SET estado = 'en_proceso', actualizado_en = now()
        WHERE id = $1 AND estado = 'pendiente' RETURNING id`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada o ya no está pendiente.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

r.post('/privacidad/:id/responder', async (req, res, next) => {
  try {
    const { respuesta } = req.body || {}
    if (!respuesta || !String(respuesta).trim()) return res.status(400).json({ error: 'Escribe una respuesta.' })

    const { rows: solicitud } = await pool.query('SELECT usuario_id FROM solicitudes_privacidad WHERE id = $1', [req.params.id])
    if (!solicitud.length) return res.status(404).json({ error: 'Solicitud no encontrada.' })

    const { rows } = await pool.query(
      `UPDATE solicitudes_privacidad
          SET respuesta = $1, respondido_en = now(), estado = 'resuelta', actualizado_en = now()
        WHERE id = $2
        RETURNING *`,
      [String(respuesta).trim(), req.params.id]
    )

    await crearNotificacion(pool, {
      usuarioId: solicitud[0].usuario_id,
      tipo: 'privacidad_respondida',
      titulo: 'Respondimos tu solicitud de privacidad',
      mensaje: 'Ya puedes ver la respuesta en Perfil › Privacidad.'
    })
    enviarPush(solicitud[0].usuario_id, {
      titulo: 'Respondimos tu solicitud de privacidad',
      mensaje: 'Ya puedes ver la respuesta en Perfil › Privacidad.'
    })

    res.json({ solicitud: rows[0] })
  } catch (err) { next(err) }
})

// ---- Verificación de identidad para restablecer contraseña (respaldo sin correo) ----
// El lado del usuario (subir la foto, sin sesión) está en routes/auth.js
// (POST /auth/verificar-identidad). Acá el admin la revisa contra el nombre de la cuenta y,
// si corresponde, genera un PIN — que es, literalmente, el mismo tipo de código que el flujo
// por correo (misma tabla restablecimientos_password), así que el usuario lo usa en la
// MISMA pantalla de "código de 6 dígitos" de la app, no en una pantalla aparte.

r.get('/identidad', async (req, res, next) => {
  try {
    const { estado } = req.query
    const condiciones = []
    const params = []
    if (estado) {
      if (!['pendiente', 'aprobada', 'rechazada'].includes(estado)) return res.status(400).json({ error: 'Estado inválido.' })
      params.push(estado)
      condiciones.push(`s.estado = $${params.length}`)
    }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    const { rows } = await pool.query(
      `SELECT s.*, u.nombre AS usuario_nombre
         FROM solicitudes_identidad_password s
         LEFT JOIN usuarios u ON u.id = s.usuario_id
         ${where}
        ORDER BY (s.estado = 'pendiente') DESC, s.creado_en DESC`,
      params
    )
    res.json({
      total: rows.length,
      solicitudes: rows.map(s => ({ ...s, foto_cedula_url: firmarUrlPrivada(s.foto_cedula_url) }))
    })
  } catch (err) { next(err) }
})

r.get('/identidad/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT s.*, u.nombre AS usuario_nombre
         FROM solicitudes_identidad_password s
         LEFT JOIN usuarios u ON u.id = s.usuario_id
        WHERE s.id = $1`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada.' })
    res.json({ solicitud: { ...rows[0], foto_cedula_url: firmarUrlPrivada(rows[0].foto_cedula_url) } })
  } catch (err) { next(err) }
})

r.post('/identidad/:id/aprobar', async (req, res, next) => {
  try {
    const { rows: solicitud } = await pool.query(
      "SELECT usuario_id, email FROM solicitudes_identidad_password WHERE id = $1 AND estado = 'pendiente'",
      [req.params.id]
    )
    if (!solicitud.length) return res.status(404).json({ error: 'Solicitud no encontrada o ya fue revisada.' })
    if (!solicitud[0].usuario_id) {
      return res.status(400).json({ error: 'Esta solicitud no tiene una cuenta asociada — revisa el correo antes de aprobar.' })
    }

    const pin = generarCodigo()
    // 24 horas, no 15 minutos como el código por correo: este PIN lo entrega el admin a
    // mano (llamada, WhatsApp, etc.), así que necesita más margen que un código automático.
    await pool.query(
      `INSERT INTO restablecimientos_password (usuario_id, codigo_hash, expira_en)
       VALUES ($1, $2, now() + interval '24 hours')`,
      [solicitud[0].usuario_id, hashCodigo(pin)]
    )
    await pool.query(
      `UPDATE solicitudes_identidad_password SET estado = 'aprobada', revisado_en = now() WHERE id = $1`,
      [req.params.id]
    )

    // El PIN se devuelve UNA sola vez, en esta respuesta — no se guarda en texto plano en
    // ningún lado (mismo principio que los códigos por correo: solo se guarda su hash) — el
    // admin tiene que copiarlo ahora y pasárselo al usuario por el medio que tenga con él.
    res.json({ ok: true, pin, vigenciaHoras: 24 })
  } catch (err) { next(err) }
})

r.post('/identidad/:id/rechazar', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE solicitudes_identidad_password SET estado = 'rechazada', revisado_en = now()
        WHERE id = $1 AND estado = 'pendiente' RETURNING email`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada o ya fue revisada.' })

    // Mejor esfuerzo: si el correo escrito de verdad recibe correo, esto le llega; si el
    // problema era justo que su correo no funciona, no llega — no hay forma de resolver eso
    // desde acá, pero no cuesta nada intentarlo.
    enviarCorreo({
      para: rows[0].email,
      asunto: 'No pudimos verificar tu identidad en PetHouse',
      texto: 'Revisamos la foto de tu cédula y no pudimos confirmar que corresponde a la cuenta. Si sigues necesitando restablecer tu contraseña, escríbenos desde la app (Soporte) o intenta de nuevo con una foto más clara.'
    })

    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Reportes (resumen + CSV descargable, filtrables por rango de fechas) ----
// `desde`/`hasta` son fechas puras (YYYY-MM-DD, del `<input type=date>` del panel) — se
// comparan contra `creado_en` (TIMESTAMPTZ) sumando un día a `hasta` para incluir TODO ese
// día completo, no solo hasta la medianoche.

function condicionRangoFecha(campo, desde, hasta, params) {
  const condiciones = []
  if (desde) { params.push(desde); condiciones.push(`${campo} >= $${params.length}`) }
  if (hasta) { params.push(hasta); condiciones.push(`${campo} < ($${params.length}::date + interval '1 day')`) }
  return condiciones
}

r.get('/reportes/resumen', async (req, res, next) => {
  try {
    await completarReservasVencidas()
    const { desde, hasta } = req.query

    const paramsReservas = []
    const condReservas = condicionRangoFecha('creado_en', desde, hasta, paramsReservas)
    const whereReservas = condReservas.length ? `WHERE ${condReservas.join(' AND ')}` : ''

    // El valor del negocio solo cuenta reservas que de verdad se concretaron o van a
    // concretarse — una 'pendiente' o 'rechazada' no es plata real todavía.
    const paramsValor = [...paramsReservas]
    const whereValor = `WHERE ${[...condReservas, `estado IN ('confirmada', 'completada')`].join(' AND ')}`

    const paramsUsuarios = []
    const condUsuarios = condicionRangoFecha('creado_en', desde, hasta, paramsUsuarios)
    const whereUsuarios = condUsuarios.length ? `WHERE ${condUsuarios.join(' AND ')}` : ''

    const paramsComision = []
    const whereComision = `WHERE ${[...condicionRangoFecha('rs.creado_en', desde, hasta, paramsComision), `rs.estado IN ('confirmada', 'completada')`].join(' AND ')}`

    const [totalReservas, valorTotal, comision, usuariosNuevos, porEstado] = await Promise.all([
      pool.query(`SELECT COUNT(*)::int AS total FROM reservas ${whereReservas}`, paramsReservas),
      pool.query(`SELECT COALESCE(SUM(total), 0)::float AS total FROM reservas ${whereValor}`, paramsValor),
      // Comisión/ganancia solo son informativas por ahora (no hay pasarela conectada) — ver
      // db/27-comision.sql. Se leen de `pagos`, que guarda el % que aplicaba en cada momento.
      pool.query(
        `SELECT COALESCE(SUM(pg.comision_monto), 0)::float AS comision,
                COALESCE(SUM(pg.monto_anfitrion), 0)::float AS ganancia_anfitriones
           FROM reservas rs JOIN pagos pg ON pg.reserva_id = rs.id
           ${whereComision}`,
        paramsComision
      ),
      pool.query(`SELECT COUNT(*)::int AS total FROM usuarios ${whereUsuarios}`, paramsUsuarios),
      pool.query(`SELECT estado, COUNT(*)::int AS total FROM reservas ${whereReservas} GROUP BY estado ORDER BY total DESC`, paramsReservas)
    ])

    res.json({
      totalReservas: totalReservas.rows[0].total,
      valorTotal: valorTotal.rows[0].total,
      comisionTotal: comision.rows[0].comision,
      gananciaAnfitrionesTotal: comision.rows[0].ganancia_anfitriones,
      usuariosNuevos: usuariosNuevos.rows[0].total,
      reservasPorEstado: porEstado.rows
    })
  } catch (err) { next(err) }
})

r.get('/reportes/reservas.csv', async (req, res, next) => {
  try {
    await completarReservasVencidas()
    const { desde, hasta } = req.query
    const params = []
    const condiciones = condicionRangoFecha('rs.creado_en', desde, hasta, params)
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    const { rows } = await pool.query(
      `SELECT rs.codigo, u.nombre AS huesped, h.titulo AS hospedaje, an.nombre AS anfitrion,
              h.localidad, h.ciudad, to_char(rs.desde, 'YYYY-MM-DD') AS desde,
              to_char(rs.hasta, 'YYYY-MM-DD') AS hasta, rs.noches, rs.total, rs.estado,
              pg.comision_porcentaje, pg.comision_monto, pg.monto_anfitrion,
              to_char(rs.creado_en, 'YYYY-MM-DD HH24:MI') AS creado_en
         FROM reservas rs
         JOIN usuarios u ON u.id = rs.usuario_id
         JOIN hospedajes h ON h.id = rs.hospedaje_id
         JOIN usuarios an ON an.id = h.anfitrion_id
         LEFT JOIN pagos pg ON pg.reserva_id = rs.id
         ${where}
        ORDER BY rs.creado_en DESC`,
      params
    )
    const csv = aCSV([
      { campo: 'codigo', etiqueta: 'Código' },
      { campo: 'huesped', etiqueta: 'Huésped' },
      { campo: 'hospedaje', etiqueta: 'Hospedaje' },
      { campo: 'anfitrion', etiqueta: 'Anfitrión' },
      { campo: 'localidad', etiqueta: 'Localidad' },
      { campo: 'ciudad', etiqueta: 'Ciudad' },
      { campo: 'desde', etiqueta: 'Desde' },
      { campo: 'hasta', etiqueta: 'Hasta' },
      { campo: 'noches', etiqueta: 'Noches' },
      { campo: 'total', etiqueta: 'Valor' },
      { campo: 'estado', etiqueta: 'Estado' },
      { campo: 'comision_porcentaje', etiqueta: '% comisión' },
      { campo: 'comision_monto', etiqueta: 'Comisión PetHouse' },
      { campo: 'monto_anfitrion', etiqueta: 'Gana el anfitrión' },
      { campo: 'creado_en', etiqueta: 'Fecha de reserva' }
    ], rows)
    res.setHeader('Content-Type', 'text/csv; charset=utf-8')
    res.setHeader('Content-Disposition', 'attachment; filename="reservas.csv"')
    res.send(csv)
  } catch (err) { next(err) }
})

r.get('/reportes/comisiones-por-anfitrion.csv', async (req, res, next) => {
  try {
    await completarReservasVencidas()
    const { desde, hasta } = req.query
    const params = []
    const condiciones = [...condicionRangoFecha('rs.creado_en', desde, hasta, params), `rs.estado IN ('confirmada', 'completada')`]

    const { rows } = await pool.query(
      `SELECT an.nombre AS anfitrion, an.email AS correo,
              COUNT(*)::int AS num_reservas,
              SUM(rs.total)::float AS valor_total,
              SUM(pg.comision_monto)::float AS comision_total,
              SUM(pg.monto_anfitrion)::float AS ganancia_total
         FROM reservas rs
         JOIN hospedajes h ON h.id = rs.hospedaje_id
         JOIN usuarios an ON an.id = h.anfitrion_id
         JOIN pagos pg ON pg.reserva_id = rs.id
        WHERE ${condiciones.join(' AND ')}
        GROUP BY an.id, an.nombre, an.email
        ORDER BY ganancia_total DESC`,
      params
    )
    const csv = aCSV([
      { campo: 'anfitrion', etiqueta: 'Anfitrión' },
      { campo: 'correo', etiqueta: 'Correo' },
      { campo: 'num_reservas', etiqueta: 'Reservas' },
      { campo: 'valor_total', etiqueta: 'Valor total' },
      { campo: 'comision_total', etiqueta: 'Comisión PetHouse' },
      { campo: 'ganancia_total', etiqueta: 'Gana el anfitrión' }
    ], rows)
    res.setHeader('Content-Type', 'text/csv; charset=utf-8')
    res.setHeader('Content-Disposition', 'attachment; filename="comisiones-por-anfitrion.csv"')
    res.send(csv)
  } catch (err) { next(err) }
})

r.get('/reportes/por-anfitrion', async (req, res, next) => {
  try {
    await completarReservasVencidas()
    const { desde, hasta } = req.query
    const params = []
    const condiciones = [...condicionRangoFecha('rs.creado_en', desde, hasta, params), `rs.estado IN ('confirmada', 'completada')`]

    const { rows } = await pool.query(
      `SELECT an.id AS anfitrion_id, an.nombre AS anfitrion_nombre,
              COUNT(*)::int AS num_reservas,
              SUM(rs.total)::float AS valor_total,
              SUM(pg.comision_monto)::float AS comision_total,
              SUM(pg.monto_anfitrion)::float AS ganancia_total
         FROM reservas rs
         JOIN hospedajes h ON h.id = rs.hospedaje_id
         JOIN usuarios an ON an.id = h.anfitrion_id
         JOIN pagos pg ON pg.reserva_id = rs.id
        WHERE ${condiciones.join(' AND ')}
        GROUP BY an.id, an.nombre
        ORDER BY ganancia_total DESC`,
      params
    )
    res.json({ anfitriones: rows })
  } catch (err) { next(err) }
})

r.get('/reportes/usuarios.csv', async (req, res, next) => {
  try {
    const { desde, hasta } = req.query
    const params = []
    const condiciones = condicionRangoFecha('creado_en', desde, hasta, params)
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''

    const { rows } = await pool.query(
      `SELECT nombre, email, telefono, rol, es_anfitrion, to_char(creado_en, 'YYYY-MM-DD HH24:MI') AS creado_en
         FROM usuarios ${where} ORDER BY creado_en DESC`,
      params
    )
    const csv = aCSV([
      { campo: 'nombre', etiqueta: 'Nombre' },
      { campo: 'email', etiqueta: 'Correo' },
      { campo: 'telefono', etiqueta: 'Teléfono' },
      { campo: 'rol', etiqueta: 'Rol' },
      { campo: 'es_anfitrion', etiqueta: 'Es anfitrión' },
      { campo: 'creado_en', etiqueta: 'Fecha de registro' }
    ], rows)
    res.setHeader('Content-Type', 'text/csv; charset=utf-8')
    res.setHeader('Content-Disposition', 'attachment; filename="usuarios.csv"')
    res.send(csv)
  } catch (err) { next(err) }
})

export default r
