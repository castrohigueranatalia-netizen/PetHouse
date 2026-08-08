// ============================================================
// PETHOUSE API · Módulo Reservas
// POST /api/reservas · GET /api/reservas/mias · GET /api/reservas/:id
// POST /api/reservas/:id/cancelar · POST /api/reservas/:id/plan
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// ---- Crear reserva (cotiza y valida disponibilidad) ----
r.post('/', auth, async (req, res, next) => {
  const client = await pool.connect()
  try {
    const { hospedaje_id, desde, hasta, mascotas = 1 } = req.body || {}
    if (!hospedaje_id || !desde || !hasta) {
      return res.status(400).json({ error: 'Faltan hospedaje_id, desde o hasta.' })
    }
    if (hasta <= desde) return res.status(400).json({ error: 'La fecha de salida debe ser posterior a la llegada.' })
    if (new Date(desde) < new Date(new Date().toDateString())) {
      return res.status(400).json({ error: 'La fecha de llegada no puede ser anterior a hoy.' })
    }

    await client.query('BEGIN')

    // Bloquea la fila del hospedaje para evitar carreras de reserva
    const { rows: hs } = await client.query(
      'SELECT id, titulo, precio_noche, max_mascotas, convivencia FROM hospedajes WHERE id = $1 FOR UPDATE',
      [hospedaje_id]
    )
    if (!hs.length) { await client.query('ROLLBACK'); return res.status(404).json({ error: 'Hospedaje no encontrado.' }) }
    const h = hs[0]

    if (mascotas > h.max_mascotas) {
      await client.query('ROLLBACK')
      return res.status(400).json({ error: `Este hospedaje admite máximo ${h.max_mascotas} mascotas.` })
    }

    const noches = Math.round((new Date(hasta) - new Date(desde)) / 86400000)
    const limpieza = Math.round(h.precio_noche * 0.6)
    const servicio = Math.round(h.precio_noche * noches * 0.1)

    const { rows } = await client.query(
      `INSERT INTO reservas (usuario_id, hospedaje_id, desde, hasta, mascotas, precio_noche, limpieza, servicio)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, codigo, desde, hasta, noches, mascotas, precio_noche, limpieza, servicio, total, estado, creado_en`,
      [req.usuario.id, hospedaje_id, desde, hasta, mascotas, h.precio_noche, limpieza, servicio]
    )

    // Pago pendiente (fase 2: pasarela)
    await client.query(
      'INSERT INTO pagos (reserva_id, monto, estado) VALUES ($1, $2, $3)',
      [rows[0].id, rows[0].total, 'pendiente']
    )

    await client.query('COMMIT')
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
    const { rows } = await pool.query(
      `SELECT rs.id, rs.codigo, rs.desde, rs.hasta, rs.noches, rs.mascotas, rs.total, rs.estado,
              h.titulo AS hospedaje_titulo, h.ciudad, h.barrio, h.tipo, h.fotos
         FROM reservas rs JOIN hospedajes h ON h.id = rs.hospedaje_id
        WHERE rs.usuario_id = $1
        ORDER BY rs.creado_en DESC`,
      [req.usuario.id]
    )
    res.json({ reservas: rows })
  } catch (err) { next(err) }
})

// ---- Detalle de reserva (dueño o anfitrión del hospedaje) ----
r.get('/:id', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT rs.*, h.titulo AS hospedaje_titulo, h.anfitrion_id
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

// ---- Cancelar reserva ----
r.post('/:id/cancelar', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `UPDATE reservas SET estado = 'cancelada'
        WHERE id = $1 AND usuario_id = $2 AND estado = 'confirmada'
        RETURNING id, codigo, estado`,
      [req.params.id, req.usuario.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Reserva no encontrada o ya cancelada.' })
    res.json({ reserva: rows[0] })
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
