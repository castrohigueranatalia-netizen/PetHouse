// ============================================================
// PETHOUSE API · Módulo Hospedajes (PostGIS)
// GET /api/hospedajes?localidad&tipo&convivencia&especie&desde&hasta&lat&lng&radio&q&orden&pagina&porPagina
//   La app opera solo en Bogotá — todo listado/búsqueda se filtra a `ciudad = 'Bogotá'`
//   siempre, y se segmenta por `localidad` en vez de una `ciudad` de texto libre.
// GET /api/hospedajes/localidades  → conteo de hospedajes por cada una de las 20 localidades
// GET /api/hospedajes/cerca?lat&lng&radio
// GET /api/hospedajes/:id/disponibilidad  → rangos de fecha ya ocupados (pública)
// GET /api/hospedajes/:id
// POST /api/hospedajes   (anfitrión) · PATCH /api/hospedajes/:id (anfitrión dueño)
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth, soloAnfitrion } from '../middleware/middleware.js'
import { MASCOTAS_DETALLE_SQL } from '../lib/mascotasDetalleSql.js'
import { completarReservasVencidas } from '../lib/completarReservas.js'

const r = Router()

// Las 20 localidades oficiales del Distrito Capital, en su orden numérico oficial
// (Usaquén = 1 … Sumapaz = 20). Duplicada en PetHouseiOS/Core/Models/Localidad.swift y en
// el CHECK de `hospedajes.localidad` (ver db/08-localidades-bogota.sql) — cambiar acá
// implica cambiar los tres lugares.
const LOCALIDADES_BOGOTA = [
  'Usaquén', 'Chapinero', 'Santa Fe', 'San Cristóbal', 'Usme', 'Tunjuelito', 'Bosa',
  'Kennedy', 'Fontibón', 'Engativá', 'Suba', 'Barrios Unidos', 'Teusaquillo',
  'Los Mártires', 'Antonio Nariño', 'Puente Aranda', 'La Candelaria',
  'Rafael Uribe Uribe', 'Ciudad Bolívar', 'Sumapaz'
]

