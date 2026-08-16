//
//  NotificacionesService.swift
//  Networking/Services
//
//  Envuelve `/api/notificaciones/*` — el historial completo detrás de la campana (ver
//  Core/Models/Notificacion.swift). Sin push notifications (ADR-7): la app pide este
//  historial por polling puntual (al abrir la campana, y para el contador del badge al
//  arrancar/loguearse/registrarse — ver SessionStore).
//

import Foundation

public protocol NotificacionesServicing: Sendable {
    func listar() async throws -> NotificacionesResponse
    func marcarLeida(id: String) async throws
    func marcarTodasLeidas() async throws
}

public final class NotificacionesService: NotificacionesServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func listar() async throws -> NotificacionesResponse {
        let request = APIRequest(method: "GET", path: "/notificaciones", requiresAuth: true)
        return try await client.send(request)
    }

    public func marcarLeida(id: String) async throws {
        let request = APIRequest(method: "POST", path: "/notificaciones/\(id)/leida", requiresAuth: true)
        try await client.sendNoBody(request)
    }

    public func marcarTodasLeidas() async throws {
        let request = APIRequest(method: "POST", path: "/notificaciones/leer-todas", requiresAuth: true)
        try await client.sendNoBody(request)
    }
}
