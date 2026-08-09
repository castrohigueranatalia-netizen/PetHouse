//
//  Mensaje.swift
//  Core/Models
//
//  GET/POST /api/conversaciones/:id/mensajes → id, remitente_id, texto, leido, creado_en.
//

import Foundation

public struct Mensaje: Codable, Identifiable, Hashable {
    public let id: String
    public let remitenteId: String
    public let texto: String
    public let leido: Bool
    public let creadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, texto, leido
        case remitenteId = "remitente_id"
        case creadoEn = "creado_en"
    }
}

public struct MensajesListResponse: Codable {
    public let mensajes: [Mensaje]
}

public struct EnviarMensajeRequest: Encodable {
    public let texto: String
    public init(texto: String) { self.texto = texto }
}

public struct EnviarMensajeResponse: Codable {
    public let mensaje: Mensaje
}

public struct MarcarLeidasResponse: Codable {
    public let marcados: Int
}