// ---- Listado con filtros (equivale a buscar_hospedajes() + detalle) ----
r.get('/', async (req, res, next) => {
  try {
    const { localidad, tipo, convivencia, especie, desde, hasta, lat, lng, radio, q, orden } = req.query
    // Antes esto era un `LIMIT 100` fijo sin forma de pedir más — el cliente hacía su
    // propia "paginación" revelando de a poco ese máximo de 100 ya descargado (ver
    // MVP_SCOPE.md #7). Ahora pagina de verdad contra la base.
    const pagina = Math.max(1, parseInt(req.query.pagina, 10) || 1)
    const porPagina = Math.min(50, Math.max(1, parseInt(req.query.porPagina, 10) || 20))
    const offset = (pagina - 1) * porPagina

    // La app es solo de Bogotá (ver encabezado del archivo): esta condición no depende de
    // ningún query param, siempre está. `u.bloqueado = FALSE` tampoco: un anfitrión
    // bloqueado por un admin (ver POST /admin/usuarios/:id/bloquear) deja de aparecer en
    // Buscar de inmediato, aunque sus hospedajes sigan `activo = TRUE`.
    const condiciones = ['h.activo = TRUE', "h.ciudad = 'Bogotá'", 'u.bloqueado = FALSE']
    const params = []

    if (tipo) { params.push(tipo); condiciones.push(`h.tipo = $${params.length}`) }
    if (convivencia) { params.push(convivencia); condiciones.push(`h.convivencia = $${params.length}`) }
    if (localidad) { params.push(localidad); condiciones.push(`h.localidad = $${params.length}`) }
    // El anfitrión declara qué especies cuida en `preferencias_anfitrion.especies` (ver
    // db/06-verificacion-anfitrion.sql) — no es un campo de `hospedajes`, así que se filtra
    // por subconsulta contra el anfitrión dueño del hospedaje. Un anfitrión que todavía no
    // llenó sus preferencias no matchea ningún filtro de especie (comportamiento correcto:
    // no declaró qué acepta).
    if (especie) {
      params.push(especie)
      condiciones.push(`EXISTS (
        SELECT 1 FROM preferencias_anfitrion pa
         WHERE pa.usuario_id = h.anfitrion_id AND $${params.length} = ANY(pa.especies))`)
    }
    if (q) {
      params.push(q)
      condiciones.push(`to_tsvector('spanish', h.titulo || ' ' || h.descripcion || ' ' || h.ciudad) @@ plainto_tsquery('spanish', $${params.length})`)
    }
    if (desde && hasta) {
      params.push(desde, hasta)
      condiciones.push(`NOT EXISTS (
        SELECT 1 FROM reservas rr
         WHERE rr.hospedaje_id = h.id AND rr.estado = 'confirmada'
           AND rr.desde < $${params.length} AND rr.hasta > $${params.length - 1})`)
    }

    let seleccion = `
      SELECT h.id, h.titulo, h.tipo, h.ciudad, h.barrio, h.localidad, h.precio_noche, h.precio_dia, h.convivencia,
             h.max_mascotas, h.rating, h.num_resenas, h.destacado, h.servicios, h.fotos,
             ST_Y(h.ubicacion::geometry) AS lat, ST_X(h.ubicacion::geometry) AS lng,
             u.nombre AS anfitrion_nombre, u.verificado AS anfitrion_verificado,
             COUNT(*) OVER() AS total_filtrado`
    let ordenSql = 'h.destacado DESC, h.rating DESC, h.num_resenas DESC'

    if (lat && lng) {
      params.push(Number(lng), Number(lat))
      const radioM = Number(radio || 10000)
      seleccion += `,
             ROUND(ST_Distance(h.ubicacion, ST_SetSRID(ST_MakePoint($${params.length - 1}, $${params.length}), 4326)::geography)) AS distancia_m`
      condiciones.push(`ST_DWithin(h.ubicacion, ST_SetSRID(ST_MakePoint($${params.length - 1}, $${params.length}), 4326)::geography, ${radioM})`)
      ordenSql = 'distancia_m ASC'
    }

    switch (orden) {
      case 'precio-asc': ordenSql = 'h.precio_noche ASC'; break
      case 'precio-desc': ordenSql = 'h.precio_noche DESC'; break
      case 'rating': ordenSql = 'h.rating DESC, h.num_resenas DESC'; break
    }

    params.push(porPagina, offset)
    const limiteParam = params.length - 1
    const offsetParam = params.length

    const sql = `${seleccion} FROM hospedajes h JOIN usuarios u ON u.id = h.anfitrion_id
                 WHERE ${condiciones.join(' AND ')} ORDER BY ${ordenSql}
                 LIMIT $${limiteParam} OFFSET $${offsetParam}`
    const { rows } = await pool.query(sql, params)
    // `COUNT(*) OVER()` cuenta las filas que matchean el filtro ANTES del LIMIT/OFFSET
    // (Postgres evalúa las funciones de ventana antes de truncar con LIMIT), así que da el
    // total real sin una segunda consulta — pero solo viene en las filas devueltas. Si se
    // pide una página vacía (offset más allá del total, ej. el total bajó entre un scroll y
    // el siguiente porque se desactivó un hospedaje) no hay de dónde leerlo, así que ahí sí
    // se hace una segunda consulta liviana — el caso normal (con filas) no paga ese costo.
    let total
    if (rows.length) {
      total = Number(rows[0].total_filtrado)
    } else {
      const paramsSinPaginacion = params.slice(0, params.length - 2)
      const { rows: conteo } = await pool.query(
        `SELECT COUNT(*)::int AS total FROM hospedajes h WHERE ${condiciones.join(' AND ')}`,
        paramsSinPaginacion
      )
      total = conteo[0].total
    }
    const hospedajes = rows.map(({ total_filtrado, ...resto }) => resto)
    res.json({ total, pagina, porPagina, hospedajes })
  } catch (err) { next(err) }
})

