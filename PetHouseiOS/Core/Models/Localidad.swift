//
//  Localidad.swift
//  Core/Models
//
//  La app opera solo en Bogotá, segmentada por sus 20 localidades oficiales (ver
//  pethouse-api/src/routes/hospedajes.js → LOCALIDADES_BOGOTA, y
//  db/08-localidades-bogota.sql → CHECK de hospedajes.localidad). Los tres lugares deben
//  coincidir exactamente en nombres y orden.
//
//  `centro` son coordenadas APROXIMADAS solo para recentrar el mapa al tocar una localidad
//  en la lista (ver Features/Search/MapaView.swift) — la app no dibuja límites oficiales de
//  localidad (decisión de producto: pines + lista con contador, no un mapa de polígonos).
//  No usa CoreLocation acá a propósito, para que Core/Models no dependa de MapKit — el
//  llamador arma el `CLLocationCoordinate2D` con estos números.
//

import Foundation

public enum Localidad: String, Codable, CaseIterable, Identifiable, Hashable {
    case usaquen = "Usaquén"
    case chapinero = "Chapinero"
    case santaFe = "Santa Fe"
    case sanCristobal = "San Cristóbal"
    case usme = "Usme"
    case tunjuelito = "Tunjuelito"
    case bosa = "Bosa"
    case kennedy = "Kennedy"
    case fontibon = "Fontibón"
    case engativa = "Engativá"
    case suba = "Suba"
    case barriosUnidos = "Barrios Unidos"
    case teusaquillo = "Teusaquillo"
    case losMartires = "Los Mártires"
    case antonioNarino = "Antonio Nariño"
    case puenteAranda = "Puente Aranda"
    case laCandelaria = "La Candelaria"
    case rafaelUribeUribe = "Rafael Uribe Uribe"
    case ciudadBolivar = "Ciudad Bolívar"
    case sumapaz = "Sumapaz"

    public var id: String { rawValue }
    public var etiqueta: String { rawValue }

    public var centro: (lat: Double, lng: Double) {
        switch self {
        case .usaquen: (4.6946, -74.0303)
        case .chapinero: (4.6584, -74.0625)
        case .santaFe: (4.6050, -74.0709)
        case .sanCristobal: (4.5709, -74.0817)
        case .usme: (4.4747, -74.1264)
        case .tunjuelito: (4.5738, -74.1332)
        case .bosa: (4.6188, -74.1873)
        case .kennedy: (4.6280, -74.1631)
        case .fontibon: (4.6797, -74.1469)
        case .engativa: (4.7099, -74.1169)
        case .suba: (4.7420, -74.0834)
        case .barriosUnidos: (4.6667, -74.0833)
        case .teusaquillo: (4.6378, -74.0930)
        case .losMartires: (4.6042, -74.0917)
        case .antonioNarino: (4.5833, -74.1000)
        case .puenteAranda: (4.6167, -74.1167)
        case .laCandelaria: (4.5966, -74.0743)
        case .rafaelUribeUribe: (4.5578, -74.1119)
        case .ciudadBolivar: (4.5000, -74.1500)
        case .sumapaz: (4.0000, -74.3833)
        }
    }

    /// Centro + span que encuadra toda Bogotá urbana — usado como cámara por defecto del
    /// mapa (ver MapaView) en vez de partir de la primera coordenada de los resultados.
    public static let centroBogota = (lat: 4.6486, lng: -74.1178)
    public static let spanBogota = (lat: 0.5, lng: 0.4)
}

/// Respuesta de `GET /api/hospedajes/localidades`: cuántos hospedajes activos hay en cada
/// una de las 20 localidades (incluye las que tienen 0, el servidor completa los ceros).
public struct LocalidadConteo: Decodable, Identifiable, Hashable {
    public let localidad: String
    public let hospedajes: Int
    public var id: String { localidad }
}

public struct LocalidadesResponse: Decodable {
    public let localidades: [LocalidadConteo]
}
