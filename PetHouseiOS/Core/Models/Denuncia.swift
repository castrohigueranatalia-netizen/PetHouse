//
//  Denuncia.swift
//  Core/Models
//
//  POST /api/denuncias — reportar un anfitrión, cualquier usuario o un mensaje puntual del
//  chat (ver pethouse-api/src/routes/denuncias.js). Se llama "denuncia", no "reporte", para
//  no chocar con las pantallas de Reportes (informes de comisión) que ya existen en el panel
//  de administrador — ver db/30-denuncias.sql.
//

import Foundation

public enum MotivoDenuncia: String, Codable, CaseIterable, Identifiable {
    case spam
    case acoso
    case contenidoInapropiado = "contenido_inapropiado"
    case informacionFalsa = "informacion_falsa"
    case fraude
    case otro

    public var id: String { rawValue }

    public var etiqueta: String {
        switch self {
        case .spam: "Spam o publicidad"
        case .acoso: "Acoso o comportamiento agresivo"
        case .contenidoInapropiado: "Contenido inapropiado"
        case .informacionFalsa: "Información falsa"
        case .fraude: "Fraude o estafa"
        case .otro: "Otro motivo"
        }
    }
}

/// Solo describe DESDE DÓNDE se hizo la denuncia — las tres siempre apuntan a un usuario
/// (`usuarioDenunciadoId`); `.mensaje` además trae `mensajeId`.
public enum TipoDenuncia: String, Codable {
    case anfitrion
    case usuario
    case mensaje
}

public struct CrearDenunciaRequest: Encodable {
    public let usuarioDenunciadoId: String
    public let tipo: TipoDenuncia
    public let motivo: MotivoDenuncia
    public let comentario: String?
    public let mensajeId: String?
    public let hospedajeId: String?

    public init(
        usuarioDenunciadoId: String, tipo: TipoDenuncia, motivo: MotivoDenuncia,
        comentario: String? = nil, mensajeId: String? = nil, hospedajeId: String? = nil
    ) {
        self.usuarioDenunciadoId = usuarioDenunciadoId
        self.tipo = tipo
        self.motivo = motivo
        self.comentario = comentario
        self.mensajeId = mensajeId
        self.hospedajeId = hospedajeId
    }
}

public struct CrearDenunciaResponse: Decodable {
    public let ok: Bool
}