// ---- Búsqueda por radio (usa el índice GIST) ----
r.get('/cerca', async (req, res, next) => {
  try {
    const lat = Number(req.query.lat), lng = Number(req.query.lng)
    const radio = Number(req.query.radio || 10000)
    if (!lat || !lng || Number.isNaN(lat) || Number.isNaN(lng)) {
      return res.status(400).json({ error: 'Parámetros lat y lng requeridos.' })
    }
    const { rows } = await pool.query(
      `SELECT h.id, h.titulo, h.tipo, h.ciudad, h.barrio, h.localidad, h.precio_noche, h.precio_dia, h.rating,
              ROUND(ST_Distance(h.ubicacion, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography)) AS distancia_m
         FROM hospedajes h
        WHERE h.activo
          AND h.ciudad = 'Bogotá'
          AND ST_DWithin(h.ubicacion, ST_SetSRID(ST_MakePoint($2, $1), 4326)::geography, $3)
        ORDER BY distancia_m`,
      [lat, lng, radio]
    )
    res.json({ total: rows.length, hospedajes: rows })
  } catch (err) { next(err) }
})

// ---- Conteo de hospedajes activos por localidad (mapa/búsqueda segmentados) ----
// IMPORTANTE: debe ir antes de GET /:id (si no, Express interpreta "localidades" como un :id).
r.get('/localidades', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT localidad, COUNT(*)::int AS hospedajes
         FROM hospedajes
        WHERE activo = TRUE AND ciudad = 'Bogotá' AND localidad IS NOT NULL
        GROUP BY localidad`
    )
    const conteos = Object.fromEntries(rows.map((fila) => [fila.localidad, fila.hospedajes]))
    // Incluye TODAS las localidades, aunque tengan 0 hospedajes — así la lista/mapa del
    // cliente no tiene que saber de antemano cuáles son las 20 para completar los ceros.
    const localidades = LOCALIDADES_BOGOTA.map((nombre) => ({
      localidad: nombre,
      hospedajes: conteos[nombre] || 0
    }))
    res.json({ localidades })
  } catch (err) { next(err) }
})

// ---- Mis hospedajes (anfitrión) ----
// IMPORTANTE: debe ir antes de GET /:id (si no, Express interpreta "mios" como un :id).
r.get('/mios', auth, soloAnfitrion, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT h.*, u.nombre AS anfitrion_nombre, u.verificado AS anfitrion_verificado,
              ST_Y(h.ubicacion::geometry) AS lat, ST_X(h.ubicacion::geometry) AS lng
         FROM hospedajes h JOIN usuarios u ON u.id = h.anfitrion_id
        WHERE h.anfitrion_id = $1
        ORDER BY h.creado_en DESC`,
      [req.usuario.id]
    )
    res.json({ hospedajes: rows })
  } catch (err) { next(err) }
})

// ---- Historial: TODAS las reservas de TODOS mis hospedajes (anfitrión) ----
// IMPORTANTE: debe ir antes de GET /:id/reservas (si no, Express interpreta "mios" como :id).
// A diferencia de /:id/reservas (una sola propiedad, con acciones de aceptar/rechazar), esta
// es de solo lectura — la tabla de historial de la app (ver Features/Anfitrion/
// HistorialReservasView.swift), con TODOS los estados (no solo pendientes) para que el
// anfitrión vea el panorama completo de cuánto ha ganado con cada hospedaje.
r.get('/mios/reservas', auth, soloAnfitrion, async (req, res, next) => {
  try {
    await completarReservasVencidas()
    const { rows } = await pool.query(
      `SELECT rs.*, h.titulo AS hospedaje_titulo, u.nombre AS usuario_nombre,
              u.rating AS usuario_rating, u.num_resenas AS usuario_num_resenas,
              pg.comision_porcentaje, pg.comision_monto, pg.monto_anfitrion,
              ${MASCOTAS_DETALLE_SQL}
         FROM reservas rs
         JOIN hospedajes h ON h.id = rs.hospedaje_id
         JOIN usuarios u ON u.id = rs.usuario_id
         LEFT JOIN pagos pg ON pg.reserva_id = rs.id
        WHERE h.anfitrion_id = $1
        ORDER BY rs.creado_en DESC`,
      [req.usuario.id]
    )
    res.json({ reservas: rows })
  } catch (err) { next(err) }
})

