//
//  SolicitudPrivacidad.swift
//  Core/Models
//
//  Formulario dentro de la app para ejercer los derechos de la política de privacidad
//  (conocer, corregir o eliminar tus datos, u otra duda). El admin responde desde el panel
//  web — ver pethouse-api/src/routes/privacidad.js y admin.js.
//

import Foundation

public enum CategoriaPrivacidad: String, Codable, CaseIterable, Identifiable {
    case conocer, corregir, eliminar, otra

    public var id: String { rawValue }

    public var etiqueta: String {
        switch self {
        case .conocer: "Conocer mis datos"
        case .corregir: "Corregir mis datos"
        case .eliminar: "Eliminar mi cuenta y mis datos"
        case .otra: "Otra pregunta o queja de privacidad"
        }
    }
}

public struct SolicitudPrivacidad: Decodable, Identifiable, Hashable {
    public let id: String
    public let categoria: CategoriaPrivacidad
    public let mensaje: String
    public let estado: String // "pendiente" | "en_proceso" | "resuelta"
    public let plazoDias: Int
    public let venceEn: String
    public let respuesta: String?
    public let respondidoEn: String?
    public let creadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, categoria, mensaje, estado
        case plazoDias = "plazo_dias"
        case venceEn = "vence_en"
        case respuesta
        case respondidoEn = "respondido_en"
        case creadoEn = "creado_en"
    }
}

public struct SolicitudesPrivacidadResponse: Decodable { public let solicitudes: [SolicitudPrivacidad] }
public struct SolicitudPrivacidadCreadaResponse: Decodable { public let solicitud: SolicitudPrivacidad }
