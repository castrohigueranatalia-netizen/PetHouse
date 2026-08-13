// ============================================================
// PETHOUSE API · Módulo Hospedajes (PostGIS)
// GET /api/hospedajes?localidad&tipo&convivencia&desde&hasta&lat&lng&radio&q&orden&pagina&porPagina
//   La app opera solo en Bogotá — todo listado/búsqueda se filtra a `ciudad = 'Bogotá'`
//   siempre, y se segmenta por `localidad` en vez de una `ciudad` de texto libre.
// GET /api/hospedajes/localidades  → conteo de hospedajes por cada una de las 20 localidades
// GET /api/hospedajes/cerca?lat&lng&radio
// GET /api/hospedajes/:id
// POST /api/hospedajes   (anfitrión)
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth, soloAnfitrion } from '../middleware/middleware.js'
import { MASCOTAS_DETALLE_SQL } from '../lib/mascotasDetalleSql.js'

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
    const { localidad, tipo, convivencia, desde, hasta, lat, lng, radio, q, orden } = req.query
    // Antes esto era un `LIMIT 100` fijo sin forma de pedir más — el cliente hacía su
    // propia "paginación" revelando de a poco ese máximo de 100 ya descargado (ver
    // MVP_SCOPE.md #7). Ahora pagina de verdad contra la base.
    const pagina = Math.max(1, parseInt(req.query.pagina, 10) || 1)
    const porPagina = Math.min(50, Math.max(1, parseInt(req.query.porPagina, 10) || 20))
    const offset = (pagina - 1) * porPagina

    // La app es solo de Bogotá (ver encabezado del archivo): esta condición no depende de
    // ningún query param, siempre está.
    const condiciones = ['h.activo = TRUE', "h.ciudad = 'Bogotá'"]
    const params = []

    if (tipo) { params.push(tipo); condiciones.push(`h.tipo = $${params.length}`) }
    if (convivencia) { params.push(convivencia); condiciones.push(`h.convivencia = $${params.length}`) }
    if (localidad) { params.push(localidad); condiciones.push(`h.localidad = $${params.length}`) }
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
      SELECT h.id, h.titulo, h.tipo, h.ciudad, h.barrio, h.localidad, h.precio_noche, h.convivencia,
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
      `SELECT h.id, h.titulo, h.tipo, h.ciudad, h.barrio, h.localidad, h.precio_noche, h.rating,
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

// ---- Reservas recibidas en un hospedaje propio ----
r.get('/:id/reservas', auth, async (req, res, next) => {
  try {
    const { rows: h } = await pool.query('SELECT anfitrion_id FROM hospedajes WHERE id = $1', [req.params.id])
    if (!h.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })
    if (h[0].anfitrion_id !== req.usuario.id) {
      return res.status(403).json({ error: 'No eres el anfitrión de este hospedaje.' })
    }

    // usuario_rating/usuario_num_resenas: la evaluación del huésped (ver
    // db/15-resenas-huesped.sql) — el anfitrión la ve de un vistazo al revisar la solicitud,
    // antes de aceptar o rechazar; el detalle completo (comentarios) está en
    // GET /api/usuarios/:id/resenas.
    const { rows } = await pool.query(
      `SELECT rs.*, h.titulo AS hospedaje_titulo, u.nombre AS usuario_nombre,
              u.rating AS usuario_rating, u.num_resenas AS usuario_num_resenas,
              ${MASCOTAS_DETALLE_SQL}
         FROM reservas rs
         JOIN hospedajes h ON h.id = rs.hospedaje_id
         JOIN usuarios u ON u.id = rs.usuario_id
        WHERE rs.hospedaje_id = $1
        ORDER BY rs.desde DESC`,
      [req.params.id]
    )
    res.json({ reservas: rows })
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
      `SELECT rs.rating, rs.titulo, rs.texto, rs.creado_en, u.nombre AS autor
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
            precioNoche, convivencia, maxMascotas, servicios, reglas, fotos } = req.body || {}

    if (!titulo || !tipo || !descripcion || !localidad || lat == null || lng == null || !precioNoche) {
      return res.status(400).json({ error: 'Faltan campos obligatorios (titulo, tipo, descripcion, localidad, lat, lng, precioNoche).' })
    }
    if (!LOCALIDADES_BOGOTA.includes(localidad)) {
      return res.status(400).json({ error: 'localidad debe ser una de las 20 localidades de Bogotá.' })
    }

    const { rows } = await pool.query(
      `INSERT INTO hospedajes
         (anfitrion_id, tipo, titulo, descripcion, ciudad, barrio, localidad, ubicacion, cobertura_radio_m,
          precio_noche, convivencia, max_mascotas, servicios, reglas, fotos)
       VALUES ($1, $2, $3, $4, 'Bogotá', $5, $6, ST_SetSRID(ST_MakePoint($7, $8), 4326), $9, $10, $11, $12, $13, $14, $15)
       RETURNING id, titulo, tipo, ciudad, localidad, precio_noche`,
      [req.usuario.id, tipo, titulo, descripcion, barrio || null, localidad, Number(lng), Number(lat),
       coberturaRadioM || null, Number(precioNoche), convivencia || 'cualquiera',
       Number(maxMascotas || 1), servicios || [], reglas || [], fotos || []]
    )
    res.status(201).json({ hospedaje: rows[0] })
  } catch (err) { next(err) }
})

export default r
