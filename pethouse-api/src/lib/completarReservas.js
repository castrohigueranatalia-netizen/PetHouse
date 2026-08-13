// ============================================================
// PETHOUSE API · Reservas completadas/vencidas automáticamente
// ------------------------------------------------------------
// Sin job en segundo plano (cero infra extra — ver db/16-completar-reservas-vencidas.sql):
// se llama al leer/tocar reservas, así el estado siempre está al día apenas alguien lo
// consulta, sin necesitar un cron corriendo aparte.
// ============================================================
import { pool } from '../config.js'

export async function completarReservasVencidas() {
  // La estadía ya ocurrió: pasa a 'completada' — habilita "Dejar reseña" (huésped) y
  // "Calificar huésped" (anfitrión, ver db/15-resenas-huesped.sql).
  await pool.query(
    `UPDATE reservas SET estado = 'completada'
      WHERE estado = 'confirmada' AND hasta < CURRENT_DATE`
  )
  // El anfitrión nunca respondió antes de que llegara la fecha: se trata como vencida.
  // 'rechazada' (no 'cancelada') porque semánticamente el desenlace es el mismo — nunca se
  // confirmó — y así reutiliza el aviso que ya existe para solicitudes resueltas
  // (notificado = FALSE → GET /api/reservas/notificaciones/resueltas).
  await pool.query(
    `UPDATE reservas SET estado = 'rechazada', notificado = FALSE
      WHERE estado = 'pendiente' AND hasta < CURRENT_DATE`
  )
}
