//
//  ReservasService.swift
//  Networking/Services
//
//  Envuelve `/api/reservas/*` (todos existen hoy salvo lo anotado). Ninguna llamada aquí
//  cobra dinero: `crear` refleja el flujo real del backend — crea la reserva Y un registro
//  de pago en estado "pendiente" (ver ARCHITECTURE_AUDIT.md §2.1/§6, ADR-7). La UI debe
//  mostrar el mensaje de "pago se coordina con el anfitrión", nunca simular un cobro.
//
//  Toda reserva nace en estado `.pendiente` — `aceptar`/`rechazar` son acciones del
//  anfitrión dueño del hospedaje, no del huésped que reservó. `resueltasSinNotificar`/
//  `marcarNotificada` son el aviso al huésped de que su solicitud se resolvió — mismo
//  patrón que `AnfitrionService.marcarVerificacionNotificada` (sin push, ADR-7), ver
//  `SessionStore.revisarResolucionesReserva()`. `calificarHuesped` es el espejo de
//  `ResenasService.crear`: ahí el huésped califica el hospedaje, acá el anfitrión califica
//  al huésped (ver db/15-resenas-huesped.sql).
//

import Foundation

public protocol ReservasServicing: Sendable {
    func crear(hospedajeId: String, desde: String, hasta: String, horaEntrega: String, horaRecogida: String, mascotaIds: [String]) async throws -> CrearReservaResponse
    func mias() async throws -> MisReservasResponse
    func detalle(id: String) async throws -> ReservaDetailResponse
    func cancelar(id: String) async throws -> CancelarReservaResponse
    func ocultar(id: String) async throws
    func aceptar(id: String) async throws -> ReservaAccionResponse
    func rechazar(id: String) async throws -> ReservaAccionResponse
    func resueltasSinNotificar() async throws -> [Reserva]
    func marcarNotificada(id: String) async throws
    func pendientesSinNotificarAnfitrion() async throws -> [Reserva]
    func marcarNotificadaAnfitrion(id: String) async throws
    func calificarHuesped(reservaId: String, rating: Int, titulo: String?, texto: String?) async throws -> Resena
    func agregarAlPlan(reservaId: String, actividadId: String, fecha: String?) async throws -> PlanActividad
    /// GET /api/reservas/:id/actualizaciones — notas/fotos que el anfitrión publicó mientras
    /// la reserva estaba 'confirmada' (ver db/38-actualizaciones-reserva.sql). La ve tanto el
    /// huésped dueño de la reserva como el anfitrión dueño del hospedaje.
    func actualizaciones(reservaId: String) async throws -> [ActualizacionReserva]
    /// POST /api/reservas/:id/actualizaciones — solo el anfitrión, y solo mientras la
    /// reserva sigue 'confirmada'. Exige `notas` o `fotos` (al menos uno de los dos).
    func crearActualizacion(reservaId: String, notas: String?, fotos: [String]) async throws -> ActualizacionReserva
}

public final class ReservasService: ReservasServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func crear(hospedajeId: String, desde: String, hasta: String, horaEntrega: String, horaRecogida: String, mascotaIds: [String]) async throws -> CrearReservaResponse {
        let payload = CrearReservaRequest(hospedajeId: hospedajeId, desde: desde, hasta: hasta, horaEntrega: horaEntrega, horaRecogida: horaRecogida, mascotaIds: mascotaIds)
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

    /// Quita una reserva ya resuelta ('completada'/'cancelada'/'rechazada') del panel "Mis
    /// reservas" de quien la hizo — no la borra de verdad (ver db/18-ocultar-reserva.sql: el
    /// servidor rechaza esto si la reserva sigue activa).
    public func ocultar(id: String) async throws {
        let request = APIRequest(method: "POST", path: "/reservas/\(id)/ocultar", requiresAuth: true)
        try await client.sendNoBody(request)
    }

    public func aceptar(id: String) async throws -> ReservaAccionResponse {
        let request = APIRequest(method: "POST", path: "/reservas/\(id)/aceptar", requiresAuth: true)
        return try await client.send(request)
    }

    public func rechazar(id: String) async throws -> ReservaAccionResponse {
        let request = APIRequest(method: "POST", path: "/reservas/\(id)/rechazar", requiresAuth: true)
        return try await client.send(request)
    }

    public func resueltasSinNotificar() async throws -> [Reserva] {
        let request = APIRequest(method: "GET", path: "/reservas/notificaciones/resueltas", requiresAuth: true)
        let response: MisReservasResponse = try await client.send(request)
        return response.reservas
    }

    public func marcarNotificada(id: String) async throws {
        let request = APIRequest(method: "POST", path: "/reservas/\(id)/notificado", requiresAuth: true)
        try await client.sendNoBody(request)
    }

    /// Solicitudes de reserva NUEVAS (recién creadas por un huésped) que el anfitrión
    /// todavía no vio — dirección opuesta a `resueltasSinNotificar()` (esa es el aviso al
    /// huésped de que SU solicitud se resolvió; esta es el aviso al anfitrión de que le
    /// LLEGÓ una solicitud).
    public func pendientesSinNotificarAnfitrion() async throws -> [Reserva] {
        let request = APIRequest(method: "GET", path: "/reservas/notificaciones/pendientes-anfitrion", requiresAuth: true)
        let response: MisReservasResponse = try await client.send(request)
        return response.reservas
    }

    public func marcarNotificadaAnfitrion(id: String) async throws {
        let request = APIRequest(method: "POST", path: "/reservas/\(id)/notificado-anfitrion", requiresAuth: true)
        try await client.sendNoBody(request)
    }

    /// El anfitrión califica al huésped de una reserva propia — espejo de
    /// `ResenasService.crear` (el huésped califica el hospedaje).
    public func calificarHuesped(reservaId: String, rating: Int, titulo: String?, texto: String?) async throws -> Resena {
        let payload = CalificarHuespedRequest(rating: rating, titulo: titulo, texto: texto)
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/reservas/\(reservaId)/resena-huesped", body: data, requiresAuth: true)
        let response: CrearResenaResponse = try await client.send(request)
        return response.resena
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

    public func actualizaciones(reservaId: String) async throws -> [ActualizacionReserva] {
        let request = APIRequest(method: "GET", path: "/reservas/\(reservaId)/actualizaciones", requiresAuth: true)
        let response: ActualizacionesReservaResponse = try await client.send(request)
        return response.actualizaciones
    }

    public func crearActualizacion(reservaId: String, notas: String?, fotos: [String]) async throws -> ActualizacionReserva {
        let payload = CrearActualizacionRequest(notas: notas, fotos: fotos)
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/reservas/\(reservaId)/actualizaciones", body: data, requiresAuth: true)
        let response: CrearActualizacionResponse = try await client.send(request)
        return response.actualizacion
    }
}
