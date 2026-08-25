//
//  ChatService.swift
//  Networking/Services
//
//  Envuelve `/api/conversaciones/*` (todo existe hoy, vía REST + polling — no hay
//  WebSockets, ver ARCHITECTURE_AUDIT.md §6 y MVP_SCOPE.md §2). `ChatDetailViewModel`
//  hace el polling periódico llamando a `mensajes(conversacionId:)` cada pocos segundos
//  mientras la vista está visible; este servicio solo expone las llamadas puntuales.
//

import Foundation

public protocol ChatServicing: Sendable {
    func conversaciones() async throws -> [Conversacion]
    func obtenerOCrear(anfitrionId: String, hospedajeId: String?) async throws -> Conversacion
    func mensajes(conversacionId: String) async throws -> [Mensaje]
    /// `texto`/`fotoUrl`: al menos uno de los dos (el servidor lo exige). `fotoUrl` ya viene
    /// subida (ver `ImagenesService`) — este método solo crea el mensaje que la referencia.
    func enviar(conversacionId: String, texto: String?, fotoUrl: String?) async throws -> Mensaje
    func marcarLeidas(conversacionId: String) async throws -> Int
}

public final class ChatService: ChatServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func conversaciones() async throws -> [Conversacion] {
        let request = APIRequest(method: "GET", path: "/conversaciones", requiresAuth: true)
        let response: ConversacionesListResponse = try await client.send(request)
        return response.conversaciones
    }

    public func obtenerOCrear(anfitrionId: String, hospedajeId: String?) async throws -> Conversacion {
        let payload = CrearConversacionRequest(anfitrionId: anfitrionId, hospedajeId: hospedajeId)
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/conversaciones", body: data, requiresAuth: true)
        let response: CrearConversacionResponse = try await client.send(request)
        return response.conversacion
    }

    public func mensajes(conversacionId: String) async throws -> [Mensaje] {
        let request = APIRequest(method: "GET", path: "/conversaciones/\(conversacionId)/mensajes", requiresAuth: true)
        let response: MensajesListResponse = try await client.send(request)
        return response.mensajes
    }

    public func enviar(conversacionId: String, texto: String?, fotoUrl: String?) async throws -> Mensaje {
        let data = try JSONEncoder().encode(EnviarMensajeRequest(texto: texto, fotoUrl: fotoUrl))
        let request = APIRequest(method: "POST", path: "/conversaciones/\(conversacionId)/mensajes", body: data, requiresAuth: true)
        let response: EnviarMensajeResponse = try await client.send(request)
        return response.mensaje
    }

    public func marcarLeidas(conversacionId: String) async throws -> Int {
        let request = APIRequest(method: "POST", path: "/conversaciones/\(conversacionId)/leidas", requiresAuth: true)
        let response: MarcarLeidasResponse = try await client.send(request)
        return response.marcados
    }
}
