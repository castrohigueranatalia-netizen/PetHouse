//
//  Disponibilidad.swift
//  Core/Models
//
//  GET /api/hospedajes/:id/disponibilidad (pública) → rangos de fecha ya ocupados
//  (confirmada/pendiente), SIN datos del huésped — el huésped que va a reservar la usa para
//  ver qué fechas evitar antes de armar su solicitud (ver PHSelectorRangoFechas).
//

import Foundation

public struct RangoOcupado: Decodable {
    public let desde: String   // YYYY-MM-DD
    public let hasta: String   // YYYY-MM-DD
    public let estado: String  // "confirmada" | "pendiente"
}

public struct DisponibilidadResponse: Decodable {
    public let ocupado: [RangoOcupado]
}
