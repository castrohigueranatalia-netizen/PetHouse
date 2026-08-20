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
    /// Respaldo de "olvidé mi contraseña" cuando el código por correo no llega: sube una
    /// foto de la cédula SIN sesión, para que un admin la revise y genere un PIN que se usa
    /// en la misma pantalla del código de 6 dígitos (ver restablecerPassword arriba).
    func subirIdentidadRecuperacion(email: String, datos: Data, nombreArchivo: String, mimeType: String) async throws
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

    /// Multipart/form-data manual, igual que ImagenesService.subir — pero SIN
    /// `requiresAuth` (el usuario, por definición, no tiene sesión en este flujo) y con el
    /// correo en la query string (mismo motivo que `tipo=verificacion` en subidas: el
    /// servidor necesita saberlo desde antes de que llegue el archivo en el multipart).
    func subirIdentidadRecuperacion(email: String, datos: Data, nombreArchivo: String, mimeType: String) async throws {
        let boundary = "PetHouse-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"archivo\"; filename=\"\(nombreArchivo)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(datos)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let request = APIRequest(
            method: "POST", path: "/auth/verificar-identidad",
            queryItems: [URLQueryItem(name: "email", value: email)],
            body: body, contentType: "multipart/form-data; boundary=\(boundary)"
        )
        try await client.sendNoBody(request)
    }
}
