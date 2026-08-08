// ============================================================
// PETHOUSE API · Módulo Reseñas (una por reserva; trigger de rating)
// POST /api/hospedajes/:id/resenas
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

r.post('/:hospedajeId/resenas', auth, async (req, res, next) => {
  try {
    const { hospedajeId } = req.params
    const { reserva_id, rating, titulo, texto } = req.body || {}

    if (!reserva_id || !rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'reserva_id y rating (1-5) son obligatorios.' })
    }

    // La reseña solo es válida si la reserva existe, es del usuario y es de ESTE hospedaje
    const { rows: rs } = await pool.query(
      `SELECT id FROM reservas
        WHERE id = $1 AND usuario_id = $2 AND hospedaje_id = $3`,
      [reserva_id, req.usuario.id, hospedajeId]
    )
    if (!rs.length) {
      return res.status(403).json({ error: 'Solo puedes reseñar una reserva propia de este hospedaje.' })
    }

    const { rows } = await pool.query(
      `INSERT INTO resenas (reserva_id, autor_id, hospedaje_id, rating, titulo, texto)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id, rating, titulo, texto, creado_en`,
      [reserva_id, req.usuario.id, hospedajeId, rating, titulo || null, texto || null]
    )
    // El trigger actualizar_rating_hospedaje() recalcula rating y num_resenas
    res.status(201).json({ resena: rows[0] })
  } catch (err) { next(err) }
})

export default r
