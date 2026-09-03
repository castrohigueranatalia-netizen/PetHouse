//
//  FechaBloqueada.swift
//  Core/Models
//
//  Un rango de fechas que el anfitrión bloqueó a mano en un hospedaje propio (viaje,
//  mantenimiento, etc.), sin necesidad de una reserva real ni de pausar el hospedaje entero
//  — ver GET/POST/DELETE /api/hospedajes/:id/fechas-bloqueadas y db/34-fechas-bloqueadas.sql.
//  `hasta` es EXCLUSIVA, mismo criterio que `Reserva.hasta`.
//

import Foundation

public struct FechaBloqueada: Decodable, Identifiable, Hashable, Sendable {
    public let id: String
    public let desde: String   // YYYY-MM-DD
    public let hasta: String   // YYYY-MM-DD, exclusiva
    public let motivo: String?
    public let creadoEn: String?

    enum CodingKeys: String, CodingKey {
        case id, desde, hasta, motivo
        case creadoEn = "creado_en"
    }

    public init(id: String, desde: String, hasta: String, motivo: String?, creadoEn: String?) {
        self.id = id
        self.desde = desde
        self.hasta = hasta
        self.motivo = motivo
        self.creadoEn = creadoEn
    }
}

public struct FechasBloqueadasResponse: Decodable {
    public let bloqueos: [FechaBloqueada]
}

public struct BloquearFechasRequest: Encodable {
    public let desde: String
    public let hasta: String
    public let motivo: String?

    public init(desde: String, hasta: String, motivo: String?) {
        self.desde = desde
        self.hasta = hasta
        self.motivo = motivo
    }
}

public struct BloquearFechasResponse: Decodable {
    public let bloqueo: FechaBloqueada
}
