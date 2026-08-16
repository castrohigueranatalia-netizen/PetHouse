// ============================================================
// PETHOUSE API · Módulo Notificaciones (historial completo, la campana de la app)
// GET /api/notificaciones · POST /api/notificaciones/:id/leida · /leer-todas
//
// Distinto de los avisos instantáneos (`.alert` al abrir la app, ver
// GET /reservas/notificaciones/resueltas, /pendientes-anfitrion y
// GET /anfitrion/verificacion): esos son efímeros y se pierden al cerrarlos. Esta tabla
// (db/19-notificaciones.sql) es un historial real — la campana muestra tanto las que ya se
// vieron como las nuevas, ver `crearNotificacion()` en lib/notificaciones.js.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// ---- Historial completo (nuevas y viejas), más recientes primero ----
r.get('/', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, tipo, titulo, mensaje, leida, reserva_id, hospedaje_id, creado_en
         FROM notificaciones
        WHERE usuario_id = $1
        ORDER BY creado_en DESC
        LIMIT 100`,
      [req.usuario.id]
    )
    const noLeidas = rows.filter(n => !n.leida).length
    res.json({ notificaciones: rows, noLeidas })
  } catch (err) { next(err) }
})

// ---- Marca como leída una notificación propia ----
r.post('/:id/leida', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'UPDATE notificaciones SET leida = TRUE WHERE id = $1 AND usuario_id = $2 RETURNING id',
      [req.params.id, req.usuario.id]
    )
    if (!rows.length) return res.status(404).json({ error: 'Notificación no encontrada.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Marca todas como leídas (al abrir la campana) ----
r.post('/leer-todas', auth, async (req, res, next) => {
  try {
    await pool.query(
      'UPDATE notificaciones SET leida = TRUE WHERE usuario_id = $1 AND NOT leida',
      [req.usuario.id]
    )
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
