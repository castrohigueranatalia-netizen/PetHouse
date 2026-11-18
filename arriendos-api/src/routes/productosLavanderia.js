// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Productos de lavandería (inventario)
// GET /api/productos-lavanderia · POST / · PUT /:id · DELETE /:id
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// ---- Listar productos ----
r.get('/', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT * FROM productos_lavanderia ORDER BY nombre')
    res.json({ productos: rows })
  } catch (err) { next(err) }
})

// ---- Crear producto ----
r.post('/', auth, async (req, res, next) => {
  try {
    const { nombre, cantidad, unidad, valor_unitario } = req.body || {}
    if (!nombre || !String(nombre).trim()) return res.status(400).json({ error: 'Falta el nombre del producto.' })

    const { rows } = await pool.query(
      `INSERT INTO productos_lavanderia (nombre, cantidad, unidad, valor_unitario) VALUES ($1,$2,$3,$4) RETURNING *`,
      [String(nombre).trim(), cantidad || 0, unidad || 'unidades', valor_unitario || null]
    )
    res.status(201).json({ producto: rows[0] })
  } catch (err) { next(err) }
})

// ---- Editar producto ----
r.put('/:id', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const columnas = {
      nombre: (v) => String(v).trim(),
      cantidad: (v) => v,
      unidad: (v) => v,
      valor_unitario: (v) => v
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
      `UPDATE productos_lavanderia SET ${sets.join(', ')} WHERE id = $${valores.length} RETURNING *`,
      valores
    )
    if (!rows.length) return res.status(404).json({ error: 'Producto no encontrado.' })
    res.json({ producto: rows[0] })
  } catch (err) { next(err) }
})

// ---- Eliminar producto ----
r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM productos_lavanderia WHERE id = $1', [req.params.id])
    if (!rowCount) return res.status(404).json({ error: 'Producto no encontrado.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
