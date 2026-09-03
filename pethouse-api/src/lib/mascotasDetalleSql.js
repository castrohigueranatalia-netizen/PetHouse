// ============================================================
// PETHOUSE API · Fragmento SQL: mascotas concretas de una reserva
// ------------------------------------------------------------
// Subconsulta reutilizada en GET /api/reservas/mias, GET /api/reservas/:id,
// GET /api/hospedajes/:id/reservas y POST /api/reservas/:id/aceptar|rechazar — todas
// necesitan mostrarle a alguien (dueño o anfitrión) qué mascotas concretas van en la
// reserva, con su raza/notas (ver tabla reserva_mascotas, 11-reservas-pendientes-mascotas.sql).
// Asume que la reserva está aliaseada como `rs` en el FROM de quien la use.
// ============================================================
export const MASCOTAS_DETALLE_SQL = `COALESCE(
  (SELECT json_agg(json_build_object(
            'id', m.id, 'nombre', m.nombre, 'especie', m.especie, 'raza', m.raza,
            'edad', m.edad, 'tamano', m.tamano, 'peso_kg', m.peso_kg,
            'vacunas_dia', m.vacunas_dia, 'necesita_medicamentos', m.necesita_medicamentos,
            'notas', m.notas, 'fotos', m.fotos
          ))
     FROM reserva_mascotas rm JOIN mascotas m ON m.id = rm.mascota_id
    WHERE rm.reserva_id = rs.id),
  '[]'
) AS mascotas_detalle`