// ---- Reservas recibidas en un hospedaje propio ----
r.get('/:id/reservas', auth, async (req, res, next) => {
  try {
    const { rows: h } = await pool.query('SELECT anfitrion_id FROM hospedajes WHERE id = $1', [req.params.id])
    if (!h.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })
    if (h[0].anfitrion_id !== req.usuario.id) {
      return res.status(403).json({ error: 'No eres el anfitrión de este hospedaje.' })
    }

    // Pone al día 'confirmada'/'pendiente' vencidas antes de listar (ver
    // db/16-completar-reservas-vencidas.sql) — así "Calificar huésped" aparece apenas la
    // estadía ya ocurrió, sin depender de un job en segundo plano.
    await completarReservasVencidas()

    // usuario_rating/usuario_num_resenas: la evaluación del huésped (ver
    // db/15-resenas-huesped.sql) — el anfitrión la ve de un vistazo al revisar la solicitud,
    // antes de aceptar o rechazar; el detalle completo (comentarios) está en
    // GET /api/usuarios/:id/resenas.
    const { rows } = await pool.query(
      `SELECT rs.*, h.titulo AS hospedaje_titulo, u.nombre AS usuario_nombre,
              u.rating AS usuario_rating, u.num_resenas AS usuario_num_resenas,
              pg.comision_porcentaje, pg.comision_monto, pg.monto_anfitrion,
              ${MASCOTAS_DETALLE_SQL}
         FROM reservas rs
         JOIN hospedajes h ON h.id = rs.hospedaje_id
         JOIN usuarios u ON u.id = rs.usuario_id
         LEFT JOIN pagos pg ON pg.reserva_id = rs.id
        WHERE rs.hospedaje_id = $1
        ORDER BY rs.desde DESC`,
      [req.params.id]
    )
    res.json({ reservas: rows })
  } catch (err) { next(err) }
})

// ---- Fechas ya ocupadas de un hospedaje (pública, sin datos del huésped) ----
// El huésped la usa para ver, ANTES de elegir fechas, cuáles ya están tomadas — evita que
// arme una solicitud para fechas que de todos modos van a rechazarse al confirmar. A
// diferencia de GET /:id/reservas (solo el anfitrión, trae nombre/rating del huésped), esta
// es pública y solo expone rangos de fecha, nada de quién reservó.
r.get('/:id/disponibilidad', async (req, res, next) => {
  try {
    // Une reservas reales con fechas que el anfitrión bloqueó a mano (ver
    // db/34-fechas-bloqueadas.sql) — el huésped ve ambas igual de "ocupadas", sin
    // distinción (no le importa POR QUÉ una fecha no está disponible).
    const { rows } = await pool.query(
      `SELECT desde, hasta, estado FROM reservas
        WHERE hospedaje_id = $1 AND estado IN ('confirmada', 'pendiente')
       UNION ALL
       SELECT desde, hasta, 'bloqueada' AS estado FROM hospedaje_fechas_bloqueadas
        WHERE hospedaje_id = $1
        ORDER BY desde ASC`,
      [req.params.id]
    )
    res.json({ ocupado: rows })
  } catch (err) { next(err) }
})

// ---- Fechas bloqueadas manualmente por el anfitrión (dueño) ----
// A diferencia de pausar el hospedaje entero (PATCH /:id { activo }), esto bloquea fechas
// puntuales sin esconder el hospedaje de Buscar — ver db/34-fechas-bloqueadas.sql.
r.get('/:id/fechas-bloqueadas', auth, soloAnfitrion, async (req, res, next) => {
  try {
    const { rows: h } = await pool.query('SELECT anfitrion_id FROM hospedajes WHERE id = $1', [req.params.id])
    if (!h.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })
    if (h[0].anfitrion_id !== req.usuario.id) {
      return res.status(403).json({ error: 'No eres el anfitrión de este hospedaje.' })
    }
    const { rows } = await pool.query(
      `SELECT id, desde, hasta, motivo, creado_en FROM hospedaje_fechas_bloqueadas
        WHERE hospedaje_id = $1 ORDER BY desde ASC`,
      [req.params.id]
    )
    res.json({ bloqueos: rows })
  } catch (err) { next(err) }
})

