//
//  AnfitrionService.swift
//  Networking/Services
//
//  Vista de anfitrión: publicar (existe hoy, ver `HospedajesService.crear`), y "mis
//  hospedajes"/"reservas recibidas" (🔴 no existen — ver ARCHITECTURE_AUDIT.md §2.1 gap
//  🟡 #6 y Core/Models/AnfitrionDTO.swift para el contrato propuesto).
//

import Foundation

public protocol AnfitrionServicing: Sendable {
    func misHospedajes() async throws -> [Hospedaje]
    func reservasRecibidas(hospedajeId: String) async throws -> [Reserva]

    /// Envía la verificación de seguridad — activa `Usuario.esAnfitrion` en el servidor
    /// si tiene éxito (ver pethouse-api/src/routes/anfitrion.js).
    func enviarVerificacion(_ payload: EnviarVerificacionRequest) async throws -> VerificacionAnfitrion
    func obtenerVerificacion() async throws -> VerificacionAnfitrion?
    /// Marca como vista la resolución (aprobado/rechazado) de la solicitud propia — se
    /// llama apenas se le muestra el aviso al usuario (ver PerfilViewModel).
    func marcarVerificacionNotificada() async throws
    func enviarPreferencias(_ payload: EnviarPreferenciasRequest) async throws -> PreferenciasAnfitrion
    func obtenerPreferencias() async throws -> PreferenciasAnfitrion?
}

public final class AnfitrionService: AnfitrionServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func misHospedajes() async throws -> [Hospedaje] {
        let request = APIRequest(method: "GET", path: "/hospedajes/mios", requiresAuth: true)
        let response: MisHospedajesResponse = try await client.send(request)
        return response.hospedajes
    }

    public func reservasRecibidas(hospedajeId: String) async throws -> [Reserva] {
        let request = APIRequest(method: "GET", path: "/hospedajes/\(hospedajeId)/reservas", requiresAuth: true)
        let response: ReservasRecibidasResponse = try await client.send(request)
        return response.reservas
    }

    public func enviarVerificacion(_ payload: EnviarVerificacionRequest) async throws -> VerificacionAnfitrion {
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/anfitrion/verificacion", body: data, requiresAuth: true)
        let response: VerificacionResponse = try await client.send(request)
        guard let verificacion = response.verificacion else { throw AppError.decodificacion }
        return verificacion
    }

    public func obtenerVerificacion() async throws -> VerificacionAnfitrion? {
        let request = APIRequest(method: "GET", path: "/anfitrion/verificacion", requiresAuth: true)
        let response: VerificacionResponse = try await client.send(request)
        return response.verificacion
    }

    public func marcarVerificacionNotificada() async throws {
        let request = APIRequest(method: "POST", path: "/anfitrion/verificacion/notificado", requiresAuth: true)
        try await client.sendNoBody(request)
    }

    public func enviarPreferencias(_ payload: EnviarPreferenciasRequest) async throws -> PreferenciasAnfitrion {
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/anfitrion/preferencias", body: data, requiresAuth: true)
        let response: PreferenciasResponse = try await client.send(request)
        guard let preferencias = response.preferencias else { throw AppError.decodificacion }
        return preferencias
    }

    public func obtenerPreferencias() async throws -> PreferenciasAnfitrion? {
        let request = APIRequest(method: "GET", path: "/anfitrion/preferencias", requiresAuth: true)
        let response: PreferenciasResponse = try await client.send(request)
        return response.preferencias
    }
}
