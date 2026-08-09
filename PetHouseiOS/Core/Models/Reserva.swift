//
//  Reserva.swift
//  Core/Models
//
//  La forma de "una reserva" varía según el endpoint (ver ARCHITECTURE_AUDIT.md §2.1/§3):
//   - POST /api/reservas             → id, codigo, desde, hasta, noches, mascotas,
//                                       precio_noche, limpieza, servicio, total, estado,
//                                       creado_en (+ `detalle` aparte, ver `NuevaReservaResponse`).
//   - GET  /api/reservas/mias        → id, codigo, desde, hasta, noches, mascotas, total,
//                                       estado + snapshot del hospedaje (titulo/ciudad/
//                                       barrio/tipo/fotos), SIN precio_noche/limpieza/servicio.
//   - GET  /api/reservas/:id         → `rs.*` completo + hospedaje_titulo + anfitrion_id.
//   - POST /api/reservas/:id/cancelar→ SOLO id, codigo, estado.
//  Único subconjunto garantizado en TODAS las respuestas: id, codigo, estado.
//  precio_noche/limpieza/servicio/total son NUMERIC → decodificación defensiva (String o
//  Double), igual que en Hospedaje.swift.
//

import Foundation

public enum EstadoReserva: String, Codable, Hashable {
    case confirmada
    case cancelada
    case completada
}

// `Decodable` (no `Codable`): tiene `init(from:)` manual (decodificación defensiva de
// columnas NUMERIC) y nunca se envía como body — ver la nota en Core/Models/Actividad.swift.
public struct Reserva: Decodable, Identifiable, Hashable {
    public let id: String
    public let codigo: String
    public let estado: EstadoReserva

    public let desde: String?   // YYYY-MM-DD
    public let hasta: String?   // YYYY-MM-DD
    public let noches: Int?
    public let mascotas: Int?
    public let total: Double?

    public let precioNoche: Double?
    public let limpieza: Double?
    public let servicio: Double?
    public let creadoEn: String?

    public let usuarioId: String?
    public let hospedajeId: String?
    public let anfitrionId: String?
    public let hospedajeTitulo: String?

    // Snapshot del hospedaje, solo presente en GET /api/reservas/mias.
    public let ciudad: String?
    public let barrio: String?
    public let tipo: TipoHospedaje?
    public let fotos: [String]?

    enum CodingKeys: String, CodingKey {
        case id, codigo, estado, desde, hasta, noches, mascotas, total
        case precioNoche = "precio_noche"
        case limpieza, servicio
        case creadoEn = "creado_en"
        case usuarioId = "usuario_id"
        case hospedajeId = "hospedaje_id"
        case anfitrionId = "anfitrion_id"
        case hospedajeTitulo = "hospedaje_titulo"
        case ciudad, barrio, tipo, fotos
    }

