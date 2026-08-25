//
//  DenunciasService.swift
//  Networking/Services
//
//  Envuelve `POST /api/denuncias` — reportar un anfitrión, cualquier usuario o un mensaje
//  del chat (ver Core/Models/Denuncia.swift y pethouse-api/src/routes/denuncias.js).
//

import Foundation

public protocol DenunciasServicing: Sendable {
    func crear(_ payload: CrearDenunciaRequest) async throws
}

public final class DenunciasService: DenunciasServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    public func crear(_ payload: CrearDenunciaRequest) async throws {
        let data = try JSONEncoder().encode(payload)
        let request = APIRequest(method: "POST", path: "/denuncias", body: data, requiresAuth: true)
        try await client.sendNoBody(request)
    }
}
