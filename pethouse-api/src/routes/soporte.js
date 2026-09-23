// ============================================================
// PETHOUSE API · Módulo Soporte (buzón del usuario)
// POST /api/soporte · GET /api/soporte/mios · GET /api/soporte/:id
// POST /api/soporte/:id/mensajes
//
// El lado del admin (ver todos los tickets, responder, marcar resuelto) vive en
// routes/admin.js — acá solo lo que un usuario normal puede hacer con SUS PROPIOS
// tickets (siempre filtrado por usuario_id = req.usuario.id).
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()
r.use(auth)

// ---- Crear un ticket nuevo (asunto + primer mensaje) ----
r.post('/', async (req, res, next) => {
  const client = await pool.connect()
  try {
    const { asunto, mensaje } = req.body || {}
    if (!asunto || !String(asunto).trim()) return res.status(400).json({ error: 'Ingresa un asunto.' })
    if (!mensaje || !String(mensaje).trim()) return res.status(400).json({ error: 'Escribe tu mensaje.' })

    await client.query('BEGIN')
    const { rows } = await client.query(
      `INSERT INTO tickets_soporte (usuario_id, asunto) VALUES ($1, $2) RETURNING *`,
      [req.usuario.id, String(asunto).trim()]
    )
    await client.query(
      `INSERT INTO mensajes_soporte (ticket_id, es_admin, texto) VALUES ($1, FALSE, $2)`,
      [rows[0].id, String(mensaje).trim()]
    )
    await client.query('COMMIT')
    res.status(201).json({ ticket: rows[0] })
  } catch (err) {
    await client.query('ROLLBACK')
    next(err)
  } finally {
    client.release()
  }
})

// ---- Mis tickets (más recientes primero) ----
r.get('/mios', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT t.*,
              (SELECT COUNT(*)::int FROM mensajes_soporte m WHERE m.ticket_id = t.id) AS num_mensajes
         FROM tickets_soporte t
        WHERE t.usuario_id = $1
        ORDER BY t.actualizado_en DESC`,
      [req.usuario.id]
    )
    res.json({ tickets: rows })
  } catch (err) { next(err) }
})

// ---- Detalle de un ticket propio, con todos sus mensajes ----
r.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM tickets_soporte WHERE id = $1 AND usuario_id = $2',
      [req.params.id, req.usuario.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Ticket no encontrado.' })

    const { rows: mensajes } = await pool.query(
      'SELECT id, es_admin, texto, creado_en FROM mensajes_soporte WHERE ticket_id = $1 ORDER BY creado_en ASC',
      [req.params.id]
    )
    res.json({ ticket: rows[0], mensajes })
  } catch (err) { next(err) }
})

// ---- Responder en un ticket propio (reabre uno resuelto si estaba cerrado) ----
r.post('/:id/mensajes', async (req, res, next) => {
  try {
    const { texto } = req.body || {}
    if (!texto || !String(texto).trim()) return res.status(400).json({ error: 'Escribe un mensaje.' })

    const { rows: propio } = await pool.query(
      'SELECT id FROM tickets_soporte WHERE id = $1 AND usuario_id = $2',
      [req.params.id, req.usuario.id]
    )
    if (!propio.length) return res.status(404).json({ error: 'Ticket no encontrado.' })

    const { rows } = await pool.query(
      `INSERT INTO mensajes_soporte (ticket_id, es_admin, texto) VALUES ($1, FALSE, $2)
       RETURNING id, es_admin, texto, creado_en`,
      [req.params.id, String(texto).trim()]
    )
    await pool.query(
      `UPDATE tickets_soporte SET estado = 'abierto', actualizado_en = now() WHERE id = $1`,
      [req.params.id]
    )
    res.status(201).json({ mensaje: rows[0] })
  } catch (err) { next(err) }
})

export default r
