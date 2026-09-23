//
//  DocumentoLegal.swift
//  Core/Models
//
//  Política de privacidad / términos de uso — el contenido lo edita un administrador
//  desde el panel web (admin-web/), la app solo lo muestra. Ver GET /api/legal/:tipo
//  (público, sin sesión — hace falta poder mostrarlo antes de registrarse).
//

import Foundation

public enum TipoDocumentoLegal: String {
    case privacidad
    case terminos
}

public struct DocumentoLegal: Decodable {
    public let tipo: String
    public let contenido: String
    public let actualizadoEn: String?

    enum CodingKeys: String, CodingKey {
        case tipo, contenido
        case actualizadoEn = "actualizado_en"
    }
}

public struct DocumentoLegalResponse: Decodable {
    public let documento: DocumentoLegal
}
