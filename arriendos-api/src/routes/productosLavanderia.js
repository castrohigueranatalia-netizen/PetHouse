// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Productos de lavandería (inventario)
// cantidad/valor_unitario de un producto se calculan a partir de su
// historial de compras (compras_producto_lavanderia), no se editan sueltos.
// GET /api/productos-lavanderia · POST / · PUT /:id · DELETE /:id
// GET/POST /api/productos-lavanderia/:id/compras · DELETE .../compras/:compraId
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// Recalcula cantidad (suma de lo comprado) y valor_unitario (el de la
// compra más reciente) de un producto a partir de su historial.
async function recalcularProducto(productoId) {
  const { rows } = await pool.query(
    `SELECT COALESCE(SUM(cantidad), 0) AS cantidad,
            (SELECT valor_unitario FROM compras_producto_lavanderia
              WHERE producto_id = $1 ORDER BY fecha_compra DESC, creado_en DESC LIMIT 1) AS ultimo_valor
       FROM compras_producto_lavanderia WHERE producto_id = $1`,
    [productoId]
  )
  const { cantidad, ultimo_valor } = rows[0]
  await pool.query(
    'UPDATE productos_lavanderia SET cantidad = $1, valor_unitario = COALESCE($2, valor_unitario) WHERE id = $3',
    [cantidad, ultimo_valor, productoId]
  )
}

// ---- Listar productos (con su historial de compras) ----
r.get('/', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT p.*, COALESCE((
               SELECT json_agg(json_build_object(
                 'id', c.id, 'fecha_compra', c.fecha_compra, 'cantidad', c.cantidad,
                 'valor_unitario', c.valor_unitario, 'valor_total', c.valor_total, 'notas', c.notas
               ) ORDER BY c.fecha_compra DESC, c.creado_en DESC)
               FROM compras_producto_lavanderia c WHERE c.producto_id = p.id
             ), '[]') AS compras
        FROM productos_lavanderia p
       ORDER BY p.nombre
    `)
    res.json({ productos: rows })
  } catch (err) { next(err) }
})

// ---- Crear producto (arranca en 0; el inventario se arma con compras) ----
r.post('/', auth, async (req, res, next) => {
  try {
    const { nombre, unidad } = req.body || {}
    if (!nombre || !String(nombre).trim()) return res.status(400).json({ error: 'Falta el nombre del producto.' })

    const { rows } = await pool.query(
      `INSERT INTO productos_lavanderia (nombre, unidad) VALUES ($1, $2) RETURNING *`,
      [String(nombre).trim(), unidad || 'unidades']
    )
    res.status(201).json({ producto: { ...rows[0], compras: [] } })
  } catch (err) { next(err) }
})

// ---- Editar producto (solo nombre/unidad; cantidad/valor se calculan solas) ----
r.put('/:id', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const columnas = { nombre: (v) => String(v).trim(), unidad: (v) => v }

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

// ---- Eliminar producto (su historial de compras se borra en cascada) ----
r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM productos_lavanderia WHERE id = $1', [req.params.id])
    if (!rowCount) return res.status(404).json({ error: 'Producto no encontrado.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Registrar una compra de un producto ----
r.post('/:id/compras', auth, async (req, res, next) => {
  try {
    const { fecha_compra, cantidad, valor_unitario, notas } = req.body || {}
    if (!fecha_compra) return res.status(400).json({ error: 'Falta la fecha de la compra.' })
    if (!(Number(cantidad) > 0)) return res.status(400).json({ error: 'La cantidad comprada debe ser mayor a 0.' })
    if (!(Number(valor_unitario) >= 0)) return res.status(400).json({ error: 'El valor por unidad no puede ser negativo.' })

    const { rows } = await pool.query(
      `INSERT INTO compras_producto_lavanderia (producto_id, fecha_compra, cantidad, valor_unitario, notas)
       VALUES ($1,$2,$3,$4,$5) RETURNING *`,
      [req.params.id, fecha_compra, cantidad, valor_unitario, notas || null]
    )
    await recalcularProducto(req.params.id)
    res.status(201).json({ compra: rows[0] })
  } catch (err) {
    if (err.code === '23503') return res.status(404).json({ error: 'Producto no encontrado.' })
    next(err)
  }
})

// ---- Quitar una compra registrada ----
r.delete('/:id/compras/:compraId', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query(
      'DELETE FROM compras_producto_lavanderia WHERE id = $1 AND producto_id = $2',
      [req.params.compraId, req.params.id]
    )
    if (!rowCount) return res.status(404).json({ error: 'Compra no encontrada.' })
    await recalcularProducto(req.params.id)
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
