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
      'SELECT id, nombre, email, telefono, rol, verificado, foto_url, es_anfitrion, bloqueado FROM usuarios WHERE id = $1',
      [payload.uid]
    )
    if (!rows.length) return res.status(401).json({ error: 'Sesión inválida.' })
    // Se revisa en CADA petición autenticada, no solo al loguearse: si un admin bloquea a
    // alguien mientras ya tiene una sesión abierta, el access token que le queda (hasta 15
    // min, ver JWT_SECRET/expira) igual deja de servir de inmediato — no hay que esperar a
    // que expire solo. `POST /admin/usuarios/:id/bloquear` además revoca sus refresh tokens
    // (tabla `sesiones`), así que tampoco puede renovar uno nuevo.
    if (rows[0].bloqueado) return res.status(401).json({ error: 'Tu cuenta fue bloqueada.' })
    req.usuario = rows[0]
    next()
  } catch {
    return res.status(401).json({ error: 'Sesión expirada o inválida. Vuelve a iniciar sesión.' })
  }
}

// ---- Solo anfitriones ----
// `es_anfitrion` es una CAPACIDAD (no un rol exclusivo — una cuenta puede reservar Y
// publicar hospedajes a la vez) que solo un admin activa al aprobar
// POST /api/admin/verificaciones/:id/aprobar (ver routes/admin.js). `rol` se conserva
// solo como intención/display; 'admin' sigue con acceso total.
export function soloAnfitrion(req, res, next) {
  if (!req.usuario?.es_anfitrion && req.usuario?.rol !== 'admin') {
    return res.status(403).json({ error: 'Necesitas activar el modo anfitrión para hacer esto.' })
  }
  next()
}

// ---- Solo administradores ----
export function soloAdmin(req, res, next) {
  if (req.usuario?.rol !== 'admin') {
    return res.status(403).json({ error: 'Solo un administrador puede hacer esto.' })
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
