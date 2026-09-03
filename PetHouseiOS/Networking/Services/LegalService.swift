//
//  LegalService.swift
//  Networking/Services
//
//  Envuelve /api/legal/* — a diferencia del resto de Networking/Services, estos endpoints
//  NO requieren sesión (`requiresAuth: false`): hace falta poder mostrar la política de
//  privacidad y los términos de uso incluso antes de registrarse. El contenido lo edita
//  un administrador desde admin-web/, esto solo lo lee.
//

import Foundation

public protocol LegalServicing: Sendable {
    func documento(_ tipo: TipoDocumentoLegal) async throws -> DocumentoLegal
}

public final class LegalService: LegalServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func documento(_ tipo: TipoDocumentoLegal) async throws -> DocumentoLegal {
        let request = APIRequest(method: "GET", path: "/legal/\(tipo.rawValue)")
        let response: DocumentoLegalResponse = try await client.send(request)
        return response.documento
    }
}
