//
//  FavoritosService.swift
//  Networking/Services
//
//  🔴 La tabla `favoritos` existe en el esquema pero no hay rutas montadas (ver
//  ARCHITECTURE_AUDIT.md §2.1 y Core/Models/Favorito.swift para el contrato propuesto).
//

import Foundation

public protocol FavoritosServicing: Sendable {
    func listar() async throws -> [Hospedaje]
    func agregar(hospedajeId: String) async throws
    func quitar(hospedajeId: String) async throws
}

public final class FavoritosService: FavoritosServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func listar() async throws -> [Hospedaje] {
        let request = APIRequest(method: "GET", path: "/favoritos", requiresAuth: true)
        let response: FavoritosListResponse = try await client.send(request)
        return response.favoritos
    }

    public func agregar(hospedajeId: String) async throws {
        let data = try JSONEncoder().encode(AgregarFavoritoRequest(hospedajeId: hospedajeId))
        let request = APIRequest(method: "POST", path: "/favoritos", body: data, requiresAuth: true)
        try await client.sendNoBody(request)
    }

    public func quitar(hospedajeId: String) async throws {
        let request = APIRequest(method: "DELETE", path: "/favoritos/\(hospedajeId)", requiresAuth: true)
        try await client.sendNoBody(request)
    }
}
