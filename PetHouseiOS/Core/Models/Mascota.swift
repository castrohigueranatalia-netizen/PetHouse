//
//  Mascota.swift
//  Core/Models
//
//  Refleja la tabla `mascotas`. `GET /api/auth/me` solo trae
//  (id, nombre, especie, raza, peso_kg, vacunas_dia) — sin `notas` ni `usuario_id` ni
//  `creado_en` — así que esos campos son opcionales. El registro (`POST /api/auth/registro`)
//  solo permite crear UNA mascota con `mascotaNombre` (especie fija 'perro') y no la
//  devuelve en la respuesta; el resto del CRUD (agregar más, editar, borrar) no existe en
//  el backend hoy — ver `MascotasService` y MVP_SCOPE.md §4.1.
//

import Foundation

public struct Mascota: Codable, Identifiable, Hashable {
    public let id: String
    public let nombre: String
    public let especie: String
    public let raza: String?
    public let pesoKg: Double?
    public let vacunasDia: Bool
    public let notas: String?
    public let usuarioId: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, especie, raza, notas
        case pesoKg = "peso_kg"
        case vacunasDia = "vacunas_dia"
        case usuarioId = "usuario_id"
    }

    public init(
        id: String,
        nombre: String,
        especie: String,
        raza: String? = nil,
        pesoKg: Double? = nil,
        vacunasDia: Bool = false,
        notas: String? = nil,
        usuarioId: String? = nil
    ) {
        self.id = id
        self.nombre = nombre
        self.especie = especie
        self.raza = raza
        self.pesoKg = pesoKg
        self.vacunasDia = vacunasDia
        self.notas = notas
        self.usuarioId = usuarioId
    }

    // `peso_kg` es NUMERIC(5,2) en Postgres → puede llegar como string desde `pg`
    // (ver Core/Utils/FlexibleDecoding.swift). Se escriben AMBOS `init(from:)` y
    // `encode(to:)` a mano (no solo uno) porque `Mascota` se codifica Y decodifica de
    // verdad en este cliente (round-trip con `UsuarioCache.mascotasJSON`, no solo
    // respuestas del servidor) — dejar que el compilador sintetice solo una mitad sería
    // ambiguo aquí.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nombre = try c.decode(String.self, forKey: .nombre)
        especie = try c.decode(String.self, forKey: .especie)
        raza = try c.decodeIfPresent(String.self, forKey: .raza)
        pesoKg = try c.decodeFlexibleDoubleIfPresent(forKey: .pesoKg)
        vacunasDia = try c.decodeIfPresent(Bool.self, forKey: .vacunasDia) ?? false
        notas = try c.decodeIfPresent(String.self, forKey: .notas)
        usuarioId = try c.decodeIfPresent(String.self, forKey: .usuarioId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(especie, forKey: .especie)
        try c.encodeIfPresent(raza, forKey: .raza)
        try c.encodeIfPresent(pesoKg, forKey: .pesoKg)
        try c.encode(vacunasDia, forKey: .vacunasDia)
        try c.encodeIfPresent(notas, forKey: .notas)
        try c.encodeIfPresent(usuarioId, forKey: .usuarioId)
    }

    /// Especies sugeridas en el formulario — el backend acepta cualquier `TEXT`, no es un enum en BD.
    public static let especiesSugeridas = ["perro", "gato", "otro"]
}

// MARK: - CRUD de mascotas (🔴 propuesto — hoy solo se crea 1 mascota durante el registro)
//
// Ver ARCHITECTURE_AUDIT.md §2.1 y MVP_SCOPE.md §4.1. Contrato propuesto, snake_case:
//   POST   /api/mascotas       { nombre, especie, raza?, peso_kg?, vacunas_dia?, notas? }
//                               → 201 { mascota: Mascota }
//   PATCH  /api/mascotas/:id   { mismos campos, todos opcionales } → 200 { mascota: Mascota }
//   DELETE /api/mascotas/:id   → 200 { ok: true }

public struct GuardarMascotaRequest: Encodable {
    public let nombre: String
    public let especie: String
    public let raza: String?
    public let pesoKg: Double?
    public let vacunasDia: Bool?
    public let notas: String?

    enum CodingKeys: String, CodingKey {
        case nombre, especie, raza, notas
        case pesoKg = "peso_kg"
        case vacunasDia = "vacunas_dia"
    }

    public init(nombre: String, especie: String, raza: String? = nil, pesoKg: Double? = nil, vacunasDia: Bool? = nil, notas: String? = nil) {
        self.nombre = nombre
        self.especie = especie
        self.raza = raza
        self.pesoKg = pesoKg
        self.vacunasDia = vacunasDia
        self.notas = notas
    }
}

public struct MascotaResponse: Codable {
    public let mascota: Mascota
}

public struct EliminarOKResponse: Codable {
    public let ok: Bool
}
