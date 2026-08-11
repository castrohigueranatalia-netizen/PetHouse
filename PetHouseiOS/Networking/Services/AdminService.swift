//
//  AdminService.swift
//  Networking/Services
//
//  Envuelve /api/admin/* — todo requiere rol admin en el servidor (soloAdmin). Si el
//  usuario logueado no es admin, cualquier llamada aquí simplemente no se hace visible en
//  la UI (no se muestra la pestaña Admin — ver MainTabView), así que un 403 aquí sería un
//  bug de la app, no un caso esperado a manejar con un estado especial.
//

import Foundation

public protocol AdminServicing: Sendable {
    func solicitudes(estado: EstadoVerificacion?) async throws -> [SolicitudAnfitrion]
    func aprobar(solicitudId: String) async throws
    func rechazar(solicitudId: String) async throws
    func estadisticas() async throws -> EstadisticasAdmin
}

public final class AdminService: AdminServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func solicitudes(estado: EstadoVerificacion?) async throws -> [SolicitudAnfitrion] {
        var items: [URLQueryItem] = []
        if let estado { items.append(.init(name: "estado", value: estado.rawValue)) }
        let request = APIRequest(method: "GET", path: "/admin/solicitudes", queryItems: items, requiresAuth: true)
        let response: SolicitudesResponse = try await client.send(request)
        return response.solicitudes
    }

    public func aprobar(solicitudId: String) async throws {
        let request = APIRequest(method: "POST", path: "/admin/solicitudes/\(solicitudId)/aprobar", requiresAuth: true)
        try await client.sendNoBody(request)
    }

    public func rechazar(solicitudId: String) async throws {
        let request = APIRequest(method: "POST", path: "/admin/solicitudes/\(solicitudId)/rechazar", requiresAuth: true)
        try await client.sendNoBody(request)
    }

    public func estadisticas() async throws -> EstadisticasAdmin {
        let request = APIRequest(method: "GET", path: "/admin/estadisticas", requiresAuth: true)
        return try await client.send(request)
    }
}
