//
//  Actividad.swift
//  Core/Models
//
//  GET /api/actividades → id, hospedaje_id, nombre, tipo, descripcion, duracion, precio.
//  POST /api/actividades (anfitrión) → respuesta reducida: id, nombre, tipo, precio.
//  `precio` es NUMERIC → decodificación defensiva.
//

import Foundation

public enum TipoActividad: String, Codable, CaseIterable, Identifiable {
    case paseos, piscina, entrenamiento, spa, fotos, social

    public var id: String { rawValue }

    public var etiqueta: String {
        switch self {
        case .paseos: "Paseos"
        case .piscina: "Piscina"
        case .entrenamiento: "Entrenamiento"
        case .spa: "Spa"
        case .fotos: "Sesión de fotos"
        case .social: "Socialización"
        }
    }
}

// Nota: `Decodable` (no `Codable`) a propósito — este tipo tiene un `init(from:)` manual
// para decodificar `precio` de forma defensiva (ver FlexibleDecoding.swift) y nunca se
// envía como body de una petición, así que no necesita `Encodable`/`encode(to:)`.
public struct Actividad: Decodable, Identifiable, Hashable {
    public let id: String
    public let hospedajeId: String?
    public let nombre: String
    public let tipo: TipoActividad
    public let descripcion: String?
    public let duracion: String?
    public let precio: Double

    enum CodingKeys: String, CodingKey {
        case id, nombre, tipo, descripcion, duracion, precio
        case hospedajeId = "hospedaje_id"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        hospedajeId = try c.decodeIfPresent(String.self, forKey: .hospedajeId)
        nombre = try c.decode(String.self, forKey: .nombre)
        tipo = try c.decode(TipoActividad.self, forKey: .tipo)
        descripcion = try c.decodeIfPresent(String.self, forKey: .descripcion)
        duracion = try c.decodeIfPresent(String.self, forKey: .duracion)
        precio = try c.decodeFlexibleDouble(forKey: .precio)
    }
}

public struct ActividadesListResponse: Decodable {
    public let total: Int
    public let actividades: [Actividad]
}
