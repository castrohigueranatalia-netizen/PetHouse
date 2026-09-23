//
//  ReservaCache.swift
//  Core/Persistence
//
//  Caché offline de "Mis reservas" (`GET /api/reservas/mias`) para lectura básica sin
//  red. Se reemplaza por completo en cada fetch exitoso (upsert por `id`); no intenta
//  reconciliar cancelaciones hechas offline — ese flujo requiere red por diseño (cancelar
//  es una escritura, no aplica caché-primero).
//

import Foundation
import SwiftData

@Model
public final class ReservaCache {
    @Attribute(.unique) public var id: String
    public var codigo: String
    public var estado: String
    public var desde: String?
    public var hasta: String?
    public var noches: Int?
    public var mascotas: Int?
    public var total: Double?
    public var hospedajeTitulo: String?
    public var ciudad: String?
    public var barrio: String?
    public var tipo: String?
    public var fotosJSON: Data
    public var actualizadoEn: Date

    public init(
        id: String, codigo: String, estado: String, desde: String?, hasta: String?,
        noches: Int?, mascotas: Int?, total: Double?, hospedajeTitulo: String?,
        ciudad: String?, barrio: String?, tipo: String?, fotosJSON: Data, actualizadoEn: Date = .now
    ) {
        self.id = id
        self.codigo = codigo
        self.estado = estado
        self.desde = desde
        self.hasta = hasta
        self.noches = noches
        self.mascotas = mascotas
        self.total = total
        self.hospedajeTitulo = hospedajeTitulo
        self.ciudad = ciudad
        self.barrio = barrio
        self.tipo = tipo
        self.fotosJSON = fotosJSON
        self.actualizadoEn = actualizadoEn
    }
}

public extension ReservaCache {
    var fotos: [String] {
        (try? JSONDecoder().decode([String].self, from: fotosJSON)) ?? []
    }

    /// Reconstruye un `Reserva` de dominio a partir de la fila de caché — solo trae los
    /// campos que también expone `GET /api/reservas/mias` (ver comentario de arriba).
    var comoReserva: Reserva {
        Reserva(
            id: id, codigo: codigo, estado: EstadoReserva(rawValue: estado) ?? .confirmada,
            desde: desde, hasta: hasta, noches: noches, mascotas: mascotas, total: total,
            precioNoche: nil, limpieza: nil, servicio: nil, creadoEn: nil,
            usuarioId: nil, hospedajeId: nil, anfitrionId: nil, hospedajeTitulo: hospedajeTitulo,
            ciudad: ciudad, barrio: barrio, tipo: tipo.flatMap(TipoHospedaje.init(rawValue:)),
            fotos: fotos
        )
    }

    convenience init(reserva: Reserva) {
        let fotosData = (try? JSONEncoder().encode(reserva.fotos ?? [])) ?? Data()
        self.init(
            id: reserva.id, codigo: reserva.codigo, estado: reserva.estado.rawValue,
            desde: reserva.desde, hasta: reserva.hasta, noches: reserva.noches,
            mascotas: reserva.mascotas, total: reserva.total, hospedajeTitulo: reserva.hospedajeTitulo,
            ciudad: reserva.ciudad, barrio: reserva.barrio, tipo: reserva.tipo?.rawValue,
            fotosJSON: fotosData, actualizadoEn: .now
        )
    }
}
