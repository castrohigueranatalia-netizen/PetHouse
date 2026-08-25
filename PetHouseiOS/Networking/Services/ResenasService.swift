//
//  ResenasService.swift
//  Networking/Services
//
//  Envuelve `POST /api/hospedajes/:id/resenas` (existe hoy). El servidor valida que la
//  reserva sea del usuario y de ese hospedaje, y hay como máximo una reseña por reserva
//  (UNIQUE reserva_id) — un intento repetido responde 409/403, que se muestra tal cual
//  (`AppError.servidor`) porque el mensaje del backend ya es legible.
//

import Foundation

public protocol ResenasServicing: Sendable {
    func crear(hospedajeId: String, reservaId: String, rating: Int, titulo: String?, texto: String?) async throws -> Resena
    /// El anfitrión dueño del hospedaje responde públicamente a una reseña.
    func responder(hospedajeId: String, resenaId: String, respuesta: String) async throws -> Resena
}

public final class ResenasService: ResenasServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func crear(hospedajeId: String, reservaId: String, rating: Int, titulo: String?, texto: String?) async throws -> Resena {
        let payload = CrearResenaRequest(reservaId: reservaId, rating: rating, titulo: titulo, texto: texto)
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/hospedajes/\(hospedajeId)/resenas", body: data, requiresAuth: true)
        let response: CrearResenaResponse = try await client.send(request)
        return response.resena
    }

    public func responder(hospedajeId: String, resenaId: String, respuesta: String) async throws -> Resena {
        let data = try JSONEncoder().encode(ResponderResenaRequest(respuesta: respuesta))
        let request = APIRequest(method: "POST", path: "/hospedajes/\(hospedajeId)/resenas/\(resenaId)/responder", body: data, requiresAuth: true)
        let response: ResponderResenaResponse = try await client.send(request)
        return response.resena
    }
}
