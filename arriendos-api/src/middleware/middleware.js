// ============================================================
// ARRIENDOS CARTAGENA API · Middlewares
// ============================================================
import jwt from 'jsonwebtoken'
import { JWT_SECRET, pool } from '../config.js'

// ---- Identifica al usuario de la cuenta ----
// La app no pide iniciar sesión (uso interno y familiar, un solo usuario).
// Si llega un token Bearer válido se usa ese usuario; si no, se usa el
// único usuario de la base de datos como dueño por defecto (lo necesitan,
// por ejemplo, las suscripciones de notificaciones push).
export async function auth(req, res, next) {
  try {
    const header = req.headers.authorization || ''
    const token = header.startsWith('Bearer ') ? header.slice(7) : null

    if (token) {
      try {
        const payload = jwt.verify(token, JWT_SECRET)
        const { rows } = await pool.query('SELECT id, nombre, email FROM usuarios WHERE id = $1', [payload.uid])
        if (rows.length) { req.usuario = rows[0]; return next() }
      } catch { /* token inválido o vencido: cae al usuario por defecto */ }
    }

    const { rows } = await pool.query('SELECT id, nombre, email FROM usuarios ORDER BY creado_en LIMIT 1')
    if (!rows.length) return res.status(500).json({ error: 'No hay ningún usuario configurado en la base de datos.' })
    req.usuario = rows[0]
    next()
  } catch (err) { next(err) }
}

// ---- Manejador global de errores ----
export function manejadorErrores(err, req, res, _next) {
  // Violación de la restricción EXCLUDE (doble reserva) o de unicidad
  if (err.code === '23P01') {
    return res.status(409).json({ error: 'Ese apartamento ya tiene una reserva confirmada que se cruza con esas fechas.' })
  }
  if (err.code === '23505') {
    return res.status(409).json({ error: 'Ya existe un registro igual (posible duplicado).' })
  }
  if (err.code === '23503') {
    return res.status(400).json({ error: 'Referencia inválida: el apartamento indicado no existe.' })
  }
  if (err.code === '23514') {
    return res.status(400).json({ error: 'Dato fuera de rango: revisa las fechas u otros valores.' })
  }
  console.error('API error:', err)
  res.status(500).json({ error: 'Error interno del servidor.' })
}

// ---- 404 ----
export function noEncontrado(req, res) {
  res.status(404).json({ error: `Ruta no encontrada: ${req.method} ${req.path}` })
}
