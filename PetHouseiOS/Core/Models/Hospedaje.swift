//
//  Hospedaje.swift
//  Core/Models
//
//  La API devuelve hospedajes en TRES formas distintas y no equivalentes entre sí
//  (ver ARCHITECTURE_AUDIT.md §2.1 y §3):
//   - GET /api/hospedajes        → lista "rica" con casi todos los campos + lat/lng.
//   - GET /api/hospedajes/cerca  → lista "pobre": solo id, titulo, tipo, ciudad, barrio,
//                                   localidad, precio_noche, rating, distancia_m (sin fotos,
//                                   servicios, convivencia, max_mascotas, lat/lng, anfitrión...).
//   - GET /api/hospedajes/:id    → `h.*` completo (incluye descripcion, reglas, direccion,
//                                   activo, anfitrion_id, cobertura_radio_m, creado_en).
//  Este modelo unifica las tres con campos opcionales fuera del núcleo común
//  (id/titulo/tipo/ciudad/precioNoche/rating), en vez de tener 3 structs distintos —
//  simplifica los ViewModels a costa de tener que chequear `nil` en vistas que muestran
//  campos "ricos" sobre resultados que pudieron venir de `/cerca`.
//
//  precioNoche, rating y distanciaM son NUMERIC/computados en Postgres → decodificación
//  defensiva vía `decodeFlexibleDouble` (ver Core/Utils/FlexibleDecoding.swift).
//

import Foundation

public enum TipoHospedaje: String, Codable, CaseIterable, Identifiable {
    case guarderia
    case veterinaria
    case campestre
    case apartamento
    case domicilio

    public var id: String { rawValue }

    public var etiqueta: String {
        switch self {
        case .guarderia: "Guardería"
        case .veterinaria: "Veterinaria"
        case .campestre: "Casa campestre"
        case .apartamento: "Apartamento"
        case .domicilio: "A domicilio"
        }
    }
}

public enum Convivencia: String, Codable, CaseIterable, Identifiable {
    case cualquiera
    case compartida
    case individual

    public var id: String { rawValue }

    public var etiqueta: String {
        switch self {
        case .cualquiera: "Cualquiera"
        case .compartida: "Convivencia compartida"
        case .individual: "Convivencia individual"
        }
    }
}

public struct Hospedaje: Codable, Identifiable, Hashable {
    // Núcleo — presente en las 3 formas de respuesta.
    public let id: String
    public let titulo: String
    public let tipo: TipoHospedaje
    public let ciudad: String
    public let barrio: String?
    /// Una de las 20 localidades de Bogotá (ver Core/Models/Localidad.swift) — `nil` en los
    /// hospedajes del seed original fuera de Bogotá, que la API ya no devuelve en ningún
    /// listado (ver pethouse-api/src/routes/hospedajes.js), pero pueden seguir en la base.
    public let localidad: String?
    public let precioNoche: Double
    public let rating: Double

    // Presente en listado y detalle, AUSENTE en /cerca.
    public let convivencia: Convivencia?
    public let maxMascotas: Int?
    public let numResenas: Int?
    public let destacado: Bool?
    public let servicios: [String]?
    public let fotos: [String]?
    public let lat: Double?
    public let lng: Double?
    public let anfitrionNombre: String?
    public let anfitrionVerificado: Bool?

    // Solo en /cerca (y en el listado cuando se pasa lat/lng).
    public let distanciaM: Double?

    // Solo en el detalle (GET /:id).
    public let descripcion: String?
    public let direccion: String?
    public let reglas: [String]?
    public let activo: Bool?
    public let anfitrionId: String?
    public let coberturaRadioM: Int?
    public let creadoEn: String?

    enum CodingKeys: String, CodingKey {
        case id, titulo, tipo, ciudad, barrio, localidad, convivencia, servicios, fotos, reglas, activo, lat, lng
        case precioNoche = "precio_noche"
        case rating
        case maxMascotas = "max_mascotas"
        case numResenas = "num_resenas"
        case destacado
        case anfitrionNombre = "anfitrion_nombre"
        case anfitrionVerificado = "anfitrion_verificado"
        case distanciaM = "distancia_m"
        case descripcion
        case direccion
        case anfitrionId = "anfitrion_id"
        case coberturaRadioM = "cobertura_radio_m"
        case creadoEn = "creado_en"
    }

