//
//  Admin.swift
//  Core/Models
//
//  Panel de administración: solicitudes de anfitrión (aprobar/rechazar) y estadísticas.
//  Todo detrás de `soloAdmin` en el backend — ver pethouse-api/src/routes/admin.js.
//

import Foundation

/// Igual que `VerificacionAnfitrion` pero con los datos del usuario que la envió (el
/// admin necesita saber QUIÉN es antes de aprobar/rechazar) — respuesta de
/// GET /api/admin/solicitudes, no reutiliza `VerificacionAnfitrion` para no forzar campos
/// opcionales ahí que solo tienen sentido en la vista de admin.
public struct SolicitudAnfitrion: Decodable, Identifiable, Hashable {
    public let id: String
    public let usuarioId: String
    public let usuarioNombre: String
    public let usuarioEmail: String
    public let usuarioTelefono: String?
    public let nombreLegal: String
    public let cedula: String
    public let certificadoPolicialUrl: String
    public let referencias: [String]
    public let fotosPersona: [String]
    public let fotosVivienda: [String]
    public let estado: EstadoVerificacion
    public let creadoEn: String
    public let actualizadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, estado
        case usuarioId = "usuario_id"
        case usuarioNombre = "usuario_nombre"
        case usuarioEmail = "usuario_email"
        case usuarioTelefono = "usuario_telefono"
        case nombreLegal = "nombre_legal"
        case cedula
        case certificadoPolicialUrl = "certificado_policial_url"
        case referencias
        case fotosPersona = "fotos_persona"
        case fotosVivienda = "fotos_vivienda"
        case creadoEn = "creado_en"
        case actualizadoEn = "actualizado_en"
    }
}

public struct SolicitudesResponse: Decodable {
    public let total: Int
    public let solicitudes: [SolicitudAnfitrion]
}

public struct ReservasPorCiudad: Decodable, Identifiable, Hashable {
    public let ciudad: String
    public let total: Int
    public var id: String { ciudad }
}

/// A diferencia del resto de la API (snake_case), este endpoint devuelve camelCase directo
/// desde `routes/admin.js` — coincide con los nombres de propiedad de Swift 1:1, sin
/// necesitar `CodingKeys`.
public struct EstadisticasAdmin: Decodable {
    public let totalUsuarios: Int
    public let totalAnfitriones: Int
    public let totalReservas: Int
    public let solicitudesPendientes: Int
    public let reservasPorCiudad: [ReservasPorCiudad]
}
