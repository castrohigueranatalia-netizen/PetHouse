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
    public let creadoEn: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, email, telefono, rol, verificado
        case fotoUrl = "foto_url"
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
        creadoEn: String? = nil
    ) {
        self.id = id
        self.nombre = nombre
        self.email = email
        self.telefono = telefono
        self.rol = rol
        self.verificado = verificado
        self.fotoUrl = fotoUrl
        self.creadoEn = creadoEn
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
