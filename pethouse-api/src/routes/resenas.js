// ============================================================
// PETHOUSE API · Módulo Reseñas (una por reserva; trigger de rating)
// POST /api/hospedajes/:id/resenas
// POST /api/hospedajes/:id/resenas/:resenaId/responder — el anfitrión responde
// públicamente (ver db/33-respuesta-resena.sql)
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth, soloAnfitrion } from '../middleware/middleware.js'

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

// ---- El anfitrión responde públicamente a una reseña de su hospedaje ----
// Una sola respuesta por reseña (se sobrescribe si la edita), no un hilo de comentarios.
r.post('/:hospedajeId/resenas/:resenaId/responder', auth, soloAnfitrion, async (req, res, next) => {
  try {
    const { respuesta } = req.body || {}
    if (!respuesta || !String(respuesta).trim()) return res.status(400).json({ error: 'Escribe una respuesta.' })

    const { rows: h } = await pool.query('SELECT anfitrion_id FROM hospedajes WHERE id = $1', [req.params.hospedajeId])
    if (!h.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })
    if (h[0].anfitrion_id !== req.usuario.id) {
      return res.status(403).json({ error: 'No eres el anfitrión de este hospedaje.' })
    }

    // `UPDATE ... FROM usuarios` (no un JOIN aparte) para poder devolver `autor` en la
    // misma vuelta — si no, el cliente reemplazaría la reseña local con una sin autor y se
    // vería "Usuario de PetHouse" en vez del nombre real hasta la próxima recarga completa.
    const { rows } = await pool.query(
      `UPDATE resenas rs SET respuesta_anfitrion = $1, respuesta_en = now()
        FROM usuarios u
       WHERE rs.id = $2 AND rs.hospedaje_id = $3 AND u.id = rs.autor_id
       RETURNING rs.id, rs.rating, rs.titulo, rs.texto, rs.creado_en, rs.respuesta_anfitrion, rs.respuesta_en, u.nombre AS autor`,
      [String(respuesta).trim(), req.params.resenaId, req.params.hospedajeId]
    )
    if (!rows.length) return res.status(404).json({ error: 'Reseña no encontrada.' })
    res.json({ resena: rows[0] })
  } catch (err) { next(err) }
})

export default r
