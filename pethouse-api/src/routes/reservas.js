// ============================================================
// PETHOUSE API · Módulo Reservas
// POST /api/reservas · GET /api/reservas/mias · GET /api/reservas/:id
// POST /api/reservas/:id/cancelar · POST /api/reservas/:id/aceptar · /rechazar
// POST /api/reservas/:id/resena-huesped · POST /api/reservas/:id/plan
//
// Toda reserva nace en estado 'pendiente' — el anfitrión debe aceptarla o rechazarla
// (ver /:id/aceptar y /:id/rechazar) antes de que cuente como confirmada. Ver
// db/11-reservas-pendientes-mascotas.sql.
//
// GET /mias, GET /:id y POST /:id/cancelar llaman a completarReservasVencidas() antes de
// leer/tocar la fila — así una reserva 'confirmada' con la fecha ya pasada aparece
// 'completada' (habilita reseñas) y una 'pendiente' vencida aparece 'rechazada', sin
// necesitar un job en segundo plano. Ver db/16-completar-reservas-vencidas.sql.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'
import { MASCOTAS_DETALLE_SQL } from '../lib/mascotasDetalleSql.js'
import { completarReservasVencidas } from '../lib/completarReservas.js'
import { crearNotificacion } from '../lib/notificaciones.js'
import { enviarPush } from '../lib/push.js'
import { hoyBogota } from '../lib/fechaBogota.js'

const r = Router()

// Fila completa de una reserva vista por el anfitrión: mismo shape que
// GET /api/hospedajes/:id/reservas (usuario_nombre + mascotas_detalle) — la usan
// /:id/aceptar y /:id/rechazar para devolver la fila completa, no solo id/codigo/estado,
// así el cliente puede reemplazarla en su lista sin perder los demás campos.
async function filaConDetalleAnfitrion(id) {
  const { rows } = await pool.query(
    `SELECT rs.*, h.titulo AS hospedaje_titulo, u.nombre AS usuario_nombre, ${MASCOTAS_DETALLE_SQL}
       FROM reservas rs
       JOIN hospedajes h ON h.id = rs.hospedaje_id
       JOIN usuarios u ON u.id = rs.usuario_id
      WHERE rs.id = $1`,
    [id]
  )
  return rows[0]
}

