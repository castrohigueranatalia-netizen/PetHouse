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
    /// Pide el código de 6 dígitos (paso 1 de "olvidé mi contraseña") — responde igual
    /// exista o no una cuenta con ese correo, así que un `throw` acá es solo por un error
    /// de red/servidor real, no porque el correo no exista.
    func olvidePassword(email: String) async throws
    /// Confirma el código y guarda la contraseña nueva (paso 2). Cierra todas las sesiones
    /// existentes de esa cuenta del lado del servidor — la propia sesión de este
    /// dispositivo, si la había, también queda cerrada y hay que iniciar sesión de nuevo.
    func restablecerPassword(email: String, codigo: String, passwordNueva: String) async throws
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

    public func olvidePassword(email: String) async throws {
        struct Body: Encodable { let email: String }
        let data = try JSONEncoder().encode(Body(email: email))
        let request = APIRequest(method: "POST", path: "/auth/olvide-password", body: data)
        try await client.sendNoBody(request)
    }

    public func restablecerPassword(email: String, codigo: String, passwordNueva: String) async throws {
        struct Body: Encodable { let email: String, codigo: String, passwordNueva: String }
        let data = try JSONEncoder().encode(Body(email: email, codigo: codigo, passwordNueva: passwordNueva))
        let request = APIRequest(method: "POST", path: "/auth/restablecer-password", body: data)
        try await client.sendNoBody(request)
    }
}
