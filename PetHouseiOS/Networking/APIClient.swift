//
//  APIClient.swift
//  Networking
//
//  Cliente HTTP único de la app: URLSession + async/await, sin Combine y sin
//  dependencias de terceros. Responsabilidades:
//   1. Anteponer `APIConfig.apiBaseURL` y armar la URL con query items.
//   2. Adjuntar `Authorization: Bearer <accessToken>` cuando la petición lo requiere.
//   3. Si el servidor responde 401, intenta UNA vez `POST /api/auth/refresh` con el
//      refresh token guardado en Keychain y reintenta la petición original con el
//      access token nuevo. Si el refresh también falla, limpia los tokens y notifica
//      `onSessionExpired` para que la capa de App cierre la sesión.
//   4. Mapea el JSON de error `{ "error": "..." }` del backend a `AppError`, distinguiendo
//      un 404 de "ruta no montada" (mensaje `"Ruta no encontrada: MÉTODO /ruta"`, que es
//      literalmente lo que emite `pethouse-api/src/middleware/middleware.js#noEncontrado`)
//      de un 404 de "recurso no encontrado" dentro de una ruta que sí existe. Esta
//      distinción es la base de los estados "función pendiente en el servidor" en las
//      features sin backend todavía (favoritos, editar perfil, CRUD de mascotas, etc).
//
//  Regla de capas: este archivo NO importa SwiftUI. Es un `actor` para serializar el
//  refresh de tokens (si dos peticiones reciben 401 a la vez, solo una dispara el
//  refresh; la otra espera el mismo resultado) sin necesidad de locks manuales.
//

import Foundation

public struct APIRequest {
    public var method: String
    /// Ruta relativa a `/api`, ej. `"/hospedajes"` o `"/reservas/\(id)/cancelar"`.
    public var path: String
    public var queryItems: [URLQueryItem]
    public var body: Data?
    /// `application/json` por defecto. `ImagenesService` la pisa con
    /// `multipart/form-data; boundary=...` para la subida de archivos.
    public var contentType: String
    /// Si `true`, exige un access token válido y dispara el flujo de refresh en 401.
    public var requiresAuth: Bool

    public init(
        method: String, path: String, queryItems: [URLQueryItem] = [], body: Data? = nil,
        contentType: String = "application/json", requiresAuth: Bool = false
    ) {
        self.method = method
        self.path = path
        self.queryItems = queryItems
        self.body = body
        self.contentType = contentType
        self.requiresAuth = requiresAuth
    }
}

public protocol APIClientProtocol: Sendable {
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
    func sendNoBody(_ request: APIRequest) async throws
}

public actor APIClient: APIClientProtocol {
    public static let shared = APIClient()

    private let session: URLSession
    private let keychain: KeychainStoring
    private let baseURL: URL

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d // los modelos decodifican fechas como String crudo (ver Core/Utils/DateFormatting.swift)
    }()
    private let encoder = JSONEncoder()

    /// Notificada cuando el refresh falla y la sesión debe cerrarse. Se fija desde `App/`
    /// (AppState/SessionStore) al arrancar — Networking no conoce SwiftUI ni AppState.
    public var onSessionExpired: (@Sendable () async -> Void)?

    /// Coordina refresh concurrente: si varias peticiones reciben 401 a la vez, solo una
    /// dispara `POST /auth/refresh`; el resto espera esta misma tarea.
    private var refreshTask: Task<Bool, Never>?

    public init(baseURL: URL = APIConfig.apiBaseURL, session: URLSession = .shared, keychain: KeychainStoring = KeychainStore.shared) {
        self.baseURL = baseURL
        self.session = session
        self.keychain = keychain
    }

    public func setOnSessionExpired(_ handler: @escaping @Sendable () async -> Void) {
        onSessionExpired = handler
    }

    // MARK: - API pública

    public func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        let data = try await performWithRefresh(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.decodificacion
        }
    }

    /// Para respuestas sin body útil (ej. `{ ok: true }` que no siempre nos importa) o
    /// endpoints 204. Sigue validando status/errores igual que `send`.
    public func sendNoBody(_ request: APIRequest) async throws {
        _ = try await performWithRefresh(request)
    }

    // MARK: - Encoding de body

    nonisolated public func encode<T: Encodable>(_ value: T) throws -> Data {
        let e = JSONEncoder()
        return try e.encode(value)
    }

    // MARK: - Core

    private func performWithRefresh(_ request: APIRequest) async throws -> Data {
        do {
            return try await perform(request)
        } catch AppError.sesionExpirada where request.requiresAuth {
            let renovado = await refrescarSesion()
            guard renovado else {
                await onSessionExpired?()
                throw AppError.sesionExpirada
            }
            // Reintento único con el access token nuevo.
            return try await perform(request)
        }
    }

    private func perform(_ request: APIRequest) async throws -> Data {
        var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: false)
        if !request.queryItems.isEmpty {
            components?.queryItems = request.queryItems
        }
        guard let url = components?.url else {
            throw AppError.desconocido("URL inválida: \(request.path)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.setValue(request.contentType, forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = request.body

        if request.requiresAuth {
            guard let token = keychain.leer(.accessToken) else {
                throw AppError.sesionExpirada
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw AppError.desconocido(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.desconocido("Respuesta HTTP inválida.")
        }

        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            throw AppError.sesionExpirada
        default:
            throw mapErrorBody(data, status: http.statusCode)
        }
    }

    private func mapErrorBody(_ data: Data, status: Int) -> AppError {
        struct ErrorBody: Decodable { let error: String }
        let mensaje = (try? decoder.decode(ErrorBody.self, from: data))?.error
            ?? "Ocurrió un error inesperado (código \(status))."

        // `noEncontrado` en el backend responde exactamente con este formato de mensaje
        // cuando la RUTA no existe (ver pethouse-api/src/middleware/middleware.js).
        // Un 404 de "recurso no encontrado" dentro de una ruta que sí existe usa otros
        // mensajes ("Hospedaje no encontrado.", "Reserva no encontrada.", etc), así que
        // esta comprobación no da falsos positivos con esos casos.
        if status == 404 && mensaje.hasPrefix("Ruta no encontrada:") {
            return .rutaNoImplementada
        }
        return .servidor(status: status, mensaje: mensaje)
    }

    private func mapURLError(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .sinConexion
        default:
            return .desconocido(error.localizedDescription)
        }
    }

    // MARK: - Refresh coordinado

    private func refrescarSesion() async -> Bool {
        if let existing = refreshTask {
            return await existing.value
        }
        let task = Task<Bool, Never> { [weak self] in
            await self?.hacerRefresh() ?? false
        }
        refreshTask = task
        let result = await task.value
        refreshTask = nil
        return result
    }

    private func hacerRefresh() async -> Bool {
        guard let refreshToken = keychain.leer(.refreshToken) else { return false }
        do {
            let body = try encoder.encode(["refreshToken": refreshToken])
            let request = APIRequest(method: "POST", path: "/auth/refresh", body: body, requiresAuth: false)
            let data = try await perform(request)
            let auth = try decoder.decode(AuthResponse.self, from: data)
            try keychain.guardar(auth.accessToken, para: .accessToken)
            try keychain.guardar(auth.refreshToken, para: .refreshToken)
            return true
        } catch {
            keychain.borrarTodo()
            return false
        }
    }
}
