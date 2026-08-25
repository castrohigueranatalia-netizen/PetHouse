// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Reservas
// GET /api/reservas · GET /:id · POST / · PUT /:id
// POST /:id/cancelar · DELETE /:id
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

const FUENTES = ['booking', 'airbnb', 'whatsapp', 'directo', 'otro']
const ESTADOS = ['confirmada', 'pendiente', 'cancelada']

// ---- Listar reservas (filtros: apartamento_id, desde, hasta, estado, fuente) ----
// "desde"/"hasta" filtran por solapamiento con ese rango, útil para la vista de calendario.
r.get('/', auth, async (req, res, next) => {
  try {
    const { apartamento_id, desde, hasta, estado, fuente } = req.query
    const condiciones = []
    const valores = []

    if (apartamento_id) { valores.push(apartamento_id); condiciones.push(`rs.apartamento_id = $${valores.length}`) }
    if (estado) { valores.push(estado); condiciones.push(`rs.estado = $${valores.length}`) }
    if (fuente) { valores.push(fuente); condiciones.push(`rs.fuente = $${valores.length}`) }
    if (desde) { valores.push(desde); condiciones.push(`rs.checkout > $${valores.length}`) }
    if (hasta) { valores.push(hasta); condiciones.push(`rs.checkin < $${valores.length}`) }

    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''
    const { rows } = await pool.query(
      `SELECT rs.*, a.nombre AS apartamento_nombre
         FROM reservas rs JOIN apartamentos a ON a.id = rs.apartamento_id
        ${where}
        ORDER BY rs.checkin`,
      valores
    )
    res.json({ reservas: rows })
  } catch (err) { next(err) }
})

// ---- Detalle de una reserva ----
r.get('/:id', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT rs.*, a.nombre AS apartamento_nombre
         FROM reservas rs JOIN apartamentos a ON a.id = rs.apartamento_id
        WHERE rs.id = $1`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Reserva no encontrada.' })
    res.json({ reserva: rows[0] })
  } catch (err) { next(err) }
})

function validarCuerpo(body, { requerirApartamento }) {
  const { apartamento_id, checkin, checkout, fuente, estado, num_huespedes } = body
  if (requerirApartamento && !apartamento_id) return 'Falta el apartamento.'
  if (requerirApartamento && (!checkin || !checkout)) return 'Faltan las fechas de entrada y salida.'
  if (checkin && checkout && checkout <= checkin) return 'La fecha de salida debe ser posterior a la de entrada.'
  if (fuente && !FUENTES.includes(fuente)) return `Fuente inválida (usa: ${FUENTES.join(', ')}).`
  if (estado && !ESTADOS.includes(estado)) return `Estado inválido (usa: ${ESTADOS.join(', ')}).`
  if (num_huespedes !== undefined && Number(num_huespedes) < 1) return 'El número de huéspedes debe ser al menos 1.'
  return null
}

// ---- Crear reserva manual (WhatsApp, directo, etc.) ----
r.post('/', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const error = validarCuerpo(body, { requerirApartamento: true })
    if (error) return res.status(400).json({ error })

    const {
      apartamento_id, huesped_nombre, huesped_telefono, checkin, checkout,
      num_huespedes = 1, precio_total, fuente = 'directo', estado = 'confirmada', notas
    } = body

    const { rows } = await pool.query(
      `INSERT INTO reservas
         (apartamento_id, huesped_nombre, huesped_telefono, checkin, checkout,
          num_huespedes, precio_total, fuente, estado, notas)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
       RETURNING *`,
      [apartamento_id, huesped_nombre || null, huesped_telefono || null, checkin, checkout,
        num_huespedes, precio_total || null, fuente, estado, notas || null]
    )
    res.status(201).json({ reserva: rows[0] })
  } catch (err) { next(err) } // 23P01 (EXCLUDE) → 409 vía el manejador global
})

// ---- Editar reserva ----
r.put('/:id', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const error = validarCuerpo(body, { requerirApartamento: false })
    if (error) return res.status(400).json({ error })

    const campos = ['apartamento_id', 'huesped_nombre', 'huesped_telefono', 'checkin', 'checkout',
      'num_huespedes', 'precio_total', 'fuente', 'estado', 'notas']
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
      `UPDATE reservas SET ${sets.join(', ')} WHERE id = $${valores.length} RETURNING *`,
      valores
    )
    if (!rows.length) return res.status(404).json({ error: 'Reserva no encontrada.' })
    res.json({ reserva: rows[0] })
  } catch (err) { next(err) }
})

// ---- Cancelar (libera las fechas sin borrar el historial) ----
r.post('/:id/cancelar', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE reservas SET estado = 'cancelada' WHERE id = $1 RETURNING *`,
      [req.params.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Reserva no encontrada.' })
    res.json({ reserva: rows[0] })
  } catch (err) { next(err) }
})

// ---- Eliminar (para corregir un registro mal digitado) ----
r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM reservas WHERE id = $1', [req.params.id])
    if (!rowCount) return res.status(404).json({ error: 'Reserva no encontrada.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
