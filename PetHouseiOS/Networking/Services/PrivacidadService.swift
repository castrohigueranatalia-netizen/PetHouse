//
//  PrivacidadService.swift
//  Networking/Services
//
//  Envuelve /api/privacidad/* — SOLO las propias solicitudes del usuario logueado (el
//  servidor filtra por usuario_id en cada ruta). El lado de administrador (ver todas,
//  responder) vive en el panel web, no en esta app.
//

import Foundation

public protocol PrivacidadServicing: Sendable {
    func crear(categoria: CategoriaPrivacidad, mensaje: String) async throws -> SolicitudPrivacidad
    func misSolicitudes() async throws -> [SolicitudPrivacidad]
}

public final class PrivacidadService: PrivacidadServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func crear(categoria: CategoriaPrivacidad, mensaje: String) async throws -> SolicitudPrivacidad {
        struct Body: Encodable { let categoria: String, mensaje: String }
        let data = try JSONEncoder().encode(Body(categoria: categoria.rawValue, mensaje: mensaje))
        let request = APIRequest(method: "POST", path: "/privacidad", body: data, requiresAuth: true)
        let response: SolicitudPrivacidadCreadaResponse = try await client.send(request)
        return response.solicitud
    }

    public func misSolicitudes() async throws -> [SolicitudPrivacidad] {
        let request = APIRequest(method: "GET", path: "/privacidad/mias", requiresAuth: true)
        let response: SolicitudesPrivacidadResponse = try await client.send(request)
        return response.solicitudes
    }
}
