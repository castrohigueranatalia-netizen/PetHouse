//
//  SoporteService.swift
//  Networking/Services
//
//  Envuelve /api/soporte/* — SOLO los propios tickets del usuario logueado (el servidor
//  filtra por usuario_id en cada ruta). El lado de administrador (ver todos, responder,
//  resolver) vive en el panel web, no en esta app.
//

import Foundation

public protocol SoporteServicing: Sendable {
    func crear(asunto: String, mensaje: String) async throws -> TicketSoporte
    func misTickets() async throws -> [TicketSoporte]
    func detalle(id: String) async throws -> (ticket: TicketSoporte, mensajes: [MensajeSoporte])
    func responder(id: String, texto: String) async throws -> MensajeSoporte
}

public final class SoporteService: SoporteServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func crear(asunto: String, mensaje: String) async throws -> TicketSoporte {
        struct Body: Encodable { let asunto: String, mensaje: String }
        let data = try JSONEncoder().encode(Body(asunto: asunto, mensaje: mensaje))
        let request = APIRequest(method: "POST", path: "/soporte", body: data, requiresAuth: true)
        let response: TicketCreadoResponse = try await client.send(request)
        return response.ticket
    }

    public func misTickets() async throws -> [TicketSoporte] {
        let request = APIRequest(method: "GET", path: "/soporte/mios", requiresAuth: true)
        let response: TicketsResponse = try await client.send(request)
        return response.tickets
    }

    public func detalle(id: String) async throws -> (ticket: TicketSoporte, mensajes: [MensajeSoporte]) {
        let request = APIRequest(method: "GET", path: "/soporte/\(id)", requiresAuth: true)
        let response: TicketDetalleResponse = try await client.send(request)
        return (response.ticket, response.mensajes)
    }

    public func responder(id: String, texto: String) async throws -> MensajeSoporte {
        struct Body: Encodable { let texto: String }
        let data = try JSONEncoder().encode(Body(texto: texto))
        let request = APIRequest(method: "POST", path: "/soporte/\(id)/mensajes", body: data, requiresAuth: true)
        let response: MensajeSoporteCreadoResponse = try await client.send(request)
        return response.mensaje
    }
}
