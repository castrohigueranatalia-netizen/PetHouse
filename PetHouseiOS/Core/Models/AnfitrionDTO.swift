//
//  AnfitrionDTO.swift
//  Core/Models
//
//  🔴 Vista de anfitrión: listar los hospedajes propios y ver las reservas RECIBIDAS en
//  ellos. Hoy no existe ninguna de las dos rutas — `GET /api/reservas/mias` devuelve las
//  reservas del usuario como DUEÑO/cliente, no como anfitrión que recibe huéspedes (ver
//  ARCHITECTURE_AUDIT.md §2.1, gap 🟡 #6, y MVP_SCOPE.md §4.4). Contrato propuesto:
//
//   GET /api/hospedajes/mios              → 200 { hospedajes: [Hospedaje] }
//       (mismos campos que GET /api/hospedajes/:id, filtrados por anfitrion_id = usuario
//       autenticado; requiere rol anfitrion, igual que POST /api/hospedajes)
//
//   GET /api/hospedajes/:id/reservas      → 200 { reservas: [Reserva] }
//       (reservas hechas POR OTROS usuarios EN este hospedaje; requiere ser el anfitrión
//       dueño del hospedaje)
//

import Foundation

public struct MisHospedajesResponse: Codable {
    public let hospedajes: [Hospedaje]
}

public struct ReservasRecibidasResponse: Decodable {
    public let reservas: [Reserva]
}
