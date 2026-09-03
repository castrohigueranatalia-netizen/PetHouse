//
//  MascotasService.swift
//  Networking/Services
//
//  Envuelve el CRUD completo de `/api/mascotas` (ver Core/Models/Mascota.swift y
//  pethouse-api/src/routes/mascotas.js) — además de la única mascota que se puede crear
//  durante el registro (`POST /api/auth/registro` con `mascotaNombre`), que no pasa por acá.
//

import Foundation

public protocol MascotasServicing: Sendable {
    func crear(_ payload: GuardarMascotaRequest) async throws -> Mascota
    func actualizar(id: String, _ payload: GuardarMascotaRequest) async throws -> Mascota
    func eliminar(id: String) async throws
}

public final class MascotasService: MascotasServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func crear(_ payload: GuardarMascotaRequest) async throws -> Mascota {
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/mascotas", body: data, requiresAuth: true)
        let response: MascotaResponse = try await client.send(request)
        return response.mascota
    }

    public func actualizar(id: String, _ payload: GuardarMascotaRequest) async throws -> Mascota {
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "PATCH", path: "/mascotas/\(id)", body: data, requiresAuth: true)
        let response: MascotaResponse = try await client.send(request)
        return response.mascota
    }

    public func eliminar(id: String) async throws {
        let request = APIRequest(method: "DELETE", path: "/mascotas/\(id)", requiresAuth: true)
        try await client.sendNoBody(request)
    }
}
