// ============================================================
// PETHOUSE API · Módulo Usuarios (evaluación pública del huésped)
// GET /api/usuarios/:id/resenas
//
// Espejo de GET /api/hospedajes/:id (sección de reseñas) — el anfitrión lo usa para ver la
// evaluación y los comentarios de un huésped antes de aceptar o rechazar su solicitud de
// reserva (ver db/15-resenas-huesped.sql y ReservasRecibidasView en el cliente iOS).
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

r.get('/:id/resenas', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT ru.id, ru.rating, ru.titulo, ru.texto, ru.creado_en, u.nombre AS autor
         FROM resenas_usuario ru JOIN usuarios u ON u.id = ru.autor_id
        WHERE ru.usuario_id = $1 ORDER BY ru.creado_en DESC LIMIT 20`,
      [req.params.id]
    )
    res.json({ resenas: rows })
  } catch (err) { next(err) }
})

export default r