r.post('/:id/fechas-bloqueadas', auth, soloAnfitrion, async (req, res, next) => {
  try {
    const { rows: h } = await pool.query('SELECT anfitrion_id FROM hospedajes WHERE id = $1', [req.params.id])
    if (!h.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })
    if (h[0].anfitrion_id !== req.usuario.id) {
      return res.status(403).json({ error: 'No eres el anfitrión de este hospedaje.' })
    }

    const { desde, hasta, motivo } = req.body || {}
    if (!desde || !hasta) return res.status(400).json({ error: 'Faltan desde o hasta.' })
    if (hasta <= desde) return res.status(400).json({ error: 'La fecha final debe ser posterior a la inicial.' })

    // No dejar bloquear fechas que ya tienen una reserva real — el anfitrión debe
    // resolver esa solicitud (aceptar/rechazar) antes de poder bloquearlas.
    const { rows: conReserva } = await pool.query(
      `SELECT 1 FROM reservas
        WHERE hospedaje_id = $1 AND estado IN ('confirmada', 'pendiente')
          AND daterange(desde, hasta) && daterange($2::date, $3::date) LIMIT 1`,
      [req.params.id, desde, hasta]
    )
    if (conReserva.length) {
      return res.status(409).json({ error: 'Ya hay una reserva en alguna de esas fechas — no se pueden bloquear.' })
    }

    const { rows } = await pool.query(
      `INSERT INTO hospedaje_fechas_bloqueadas (hospedaje_id, desde, hasta, motivo)
       VALUES ($1, $2, $3, $4) RETURNING id, desde, hasta, motivo, creado_en`,
      [req.params.id, desde, hasta, motivo || null]
    )
    res.status(201).json({ bloqueo: rows[0] })
  } catch (err) {
    if (err.code === '23P01') return res.status(409).json({ error: 'Esas fechas se cruzan con otro bloqueo ya creado.' })
    next(err)
  }
})

