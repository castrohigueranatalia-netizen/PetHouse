// ============================================================
// PETHOUSE API · Middlewares
// ============================================================
import jwt from 'jsonwebtoken'
import { JWT_SECRET, pool } from '../config.js'

// ---- Autenticación: requiere "Authorization: Bearer <access>" ----
export async function auth(req, res, next) {
  const header = req.headers.authorization || ''
  const token = header.startsWith('Bearer ') ? header.slice(7) : null
  if (!token) return res.status(401).json({ error: 'Se requiere iniciar sesión.' })

  try {
    const payload = jwt.verify(token, JWT_SECRET)
    const { rows } = await pool.query(
      'SELECT id, nombre, email, rol, verificado FROM usuarios WHERE id = $1',
      [payload.uid]
    )
    if (!rows.length) return res.status(401).json({ error: 'Sesión inválida.' })
    req.usuario = rows[0]
    next()
  } catch {
    return res.status(401).json({ error: 'Sesión expirada o inválida. Vuelve a iniciar sesión.' })
  }
}

// ---- Solo anfitriones ----
export function soloAnfitrion(req, res, next) {
  if (req.usuario?.rol !== 'anfitrion' && req.usuario?.rol !== 'admin') {
    return res.status(403).json({ error: 'Solo los anfitriones pueden hacer esto.' })
  }
  next()
}

// ---- Manejador global de errores ----
export function manejadorErrores(err, req, res, _next) {
  // Violación de la restricción EXCLUDE (doble reserva) o de unicidad
  if (err.code === '23P01' || err.code === '23505') {
    return res.status(409).json({ error: 'Conflicto: el hospedaje ya no está disponible para esas fechas.' })
  }
  if (err.code === '23503') {
    return res.status(400).json({ error: 'Referencia inválida: uno de los datos no existe.' })
  }
  if (err.code === '23514') {
    return res.status(400).json({ error: 'Dato fuera de rango: revisa fechas, mascotas o valores.' })
  }
  console.error('API error:', err)
  res.status(500).json({ error: 'Error interno del servidor.' })
}

// ---- 404 ----
export function noEncontrado(req, res) {
  res.status(404).json({ error: `Ruta no encontrada: ${req.method} ${req.path}` })
}
