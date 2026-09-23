//
//  ActividadesService.swift
//  Networking/Services
//
//  Envuelve `GET /api/actividades` y `POST /api/actividades` (existentes hoy).
//

import Foundation

public protocol ActividadesServicing: Sendable {
    func listar(tipo: TipoActividad?, q: String?) async throws -> [Actividad]
}

public final class ActividadesService: ActividadesServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func listar(tipo: TipoActividad? = nil, q: String? = nil) async throws -> [Actividad] {
        var items: [URLQueryItem] = []
        if let tipo { items.append(.init(name: "tipo", value: tipo.rawValue)) }
        if let q, !q.isEmpty { items.append(.init(name: "q", value: q)) }
        let request = APIRequest(method: "GET", path: "/actividades", queryItems: items)
        let response: ActividadesListResponse = try await client.send(request)
        return response.actividades
    }
}
