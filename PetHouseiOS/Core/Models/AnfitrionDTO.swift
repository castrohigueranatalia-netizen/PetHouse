//
//  AnfitrionDTO.swift
//  Core/Models
//
//  Vista de anfitrión: listar los hospedajes propios y ver las reservas RECIBIDAS en ellos
//  (distinto de `GET /api/reservas/mias`, que devuelve las reservas del usuario como
//  DUEÑO/cliente, no como anfitrión que recibe huéspedes).
//
//   GET /api/hospedajes/mios              → 200 { hospedajes: [Hospedaje] }
//       (mismos campos que GET /api/hospedajes/:id, filtrados por anfitrion_id = usuario
//       autenticado; requiere rol anfitrion, igual que POST /api/hospedajes)
//
//   GET /api/hospedajes/:id/reservas      → 200 { reservas: [Reserva] }
//       (reservas hechas POR OTROS usuarios EN este hospedaje, incluye usuario_nombre;
//       requiere ser el anfitrión dueño del hospedaje)
//
//   GET /api/hospedajes/mios/reservas     → 200 { reservas: [Reserva] }
//       (TODAS las reservas de TODOS los hospedajes propios, en cualquier estado — a
//       diferencia de GET /:id/reservas, que es de un solo hospedaje. Usada por
//       AnfitrionDashboardViewModel para calcular mascotas hospedadas y total ganado.)
//

import Foundation

public struct MisHospedajesResponse: Codable {
    public let hospedajes: [Hospedaje]
}

public struct ReservasRecibidasResponse: Decodable {
    public let reservas: [Reserva]
}

public struct HistorialReservasResponse: Decodable {
    public let reservas: [Reserva]
}
