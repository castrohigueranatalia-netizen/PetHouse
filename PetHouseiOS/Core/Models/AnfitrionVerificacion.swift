//
//  AnfitrionVerificacion.swift
//  Core/Models
//
//  Verificación de seguridad obligatoria antes de poder publicar hospedajes: nombre legal,
//  cédula, certificado de antecedentes policiales, referencias y fotos (persona + vivienda).
//  Enviarla deja el registro en 'pendiente' — activar `Usuario.esAnfitrion` requiere que un
//  administrador la apruebe (ver pethouse-api/src/routes/anfitrion.js y routes/admin.js).
//
//  Mientras esté 'pendiente' o ya 'aprobado', el servidor rechaza un reenvío (409) — ver
//  VerificacionAnfitrionViewModel.cargarEstadoActual(), que revisa esto ANTES de mostrar el
//  formulario, así la app nunca deja que alguien llene y envíe algo que el servidor de
//  todos modos va a rechazar.
//

import Foundation

public enum EstadoVerificacion: String, Codable, Hashable {
    case pendiente
    case aprobado
    case rechazado

    public var etiqueta: String {
        switch self {
        case .pendiente: "En revisión"
        case .aprobado: "Verificado"
        case .rechazado: "Rechazada"
        }
    }
}

public struct VerificacionAnfitrion: Decodable, Hashable {
    public let id: String
    public let usuarioId: String
    public let nombreLegal: String
    public let cedula: String
    public let certificadoPolicialUrl: String
    public let referencias: [String]
    public let fotosPersona: [String]
    public let fotosVivienda: [String]
    public let estado: EstadoVerificacion
    /// `false` cuando `estado` acaba de pasar a aprobado/rechazado y el usuario todavía no
    /// vio el aviso — sin push notifications (ADR-7), la app lo detecta al abrir el Perfil
    /// (ver PerfilViewModel) y llama a `POST /api/anfitrion/verificacion/notificado` para
    /// apagarlo. Siempre `true` mientras `estado == .pendiente`.
    public let notificado: Bool
    public let creadoEn: String
    public let actualizadoEn: String

    enum CodingKeys: String, CodingKey {
        case id, estado, notificado
        case usuarioId = "usuario_id"
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

public struct VerificacionResponse: Decodable {
    public let verificacion: VerificacionAnfitrion?
}

public struct EnviarVerificacionRequest: Encodable {
    public let nombreLegal: String
    public let cedula: String
    public let certificadoPolicialUrl: String
    public let referencias: [String]
    public let fotosPersona: [String]
    public let fotosVivienda: [String]

    public init(
        nombreLegal: String, cedula: String, certificadoPolicialUrl: String,
        referencias: [String], fotosPersona: [String], fotosVivienda: [String]
    ) {
        self.nombreLegal = nombreLegal
        self.cedula = cedula
        self.certificadoPolicialUrl = certificadoPolicialUrl
        self.referencias = referencias
        self.fotosPersona = fotosPersona
        self.fotosVivienda = fotosVivienda
    }
}

// MARK: - Preferencias de cuidado (paso 2, después de la verificación)

public enum EspecieCuidado: String, Codable, CaseIterable, Identifiable {
    case perro
    case gato
    public var id: String { rawValue }
    public var etiqueta: String { self == .perro ? "Perros" : "Gatos" }
}

public enum ModalidadCuidado: String, Codable, CaseIterable, Identifiable {
    case dias
    case horas
    public var id: String { rawValue }
    public var etiqueta: String { self == .dias ? "Por días" : "Por horas" }
}

public enum TamanoMascota: String, Codable, CaseIterable, Identifiable {
    case pequeno
    case mediano
    case grande
    public var id: String { rawValue }
    public var etiqueta: String {
        switch self {
        case .pequeno: "Pequeño"
        case .mediano: "Mediano"
        case .grande: "Grande"
        }
    }
}

public struct PreferenciasAnfitrion: Decodable, Hashable {
    public let usuarioId: String
    public let especies: [EspecieCuidado]
    public let modalidades: [ModalidadCuidado]
    public let tamanos: [TamanoMascota]
    public let actualizadoEn: String

    enum CodingKeys: String, CodingKey {
        case usuarioId = "usuario_id"
        case especies, modalidades, tamanos
        case actualizadoEn = "actualizado_en"
    }
}

public struct PreferenciasResponse: Decodable {
    public let preferencias: PreferenciasAnfitrion?
}

public struct EnviarPreferenciasRequest: Encodable {
    public let especies: [String]
    public let modalidades: [String]
    public let tamanos: [String]

    public init(especies: [EspecieCuidado], modalidades: [ModalidadCuidado], tamanos: [TamanoMascota]) {
        self.especies = especies.map(\.rawValue)
        self.modalidades = modalidades.map(\.rawValue)
        self.tamanos = tamanos.map(\.rawValue)
    }
}
