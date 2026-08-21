//
//  HospedajesService.swift
//  Networking/Services
//
//  Envuelve `GET /api/hospedajes`, `GET /api/hospedajes/localidades`, `GET /api/hospedajes/cerca`,
//  `GET /api/hospedajes/:id`, `POST /api/hospedajes` y `PATCH /api/hospedajes/:id`. `crear`/
//  `editar` usan `CrearHospedajeRequest`, que se serializa en camelCase a propósito — ver el
//  comentario en Core/Models/Hospedaje.swift.
//

import Foundation

public struct BuscarHospedajesFiltros: Sendable {
    /// La app es solo de Bogotá (ver pethouse-api/src/routes/hospedajes.js) — se segmenta
    /// por localidad, no por una ciudad de texto libre. `nil` busca en toda Bogotá.
    public var localidad: Localidad?
    public var tipo: TipoHospedaje?
    public var convivencia: Convivencia?
    /// Filtro real por especie que el anfitrión declaró cuidar (ver
    /// `preferencias_anfitrion.especies` en pethouse-api/src/routes/hospedajes.js) — no es
    /// un campo del hospedaje en sí.
    public var especie: EspecieCuidado?
    public var desde: String?   // YYYY-MM-DD
    public var hasta: String?   // YYYY-MM-DD
    public var lat: Double?
    public var lng: Double?
    public var radio: Int?
    public var q: String?
    public var orden: String?   // "precio-asc" | "precio-desc" | "rating"

    public init(
        localidad: Localidad? = nil, tipo: TipoHospedaje? = nil, convivencia: Convivencia? = nil,
        especie: EspecieCuidado? = nil,
        desde: String? = nil, hasta: String? = nil, lat: Double? = nil, lng: Double? = nil,
        radio: Int? = nil, q: String? = nil, orden: String? = nil
    ) {
        self.localidad = localidad; self.tipo = tipo; self.convivencia = convivencia
        self.especie = especie
        self.desde = desde; self.hasta = hasta; self.lat = lat; self.lng = lng
        self.radio = radio; self.q = q; self.orden = orden
    }
}

public protocol HospedajesServicing: Sendable {
    func buscar(_ filtros: BuscarHospedajesFiltros, pagina: Int, porPagina: Int) async throws -> HospedajesListResponse
    func cerca(lat: Double, lng: Double, radio: Int) async throws -> HospedajesListResponse
    func detalle(id: String) async throws -> HospedajeDetailResponse
    func crear(_ payload: CrearHospedajeRequest) async throws -> CrearHospedajeResponse
    /// PATCH /api/hospedajes/:id — el anfitrión dueño edita un hospedaje ya publicado.
    /// Mismo body que `crear`, pero devuelve el `Hospedaje` completo (ver
    /// `EditarHospedajeResponse`).
    func editar(id: String, _ payload: CrearHospedajeRequest) async throws -> Hospedaje
    /// GET /api/hospedajes/localidades — conteo de hospedajes activos por cada una de las
    /// 20 localidades (incluye las que tienen 0), usado por el mapa/lista segmentados.
    func localidades() async throws -> [LocalidadConteo]
}

public final class HospedajesService: HospedajesServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func buscar(_ filtros: BuscarHospedajesFiltros, pagina: Int, porPagina: Int) async throws -> HospedajesListResponse {
        var items: [URLQueryItem] = []
        if let v = filtros.localidad { items.append(.init(name: "localidad", value: v.rawValue)) }
        if let v = filtros.tipo { items.append(.init(name: "tipo", value: v.rawValue)) }
        if let v = filtros.convivencia { items.append(.init(name: "convivencia", value: v.rawValue)) }
        if let v = filtros.especie { items.append(.init(name: "especie", value: v.rawValue)) }
        if let v = filtros.desde { items.append(.init(name: "desde", value: v)) }
        if let v = filtros.hasta { items.append(.init(name: "hasta", value: v)) }
        if let v = filtros.lat { items.append(.init(name: "lat", value: String(v))) }
        if let v = filtros.lng { items.append(.init(name: "lng", value: String(v))) }
        if let v = filtros.radio { items.append(.init(name: "radio", value: String(v))) }
        if let v = filtros.q, !v.isEmpty { items.append(.init(name: "q", value: v)) }
        if let v = filtros.orden { items.append(.init(name: "orden", value: v)) }
        items.append(.init(name: "pagina", value: String(pagina)))
        items.append(.init(name: "porPagina", value: String(porPagina)))

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

    public func editar(id: String, _ payload: CrearHospedajeRequest) async throws -> Hospedaje {
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "PATCH", path: "/hospedajes/\(id)", body: data, requiresAuth: true)
        let response: EditarHospedajeResponse = try await client.send(request)
        return response.hospedaje
    }

    public func localidades() async throws -> [LocalidadConteo] {
        let request = APIRequest(method: "GET", path: "/hospedajes/localidades")
        let response: LocalidadesResponse = try await client.send(request)
        return response.localidades
    }
}
