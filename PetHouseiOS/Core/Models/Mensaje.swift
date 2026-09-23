//
//  Mensaje.swift
//  Core/Models
//
//  GET/POST /api/conversaciones/:id/mensajes → id, remitente_id, texto, foto_url, leido,
//  creado_en. Un mensaje puede ser solo texto, solo una foto, o los dos — al menos uno de
//  `texto`/`fotoUrl` siempre viene (el servidor lo exige, ver db/32-fotos-chat.sql).
//

import Foundation

public struct Mensaje: Codable, Identifiable, Hashable {
    public let id: String
    public let remitenteId: String
    public let texto: String?
    public let fotoUrl: String?
    public let leido: Bool
    public let creadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, texto, leido
        case remitenteId = "remitente_id"
        case fotoUrl = "foto_url"
        case creadoEn = "creado_en"
    }
}

public struct MensajesListResponse: Codable {
    public let mensajes: [Mensaje]
}

public struct EnviarMensajeRequest: Encodable {
    public let texto: String?
    public let fotoUrl: String?
    public init(texto: String? = nil, fotoUrl: String? = nil) {
        self.texto = texto
        self.fotoUrl = fotoUrl
    }
}

public struct EnviarMensajeResponse: Codable {
    public let mensaje: Mensaje
}

public struct MarcarLeidasResponse: Codable {
    public let marcados: Int
}
