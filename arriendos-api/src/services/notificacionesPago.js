// ============================================================
// ARRIENDOS CARTAGENA API · Notificaciones push de pago pendiente
// ------------------------------------------------------------
// Revisa las reservas "confirmada" (sin pagar) cuyo check-in ya está
// cerca y manda una notificación push (al navegador, gratis, sin
// depender de ningún tercero) recordando llamar al huésped.
//
// Requiere VAPID_PUBLIC_KEY/VAPID_PRIVATE_KEY en .env (ver README:
// "Notificaciones push"). Sin esas claves, esta función no hace nada — la
// app sigue funcionando igual.
// ============================================================
import { setVapidDetails, sendNotification } from 'web-push'
import { pool, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT, RECORDATORIO_PAGO_DIAS } from '../config.js'

let configurado = false
function asegurarConfigurado() {
  if (configurado) return true
  if (!VAPID_PUBLIC_KEY || !VAPID_PRIVATE_KEY) return false
  setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY)
  configurado = true
  return true
}

function formatoFechaCorta(fecha) {
  return new Date(fecha).toLocaleDateString('es-CO', { day: 'numeric', month: 'short', timeZone: 'UTC' })
}

async function enviarATodasLasSuscripciones(payload) {
  const { rows: suscripciones } = await pool.query('SELECT * FROM push_suscripciones')
  let enviados = 0
  for (const sub of suscripciones) {
    const suscripcion = { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } }
    try {
      await sendNotification(suscripcion, JSON.stringify(payload))
      enviados++
    } catch (err) {
      // 404/410 = el navegador canceló esa suscripción (desinstaló, limpió datos, etc.)
      if (err.statusCode === 404 || err.statusCode === 410) {
        await pool.query('DELETE FROM push_suscripciones WHERE id = $1', [sub.id])
      } else {
        console.error('Error enviando notificación push:', err.message)
      }
    }
  }
  return enviados
}

// ---- Revisa reservas confirmadas (sin pagar) con check-in próximo o ya
// pasado, y manda una notificación por cada una (una sola vez por reserva) ----
export async function revisarPagosPendientes() {
  if (!asegurarConfigurado()) return { ok: false, motivo: 'Notificaciones push no configuradas (falta VAPID_PUBLIC_KEY/VAPID_PRIVATE_KEY en .env).' }

  const { rows: reservas } = await pool.query(
    `SELECT r.*, a.nombre AS apartamento_nombre
       FROM reservas r JOIN apartamentos a ON a.id = r.apartamento_id
      WHERE r.estado = 'confirmada'
        AND r.recordatorio_pago_enviado_en IS NULL
        AND r.checkin <= CURRENT_DATE + ($1 || ' days')::interval
      ORDER BY r.checkin`,
    [RECORDATORIO_PAGO_DIAS]
  )

  let notificacionesEnviadas = 0
  for (const r of reservas) {
    const titulo = `💰 Falta el pago — ${r.apartamento_nombre}`
    const cuerpo = `${r.huesped_nombre || 'Huésped sin nombre'}${r.huesped_telefono ? ' · ' + r.huesped_telefono : ''} — check-in ${formatoFechaCorta(r.checkin)}. Llama para confirmar el pago.`
    const enviados = await enviarATodasLasSuscripciones({
      title: titulo,
      body: cuerpo,
      tag: `pago-${r.id}`,
      url: '/'
    })
    if (enviados > 0) {
      notificacionesEnviadas++
      // Solo se marca como enviada si de verdad llegó a alguna suscripción;
      // si todavía no hay ninguna (ej. recién se activó la función y nadie
      // ha dado clic en "Activar notificaciones"), se vuelve a intentar en
      // la próxima revisión en vez de darla por avisada sin haberlo estado.
      await pool.query('UPDATE reservas SET recordatorio_pago_enviado_en = now() WHERE id = $1', [r.id])
    }
  }

  return { ok: true, revisadas: reservas.length, notificacionesEnviadas }
}
