//
//  Resena.swift
//  Core/Models
//
//  `POST /api/hospedajes/:id/resenas` responde { id, rating, titulo, texto, creado_en }.
//  Las reseñas embebidas en `GET /api/hospedajes/:id` (últimas 20) no traen `id`, pero sí
//  `autor` (nombre del usuario, via JOIN) — por eso ambos son opcionales.
//  `rating` es SMALLINT (1-5) en BD, así que llega como número entero normal (a
//  diferencia de las columnas NUMERIC como `hospedajes.rating`, que llegan como string).
//
//  Mismo shape para las dos direcciones de reseña que existen en la app: el huésped
//  califica el hospedaje (`resenas`, arriba) y el anfitrión califica al huésped
//  (`resenas_usuario`, ver db/15-resenas-huesped.sql y `GET /api/usuarios/:id/resenas`) —
//  no hace falta un modelo separado, ambos endpoints devuelven exactamente esta forma.
//

import Foundation

public struct Resena: Codable, Identifiable, Hashable {
    public let id: String?
    public let rating: Int
    public let titulo: String?
    public let texto: String?
    public let creadoEn: String?
    public let autor: String?

    enum CodingKeys: String, CodingKey {
        case id, rating, titulo, texto, autor
        case creadoEn = "creado_en"
    }

    /// Identidad estable para `List`/`ForEach` incluso cuando `id` no viene en la respuesta.
    public var identity: String { id ?? "\(autor ?? "")-\(creadoEn ?? "")-\(rating)" }

    public init(id: String?, rating: Int, titulo: String?, texto: String?, creadoEn: String?, autor: String?) {
        self.id = id
        self.rating = rating
        self.titulo = titulo
        self.texto = texto
        self.creadoEn = creadoEn
        self.autor = autor
    }
}

/// Body de `POST /api/hospedajes/:id/resenas` — este SÍ es snake_case, consistente con
/// el resto de la API (solo `POST /api/hospedajes` rompe la convención, ver Hospedaje.swift).
public struct CrearResenaRequest: Encodable {
    public let reservaId: String
    public let rating: Int
    public let titulo: String?
    public let texto: String?

    enum CodingKeys: String, CodingKey {
        case reservaId = "reserva_id"
        case rating, titulo, texto
    }

    public init(reservaId: String, rating: Int, titulo: String?, texto: String?) {
        self.reservaId = reservaId
        self.rating = rating
        self.titulo = titulo
        self.texto = texto
    }
}

public struct CrearResenaResponse: Codable {
    public let resena: Resena
}

/// Respuesta de `GET /api/usuarios/:id/resenas` — la evaluación completa de un huésped.
public struct ResenasUsuarioResponse: Decodable {
    public let resenas: [Resena]
}
