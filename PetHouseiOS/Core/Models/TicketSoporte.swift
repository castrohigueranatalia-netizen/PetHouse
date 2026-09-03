//
//  TicketSoporte.swift
//  Core/Models
//
//  Buzón de soporte — un usuario escribe un ticket, un administrador responde desde el
//  panel web (ver pethouse-api/src/routes/soporte.js y admin.js). Mismo patrón de dos
//  tablas que el chat huésped↔anfitrión (conversaciones/mensajes), pero acá es
//  usuario↔equipo de PetHouse, no entre dos usuarios.
//

import Foundation

public struct TicketSoporte: Decodable, Identifiable, Hashable {
    public let id: String
    public let asunto: String
    public let estado: String // "abierto" | "resuelto"
    public let numMensajes: Int?
    public let creadoEn: String
    public let actualizadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, asunto, estado
        case numMensajes = "num_mensajes"
        case creadoEn = "creado_en"
        case actualizadoEn = "actualizado_en"
    }
}

public struct MensajeSoporte: Decodable, Identifiable, Hashable {
    public let id: String
    public let esAdmin: Bool
    public let texto: String
    public let creadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, texto
        case esAdmin = "es_admin"
        case creadoEn = "creado_en"
    }
}

public struct TicketsResponse: Decodable { public let tickets: [TicketSoporte] }
public struct TicketCreadoResponse: Decodable { public let ticket: TicketSoporte }
public struct TicketDetalleResponse: Decodable { public let ticket: TicketSoporte; public let mensajes: [MensajeSoporte] }
public struct MensajeSoporteCreadoResponse: Decodable { public let mensaje: MensajeSoporte }