r.delete('/:id/fechas-bloqueadas/:bloqueoId', auth, soloAnfitrion, async (req, res, next) => {
  try {
    const { rows: h } = await pool.query('SELECT anfitrion_id FROM hospedajes WHERE id = $1', [req.params.id])
    if (!h.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })
    if (h[0].anfitrion_id !== req.usuario.id) {
      return res.status(403).json({ error: 'No eres el anfitrión de este hospedaje.' })
    }
    const { rowCount } = await pool.query(
      'DELETE FROM hospedaje_fechas_bloqueadas WHERE id = $1 AND hospedaje_id = $2',
      [req.params.bloqueoId, req.params.id]
    )
    if (!rowCount) return res.status(404).json({ error: 'Bloqueo no encontrado.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Detalle: hospedaje + anfitrión + reseñas ----
r.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT h.*, u.nombre AS anfitrion_nombre, u.verificado AS anfitrion_verificado,
              ST_Y(h.ubicacion::geometry) AS lat, ST_X(h.ubicacion::geometry) AS lng
         FROM hospedajes h JOIN usuarios u ON u.id = h.anfitrion_id
        WHERE h.id = $1`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })

    const { rows: resenas } = await pool.query(
      `SELECT rs.id, rs.rating, rs.titulo, rs.texto, rs.creado_en,
              rs.respuesta_anfitrion, rs.respuesta_en, u.nombre AS autor
         FROM resenas rs JOIN usuarios u ON u.id = rs.autor_id
        WHERE rs.hospedaje_id = $1 ORDER BY rs.creado_en DESC LIMIT 20`,
      [req.params.id]
    )
    res.json({ hospedaje: rows[0], resenas })
  } catch (err) { next(err) }
})

// ---- Crear hospedaje (anfitrión) ----
r.post('/', auth, soloAnfitrion, async (req, res, next) => {
  try {
    const { titulo, tipo, descripcion, localidad, barrio, lat, lng, coberturaRadioM,
            precioNoche, precioDia, convivencia, maxMascotas, servicios, reglas, fotos } = req.body || {}

    if (!titulo || !tipo || !descripcion || !localidad || lat == null || lng == null || !precioNoche) {
      return res.status(400).json({ error: 'Faltan campos obligatorios (titulo, tipo, descripcion, localidad, lat, lng, precioNoche).' })
    }
    if (!LOCALIDADES_BOGOTA.includes(localidad)) {
      return res.status(400).json({ error: 'localidad debe ser una de las 20 localidades de Bogotá.' })
    }

    const { rows } = await pool.query(
      `INSERT INTO hospedajes
         (anfitrion_id, tipo, titulo, descripcion, ciudad, barrio, localidad, ubicacion, cobertura_radio_m,
          precio_noche, precio_dia, convivencia, max_mascotas, servicios, reglas, fotos)
       VALUES ($1, $2, $3, $4, 'Bogotá', $5, $6, ST_SetSRID(ST_MakePoint($7, $8), 4326), $9, $10, $11, $12, $13, $14, $15, $16)
       RETURNING id, titulo, tipo, ciudad, localidad, precio_noche, precio_dia`,
      [req.usuario.id, tipo, titulo, descripcion, barrio || null, localidad, Number(lng), Number(lat),
       coberturaRadioM || null, Number(precioNoche), precioDia ? Number(precioDia) : null, convivencia || 'cualquiera',
       Number(maxMascotas || 1), servicios || [], reglas || [], fotos || []]
    )
    res.status(201).json({ hospedaje: rows[0] })
  } catch (err) { next(err) }
})

// ---- Editar hospedaje propio (anfitrión dueño) ----
r.patch('/:id', auth, soloAnfitrion, async (req, res, next) => {
  try {
    const { rows: h } = await pool.query('SELECT anfitrion_id FROM hospedajes WHERE id = $1', [req.params.id])
    if (!h.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })
    if (h[0].anfitrion_id !== req.usuario.id) {
      return res.status(403).json({ error: 'No eres el anfitrión de este hospedaje.' })
    }

    const { titulo, tipo, descripcion, localidad, barrio, lat, lng, coberturaRadioM,
            precioNoche, precioDia, convivencia, maxMascotas, servicios, reglas, fotos, activo } = req.body || {}

    if (localidad !== undefined && !LOCALIDADES_BOGOTA.includes(localidad)) {
      return res.status(400).json({ error: 'localidad debe ser una de las 20 localidades de Bogotá.' })
    }

    const campos = []
    const valores = []
    const set = (col, val) => { valores.push(val); campos.push(`${col} = $${valores.length}`) }
    if (titulo !== undefined) set('titulo', titulo)
    if (tipo !== undefined) set('tipo', tipo)
    if (descripcion !== undefined) set('descripcion', descripcion)
    if (localidad !== undefined) set('localidad', localidad)
    if (barrio !== undefined) set('barrio', barrio || null)
    if (coberturaRadioM !== undefined) set('cobertura_radio_m', coberturaRadioM || null)
    if (precioNoche !== undefined) set('precio_noche', precioNoche)
    // `null`/vacío desactiva la opción de un solo día para este hospedaje (no exige tenerla).
    if (precioDia !== undefined) set('precio_dia', precioDia || null)
    if (convivencia !== undefined) set('convivencia', convivencia)
    if (maxMascotas !== undefined) set('max_mascotas', maxMascotas)
    if (servicios !== undefined) set('servicios', servicios || [])
    if (reglas !== undefined) set('reglas', reglas || [])
    if (fotos !== undefined) set('fotos', fotos || [])
    // Pausar/reactivar (ver "Pausar hospedaje" en el cliente): un hospedaje pausado
    // (activo = FALSE) no aparece en Buscar ni en el mapa, pero no se borra — el anfitrión
    // conserva su historial de reservas y reseñas, y puede reactivarlo cuando quiera.
    if (activo !== undefined) set('activo', activo)
    if (lat !== undefined && lng !== undefined) {
      valores.push(Number(lng), Number(lat))
      campos.push(`ubicacion = ST_SetSRID(ST_MakePoint($${valores.length - 1}, $${valores.length}), 4326)`)
    }

    if (!campos.length) return res.status(400).json({ error: 'No hay nada que actualizar.' })

    valores.push(req.params.id)
    // Devuelve la fila completa (con lat/lng ya extraídos), mismo shape que GET /:id — así
    // el cliente puede reemplazar el hospedaje editado en su lista sin perder ningún campo
    // (a diferencia de POST /, que solo devuelve un subconjunto mínimo).
    const { rows } = await pool.query(
      `UPDATE hospedajes SET ${campos.join(', ')}
        WHERE id = $${valores.length}
        RETURNING *, ST_Y(ubicacion::geometry) AS lat, ST_X(ubicacion::geometry) AS lng`,
      valores
    )
    res.json({ hospedaje: rows[0] })
  } catch (err) { next(err) }
})

export default r
