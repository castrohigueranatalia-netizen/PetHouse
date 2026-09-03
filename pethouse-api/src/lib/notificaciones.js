// ============================================================
// PETHOUSE API · Crear una fila en el historial de notificaciones (ver db/19-notificaciones.sql)
// ------------------------------------------------------------
// Un solo punto para insertar, usado desde cada lugar que ya dispara un aviso instantáneo
// (routes/reservas.js al crear/aceptar/rechazar, routes/admin.js al aprobar/rechazar una
// verificación) — así la campana (GET /api/notificaciones) tiene el mismo contenido que esos
// avisos, sin duplicar el texto en cada sitio.
//
// Recibe `queryable` (el `pool` normal, o un `client` de una transacción en curso) en vez de
// importar `pool` acá adentro — routes/admin.js llama esto DENTRO de una transacción
// (BEGIN/COMMIT) y necesita que el INSERT use ese mismo `client`, no una conexión aparte.
// ============================================================

export async function crearNotificacion(queryable, { usuarioId, tipo, titulo, mensaje, reservaId = null, hospedajeId = null }) {
  await queryable.query(
    `INSERT INTO notificaciones (usuario_id, tipo, titulo, mensaje, reserva_id, hospedaje_id)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [usuarioId, tipo, titulo, mensaje, reservaId, hospedajeId]
  )
}
