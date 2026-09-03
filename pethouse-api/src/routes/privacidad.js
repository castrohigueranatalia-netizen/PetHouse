// ============================================================
// PETHOUSE API · Solicitudes de privacidad (lado del usuario)
// POST /api/privacidad · GET /api/privacidad/mias · GET /api/privacidad/:id
//
// Ejercer los derechos que describe la política de privacidad (conocer, corregir o
// eliminar tus datos, u otra duda). El lado del admin (ver todas, responder) vive en
// routes/admin.js — acá solo lo que un usuario puede hacer con SUS PROPIAS solicitudes.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'
import { sumarDiasHabiles, diasHabilesPorCategoria } from '../lib/diasHabiles.js'

const r = Router()
r.use(auth)

const CATEGORIAS_VALIDAS = ['conocer', 'corregir', 'eliminar', 'otra']

r.post('/', async (req, res, next) => {
  try {
    const { categoria, mensaje } = req.body || {}
    if (!CATEGORIAS_VALIDAS.includes(categoria)) {
      return res.status(400).json({ error: 'Selecciona un tipo de solicitud válido.' })
    }
    if (!mensaje || !String(mensaje).trim()) return res.status(400).json({ error: 'Cuéntanos qué necesitas.' })

    const plazoDias = diasHabilesPorCategoria(categoria)
    const venceEn = sumarDiasHabiles(new Date(), plazoDias)

    const { rows } = await pool.query(
      `INSERT INTO solicitudes_privacidad (usuario_id, categoria, mensaje, plazo_dias, vence_en)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.usuario.id, categoria, String(mensaje).trim(), plazoDias, venceEn]
    )
    res.status(201).json({ solicitud: rows[0] })
  } catch (err) { next(err) }
})

r.get('/mias', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM solicitudes_privacidad WHERE usuario_id = $1 ORDER BY creado_en DESC',
      [req.usuario.id]
    )
    res.json({ solicitudes: rows })
  } catch (err) { next(err) }
})

r.get('/:id', async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM solicitudes_privacidad WHERE id = $1 AND usuario_id = $2',
      [req.params.id, req.usuario.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Solicitud no encontrada.' })
    res.json({ solicitud: rows[0] })
  } catch (err) { next(err) }
})

export default r
