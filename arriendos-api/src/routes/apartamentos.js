// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Apartamentos
// GET /api/apartamentos · GET /:id · POST / · PUT /:id
// ============================================================
import { Router } from 'express'
import { pool, PUBLIC_URL } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

function conUrlExportar(apto) {
  return { ...apto, ical_url_exportar: `${PUBLIC_URL}/api/apartamentos/${apto.id}/calendario.ics?token=${apto.ical_token}` }
}

// ---- Listar apartamentos (incluye inactivos si ?todos=1) ----
r.get('/', auth, async (req, res, next) => {
  try {
    const soloActivos = req.query.todos !== '1'
    const { rows } = await pool.query(
      `SELECT id, nombre, descripcion, capacidad, precio_noche_base,
              ical_url_importar, ical_token, ical_ultima_sync, ical_ultimo_error,
              activo, creado_en
         FROM apartamentos
        ${soloActivos ? 'WHERE activo' : ''}
        ORDER BY nombre`
    )
    res.json({ apartamentos: rows.map(conUrlExportar) })
  } catch (err) { next(err) }
})

// ---- Detalle de un apartamento ----
r.get('/:id', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM apartamentos WHERE id = $1', [req.params.id])
    if (!rows.length) return res.status(404).json({ error: 'Apartamento no encontrado.' })
    res.json({ apartamento: conUrlExportar(rows[0]) })
  } catch (err) { next(err) }
})

// ---- Crear apartamento (por si en el futuro son más de 7) ----
r.post('/', auth, async (req, res, next) => {
  try {
    const { nombre, descripcion, capacidad = 2, precio_noche_base } = req.body || {}
    if (!nombre || !String(nombre).trim()) return res.status(400).json({ error: 'Falta el nombre del apartamento.' })

    const { rows } = await pool.query(
      `INSERT INTO apartamentos (nombre, descripcion, capacidad, precio_noche_base)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [String(nombre).trim(), descripcion || null, capacidad, precio_noche_base || null]
    )
    res.status(201).json({ apartamento: conUrlExportar(rows[0]) })
  } catch (err) { next(err) }
})

// ---- Editar apartamento (datos básicos, precio, link de Booking/Airbnb, activo) ----
// Solo toca las columnas cuya clave viene presente en el body (permite, por
// ejemplo, mandar ical_url_importar: "" para borrar el link sin afectar lo demás).
r.put('/:id', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const columnas = {
      nombre: (v) => String(v).trim(),
      descripcion: (v) => v,
      capacidad: (v) => v,
      precio_noche_base: (v) => v,
      ical_url_importar: (v) => (String(v).trim() === '' ? null : String(v).trim()),
      activo: (v) => Boolean(v)
    }

    const sets = []
    const valores = []
    for (const [campo, normalizar] of Object.entries(columnas)) {
      if (campo in body) {
        valores.push(normalizar(body[campo]))
        sets.push(`${campo} = $${valores.length}`)
      }
    }
    if (!sets.length) return res.status(400).json({ error: 'No enviaste ningún dato para actualizar.' })

    valores.push(req.params.id)
    const { rows } = await pool.query(
      `UPDATE apartamentos SET ${sets.join(', ')} WHERE id = $${valores.length} RETURNING *`,
      valores
    )
    if (!rows.length) return res.status(404).json({ error: 'Apartamento no encontrado.' })
    res.json({ apartamento: conUrlExportar(rows[0]) })
  } catch (err) { next(err) }
})

export default r
