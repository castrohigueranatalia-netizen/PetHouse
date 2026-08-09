//
//  HospedajesService.swift
//  Networking/Services
//
//  Envuelve `GET /api/hospedajes`, `GET /api/hospedajes/cerca`, `GET /api/hospedajes/:id`
//  y `POST /api/hospedajes` (existentes hoy). `crear` usa `CrearHospedajeRequest`, que se
//  serializa en camelCase a propósito — ver el comentario en Core/Models/Hospedaje.swift.
//

import Foundation

public struct BuscarHospedajesFiltros: Sendable {
    public var ciudad: String?
    public var tipo: TipoHospedaje?
    public var convivencia: Convivencia?
    public var desde: String?   // YYYY-MM-DD
    public var hasta: String?   // YYYY-MM-DD
    public var lat: Double?
    public var lng: Double?
    public var radio: Int?
    public var q: String?
    public var orden: String?   // "precio-asc" | "precio-desc" | "rating"

    public init(
        ciudad: String? = nil, tipo: TipoHospedaje? = nil, convivencia: Convivencia? = nil,
        desde: String? = nil, hasta: String? = nil, lat: Double? = nil, lng: Double? = nil,
        radio: Int? = nil, q: String? = nil, orden: String? = nil
    ) {
        self.ciudad = ciudad; self.tipo = tipo; self.convivencia = convivencia
        self.desde = desde; self.hasta = hasta; self.lat = lat; self.lng = lng
        self.radio = radio; self.q = q; self.orden = orden
    }
}

public protocol HospedajesServicing: Sendable {
    func buscar(_ filtros: BuscarHospedajesFiltros) async throws -> HospedajesListResponse
    func cerca(lat: Double, lng: Double, radio: Int) async throws -> HospedajesListResponse
    func detalle(id: String) async throws -> HospedajeDetailResponse
    func crear(_ payload: CrearHospedajeRequest) async throws -> CrearHospedajeResponse
}

public final class HospedajesService: HospedajesServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func buscar(_ filtros: BuscarHospedajesFiltros) async throws -> HospedajesListResponse {
        var items: [URLQueryItem] = []
        if let v = filtros.ciudad, !v.isEmpty { items.append(.init(name: "ciudad", value: v)) }
        if let v = filtros.tipo { items.append(.init(name: "tipo", value: v.rawValue)) }
        if let v = filtros.convivencia { items.append(.init(name: "convivencia", value: v.rawValue)) }
        if let v = filtros.desde { items.append(.init(name: "desde", value: v)) }
        if let v = filtros.hasta { items.append(.init(name: "hasta", value: v)) }
        if let v = filtros.lat { items.append(.init(name: "lat", value: String(v))) }
        if let v = filtros.lng { items.append(.init(name: "lng", value: String(v))) }
        if let v = filtros.radio { items.append(.init(name: "radio", value: String(v))) }
        if let v = filtros.q, !v.isEmpty { items.append(.init(name: "q", value: v)) }
        if let v = filtros.orden { items.append(.init(name: "orden", value: v)) }

        let request = APIRequest(method: "GET", path: "/hospedajes", queryItems: items)
        return try await client.send(request)
    }

    public func cerca(lat: Double, lng: Double, radio: Int) async throws -> HospedajesListResponse {
        let items: [URLQueryItem] = [
            .init(name: "lat", value: String(lat)),
            .init(name: "lng", value: String(lng)),
            .init(name: "radio", value: String(radio))
        ]
        let request = APIRequest(method: "GET", path: "/hospedajes/cerca", queryItems: items)
        return try await client.send(request)
    }

    public func detalle(id: String) async throws -> HospedajeDetailResponse {
        let request = APIRequest(method: "GET", path: "/hospedajes/\(id)")
        return try await client.send(request)
    }

    public func crear(_ payload: CrearHospedajeRequest) async throws -> CrearHospedajeResponse {
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/hospedajes", body: data, requiresAuth: true)
        return try await client.send(request)
    }
}
