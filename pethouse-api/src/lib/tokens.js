// ============================================================
// PETHOUSE API · Tokens JWT (access) + refresh rotativo
// ============================================================
import jwt from 'jsonwebtoken'
import { randomUUID } from 'crypto'
import { JWT_SECRET, pool } from '../config.js'

const ACCESS_TTL = '15m'        // access token: 15 minutos
const REFRESH_DIAS = 30         // refresh token: 30 días

export function firmarAccess(usuario) {
  return jwt.sign({ uid: usuario.id, rol: usuario.rol }, JWT_SECRET, { expiresIn: ACCESS_TTL })
}

// Crea el refresh token, lo guarda en la tabla `sesiones` y lo devuelve
export async function crearRefresh(usuarioId, userAgent) {
  const token = randomUUID() + randomUUID()
  await pool.query(
    `INSERT INTO sesiones (usuario_id, refresh_token, user_agent, expira_en)
     VALUES ($1, $2, $3, now() + interval '${REFRESH_DIAS} days')`,
    [usuarioId, token, userAgent || null]
  )
  return token
}

// Emite un par nuevo (access + refresh) para un usuario
export async function emitirTokens(usuario, userAgent) {
  const access = firmarAccess(usuario)
  const refresh = await crearRefresh(usuario.id, userAgent)
  return { accessToken: access, refreshToken: refresh, expiraEn: '15m' }
}

// Renueva el par si el refresh existe y no ha expirado
export async function renovarRefresh(refreshToken) {
  const { rows } = await pool.query(
    `SELECT s.usuario_id, u.rol
       FROM sesiones s
       JOIN usuarios u ON u.id = s.usuario_id
      WHERE s.refresh_token = $1 AND s.expira_en > now()`,
    [refreshToken]
  )
  if (!rows.length) return null
  return { id: rows[0].usuario_id, rol: rows[0].rol }
}

export async function revocarRefresh(refreshToken) {
  await pool.query('DELETE FROM sesiones WHERE refresh_token = $1', [refreshToken])
}
