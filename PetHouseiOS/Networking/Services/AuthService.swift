//
//  AuthService.swift
//  Networking/Services
//
//  Envuelve `/api/auth/*` (todos existen hoy). Ninguno de estos métodos requiere lógica
//  de "función pendiente" — el módulo Auth está completo en el backend.
//

import Foundation

public protocol AuthServicing: Sendable {
    func registro(nombre: String, email: String, password: String, telefono: String?, rol: Usuario.Rol, mascotaNombre: String?) async throws -> AuthResponse
    func login(email: String, password: String) async throws -> AuthResponse
    func logout(refreshToken: String) async throws
    func me() async throws -> MeResponse
}

public final class AuthService: AuthServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func registro(
        nombre: String, email: String, password: String, telefono: String?,
        rol: Usuario.Rol, mascotaNombre: String?
    ) async throws -> AuthResponse {
        struct Body: Encodable {
            let nombre: String, email: String, password: String
            let telefono: String?, rol: String, mascotaNombre: String?
        }
        let body = Body(nombre: nombre, email: email, password: password, telefono: telefono, rol: rol.rawValue, mascotaNombre: mascotaNombre)
        let data = try JSONEncoder().encode(body)
        let request = APIRequest(method: "POST", path: "/auth/registro", body: data)
        return try await client.send(request)
    }

    public func login(email: String, password: String) async throws -> AuthResponse {
        struct Body: Encodable { let email: String, password: String }
        let data = try JSONEncoder().encode(Body(email: email, password: password))
        let request = APIRequest(method: "POST", path: "/auth/login", body: data)
        return try await client.send(request)
    }

    public func logout(refreshToken: String) async throws {
        struct Body: Encodable { let refreshToken: String }
        let data = try JSONEncoder().encode(Body(refreshToken: refreshToken))
        let request = APIRequest(method: "POST", path: "/auth/logout", body: data)
        try await client.sendNoBody(request)
    }

    public func me() async throws -> MeResponse {
        let request = APIRequest(method: "GET", path: "/auth/me", requiresAuth: true)
        return try await client.send(request)
    }
}
