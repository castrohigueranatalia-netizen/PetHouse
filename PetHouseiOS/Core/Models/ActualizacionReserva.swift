//
//  ActualizacionReserva.swift
//  Core/Models
//
//  Actualizaciones que el anfitrión publica MIENTRAS la reserva está 'confirmada' (el
//  huésped ya dejó a la mascota, todavía no la recoge) — notas y/o fotos de cómo va,
//  visibles para el huésped en el detalle de su reserva. Ver
//  db/38-actualizaciones-reserva.sql y pethouse-api/src/routes/reservas.js
//  (GET/POST /api/reservas/:id/actualizaciones).
//

import Foundation

public struct ActualizacionReserva: Decodable, Identifiable, Hashable {
    public let id: String
    public let reservaId: String
    /// Al menos uno de los dos (`notas`, `fotos`) siempre viene con contenido — el servidor
    /// rechaza una actualización completamente vacía.
    public let notas: String?
    public let fotos: [String]
    public let creadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, notas, fotos
        case reservaId = "reserva_id"
        case creadoEn = "creado_en"
    }
}

public struct ActualizacionesReservaResponse: Decodable {
    public let actualizaciones: [ActualizacionReserva]
}

public struct CrearActualizacionRequest: Encodable {
    public let notas: String?
    public let fotos: [String]

    public init(notas: String?, fotos: [String]) {
        self.notas = notas
        self.fotos = fotos
    }
}

public struct CrearActualizacionResponse: Decodable {
    public let actualizacion: ActualizacionReserva
}
