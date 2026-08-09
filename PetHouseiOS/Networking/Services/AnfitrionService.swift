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
}
