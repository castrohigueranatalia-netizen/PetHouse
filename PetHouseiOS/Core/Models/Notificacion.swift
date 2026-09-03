//
//  Notificacion.swift
//  Core/Models
//
//  Historial completo de notificaciones (la campana, ver NotificacionesView) — distinto de
//  los avisos instantáneos (`.alert` al abrir la app, ver SessionStore.revisarResolucion*),
//  que son efímeros y se pierden al cerrarlos. Cada evento que dispara uno de esos avisos
//  ADEMÁS crea una fila acá (ver pethouse-api/src/lib/notificaciones.js), así la campana
//  puede mostrar tanto las nuevas como las viejas — GET /api/notificaciones trae las 100 más
//  recientes, leídas y sin leer, más recientes primero.
//

import Foundation

public enum TipoNotificacion: String, Decodable, Hashable {
    case verificacionResuelta = "verificacion_resuelta"
    case reservaResuelta = "reserva_resuelta"
    case solicitudNueva = "solicitud_nueva"
    case soporteRespondido = "soporte_respondido"
    case privacidadRespondida = "privacidad_respondida"
    /// El anfitrión publicó una nota/foto durante la estadía (ver
    /// db/38-actualizaciones-reserva.sql) — la recibe el huésped dueño de la reserva.
    case actualizacionReserva = "actualizacion_reserva"
}

public struct Notificacion: Decodable, Identifiable, Hashable {
    public let id: String
    public let tipo: TipoNotificacion
    public let titulo: String
    public let mensaje: String
    public let leida: Bool
    public let reservaId: String?
    public let hospedajeId: String?
    public let creadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, tipo, titulo, mensaje, leida
        case reservaId = "reserva_id"
        case hospedajeId = "hospedaje_id"
        case creadoEn = "creado_en"
    }
}

public struct NotificacionesResponse: Decodable {
    public let notificaciones: [Notificacion]
    public let noLeidas: Int
}
