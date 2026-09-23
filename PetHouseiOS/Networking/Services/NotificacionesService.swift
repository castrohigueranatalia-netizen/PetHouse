//
//  NotificacionesService.swift
//  Networking/Services
//
//  Envuelve `/api/notificaciones/*` — el historial completo detrás de la campana (ver
//  Core/Models/Notificacion.swift). Además de pedirlo por polling puntual (al abrir la
//  campana, y para el contador del badge al arrancar/loguearse/registrarse — ver
//  SessionStore), `registrarDispositivo` avisa al servidor del token de push del
//  dispositivo (ver AppDelegate.swift), para que además de la campana llegue un push real.
//

import Foundation

public protocol NotificacionesServicing: Sendable {
    func listar() async throws -> NotificacionesResponse
    func marcarLeida(id: String) async throws
    func marcarTodasLeidas() async throws
    /// Registra (o reasigna a la cuenta actual) el token de push que Apple le entregó al
    /// dispositivo — ver AppDelegate.swift. No hace nada visible en la UI; si falla (ej.
    /// sin red en ese instante), simplemente no se registra y no se reintenta.
    func registrarDispositivo(token: String) async throws
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

    public func registrarDispositivo(token: String) async throws {
        let data = try JSONEncoder().encode(["token": token])
        let request = APIRequest(method: "POST", path: "/notificaciones/dispositivo", body: data, requiresAuth: true)
        try await client.sendNoBody(request)
    }
}
