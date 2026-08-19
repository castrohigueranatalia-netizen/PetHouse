// ============================================================
// PETHOUSE API · Tokens JWT (access) + refresh rotativo
// ============================================================
import jwt from 'jsonwebtoken'
import { randomUUID, createHash } from 'crypto'
import { JWT_SECRET, pool } from '../config.js'

const ACCESS_TTL = '15m'        // access token: 15 minutos
const REFRESH_DIAS = 30         // refresh token: 30 días

export function firmarAccess(usuario) {
  return jwt.sign({ uid: usuario.id, rol: usuario.rol }, JWT_SECRET, { expiresIn: ACCESS_TTL })
}

// La tabla `sesiones` guarda un HASH del refresh token, no el token en sí (mismo principio
// que las contraseñas: si alguna vez se filtra un backup o hay una fuga de datos, un
// refresh token en texto plano es usable de inmediato por quien lo tenga, sin tener que
// "romper" nada — hashearlo hace que la fuga por sí sola no alcance para tomar la sesión de
// nadie). SHA-256 (no bcrypt) porque el token YA tiene su propia entropía alta (dos UUID
// random, ver `crearRefresh`) — a diferencia de una contraseña elegida por una persona, acá
// no hace falta un hash lento diseñado contra fuerza bruta de diccionario.
function hashToken(token) {
  return createHash('sha256').update(token).digest('hex')
}

// Crea el refresh token, guarda su HASH en la tabla `sesiones` y devuelve el token real
// (el único momento en que existe en texto plano es en la respuesta al cliente, que lo
// guarda en su Keychain — ver PetHouseiOS/Core/Security/KeychainStore.swift).
export async function crearRefresh(usuarioId, userAgent) {
  const token = randomUUID() + randomUUID()
  await pool.query(
    `INSERT INTO sesiones (usuario_id, refresh_token, user_agent, expira_en)
     VALUES ($1, $2, $3, now() + interval '${REFRESH_DIAS} days')`,
    [usuarioId, hashToken(token), userAgent || null]
  )
  return token
}

// Emite un par nuevo (access + refresh) para un usuario
export async function emitirTokens(usuario, userAgent) {
  const access = firmarAccess(usuario)
  const refresh = await crearRefresh(usuario.id, userAgent)
  return { accessToken: access, refreshToken: refresh, expiraEn: '15m' }
}

// Renueva el par si el refresh existe y no ha expirado.
//
// Devuelve la fila COMPLETA del usuario (no solo id+rol): el cliente decodifica esto como
// el mismo `AuthResponse` que login/registro, que requiere nombre/email/verificado (no son
// opcionales en el modelo `Usuario` de PetHouseiOS). Antes solo se devolvía {id, rol}, lo
// que hacía fallar la decodificación en el cliente y forzaba un logout silencioso cada vez
// que el access token expiraba (cada 15 min) — bug real encontrado al revisar este archivo,
// no solo teórico: `APIClient.hacerRefresh()` descarta la sesión entera si el `try
// decoder.decode(AuthResponse.self, ...)` lanza.
export async function renovarRefresh(refreshToken) {
  const { rows } = await pool.query(
    `SELECT u.id, u.nombre, u.email, u.telefono, u.rol, u.verificado, u.foto_url, u.es_anfitrion, u.creado_en
       FROM sesiones s
       JOIN usuarios u ON u.id = s.usuario_id
      WHERE s.refresh_token = $1 AND s.expira_en > now()`,
    [hashToken(refreshToken)]
  )
  if (!rows.length) return null
  return rows[0]
}

export async function revocarRefresh(refreshToken) {
  await pool.query('DELETE FROM sesiones WHERE refresh_token = $1', [hashToken(refreshToken)])
}

// Cierra TODAS las sesiones de un usuario en todos sus dispositivos (ej. si sospecha que
// perdió el teléfono, o como medida general al detectar algo raro) — a diferencia de
// `revocarRefresh`, que solo cierra la sesión de ESTE refresh token puntual.
export async function revocarTodasLasSesiones(usuarioId) {
  await pool.query('DELETE FROM sesiones WHERE usuario_id = $1', [usuarioId])
}
