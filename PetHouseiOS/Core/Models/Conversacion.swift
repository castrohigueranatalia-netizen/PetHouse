//
//  Conversacion.swift
//  Core/Models
//
//  GET /api/conversaciones → id, hospedaje_id, otro_id, otro_nombre, no_leidos,
//  ultimo_mensaje, ultimo_en. POST /api/conversaciones (crear-u-obtener) responde solo
//  { id } cuando ya existía, o { id } al crearla — por eso todo excepto `id` es opcional.
//
//  `no_leidos` viene de un `COUNT(*)` en el SQL (ver `pethouse-api/src/routes/chat.js`),
//  que Postgres tipa como `BIGINT` — `node-postgres` lo serializa como `String` por
//  defecto (mismo motivo que las columnas `NUMERIC`, ver FlexibleDecoding.swift), así que
//  se decodifica de forma defensiva igual que los campos de precio en otros modelos.
//

import Foundation

// `Decodable` (no `Codable`): tiene `init(from:)` manual y nunca se envía como body
// (ver la nota de Core/Models/Actividad.swift para el razonamiento completo).
public struct Conversacion: Decodable, Identifiable, Hashable {
    public let id: String
    public let hospedajeId: String?
    public let otroId: String?
    public let otroNombre: String?
    public let noLeidos: Int?
    public let ultimoMensaje: String?
    public let ultimoEn: String?

    enum CodingKeys: String, CodingKey {
        case id
        case hospedajeId = "hospedaje_id"
        case otroId = "otro_id"
        case otroNombre = "otro_nombre"
        case noLeidos = "no_leidos"
        case ultimoMensaje = "ultimo_mensaje"
        case ultimoEn = "ultimo_en"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        hospedajeId = try c.decodeIfPresent(String.self, forKey: .hospedajeId)
        otroId = try c.decodeIfPresent(String.self, forKey: .otroId)
        otroNombre = try c.decodeIfPresent(String.self, forKey: .otroNombre)
        noLeidos = try c.decodeFlexibleIntIfPresent(forKey: .noLeidos)
        ultimoMensaje = try c.decodeIfPresent(String.self, forKey: .ultimoMensaje)
        ultimoEn = try c.decodeIfPresent(String.self, forKey: .ultimoEn)
    }
}

public struct ConversacionesListResponse: Decodable {
    public let conversaciones: [Conversacion]
}

public struct CrearConversacionRequest: Encodable {
    public let anfitrionId: String
    public let hospedajeId: String?

    enum CodingKeys: String, CodingKey {
        case anfitrionId = "anfitrion_id"
        case hospedajeId = "hospedaje_id"
    }

    public init(anfitrionId: String, hospedajeId: String?) {
        self.anfitrionId = anfitrionId
        self.hospedajeId = hospedajeId
    }
}

public struct CrearConversacionResponse: Decodable {
    public let conversacion: Conversacion
}
