//
//  ReservasService.swift
//  Networking/Services
//
//  Envuelve `/api/reservas/*` (todos existen hoy salvo lo anotado). Ninguna llamada aquí
//  cobra dinero: `crear` refleja el flujo real del backend — crea la reserva Y un registro
//  de pago en estado "pendiente" (ver ARCHITECTURE_AUDIT.md §2.1/§6, ADR-7). La UI debe
//  mostrar el mensaje de "pago se coordina con el anfitrión", nunca simular un cobro.
//

import Foundation

public protocol ReservasServicing: Sendable {
    func crear(hospedajeId: String, desde: String, hasta: String, mascotas: Int) async throws -> CrearReservaResponse
    func mias() async throws -> MisReservasResponse
    func detalle(id: String) async throws -> ReservaDetailResponse
    func cancelar(id: String) async throws -> CancelarReservaResponse
    func agregarAlPlan(reservaId: String, actividadId: String, fecha: String?) async throws -> PlanActividad
}

public final class ReservasService: ReservasServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func crear(hospedajeId: String, desde: String, hasta: String, mascotas: Int) async throws -> CrearReservaResponse {
        let payload = CrearReservaRequest(hospedajeId: hospedajeId, desde: desde, hasta: hasta, mascotas: mascotas)
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/reservas", body: data, requiresAuth: true)
        return try await client.send(request)
    }

    public func mias() async throws -> MisReservasResponse {
        let request = APIRequest(method: "GET", path: "/reservas/mias", requiresAuth: true)
        return try await client.send(request)
    }

    public func detalle(id: String) async throws -> ReservaDetailResponse {
        let request = APIRequest(method: "GET", path: "/reservas/\(id)", requiresAuth: true)
        return try await client.send(request)
    }

    public func cancelar(id: String) async throws -> CancelarReservaResponse {
        let request = APIRequest(method: "POST", path: "/reservas/\(id)/cancelar", requiresAuth: true)
        return try await client.send(request)
    }

    public func agregarAlPlan(reservaId: String, actividadId: String, fecha: String?) async throws -> PlanActividad {
        struct Body: Encodable {
            let actividad_id: String
            let fecha: String?
        }
        let data = try JSONEncoder().encode(Body(actividad_id: actividadId, fecha: fecha))
        let request = APIRequest(method: "POST", path: "/reservas/\(reservaId)/plan", body: data, requiresAuth: true)
        struct Wrapper: Decodable { let plan: PlanActividad }
        let wrapper: Wrapper = try await client.send(request)
        return wrapper.plan
    }
}
