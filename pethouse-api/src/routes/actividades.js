// ============================================================
// PETHOUSE API · Módulo Actividades
// GET /api/actividades?tipo=... · POST /api/actividades (anfitrión)
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth, soloAnfitrion } from '../middleware/middleware.js'

const r = Router()

r.get('/', async (req, res, next) => {
  try {
    const { tipo, q } = req.query
    const condiciones = ['activa = TRUE']
    const params = []
    if (tipo) { params.push(tipo); condiciones.push(`tipo = $${params.length}`) }
    if (q) { params.push(`%${q}%`); condiciones.push(`(nombre ILIKE $${params.length} OR descripcion ILIKE $${params.length})`) }
    const { rows } = await pool.query(
      `SELECT id, hospedaje_id, nombre, tipo, descripcion, duracion, precio
         FROM actividades WHERE ${condiciones.join(' AND ')} ORDER BY precio`,
      params
    )
    res.json({ total: rows.length, actividades: rows })
  } catch (err) { next(err) }
})

r.post('/', auth, soloAnfitrion, async (req, res, next) => {
  try {
    const { nombre, tipo, descripcion, duracion, precio, hospedaje_id } = req.body || {}
    if (!nombre || !tipo || precio == null) {
      return res.status(400).json({ error: 'Faltan nombre, tipo o precio.' })
    }
    const { rows } = await pool.query(
      `INSERT INTO actividades (hospedaje_id, nombre, tipo, descripcion, duracion, precio)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, nombre, tipo, precio`,
      [hospedaje_id || null, nombre, tipo, descripcion || null, duracion || null, Number(precio)]
    )
    res.status(201).json({ actividad: rows[0] })
  } catch (err) { next(err) }
})

export default r