// ---- Crear reserva (cotiza y valida disponibilidad) ----
r.post('/', auth, async (req, res, next) => {
  const client = await pool.connect()
  try {
    const { hospedaje_id, desde, hasta, mascota_ids } = req.body || {}
    if (!hospedaje_id || !desde || !hasta) {
      return res.status(400).json({ error: 'Faltan hospedaje_id, desde o hasta.' })
    }
    if (!Array.isArray(mascota_ids) || !mascota_ids.length) {
      return res.status(400).json({ error: 'Selecciona al menos una mascota.' })
    }
    // `hasta === desde` es una reserva de UN SOLO DÍA (entrega y recogida el mismo día, ver
    // db/35-reserva-mismo-dia.sql) — ya no es un error, solo lo es `hasta` ANTES de `desde`.
    if (hasta < desde) return res.status(400).json({ error: 'La fecha de salida debe ser posterior o igual a la llegada.' })
    const mismoDia = hasta === desde
    // Comparación de texto (YYYY-MM-DD), no de objetos Date — ver el comentario de
    // hoyBogota() sobre por qué mezclar Date/UTC/local acá era un bug real.
    if (desde < hoyBogota()) {
      return res.status(400).json({ error: 'La fecha de llegada no puede ser anterior a hoy.' })
    }

    await client.query('BEGIN')

    // Bloquea la fila del hospedaje para evitar carreras de reserva
    const { rows: hs } = await client.query(
      'SELECT id, titulo, anfitrion_id, precio_noche, precio_dia, max_mascotas, convivencia, activo FROM hospedajes WHERE id = $1 FOR UPDATE',
      [hospedaje_id]
    )
    if (!hs.length) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'Hospedaje no encontrado.' }) }
    const h = hs[0]
    // El anfitrión lo pausó (ver PATCH /api/hospedajes/:id { activo }) — ya no aparece en
    // Buscar, pero alguien pudo tenerlo abierto desde antes de que lo pausara.
    if (!h.activo) {
      await client.query('ROLLBACK')
      return res.status(409).json({ error: 'Este hospedaje no está disponible para reservar en este momento.' })
    }
    if (mismoDia && h.precio_dia == null) {
      await client.query('ROLLBACK')
      return res.status(400).json({ error: 'Este hospedaje no ofrece reservas de un solo día.' })
    }

    // `hastaReal` es SIEMPRE `desde + 1` para una reserva de un solo día — internamente
    // ocupa ese día completo igual que una reserva de 1 noche (mismo EXCLUDE, mismo chequeo
    // de traslapes de abajo), lo único que cambia es qué precio se cobra (ver `mismoDia` en
    // el INSERT). Calculado en Postgres, no con `new Date()`, para no repetir el bug de
    // huso horario que ya se arregló en hoyBogota().
    let hastaReal = hasta
    if (mismoDia) {
      const { rows: sumado } = await client.query('SELECT ($1::date + 1)::text AS valor', [desde])
      hastaReal = sumado[0].valor
    }

    // El anfitrión bloqueó estas fechas a mano (ver db/34-fechas-bloqueadas.sql) — mismo
    // criterio de traslape que el EXCLUDE de `reservas`, pero verificado a mano porque un
    // EXCLUDE no puede cruzar dos tablas distintas. Usa `hastaReal`, no la `hasta` que mandó
    // el cliente — con `hasta === desde` un daterange quedaría vacío y nunca "traslaparía"
    // nada, dejando colar una reserva de un solo día sobre una fecha bloqueada.
    const { rows: bloqueado } = await client.query(
      `SELECT 1 FROM hospedaje_fechas_bloqueadas
        WHERE hospedaje_id = $1 AND daterange(desde, hasta) && daterange($2::date, $3::date) LIMIT 1`,
      [hospedaje_id, desde, hastaReal]
    )
    if (bloqueado.length) {
      await client.query('ROLLBACK')
      return res.status(409).json({ error: 'El anfitrión bloqueó esas fechas — elige otras.' })
    }

    // Valida que las mascotas seleccionadas sean del usuario autenticado
    const { rows: mascotasPropias } = await client.query(
      `SELECT id, nombre, raza, edad, tamano, peso_kg, fotos, necesita_medicamentos, notas
         FROM mascotas WHERE id = ANY($1::uuid[]) AND usuario_id = $2`,
      [mascota_ids, req.usuario.id]
    )
    if (mascotasPropias.length !== mascota_ids.length) {
      await client.query('ROLLBACK')
      return res.status(400).json({ error: 'Alguna mascota seleccionada no es válida.' })
    }

    // Ficha completa: no basta con el nombre — el anfitrión necesita raza, edad, tamaño,
    // peso y al menos una foto para decidir con confianza si acepta la solicitud (y, si la
    // mascota toma medicamentos, el detalle en notas). Mismo criterio que valida la app
    // ANTES de dejar seleccionar una mascota (ver Mascota.fichaCompleta en iOS) — esto es
    // la versión de servidor, para que no se pueda saltar llamando a la API directo.
    const incompletas = mascotasPropias.filter(m =>
      !m.raza || m.edad === null || !m.tamano || m.peso_kg === null || !(m.fotos || []).length ||
      (m.necesita_medicamentos && !m.notas)
    )
    if (incompletas.length) {
      await client.query('ROLLBACK')
      return res.status(400).json({
        error: `Completa la ficha de ${incompletas.map(m => m.nombre).join(', ')} (raza, edad, tamaño, peso y una foto) antes de reservar.`
      })
    }

    const mascotas = mascota_ids.length
    if (mascotas > h.max_mascotas) {
      await client.query('ROLLBACK')
      return res.status(400).json({ error: `Este hospedaje admite máximo ${h.max_mascotas} mascotas.` })
    }

    const noches = Math.round((new Date(hastaReal) - new Date(desde)) / 86400000)
    // Base para limpieza/servicio: precio_dia si es de un solo día, precio_noche si no —
    // el huésped de un solo día no debería pagar tarifas calculadas sobre el precio de
    // noche completa cuando ni siquiera se queda a dormir.
    const precioBase = mismoDia ? h.precio_dia : h.precio_noche
    const limpieza = Math.round(precioBase * 0.6)
    const servicio = Math.round(precioBase * noches * 0.1)

    // % de comisión vigente AHORA MISMO — se guarda en el pago, no se vuelve a leer después,
    // para que cambiarlo más adelante no altere lo ya calculado de reservas viejas.
    const { rows: entidad } = await client.query('SELECT comision_porcentaje FROM entidad_legal WHERE id = 1')
    const comisionPorcentaje = entidad[0]?.comision_porcentaje ?? 10

    // notificado_anfitrion = FALSE: el anfitrión todavía no vio que llegó esta solicitud —
    // ver GET /notificaciones/pendientes-anfitrion y POST /:id/notificado-anfitrion más
    // abajo, mismo patrón que `notificado` (aviso al huésped) pero en la otra dirección.
    // `hasta` guarda `hastaReal` (no el `hasta` crudo del cliente) — así el EXCLUDE de
    // traslapes (ver 01-esquema.sql/11-reservas-pendientes-mascotas.sql) sigue protegiendo
    // también las reservas de un solo día sin ningún cambio en esa restricción.
    const { rows } = await client.query(
      `INSERT INTO reservas
         (usuario_id, hospedaje_id, desde, hasta, mascotas, precio_noche, mismo_dia, precio_dia, limpieza, servicio, notificado_anfitrion)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, FALSE)
       RETURNING id, codigo, desde, hasta, noches, mascotas, precio_noche, mismo_dia, precio_dia, limpieza, servicio, total, estado, creado_en`,
      [req.usuario.id, hospedaje_id, desde, hastaReal, mascotas, h.precio_noche, mismoDia, mismoDia ? h.precio_dia : null, limpieza, servicio]
    )

    await client.query(
      'INSERT INTO reserva_mascotas (reserva_id, mascota_id) SELECT $1, unnest($2::uuid[])',
      [rows[0].id, mascota_ids]
    )

    // Pago pendiente (fase 2: pasarela). `comision_porcentaje` queda fijo desde ya —
    // `comision_monto`/`monto_anfitrion` se calculan solos (columnas generadas).
    await client.query(
      'INSERT INTO pagos (reserva_id, monto, estado, comision_porcentaje) VALUES ($1, $2, $3, $4)',
      [rows[0].id, rows[0].total, 'pendiente', comisionPorcentaje]
    )

    // Historial de la campana (ver GET /api/notificaciones) — además del `notificado_anfitrion`
    // de arriba, que sigue alimentando el aviso instantáneo de siempre.
    await crearNotificacion(client, {
      usuarioId: h.anfitrion_id,
      tipo: 'solicitud_nueva',
      titulo: '¡Nueva solicitud de reserva!',
      mensaje: `${req.usuario.nombre} quiere reservar en ${h.titulo}.`,
      reservaId: rows[0].id,
      hospedajeId: h.id
    })

    await client.query('COMMIT')
    // Sin await a propósito: un push lento o fallido a Apple nunca debe demorar la
    // respuesta de "reserva creada" (ver lib/push.js).
    enviarPush(h.anfitrion_id, {
      titulo: '¡Nueva solicitud de reserva!',
      mensaje: `${req.usuario.nombre} quiere reservar en ${h.titulo}.`
    })
    res.status(201).json({ reserva: rows[0], detalle: { hospedaje: h.titulo, noches, limpieza, servicio } })
  } catch (err) {
    await client.query('ROLLBACK')
    next(err) // 23P01 (EXCLUDE) → 409 por el manejador global
  } finally {
    client.release()
  }
})