    /// Memberwise explícito — Swift no lo sintetiza porque hay un `init(from:)` manual.
    /// Usado principalmente para reconstruir un `Reserva` desde `ReservaCache` (offline),
    /// sin pasar por JSON. Ver `ReservaCache.comoReserva`.
    public init(
        id: String, codigo: String, estado: EstadoReserva, desde: String?, hasta: String?,
        noches: Int?, mascotas: Int?, total: Double?, precioNoche: Double?, limpieza: Double?,
        servicio: Double?, creadoEn: String?, usuarioId: String?, hospedajeId: String?,
        anfitrionId: String?, hospedajeTitulo: String?, ciudad: String?, barrio: String?,
        tipo: TipoHospedaje?, fotos: [String]?
    ) {
        self.id = id
        self.codigo = codigo
        self.estado = estado
        self.desde = desde
        self.hasta = hasta
        self.noches = noches
        self.mascotas = mascotas
        self.total = total
        self.precioNoche = precioNoche
        self.limpieza = limpieza
        self.servicio = servicio
        self.creadoEn = creadoEn
        self.usuarioId = usuarioId
        self.hospedajeId = hospedajeId
        self.anfitrionId = anfitrionId
        self.hospedajeTitulo = hospedajeTitulo
        self.ciudad = ciudad
        self.barrio = barrio
        self.tipo = tipo
        self.fotos = fotos
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        codigo = try c.decode(String.self, forKey: .codigo)
        estado = try c.decode(EstadoReserva.self, forKey: .estado)
        desde = try c.decodeIfPresent(String.self, forKey: .desde)
        hasta = try c.decodeIfPresent(String.self, forKey: .hasta)
        noches = try c.decodeIfPresent(Int.self, forKey: .noches)
        mascotas = try c.decodeIfPresent(Int.self, forKey: .mascotas)
        total = try c.decodeFlexibleDoubleIfPresent(forKey: .total)
        precioNoche = try c.decodeFlexibleDoubleIfPresent(forKey: .precioNoche)
        limpieza = try c.decodeFlexibleDoubleIfPresent(forKey: .limpieza)
        servicio = try c.decodeFlexibleDoubleIfPresent(forKey: .servicio)
        creadoEn = try c.decodeIfPresent(String.self, forKey: .creadoEn)
        usuarioId = try c.decodeIfPresent(String.self, forKey: .usuarioId)
        hospedajeId = try c.decodeIfPresent(String.self, forKey: .hospedajeId)
        anfitrionId = try c.decodeIfPresent(String.self, forKey: .anfitrionId)
        hospedajeTitulo = try c.decodeIfPresent(String.self, forKey: .hospedajeTitulo)
        ciudad = try c.decodeIfPresent(String.self, forKey: .ciudad)
        barrio = try c.decodeIfPresent(String.self, forKey: .barrio)
        tipo = try c.decodeIfPresent(TipoHospedaje.self, forKey: .tipo)
        fotos = try c.decodeIfPresent([String].self, forKey: .fotos)
    }
}

public struct CrearReservaRequest: Encodable {
    public let hospedajeId: String
    public let desde: String
    public let hasta: String
    public let mascotas: Int

    enum CodingKeys: String, CodingKey {
        case hospedajeId = "hospedaje_id"
        case desde, hasta, mascotas
    }

    public init(hospedajeId: String, desde: String, hasta: String, mascotas: Int) {
        self.hospedajeId = hospedajeId
        self.desde = desde
        self.hasta = hasta
        self.mascotas = mascotas
    }
}

public struct ReservaDetalleCotizacion: Decodable, Hashable {
    public let hospedaje: String
    public let noches: Int
    public let limpieza: Double
    public let servicio: Double

    enum CodingKeys: String, CodingKey {
        case hospedaje, noches, limpieza, servicio
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hospedaje = try c.decode(String.self, forKey: .hospedaje)
        noches = try c.decode(Int.self, forKey: .noches)
        limpieza = try c.decodeFlexibleDouble(forKey: .limpieza)
        servicio = try c.decodeFlexibleDouble(forKey: .servicio)
    }
}

public struct CrearReservaResponse: Decodable {
    public let reserva: Reserva
    public let detalle: ReservaDetalleCotizacion
}

public struct MisReservasResponse: Decodable {
    public let reservas: [Reserva]
}

public struct PlanActividad: Decodable, Identifiable, Hashable {
    public let id: String
    public let fecha: String?
    public let precio: Double
    public let nombre: String
    public let tipo: String

    enum CodingKeys: String, CodingKey {
        case id, fecha, precio, nombre, tipo
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha)
        precio = try c.decodeFlexibleDouble(forKey: .precio)
        nombre = try c.decode(String.self, forKey: .nombre)
        tipo = try c.decode(String.self, forKey: .tipo)
    }
}

public struct ReservaDetailResponse: Decodable {
    public let reserva: Reserva
    public let plan: [PlanActividad]
}

public struct CancelarReservaResponse: Decodable {
    public let reserva: Reserva
}