    /// Memberwise explícito — Swift no lo sintetiza porque hay un `init(from:)` manual.
    /// Se usa para construir un `Hospedaje` "placeholder" fuera de una respuesta HTTP real,
    /// ej. tras `POST /api/hospedajes` (que devuelve un subconjunto de campos, ver
    /// `HospedajeCreado`) — así la card recién publicada aparece de inmediato en
    /// `MisHospedajesView` sin esperar a `GET /api/hospedajes/mios` (🔴 pendiente).
    public init(
        id: String, titulo: String, tipo: TipoHospedaje, ciudad: String, barrio: String? = nil,
        localidad: String? = nil,
        precioNoche: Double, rating: Double = 0, convivencia: Convivencia? = nil, maxMascotas: Int? = nil,
        numResenas: Int? = nil, destacado: Bool? = nil, servicios: [String]? = nil, fotos: [String]? = nil,
        lat: Double? = nil, lng: Double? = nil, anfitrionNombre: String? = nil, anfitrionVerificado: Bool? = nil,
        distanciaM: Double? = nil, descripcion: String? = nil, direccion: String? = nil, reglas: [String]? = nil,
        activo: Bool? = nil, anfitrionId: String? = nil, coberturaRadioM: Int? = nil, creadoEn: String? = nil
    ) {
        self.id = id
        self.titulo = titulo
        self.tipo = tipo
        self.ciudad = ciudad
        self.barrio = barrio
        self.localidad = localidad
        self.precioNoche = precioNoche
        self.rating = rating
        self.convivencia = convivencia
        self.maxMascotas = maxMascotas
        self.numResenas = numResenas
        self.destacado = destacado
        self.servicios = servicios
        self.fotos = fotos
        self.lat = lat
        self.lng = lng
        self.anfitrionNombre = anfitrionNombre
        self.anfitrionVerificado = anfitrionVerificado
        self.distanciaM = distanciaM
        self.descripcion = descripcion
        self.direccion = direccion
        self.reglas = reglas
        self.activo = activo
        self.anfitrionId = anfitrionId
        self.coberturaRadioM = coberturaRadioM
        self.creadoEn = creadoEn
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titulo = try c.decode(String.self, forKey: .titulo)
        tipo = try c.decode(TipoHospedaje.self, forKey: .tipo)
        ciudad = try c.decode(String.self, forKey: .ciudad)
        barrio = try c.decodeIfPresent(String.self, forKey: .barrio)
        localidad = try c.decodeIfPresent(String.self, forKey: .localidad)
        precioNoche = try c.decodeFlexibleDouble(forKey: .precioNoche)
        rating = try c.decodeFlexibleDoubleIfPresent(forKey: .rating) ?? 0

        convivencia = try c.decodeIfPresent(Convivencia.self, forKey: .convivencia)
        maxMascotas = try c.decodeIfPresent(Int.self, forKey: .maxMascotas)
        numResenas = try c.decodeIfPresent(Int.self, forKey: .numResenas)
        destacado = try c.decodeIfPresent(Bool.self, forKey: .destacado)
        servicios = try c.decodeIfPresent([String].self, forKey: .servicios)
        fotos = try c.decodeIfPresent([String].self, forKey: .fotos)
        lat = try c.decodeFlexibleDoubleIfPresent(forKey: .lat)
        lng = try c.decodeFlexibleDoubleIfPresent(forKey: .lng)
        anfitrionNombre = try c.decodeIfPresent(String.self, forKey: .anfitrionNombre)
        anfitrionVerificado = try c.decodeIfPresent(Bool.self, forKey: .anfitrionVerificado)

        distanciaM = try c.decodeFlexibleDoubleIfPresent(forKey: .distanciaM)

        descripcion = try c.decodeIfPresent(String.self, forKey: .descripcion)
        direccion = try c.decodeIfPresent(String.self, forKey: .direccion)
        reglas = try c.decodeIfPresent([String].self, forKey: .reglas)
        activo = try c.decodeIfPresent(Bool.self, forKey: .activo)
        anfitrionId = try c.decodeIfPresent(String.self, forKey: .anfitrionId)
        coberturaRadioM = try c.decodeIfPresent(Int.self, forKey: .coberturaRadioM)
        creadoEn = try c.decodeIfPresent(String.self, forKey: .creadoEn)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(titulo, forKey: .titulo)
        try c.encode(tipo, forKey: .tipo)
        try c.encode(ciudad, forKey: .ciudad)
        try c.encodeIfPresent(barrio, forKey: .barrio)
        try c.encodeIfPresent(localidad, forKey: .localidad)
        try c.encode(precioNoche, forKey: .precioNoche)
        try c.encode(rating, forKey: .rating)
        try c.encodeIfPresent(convivencia, forKey: .convivencia)
        try c.encodeIfPresent(maxMascotas, forKey: .maxMascotas)
        try c.encodeIfPresent(numResenas, forKey: .numResenas)
        try c.encodeIfPresent(destacado, forKey: .destacado)
        try c.encodeIfPresent(servicios, forKey: .servicios)
        try c.encodeIfPresent(fotos, forKey: .fotos)
        try c.encodeIfPresent(lat, forKey: .lat)
        try c.encodeIfPresent(lng, forKey: .lng)
        try c.encodeIfPresent(anfitrionNombre, forKey: .anfitrionNombre)
        try c.encodeIfPresent(anfitrionVerificado, forKey: .anfitrionVerificado)
        try c.encodeIfPresent(distanciaM, forKey: .distanciaM)
        try c.encodeIfPresent(descripcion, forKey: .descripcion)
        try c.encodeIfPresent(direccion, forKey: .direccion)
        try c.encodeIfPresent(reglas, forKey: .reglas)
        try c.encodeIfPresent(activo, forKey: .activo)
        try c.encodeIfPresent(anfitrionId, forKey: .anfitrionId)
        try c.encodeIfPresent(coberturaRadioM, forKey: .coberturaRadioM)
        try c.encodeIfPresent(creadoEn, forKey: .creadoEn)
    }
}

