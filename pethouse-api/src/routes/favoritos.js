// ============================================================
// PETHOUSE API · Módulo Favoritos
// GET /api/favoritos · POST /api/favoritos · DELETE /api/favoritos/:hospedajeId
//
// La tabla `favoritos` (usuario_id, hospedaje_id, creado_en — PK compuesta) ya existía en
// db/01-esquema.sql sin rutas montadas. Contrato consumido ya por
// PetHouseiOS/Networking/Services/FavoritosService.swift.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// Devuelve hospedajes completos (misma forma que GET /api/hospedajes) para no forzar al
// cliente a pedir el detalle de cada favorito por separado.
r.get('/', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT h.id, h.titulo, h.tipo, h.ciudad, h.barrio, h.precio_noche, h.precio_dia, h.convivencia,
              h.max_mascotas, h.rating, h.num_resenas, h.destacado, h.servicios, h.fotos,
              ST_Y(h.ubicacion::geometry) AS lat, ST_X(h.ubicacion::geometry) AS lng,
              u.nombre AS anfitrion_nombre, u.verificado AS anfitrion_verificado
         FROM favoritos f
         JOIN hospedajes h ON h.id = f.hospedaje_id
         JOIN usuarios u ON u.id = h.anfitrion_id
        WHERE f.usuario_id = $1
        ORDER BY f.creado_en DESC`,
      [req.usuario.id]
    )
    res.json({ favoritos: rows })
  } catch (err) { next(err) }
})

r.post('/', auth, async (req, res, next) => {
  try {
    const { hospedaje_id: hospedajeId } = req.body || {}
    if (!hospedajeId) return res.status(400).json({ error: 'Falta hospedaje_id.' })

    const { rows: h } = await pool.query('SELECT id FROM hospedajes WHERE id = $1', [hospedajeId])
    if (!h.length) return res.status(404).json({ error: 'Hospedaje no encontrado.' })

    const { rows } = await pool.query(
      `INSERT INTO favoritos (usuario_id, hospedaje_id) VALUES ($1, $2)
       ON CONFLICT (usuario_id, hospedaje_id) DO UPDATE SET usuario_id = EXCLUDED.usuario_id
       RETURNING usuario_id, hospedaje_id, creado_en`,
      [req.usuario.id, hospedajeId]
    )
    res.status(201).json({ favorito: rows[0] })
  } catch (err) { next(err) }
})

r.delete('/:hospedajeId', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query(
      'DELETE FROM favoritos WHERE usuario_id = $1 AND hospedaje_id = $2',
      [req.usuario.id, req.params.hospedajeId]
    )
    if (!rowCount) return res.status(404).json({ error: 'No estaba en tus favoritos.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
