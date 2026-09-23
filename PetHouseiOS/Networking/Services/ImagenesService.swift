//
//  ImagenesService.swift
//  Networking/Services
//
//  Sube un archivo a POST /api/subidas (perfil, mascota, hospedaje) o, con `privado:
//  true`, a POST /api/subidas?tipo=verificacion — cédula/antecedentes/fotos de la
//  verificación de anfitrión, que el servidor guarda aparte y solo sirve con una URL
//  firmada de corta duración (ver pethouse-api/src/lib/urlsPrivadas.js). El único llamador
//  que pasa `privado: true` es VerificacionAnfitrionViewModel; el resto (Perfil, Mascotas,
//  Publicar hospedaje) usa el valor por defecto `false` sin tener que cambiar nada.
//

import Foundation

public protocol ImagenesServicing: Sendable {
    func subir(datos: Data, nombreArchivo: String, mimeType: String, privado: Bool) async throws -> String
}

public extension ImagenesServicing {
    func subir(datos: Data, nombreArchivo: String, mimeType: String) async throws -> String {
        try await subir(datos: datos, nombreArchivo: nombreArchivo, mimeType: mimeType, privado: false)
    }
}

public final class ImagenesService: ImagenesServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    /// Multipart/form-data manual (sin dependencias de terceros).
    public func subir(datos: Data, nombreArchivo: String, mimeType: String, privado: Bool = false) async throws -> String {
        let boundary = "PetHouse-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"archivo\"; filename=\"\(nombreArchivo)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(datos)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let queryItems = privado ? [URLQueryItem(name: "tipo", value: "verificacion")] : []
        let request = APIRequest(
            method: "POST", path: "/subidas", queryItems: queryItems, body: body,
            contentType: "multipart/form-data; boundary=\(boundary)", requiresAuth: true
        )
        let response: SubidaImagenResponse = try await client.send(request)
        return response.url
    }
}
