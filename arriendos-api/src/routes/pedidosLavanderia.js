// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Pedidos de lavandería
// GET /api/pedidos-lavanderia · POST / · PUT /:id · DELETE /:id
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

const ESTADOS = ['en_proceso', 'entregado']
const TIPOS_SERVICIO = ['lavado', 'planchado', 'lavado_y_planchado']

// ---- Listar pedidos ----
r.get('/', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT pl.*, p.nombre AS personal_nombre
         FROM pedidos_lavanderia pl
         LEFT JOIN personal_limpieza p ON p.id = pl.personal_id
        ORDER BY pl.fecha_ingreso DESC, pl.creado_en DESC`
    )
    res.json({ pedidos: rows })
  } catch (err) { next(err) }
})

function validarCuerpo(body, { requerido }) {
  const { fecha_ingreso, estado, num_prendas, tipo_servicio } = body
  if (requerido && !fecha_ingreso) return 'Falta la fecha de ingreso.'
  if (estado && !ESTADOS.includes(estado)) return `Estado inválido (usa: ${ESTADOS.join(', ')}).`
  if (tipo_servicio && !TIPOS_SERVICIO.includes(tipo_servicio)) return `Tipo de servicio inválido (usa: ${TIPOS_SERVICIO.join(', ')}).`
  if (num_prendas !== undefined && num_prendas !== null && Number(num_prendas) <= 0) return 'El número de prendas debe ser mayor a 0.'
  return null
}

// ---- Crear pedido ----
r.post('/', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const error = validarCuerpo(body, { requerido: true })
    if (error) return res.status(400).json({ error })

    const {
      cliente_nombre, cliente_telefono, num_prendas, tipo_servicio = 'lavado', personal_id,
      fecha_ingreso, fecha_entrega, valor, estado = 'en_proceso', notas
    } = body
    const { rows } = await pool.query(
      `INSERT INTO pedidos_lavanderia
         (cliente_nombre, cliente_telefono, num_prendas, tipo_servicio, personal_id, fecha_ingreso, fecha_entrega, valor, estado, notas)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
      [cliente_nombre || null, cliente_telefono || null, num_prendas || null, tipo_servicio, personal_id || null,
        fecha_ingreso, fecha_entrega || null, valor || null, estado, notas || null]
    )
    res.status(201).json({ pedido: rows[0] })
  } catch (err) { next(err) }
})

// ---- Editar pedido ----
r.put('/:id', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const error = validarCuerpo(body, { requerido: false })
    if (error) return res.status(400).json({ error })

    const campos = ['cliente_nombre', 'cliente_telefono', 'num_prendas', 'tipo_servicio', 'personal_id', 'fecha_ingreso', 'fecha_entrega', 'valor', 'estado', 'notas']
    const sets = []
    const valores = []
    for (const campo of campos) {
      if (campo in body) {
        valores.push(body[campo] === '' ? null : body[campo])
        sets.push(`${campo} = $${valores.length}`)
      }
    }
    if (!sets.length) return res.status(400).json({ error: 'No enviaste ningún dato para actualizar.' })

    valores.push(req.params.id)
    const { rows } = await pool.query(
      `UPDATE pedidos_lavanderia SET ${sets.join(', ')} WHERE id = $${valores.length} RETURNING *`,
      valores
    )
    if (!rows.length) return res.status(404).json({ error: 'Pedido no encontrado.' })
    res.json({ pedido: rows[0] })
  } catch (err) { next(err) }
})

// ---- Eliminar pedido ----
r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM pedidos_lavanderia WHERE id = $1', [req.params.id])
    if (!rowCount) return res.status(404).json({ error: 'Pedido no encontrado.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
