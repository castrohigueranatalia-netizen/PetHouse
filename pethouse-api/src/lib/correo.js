// ============================================================
// PETHOUSE API · Envío de correos (hoy: solo "olvidé mi contraseña")
//
// Mismo principio que lib/push.js: cero dependencias de un proveedor de pago para
// arrancar. Usa SMTP genérico vía `nodemailer` — funciona con Gmail (gratis, ver
// .env.example para el paso a paso de la "contraseña de aplicación") o con cualquier otro
// proveedor SMTP más adelante, sin cambiar código.
//
// SIN las variables SMTP_* configuradas (caso normal en desarrollo, antes de que alguien
// configure un correo real): en vez de fallar o quedarse callado, IMPRIME el mensaje
// completo en la consola del servidor — así se puede probar todo el flujo de
// "olvidé mi contraseña" en desarrollo sin tener que configurar nada todavía. En
// producción sí hay que configurar las variables para que el código le llegue de verdad
// a la persona.
// ============================================================
import nodemailer from 'nodemailer'

const SMTP_HOST = process.env.SMTP_HOST || ''
const SMTP_PORT = Number(process.env.SMTP_PORT || 587)
const SMTP_USER = process.env.SMTP_USER || ''
const SMTP_PASS = process.env.SMTP_PASS || ''
const SMTP_FROM = process.env.SMTP_FROM || SMTP_USER

const configurado = Boolean(SMTP_HOST && SMTP_USER && SMTP_PASS)
if (!configurado) {
  console.warn(
    '⚠ SMTP_HOST/SMTP_USER/SMTP_PASS no están configuradas: los correos (ej. "olvidé mi ' +
    'contraseña") se imprimen en esta consola en vez de enviarse de verdad. ' +
    'Ver pethouse-api/.env.example para configurarlo con Gmail (gratis).'
  )
}

let transportador = null
function obtenerTransportador() {
  if (!transportador) {
    transportador = nodemailer.createTransport({
      host: SMTP_HOST,
      port: SMTP_PORT,
      secure: SMTP_PORT === 465,
      auth: { user: SMTP_USER, pass: SMTP_PASS }
    })
  }
  return transportador
}

/// Nunca lanza — un correo que no se pudo enviar no debe romper la petición que lo
/// disparó (mismo principio que `enviarPush`). Sin SMTP configurado, imprime el mensaje
/// completo en consola en vez de enviarlo, para poder seguir probando en desarrollo.
export async function enviarCorreo({ para, asunto, texto }) {
  if (!configurado) {
    console.log(`\n✉️  [correo simulado, SMTP no configurado] Para: ${para}\nAsunto: ${asunto}\n\n${texto}\n`)
    return
  }
  try {
    await obtenerTransportador().sendMail({ from: SMTP_FROM, to: para, subject: asunto, text: texto })
  } catch (err) {
    console.error('Error enviando correo (ignorado, no afecta la petición):', err.message)
  }
}
