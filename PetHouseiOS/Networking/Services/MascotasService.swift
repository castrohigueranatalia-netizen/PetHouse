//
//  MascotasService.swift
//  Networking/Services
//
//  🔴 Hoy solo se puede crear UNA mascota, durante el registro (`POST /api/auth/registro`
//  con `mascotaNombre`). No existe `POST/PATCH/DELETE /api/mascotas` — ver
//  ARCHITECTURE_AUDIT.md §2.1 y Core/Models/Mascota.swift para el contrato propuesto.
//  Igual que `PerfilService`: se llama al contrato propuesto ya, listo para cuando el
//  backend lo implemente; hasta entonces el 404 de ruta se traduce a
//  `AppError.rutaNoImplementada` y la UI muestra el estado "función pendiente".
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
