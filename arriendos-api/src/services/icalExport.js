// ============================================================
// ARRIENDOS CARTAGENA API · Exportar calendario (.ics)
// ------------------------------------------------------------
// Genera el .ics que se pega en Booking/Airbnb ("importar calendario")
// para bloquear ahí las fechas que ya se reservaron por WhatsApp,
// directo u otra plataforma, y así evitar sobreventas.
// ============================================================
import { aFechaICS } from '../lib/fechas.js'

function escapar(texto) {
  return String(texto).replace(/([,;\\])/g, '\\$1').replace(/\r?\n/g, '\\n')
}

export function generarICS(apartamento, reservas) {
  const dtstamp = new Date().toISOString().replace(/[-:]/g, '').split('.')[0] + 'Z'

  const lineas = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Arriendos Cartagena//arriendos-api//ES',
    'CALSCALE:GREGORIAN',
    `X-WR-CALNAME:${escapar(apartamento.nombre)}`
  ]

  for (const reserva of reservas) {
    lineas.push(
      'BEGIN:VEVENT',
      `UID:${reserva.id}@arriendos-cartagena`,
      `DTSTAMP:${dtstamp}`,
      `DTSTART;VALUE=DATE:${aFechaICS(reserva.checkin)}`,
      `DTEND;VALUE=DATE:${aFechaICS(reserva.checkout)}`,
      `SUMMARY:${escapar(`Reservado${reserva.fuente ? ` (${reserva.fuente})` : ''}`)}`,
      'END:VEVENT'
    )
  }

  lineas.push('END:VCALENDAR')
  return lineas.join('\r\n') + '\r\n'
}
