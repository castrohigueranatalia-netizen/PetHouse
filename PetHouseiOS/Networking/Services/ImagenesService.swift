//
//  ImagenesService.swift
//  Networking/Services
//
//  🔴 No existe endpoint de subida de imágenes (gap BLOQUEANTE #1, ver
//  ARCHITECTURE_AUDIT.md §6 y Core/Models/SubidaDTO.swift). Compartido por Perfil,
//  Mascotas y Anfitrión (publicar hospedaje) — todos necesitan "subir una foto" y
//  todos deben mostrar el mismo estado "función pendiente" hasta que exista storage.
//

import Foundation

public protocol ImagenesServicing: Sendable {
    func subir(datos: Data, nombreArchivo: String, mimeType: String) async throws -> String
}

public final class ImagenesService: ImagenesServicing, @unchecked Sendable {
    private let client: APIClientProtocol

    public init(client: APIClientProtocol = APIClient.shared) {
        self.client = client
    }

    /// Multipart/form-data manual (sin dependencias de terceros). Como la ruta no existe
    /// hoy, esto siempre va a terminar en `AppError.rutaNoImplementada` contra el backend
    /// actual — se deja implementado por completo para que funcione el día que exista.
    public func subir(datos: Data, nombreArchivo: String, mimeType: String) async throws -> String {
        let boundary = "PetHouse-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"archivo\"; filename=\"\(nombreArchivo)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(datos)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        let request = APIRequest(
            method: "POST", path: "/subidas", body: body,
            contentType: "multipart/form-data; boundary=\(boundary)", requiresAuth: true
        )
        let response: SubidaImagenResponse = try await client.send(request)
        return response.url
    }
}
