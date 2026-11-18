// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Personal de limpieza
// GET /api/personal-limpieza · POST / · PUT /:id · DELETE /:id
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// ---- Listar personal (incluye inactivos si ?todos=1) ----
r.get('/', auth, async (req, res, next) => {
  try {
    const soloActivos = req.query.todos !== '1'
    const { rows } = await pool.query(
      `SELECT id, nombre, telefono, activo, creado_en
         FROM personal_limpieza
        ${soloActivos ? 'WHERE activo' : ''}
        ORDER BY nombre`
    )
    res.json({ personal: rows })
  } catch (err) { next(err) }
})

// ---- Agregar una niña de limpieza ----
r.post('/', auth, async (req, res, next) => {
  try {
    const { nombre, telefono } = req.body || {}
    if (!nombre || !String(nombre).trim()) return res.status(400).json({ error: 'Falta el nombre.' })

    const { rows } = await pool.query(
      `INSERT INTO personal_limpieza (nombre, telefono) VALUES ($1, $2) RETURNING *`,
      [String(nombre).trim(), telefono || null]
    )
    res.status(201).json({ personal: rows[0] })
  } catch (err) { next(err) }
})

// ---- Editar (nombre, teléfono, activo) ----
r.put('/:id', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const columnas = {
      nombre: (v) => String(v).trim(),
      telefono: (v) => (String(v).trim() === '' ? null : String(v).trim()),
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
      `UPDATE personal_limpieza SET ${sets.join(', ')} WHERE id = $${valores.length} RETURNING *`,
      valores
    )
    if (!rows.length) return res.status(404).json({ error: 'No encontrada.' })
    res.json({ personal: rows[0] })
  } catch (err) { next(err) }
})

// ---- Eliminar (las tareas que tenía quedan sin asignar, no se borran) ----
r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM personal_limpieza WHERE id = $1', [req.params.id])
    if (!rowCount) return res.status(404).json({ error: 'No encontrada.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
