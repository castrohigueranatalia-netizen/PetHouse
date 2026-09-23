// ============================================================
// PETHOUSE API · Notificaciones push (APNs — Apple Push Notification service)
//
// Envía un push al teléfono del usuario además de guardarle la notificación en la
// campana (ver lib/notificaciones.js). Usa autenticación por token (JWT firmado con
// ES256 con la clave .p8), vía HTTP/2 directo al servidor de Apple — sin librerías
// nuevas: `http2` es del propio Node y `jsonwebtoken` ya es dependencia del proyecto.
//
// Requiere una cuenta de pago de Apple Developer Program y la capacidad "Push
// Notifications" habilitada en Xcode (ver PetHouseiOS/project.yml) — algo que esta API
// NO puede activar por sí sola. Mientras APNS_KEY_PATH/APNS_KEY_ID/APNS_TEAM_ID/
// APNS_BUNDLE_ID no estén configuradas, `enviarPush` no hace nada (no falla, no
// bloquea, solo se sale) — así el resto de la app (crear/aceptar/rechazar reservas,
// aprobar anfitriones) funciona igual hoy, y el push empieza a mandarse solo apenas se
// configuren las variables de entorno, sin tocar código de nuevo.
// ============================================================
import fs from 'node:fs'
import http2 from 'node:http2'
import jwt from 'jsonwebtoken'
import { pool } from '../config.js'

const APNS_KEY_PATH = process.env.APNS_KEY_PATH || ''
const APNS_KEY_ID = process.env.APNS_KEY_ID || ''
const APNS_TEAM_ID = process.env.APNS_TEAM_ID || ''
const APNS_BUNDLE_ID = process.env.APNS_BUNDLE_ID || ''
// "production" (App Store/TestFlight) o "sandbox" (desarrollo, apps corridas desde Xcode).
// Por defecto "sandbox" — es lo correcto mientras se prueba antes de publicar la app.
const APNS_HOST = process.env.APNS_ENVIRONMENT === 'production'
  ? 'api.push.apple.com'
  : 'api.sandbox.push.apple.com'

const configurado = Boolean(APNS_KEY_PATH && APNS_KEY_ID && APNS_TEAM_ID && APNS_BUNDLE_ID)
if (!configurado) {
  console.warn(
    '⚠ APNS_KEY_PATH/APNS_KEY_ID/APNS_TEAM_ID/APNS_BUNDLE_ID no están configuradas: ' +
    'las notificaciones push están desactivadas (la campana en la app sigue funcionando igual).'
  )
}

let claveP8Cache = null
function obtenerClaveP8() {
  if (!claveP8Cache) claveP8Cache = fs.readFileSync(APNS_KEY_PATH, 'utf8')
  return claveP8Cache
}

let tokenCache = null
function obtenerTokenFirmado() {
  const ahoraSegundos = Math.floor(Date.now() / 1000)
  // Apple recomienda no firmar un token nuevo en cada envío; este dura como máximo 1 hora,
  // así que se reusa mientras tenga menos de 50 minutos.
  if (tokenCache && ahoraSegundos - tokenCache.creadoEn < 50 * 60) return tokenCache.token
  const token = jwt.sign(
    { iss: APNS_TEAM_ID, iat: ahoraSegundos },
    obtenerClaveP8(),
    { algorithm: 'ES256', header: { alg: 'ES256', kid: APNS_KEY_ID } }
  )
  tokenCache = { token, creadoEn: ahoraSegundos }
  return token
}

/// Envía un único push a un token de dispositivo. Nunca rechaza (resuelve `false` en
/// cualquier error) — un push fallido no debe romper ni frenar la acción que lo disparó.
function enviarADispositivo(deviceToken, payload) {
  return new Promise((resolve) => {
    let resuelto = false
    const terminar = (ok) => {
      if (resuelto) return
      resuelto = true
      resolve(ok)
    }

    let cliente
    try {
      cliente = http2.connect(`https://${APNS_HOST}`)
    } catch {
      terminar(false)
      return
    }

    cliente.on('error', () => terminar(false))

    const cuerpo = JSON.stringify(payload)
    const req = cliente.request({
      ':method': 'POST',
      ':path': `/3/device/${deviceToken}`,
      authorization: `bearer ${obtenerTokenFirmado()}`,
      'apns-topic': APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
      'content-length': Buffer.byteLength(cuerpo)
    })

    req.on('response', (headers) => {
      const status = headers[':status']
      terminar(status === 200)
    })
    req.on('error', () => terminar(false))
    req.on('close', () => {
      terminar(false)
      cliente.close()
    })

    req.write(cuerpo)
    req.end()
  })
}

/// Manda un push a todos los dispositivos registrados de un usuario. Se llama "al
/// vuelo" (sin `await`) junto a `crearNotificacion` — nunca debe demorar ni romper la
/// respuesta de la petición que lo dispara (crear/aceptar/rechazar reserva, aprobar
/// anfitrión). Si APNs no está configurado, o el usuario no tiene dispositivos, o algo
/// falla, simplemente no hace nada — nunca lanza.
export async function enviarPush(usuarioId, { titulo, mensaje }) {
  if (!configurado) return
  try {
    const { rows } = await pool.query(
      'SELECT token FROM dispositivos_push WHERE usuario_id = $1',
      [usuarioId]
    )
    if (!rows.length) return
    const payload = { aps: { alert: { title: titulo, body: mensaje }, sound: 'default' } }
    await Promise.all(rows.map(({ token }) => enviarADispositivo(token, payload)))
  } catch (err) {
    console.error('Error enviando push (ignorado, no afecta la petición):', err.message)
  }
}