// ---- Mis reservas (con hospedaje) ----
r.get('/mias', auth, async (req, res, next) => {
  try {
    await completarReservasVencidas()
    const { rows } = await pool.query(
      // hospedaje_id + anfitrion_id: antes no venían, así que el cliente no tenía forma de
      // abrir el detalle del hospedaje ni de escribirle al anfitrión desde "Mis reservas".
      `SELECT rs.id, rs.codigo, rs.desde, rs.hasta, rs.noches, rs.mismo_dia, rs.mascotas, rs.total, rs.estado,
              rs.hospedaje_id, h.anfitrion_id,
              h.titulo AS hospedaje_titulo, h.ciudad, h.barrio, h.tipo, h.fotos,
              ${MASCOTAS_DETALLE_SQL}
         FROM reservas rs JOIN hospedajes h ON h.id = rs.hospedaje_id
        WHERE rs.usuario_id = $1 AND NOT rs.oculta_por_usuario
        ORDER BY rs.creado_en DESC`,
      [req.usuario.id]
    )
    res.json({ reservas: rows })
  } catch (err) { next(err) }
})

// ---- Detalle de reserva (dueño o anfitrión del hospedaje) ----
r.get('/:id', auth, async (req, res, next) => {
  try {
    await completarReservasVencidas()
    const { rows } = await pool.query(
      `SELECT rs.*, h.titulo AS hospedaje_titulo, h.anfitrion_id, ${MASCOTAS_DETALLE_SQL}
         FROM reservas rs JOIN hospedajes h ON h.id = rs.hospedaje_id
        WHERE rs.id = $1`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Reserva no encontrada.' })
    if (rows[0].usuario_id !== req.usuario.id && rows[0].anfitrion_id !== req.usuario.id) {
      return res.status(403).json({ error: 'No tienes acceso a esta reserva.' })
    }
    const { rows: plan } = await pool.query(
      `SELECT pa.id, pa.fecha, pa.precio, a.nombre, a.tipo
         FROM plan_actividades pa JOIN actividades a ON a.id = pa.actividad_id
        WHERE pa.reserva_id = $1 ORDER BY pa.fecha NULLS LAST`,
      [req.params.id]
    )
    res.json({ reserva: rows[0], plan })
  } catch (err) { next(err) }
})

// ---- Cancelar reserva (el huésped, mientras esté pendiente o ya confirmada) ----
r.post('/:id/cancelar', auth, async (req, res, next) => {
  try {
    // Sin esto, una reserva cuya fecha ya pasó pero que nadie había vuelto a consultar
    // podría "cancelarse" como si la estadía no hubiera ocurrido — completarReservasVencidas()
    // la pone al día primero (a 'completada' o 'rechazada' según corresponda), y entonces
    // el UPDATE de abajo (que solo actúa sobre 'pendiente'/'confirmada') ya no la toca.
    await completarReservasVencidas()
    const { rows } = await pool.query(
      `UPDATE reservas SET estado = 'cancelada'
        WHERE id = $1 AND usuario_id = $2 AND estado IN ('pendiente', 'confirmada')
        RETURNING id, codigo, estado`,
      [req.params.id, req.usuario.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Reserva no encontrada o ya resuelta.' })
    res.json({ reserva: rows[0] })
  } catch (err) { next(err) }
})

// ---- Ocultar del panel "Mis reservas" una reserva ya resuelta (el huésped dueño) ----
// NO borra la fila de verdad (no se puede: `pagos.reserva_id` es ON DELETE RESTRICT, y
// además destruiría historial real) — ver db/18-ocultar-reserva.sql. Solo para reservas ya
// resueltas ('completada', 'cancelada', 'rechazada'): una 'pendiente' o 'confirmada' sigue
// activa, ocultarla la dejaría "perdida" sin poder cancelarla ni verla en la lista.
r.post('/:id/ocultar', auth, async (req, res, next) => {
  try {
    await completarReservasVencidas()
    const { rows } = await pool.query(
      `UPDATE reservas SET oculta_por_usuario = TRUE
        WHERE id = $1 AND usuario_id = $2 AND estado IN ('completada', 'cancelada', 'rechazada')
        RETURNING id`,
      [req.params.id, req.usuario.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Reserva no encontrada o todavía activa.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Aceptar / rechazar solicitud de reserva (el anfitrión dueño del hospedaje) ----
// `notificado = FALSE`: el huésped todavía no vio esta resolución — ver
// GET /notificaciones/resueltas y POST /:id/notificado más abajo (db/12-notificacion-
// reserva-resuelta.sql), mismo patrón que verificaciones_anfitrion.notificado en admin.js.
r.post('/:id/aceptar', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE reservas SET estado = 'confirmada', notificado = FALSE
         FROM hospedajes h
        WHERE reservas.id = $1 AND reservas.hospedaje_id = h.id
          AND h.anfitrion_id = $2 AND reservas.estado = 'pendiente'
        RETURNING reservas.id`,
      [req.params.id, req.usuario.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada o ya resuelta.' })
    const detalle = await filaConDetalleAnfitrion(rows[0].id)
    await crearNotificacion(pool, {
      usuarioId: detalle.usuario_id,
      tipo: 'reserva_resuelta',
      titulo: '¡Reserva confirmada!',
      mensaje: `El anfitrión aceptó tu solicitud en ${detalle.hospedaje_titulo}. Revisa los detalles en la pestaña Reservas.`,
      reservaId: detalle.id,
      hospedajeId: detalle.hospedaje_id
    })
    enviarPush(detalle.usuario_id, {
      titulo: '¡Reserva confirmada!',
      mensaje: `El anfitrión aceptó tu solicitud en ${detalle.hospedaje_titulo}. Revisa los detalles en la pestaña Reservas.`
    })
    res.json({ reserva: detalle })
  } catch (err) { next(err) }
})

r.post('/:id/rechazar', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE reservas SET estado = 'rechazada', notificado = FALSE
         FROM hospedajes h
        WHERE reservas.id = $1 AND reservas.hospedaje_id = h.id
          AND h.anfitrion_id = $2 AND reservas.estado = 'pendiente'
        RETURNING reservas.id`,
      [req.params.id, req.usuario.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada o ya resuelta.' })
    const detalle = await filaConDetalleAnfitrion(rows[0].id)
    await crearNotificacion(pool, {
      usuarioId: detalle.usuario_id,
      tipo: 'reserva_resuelta',
      titulo: 'Solicitud de reserva rechazada',
      mensaje: `El anfitrión no pudo aceptar tu solicitud en ${detalle.hospedaje_titulo}. Puedes buscar otro hospedaje disponible.`,
      reservaId: detalle.id,
      hospedajeId: detalle.hospedaje_id
    })
    enviarPush(detalle.usuario_id, {
      titulo: 'Solicitud de reserva rechazada',
      mensaje: `El anfitrión no pudo aceptar tu solicitud en ${detalle.hospedaje_titulo}. Puedes buscar otro hospedaje disponible.`
    })
    res.json({ reserva: detalle })
  } catch (err) { next(err) }
})

// ---- Solicitudes resueltas que el huésped todavía no vio ----
r.get('/notificaciones/resueltas', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT rs.id, rs.codigo, rs.desde, rs.hasta, rs.estado, h.titulo AS hospedaje_titulo
         FROM reservas rs JOIN hospedajes h ON h.id = rs.hospedaje_id
        WHERE rs.usuario_id = $1 AND rs.notificado = FALSE AND rs.estado IN ('confirmada', 'rechazada')
        ORDER BY rs.creado_en ASC`,
      [req.usuario.id]
    )
    res.json({ reservas: rows })
  } catch (err) { next(err) }
})

// ---- Marca como vista la resolución de una solicitud propia ----
r.post('/:id/notificado', auth, async (req, res, next) => {
  try {
    await pool.query(
      'UPDATE reservas SET notificado = TRUE WHERE id = $1 AND usuario_id = $2',
      [req.params.id, req.usuario.id]
    )
    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Solicitudes nuevas que el anfitrión todavía no vio (ver notificado_anfitrion en
// POST / arriba) — mismo shape que GET /api/hospedajes/:id/reservas (usuario_nombre +
// mascotas_detalle), para que la app pueda mostrar de una vez quién y qué mascota es. ----
r.get('/notificaciones/pendientes-anfitrion', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT rs.*, h.titulo AS hospedaje_titulo, u.nombre AS usuario_nombre, ${MASCOTAS_DETALLE_SQL}
         FROM reservas rs
         JOIN hospedajes h ON h.id = rs.hospedaje_id
         JOIN usuarios u ON u.id = rs.usuario_id
        WHERE h.anfitrion_id = $1 AND rs.notificado_anfitrion = FALSE AND rs.estado = 'pendiente'
        ORDER BY rs.creado_en ASC`,
      [req.usuario.id]
    )
    res.json({ reservas: rows })
  } catch (err) { next(err) }
})

// ---- Marca como vista una solicitud nueva (el anfitrión dueño del hospedaje) ----
r.post('/:id/notificado-anfitrion', auth, async (req, res, next) => {
  try {
    await pool.query(
      `UPDATE reservas SET notificado_anfitrion = TRUE
         FROM hospedajes h
        WHERE reservas.id = $1 AND reservas.hospedaje_id = h.id AND h.anfitrion_id = $2`,
      [req.params.id, req.usuario.id]
    )
    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- El anfitrión califica al huésped de una reserva propia (espejo de
// POST /api/hospedajes/:id/resenas, ver db/15-resenas-huesped.sql) ----
r.post('/:id/resena-huesped', auth, async (req, res, next) => {
  try {
    const { rating, titulo, texto } = req.body || {}
    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'rating (1-5) es obligatorio.' })
    }

    // Solo el anfitrión dueño del hospedaje de ESTA reserva puede calificar a ese huésped
    const { rows: rs } = await pool.query(
      `SELECT rs.usuario_id
         FROM reservas rs JOIN hospedajes h ON h.id = rs.hospedaje_id
        WHERE rs.id = $1 AND h.anfitrion_id = $2`,
      [req.params.id, req.usuario.id]
    )
    if (!rs.length) {
      return res.status(403).json({ error: 'Solo puedes calificar al huésped de una reserva de tu hospedaje.' })
    }

    const { rows } = await pool.query(
      `INSERT INTO resenas_usuario (reserva_id, autor_id, usuario_id, rating, titulo, texto)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, rating, titulo, texto, creado_en`,
      [req.params.id, req.usuario.id, rs[0].usuario_id, rating, titulo || null, texto || null]
    )
    // El trigger actualizar_rating_usuario() recalcula rating y num_resenas del huésped
    res.status(201).json({ resena: rows[0] })
  } catch (err) { next(err) }
})

// ---- Agregar actividad al plan de la reserva ----
r.post('/:id/plan', auth, async (req, res, next) => {
  try {
    const { actividad_id, fecha } = req.body || {}
    if (!actividad_id) return res.status(400).json({ error: 'Falta actividad_id.' })

    // Verifica que la reserva es del usuario y obtiene el precio de la actividad
    const { rows: rs } = await pool.query(
      'SELECT id FROM reservas WHERE id = $1 AND usuario_id = $2',
      [req.params.id, req.usuario.id]
    )
    if (!rs.length) return res.status(404).json({ error: 'Reserva no encontrada.' })

    const { rows: act } = await pool.query(
      'SELECT id, precio FROM actividades WHERE id = $1 AND activa',
      [actividad_id]
    )
    if (!act.length) return res.status(404).json({ error: 'Actividad no encontrada.' })

    const { rows } = await pool.query(
      `INSERT INTO plan_actividades (reserva_id, actividad_id, fecha, precio)
       VALUES ($1, $2, $3, $4) RETURNING id, actividad_id, fecha, precio`,
      [req.params.id, actividad_id, fecha || null, act[0].precio]
    )
    res.status(201).json({ plan: rows[0] })
  } catch (err) { next(err) }
})

export default r