public struct HospedajesListResponse: Codable {
    /// Total de hospedajes que matchean el filtro completo (no solo los de esta página) —
    /// viene de `COUNT(*) OVER()` en el servidor. `pagina`/`porPagina` son `nil` en
    /// `GET /api/hospedajes/cerca`, que no pagina (siempre devuelve todo el radio).
    public let total: Int
    public let pagina: Int?
    public let porPagina: Int?
    public let hospedajes: [Hospedaje]
}

public struct HospedajeDetailResponse: Codable {
    public let hospedaje: Hospedaje
    public let resenas: [Resena]
}

/// Body de `POST /api/hospedajes` — a diferencia de TODAS las respuestas (snake_case),
/// esta ruta espera el body en **camelCase** (ver `pethouse-api/src/routes/hospedajes.js`,
/// ruta `POST /`: `coberturaRadioM, precioNoche, maxMascotas`). Inconsistencia real del
/// backend, no un error de este cliente — de ahí que este DTO tenga su propio
/// `CodingKeys` distinto al de `Hospedaje`.
/// `ciudad` no se manda: el servidor la fija en `'Bogotá'` siempre (la app opera solo ahí,
/// ver `pethouse-api/src/routes/hospedajes.js`) — en su lugar se manda `localidad`,
/// obligatoria y validada contra las 20 localidades oficiales.
public struct CrearHospedajeRequest: Encodable {
    public let titulo: String
    public let tipo: TipoHospedaje
    public let descripcion: String
    public let localidad: String
    public let barrio: String?
    public let lat: Double
    public let lng: Double
    public let coberturaRadioM: Int?
    public let precioNoche: Double
    public let convivencia: Convivencia
    public let maxMascotas: Int
    public let servicios: [String]
    public let reglas: [String]
    /// URLs ya alojadas — no hay endpoint de subida hoy (ver README, gap bloqueante #1).
    public let fotos: [String]

    public init(
        titulo: String, tipo: TipoHospedaje, descripcion: String, localidad: String, barrio: String?,
        lat: Double, lng: Double, coberturaRadioM: Int?, precioNoche: Double, convivencia: Convivencia,
        maxMascotas: Int, servicios: [String], reglas: [String], fotos: [String]
    ) {
        self.titulo = titulo
        self.tipo = tipo
        self.descripcion = descripcion
        self.localidad = localidad
        self.barrio = barrio
        self.lat = lat
        self.lng = lng
        self.coberturaRadioM = coberturaRadioM
        self.precioNoche = precioNoche
        self.convivencia = convivencia
        self.maxMascotas = maxMascotas
        self.servicios = servicios
        self.reglas = reglas
        self.fotos = fotos
    }
}

/// Respuesta de `POST /api/hospedajes` — SÍ en snake_case (solo `precio_noche`), a
/// diferencia del request. Ver el comentario de `CrearHospedajeRequest`.
// `Decodable` (no `Codable`): tiene `init(from:)` manual para el precio y solo se decodifica
// (nunca se envía) — ver la nota de `Actividad` en Core/Models/Actividad.swift.
public struct HospedajeCreado: Decodable {
    public let id: String
    public let titulo: String
    public let tipo: TipoHospedaje
    public let ciudad: String
    public let localidad: String?
    public let precioNoche: Double

    enum CodingKeys: String, CodingKey {
        case id, titulo, tipo, ciudad, localidad
        case precioNoche = "precio_noche"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        titulo = try c.decode(String.self, forKey: .titulo)
        tipo = try c.decode(TipoHospedaje.self, forKey: .tipo)
        ciudad = try c.decode(String.self, forKey: .ciudad)
        localidad = try c.decodeIfPresent(String.self, forKey: .localidad)
        precioNoche = try c.decodeFlexibleDouble(forKey: .precioNoche)
    }
}

public struct CrearHospedajeResponse: Decodable {
    public let hospedaje: HospedajeCreado
}
