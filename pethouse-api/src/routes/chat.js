// ============================================================
// PETHOUSE API · Módulo Chat (mensajería dueño ⇄ anfitrión)
// GET /api/conversaciones · POST /api/conversaciones
// GET/POST /api/conversaciones/:id/mensajes · POST .../leidas
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// ---- Listar conversaciones del usuario (con último mensaje y no-leídos) ----
r.get('/', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT c.id, c.hospedaje_id,
              CASE WHEN c.usuario_id = $1 THEN c.anfitrion_id ELSE c.usuario_id END AS otro_id,
              u.nombre AS otro_nombre,
              (SELECT COUNT(*) FROM mensajes m
                WHERE m.conversacion_id = c.id AND m.remitente_id <> $1 AND m.leido = FALSE) AS no_leidos,
              (SELECT texto FROM mensajes m WHERE m.conversacion_id = c.id
                ORDER BY m.creado_en DESC LIMIT 1) AS ultimo_mensaje,
              (SELECT creado_en FROM mensajes m WHERE m.conversacion_id = c.id
                ORDER BY m.creado_en DESC LIMIT 1) AS ultimo_en
         FROM conversaciones c
         JOIN usuarios u ON u.id = CASE WHEN c.usuario_id = $1 THEN c.anfitrion_id ELSE c.usuario_id END
        WHERE c.usuario_id = $1 OR c.anfitrion_id = $1
        ORDER BY ultimo_en DESC NULLS LAST`,
      [req.usuario.id]
    )
    res.json({ conversaciones: rows })
  } catch (err) { next(err) }
})

// ---- Obtener o crear conversación con un anfitrión ----
r.post('/', auth, async (req, res, next) => {
  try {
    const { anfitrion_id, hospedaje_id } = req.body || {}
    if (!anfitrion_id) return res.status(400).json({ error: 'Falta anfitrion_id.' })
    if (anfitrion_id === req.usuario.id) return res.status(400).json({ error: 'No puedes chatear contigo mismo.' })

    const { rows: existente } = await pool.query(
      `SELECT id FROM conversaciones
        WHERE (usuario_id = $1 AND anfitrion_id = $2) OR (usuario_id = $2 AND anfitrion_id = $1)
        ORDER BY creado_en DESC LIMIT 1`,
      [req.usuario.id, anfitrion_id]
    )
    if (existente.length) return res.json({ conversacion: existente[0] })

    const { rows } = await pool.query(
      `INSERT INTO conversaciones (usuario_id, anfitrion_id, hospedaje_id)
       VALUES ($1, $2, $3) RETURNING id`,
      [req.usuario.id, anfitrion_id, hospedaje_id || null]
    )
    res.status(201).json({ conversacion: rows[0] })
  } catch (err) { next(err) }
})

// ---- Mensajes de una conversación (solo participantes) ----
r.get('/:id/mensajes', auth, async (req, res, next) => {
  try {
    const { rows: c } = await pool.query(
      'SELECT id FROM conversaciones WHERE id = $1 AND (usuario_id = $2 OR anfitrion_id = $2)',
      [req.params.id, req.usuario.id]
    )
    if (!c.length) return res.status(403).json({ error: 'No perteneces a esta conversación.' })

    const { rows } = await pool.query(
      `SELECT id, remitente_id, texto, leido, creado_en
         FROM mensajes WHERE conversacion_id = $1
        ORDER BY creado_en ASC LIMIT 200`,
      [req.params.id]
    )
    res.json({ mensajes: rows })
  } catch (err) { next(err) }
})

// ---- Enviar mensaje ----
r.post('/:id/mensajes', auth, async (req, res, next) => {
  try {
    const { texto } = req.body || {}
    if (!texto || !String(texto).trim()) return res.status(400).json({ error: 'El mensaje no puede estar vacío.' })

    const { rows: c } = await pool.query(
      'SELECT id FROM conversaciones WHERE id = $1 AND (usuario_id = $2 OR anfitrion_id = $2)',
      [req.params.id, req.usuario.id]
    )
    if (!c.length) return res.status(403).json({ error: 'No perteneces a esta conversación.' })

    const { rows } = await pool.query(
      `INSERT INTO mensajes (conversacion_id, remitente_id, texto)
       VALUES ($1, $2, $3) RETURNING id, remitente_id, texto, leido, creado_en`,
      [req.params.id, req.usuario.id, String(texto).trim()]
    )
    res.status(201).json({ mensaje: rows[0] })
  } catch (err) { next(err) }
})

// ---- Marcar mensajes como leídos ----
r.post('/:id/leidas', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query(
      `UPDATE mensajes SET leido = TRUE
        WHERE conversacion_id = $1 AND remitente_id <> $2`,
      [req.params.id, req.usuario.id]
    )
    res.json({ marcados: rowCount })
  } catch (err) { next(err) }
})

export default r
