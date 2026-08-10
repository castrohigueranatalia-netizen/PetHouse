//
//  Usuario.swift
//  Core/Models
//
//  Refleja la tabla `usuarios` (db/01-esquema.sql) y las formas en que la API la devuelve,
//  que no son idénticas entre sí:
//   - POST /api/auth/registro → RETURNING id, nombre, email, rol, verificado, creado_en
//                                (sin foto_url: recién creado, todavía no tiene)
//   - POST /api/auth/login    → fila completa menos password_hash (incluye telefono)
//   - GET  /api/auth/me       → id, nombre, email, telefono, rol, verificado, foto_url
//                                (sin creado_en — el middleware `auth` limita la consulta;
//                                ver db/04-perfil-mvp-ios.sql para la columna foto_url)
//   - PATCH /api/auth/me      → fila completa actualizada, incluye foto_url
//  Por eso `telefono`, `fotoUrl` y `creadoEn` son opcionales: no asumas que siempre vienen.
//

import Foundation

public struct Usuario: Codable, Identifiable, Hashable {
    public enum Rol: String, Codable, CaseIterable {
        case cliente
        case anfitrion
        case admin
    }

    public let id: String
    public let nombre: String
    public let email: String
    public let telefono: String?
    public let rol: Rol
    public let verificado: Bool
    public let fotoUrl: String?
    /// Capacidad de anfitrión (publicar hospedajes, ver reservas recibidas) — ADITIVA, no
    /// exclusiva con `rol`: una cuenta puede reservar Y ofrecer hospedaje a la vez. `rol`
    /// se conserva solo como intención principal para mostrar en UI; la autorización real
    /// de acciones de anfitrión depende de este campo (ver `soloAnfitrion` en el backend y
    /// db/05-multi-rol.sql). `false` si el backend no lo manda (compatibilidad con
    /// respuestas viejas antes de esta migración).
    public let esAnfitrion: Bool
    public let creadoEn: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, email, telefono, rol, verificado
        case fotoUrl = "foto_url"
        case esAnfitrion = "es_anfitrion"
        case creadoEn = "creado_en"
    }

    public init(
        id: String,
        nombre: String,
        email: String,
        telefono: String? = nil,
        rol: Rol,
        verificado: Bool,
        fotoUrl: String? = nil,
        esAnfitrion: Bool = false,
        creadoEn: String? = nil
    ) {
        self.id = id
        self.nombre = nombre
        self.email = email
        self.telefono = telefono
        self.rol = rol
        self.verificado = verificado
        self.fotoUrl = fotoUrl
        self.esAnfitrion = esAnfitrion
        self.creadoEn = creadoEn
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nombre = try c.decode(String.self, forKey: .nombre)
        email = try c.decode(String.self, forKey: .email)
        telefono = try c.decodeIfPresent(String.self, forKey: .telefono)
        rol = try c.decode(Rol.self, forKey: .rol)
        verificado = try c.decode(Bool.self, forKey: .verificado)
        fotoUrl = try c.decodeIfPresent(String.self, forKey: .fotoUrl)
        esAnfitrion = try c.decodeIfPresent(Bool.self, forKey: .esAnfitrion) ?? false
        creadoEn = try c.decodeIfPresent(String.self, forKey: .creadoEn)
    }
}

/// Payload de respuesta de `/api/auth/registro`, `/login`, `/refresh`.
public struct AuthResponse: Codable {
    public let usuario: Usuario
    public let accessToken: String
    public let refreshToken: String
    public let expiraEn: String
}

/// Payload de `GET /api/auth/me`.
public struct MeResponse: Codable {
    public let usuario: Usuario
    public let mascotas: [Mascota]
}

// MARK: - Editar perfil (🔴 propuesto — no existe `PATCH /api/auth/me` hoy)
//
// Ver ARCHITECTURE_AUDIT.md §2.1 ("No existen: PATCH de perfil de usuario...") y
// MVP_SCOPE.md §4.1. Contrato propuesto, siguiendo la convención snake_case ya usada
// en el resto de bodies de la API (excepto POST /api/hospedajes, ver Hospedaje.swift):
//   PATCH /api/auth/me { nombre?, telefono?, foto_url? } → 200 { usuario: Usuario }

public struct EditarPerfilRequest: Encodable {
    public let nombre: String?
    public let telefono: String?
    public let fotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case nombre, telefono
        case fotoUrl = "foto_url"
    }

    public init(nombre: String? = nil, telefono: String? = nil, fotoUrl: String? = nil) {
        self.nombre = nombre
        self.telefono = telefono
        self.fotoUrl = fotoUrl
    }
}

public struct EditarPerfilResponse: Codable {
    public let usuario: Usuario
}
