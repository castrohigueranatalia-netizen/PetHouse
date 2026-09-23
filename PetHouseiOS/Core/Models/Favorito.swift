//
//  Favorito.swift
//  Core/Models
//
//  🔴 NO EXISTE en el backend hoy — la tabla `favoritos` existe en el esquema
//  (usuario_id, hospedaje_id, creado_en — sin columna `id`, la PK es compuesta) pero no
//  hay rutas montadas (ver ARCHITECTURE_AUDIT.md §2.1 y MVP_SCOPE.md §4.5).
//  Este es el contrato PROPUESTO que tendría el backend si se implementara, siguiendo las
//  convenciones ya vigentes (español, snake_case, `{ error }` en fallos, recurso anidado
//  bajo su nombre en plural). `FavoritosService` llama a estas rutas y trata cualquier
//  404 de ruta inexistente como "función pendiente en el servidor", nunca como éxito.
//
//   Propuesto:
//   - GET    /api/favoritos              → { favoritos: [Hospedaje] }  (hospedajes completos,
//                                           igual forma que GET /api/hospedajes, para no
//                                           forzar una segunda llamada por cada favorito)
//   - POST   /api/favoritos { hospedaje_id } → 201 { favorito: Favorito }
//   - DELETE /api/favoritos/:hospedajeId     → 200 { ok: true }
//

import Foundation

public struct Favorito: Codable, Hashable {
    public let hospedajeId: String
    public let creadoEn: String?

    enum CodingKeys: String, CodingKey {
        case hospedajeId = "hospedaje_id"
        case creadoEn = "creado_en"
    }
}

public struct FavoritosListResponse: Codable {
    public let favoritos: [Hospedaje]
}

public struct AgregarFavoritoRequest: Encodable {
    public let hospedajeId: String
    enum CodingKeys: String, CodingKey { case hospedajeId = "hospedaje_id" }
    public init(hospedajeId: String) { self.hospedajeId = hospedajeId }
}

public struct AgregarFavoritoResponse: Codable {
    public let favorito: Favorito
}
