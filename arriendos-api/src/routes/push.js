// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Push (notificaciones del navegador)
// GET /api/push/clave-publica · POST /api/push/suscribir · POST /api/push/revisar
// ============================================================
import { Router } from 'express'
import { pool, VAPID_PUBLIC_KEY } from '../config.js'
import { auth } from '../middleware/middleware.js'
import { revisarPagosPendientes } from '../services/notificacionesPago.js'

const r = Router()

// ---- Clave pública VAPID (no es secreta; la necesita el navegador para suscribirse) ----
r.get('/clave-publica', auth, async (_req, res) => {
  res.json({ clave: VAPID_PUBLIC_KEY || null })
})

// ---- Guarda (o actualiza) la suscripción push de este navegador ----
r.post('/suscribir', auth, async (req, res, next) => {
  try {
    const { endpoint, keys } = req.body || {}
    if (!endpoint || !keys?.p256dh || !keys?.auth) {
      return res.status(400).json({ error: 'Suscripción push inválida.' })
    }
    await pool.query(
      `INSERT INTO push_suscripciones (usuario_id, endpoint, p256dh, auth)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (endpoint) DO UPDATE SET usuario_id = EXCLUDED.usuario_id, p256dh = EXCLUDED.p256dh, auth = EXCLUDED.auth`,
      [req.usuario.id, endpoint, keys.p256dh, keys.auth]
    )
    res.status(201).json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Revisar ahora (botón "Revisar ahora" en la app, no hay que esperar al cron) ----
r.post('/revisar', auth, async (req, res, next) => {
  try {
    const resultado = await revisarPagosPendientes()
    res.json(resultado)
  } catch (err) { next(err) }
})

export default r
