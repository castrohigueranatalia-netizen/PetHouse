// ============================================================
// ARRIENDOS CARTAGENA API · Sincronización con Booking/Airbnb (iCal)
// ------------------------------------------------------------
// Booking y Airbnb no dan una API abierta para leer reservas (esa API
// solo la otorgan a channel managers registrados), pero sí ofrecen un
// link de "exportar calendario" (.ics) por cada apartamento. Este módulo
// lee ese link cada cierto tiempo y crea/actualiza reservas aquí.
//
// Importante: ese calendario solo trae fechas bloqueadas, NO el nombre,
// teléfono ni el precio del huésped (por privacidad de la plataforma).
// Esos datos se siguen completando a mano cuando llega la notificación.
// ============================================================
import ical from 'node-ical'
import { pool } from '../config.js'
import { aFechaSQL } from '../lib/fechas.js'

// ---- Sincroniza un solo apartamento y devuelve un resumen ----
async function sincronizarApartamento(apartamento) {
  const eventos = await ical.async.fromURL(apartamento.ical_url_importar)
  const vevents = Object.values(eventos).filter((e) => e && e.type === 'VEVENT' && e.uid && e.start && e.end)

  const uidsVistos = []
  let importadas = 0
  const conflictos = []

  for (const ev of vevents) {
    const checkin = aFechaSQL(ev.start)
    const checkout = aFechaSQL(ev.end)
    if (checkout <= checkin) continue // evento de un solo día u otro ruido del feed

    uidsVistos.push(ev.uid)

    try {
      const { rows } = await pool.query(
        `INSERT INTO reservas (apartamento_id, checkin, checkout, fuente, estado, notas, ical_uid)
         VALUES ($1, $2, $3, 'booking', 'confirmada', $4, $5)
         ON CONFLICT (apartamento_id, ical_uid) DO UPDATE
           SET checkin = EXCLUDED.checkin, checkout = EXCLUDED.checkout, estado = 'confirmada'
         RETURNING (xmax = 0) AS es_nueva`,
        [apartamento.id, checkin, checkout, ev.summary || null, ev.uid]
      )
      if (rows[0]?.es_nueva) importadas++
    } catch (err) {
      // 23P01 = se cruza con otra reserva ya confirmada a mano (posible sobreventa real):
      // se deja pendiente de revisión en vez de tumbar toda la sincronización.
      if (err.code === '23P01') {
        conflictos.push(`${checkin} → ${checkout} se cruza con otra reserva ya confirmada`)
      } else {
        throw err
      }
    }
  }

  // Lo que antes vino de este mismo feed y ya no aparece = se canceló en la plataforma
  const { rowCount: canceladas } = await pool.query(
    `UPDATE reservas SET estado = 'cancelada'
      WHERE apartamento_id = $1 AND fuente = 'booking' AND estado = 'confirmada'
        AND ical_uid IS NOT NULL AND NOT (ical_uid = ANY($2::text[]))`,
    [apartamento.id, uidsVistos]
  )

  return { importadas, canceladas, conflictos }
}

// ---- Sincroniza un apartamento por id y guarda el resultado en la tabla ----
export async function sincronizarApartamentoPorId(id) {
  const { rows } = await pool.query('SELECT id, ical_url_importar FROM apartamentos WHERE id = $1', [id])
  if (!rows.length) return { ok: false, error: 'Apartamento no encontrado.' }
  const apartamento = rows[0]
  if (!apartamento.ical_url_importar) return { ok: false, error: 'Este apartamento no tiene un link de Booking/Airbnb configurado.' }

  try {
    const resultado = await sincronizarApartamento(apartamento)
    const error = resultado.conflictos.length ? resultado.conflictos.join(' · ') : null
    await pool.query('UPDATE apartamentos SET ical_ultima_sync = now(), ical_ultimo_error = $1 WHERE id = $2', [error, id])
    return { ok: true, ...resultado }
  } catch (err) {
    const mensaje = err.message?.slice(0, 500) || 'Error desconocido al sincronizar.'
    await pool.query('UPDATE apartamentos SET ical_ultima_sync = now(), ical_ultimo_error = $1 WHERE id = $2', [mensaje, id])
    return { ok: false, error: mensaje }
  }
}

// ---- Sincroniza todos los apartamentos activos que tengan link configurado ----
export async function sincronizarTodos() {
  const { rows } = await pool.query(
    `SELECT id FROM apartamentos WHERE activo AND ical_url_importar IS NOT NULL`
  )
  const resultados = []
  for (const { id } of rows) {
    resultados.push({ apartamento_id: id, ...(await sincronizarApartamentoPorId(id)) })
  }
  return resultados
}
