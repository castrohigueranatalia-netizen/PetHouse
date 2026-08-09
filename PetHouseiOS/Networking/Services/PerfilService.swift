//
//  PerfilService.swift
//  Networking/Services
//
//  🔴 `PATCH /api/auth/me` NO existe en el backend hoy (ver ARCHITECTURE_AUDIT.md §2.1 y
//  Core/Models/Usuario.swift para el contrato propuesto). Este servicio llama a la ruta
//  de todas formas: cuando el backend la agregue, empieza a funcionar sin tocar el
//  cliente. Hasta entonces, `APIClient` traduce el 404 de "ruta no montada" a
//  `AppError.rutaNoImplementada`, que `PerfilViewModel` usa para mostrar el estado
//  "Esta función estará disponible pronto" en vez de un error genérico o un falso éxito.
//

import Foundation

public protocol PerfilServicing: Sendable {
    func editarPerfil(nombre: String?, telefono: String?, fotoUrl: String?) async throws -> Usuario
}

public final class PerfilService: PerfilServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func editarPerfil(nombre: String?, telefono: String?, fotoUrl: String?) async throws -> Usuario {
        let payload = EditarPerfilRequest(nombre: nombre, telefono: telefono, fotoUrl: fotoUrl)
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "PATCH", path: "/auth/me", body: data, requiresAuth: true)
        let response: EditarPerfilResponse = try await client.send(request)
        return response.usuario
    }
}
