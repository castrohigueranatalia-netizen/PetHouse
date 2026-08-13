//
//  UsuariosService.swift
//  Networking/Services
//
//  Envuelve `GET /api/usuarios/:id/resenas` — la evaluación pública de un huésped (espejo
//  de las reseñas de un hospedaje en `GET /api/hospedajes/:id`). El anfitrión la consulta
//  desde `EvaluacionHuespedView` al revisar una solicitud de reserva.
//

import Foundation

public protocol UsuariosServicing: Sendable {
    func resenas(usuarioId: String) async throws -> [Resena]
}

public final class UsuariosService: UsuariosServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func resenas(usuarioId: String) async throws -> [Resena] {
        let request = APIRequest(method: "GET", path: "/usuarios/\(usuarioId)/resenas", requiresAuth: true)
        let response: ResenasUsuarioResponse = try await client.send(request)
        return response.resenas
    }
}
