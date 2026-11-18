// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Turnos de lavandería
// Qué niñas están asignadas a atender el local cada día.
// GET /api/turnos-lavanderia · POST / · DELETE /:id
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// ---- Listar turnos ----
r.get('/', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT t.*, p.nombre AS personal_nombre
         FROM turnos_lavanderia t
         JOIN personal_limpieza p ON p.id = t.personal_id
        ORDER BY t.fecha`
    )
    res.json({ turnos: rows })
  } catch (err) { next(err) }
})

// ---- Asignar una niña a la lavandería en una fecha ----
r.post('/', auth, async (req, res, next) => {
  try {
    const { personal_id, fecha } = req.body || {}
    if (!personal_id) return res.status(400).json({ error: 'Falta la niña.' })
    if (!fecha) return res.status(400).json({ error: 'Falta la fecha.' })

    const { rows } = await pool.query(
      `INSERT INTO turnos_lavanderia (personal_id, fecha) VALUES ($1, $2) RETURNING *`,
      [personal_id, fecha]
    )
    res.status(201).json({ turno: rows[0] })
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'Esa niña ya está asignada a la lavandería ese día.' })
    }
    next(err)
  }
})

// ---- Quitar una asignación ----
r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM turnos_lavanderia WHERE id = $1', [req.params.id])
    if (!rowCount) return res.status(404).json({ error: 'No encontrada.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
