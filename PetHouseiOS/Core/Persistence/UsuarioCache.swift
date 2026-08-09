//
//  UsuarioCache.swift
//  Core/Persistence
//
//  Caché offline del perfil del usuario logueado + sus mascotas (lectura básica sin red,
//  no sincronización compleja — ver system prompt de este MVP). Se sobrescribe por
//  completo cada vez que `GET /api/auth/me` responde con éxito; nunca se edita desde
//  aquí directamente cuando hay red disponible, solo se lee como respaldo.
//
//  Las mascotas se guardan como JSON embebido en vez de una relación SwiftData aparte:
//  para el alcance de este MVP (una sola fila "el perfil actual") es más simple y evita
//  modelar relaciones/borrados en cascada para un caso de uso de solo-lectura offline.
//

import Foundation
import SwiftData

@Model
public final class UsuarioCache {
    @Attribute(.unique) public var id: String
    public var nombre: String
    public var email: String
    public var telefono: String?
    public var rol: String
    public var verificado: Bool
    public var creadoEn: String?
    public var mascotasJSON: Data
    public var actualizadoEn: Date

    public init(
        id: String, nombre: String, email: String, telefono: String?, rol: String,
        verificado: Bool, creadoEn: String?, mascotasJSON: Data, actualizadoEn: Date = .now
    ) {
        self.id = id
        self.nombre = nombre
        self.email = email
        self.telefono = telefono
        self.rol = rol
        self.verificado = verificado
        self.creadoEn = creadoEn
        self.mascotasJSON = mascotasJSON
        self.actualizadoEn = actualizadoEn
    }
}

public extension UsuarioCache {
    /// Construye la fila de caché a partir de la respuesta real de `GET /api/auth/me`.
    convenience init(usuario: Usuario, mascotas: [Mascota]) {
        let mascotasData = (try? JSONEncoder().encode(mascotas)) ?? Data()
        self.init(
            id: usuario.id, nombre: usuario.nombre, email: usuario.email,
            telefono: usuario.telefono, rol: usuario.rol.rawValue, verificado: usuario.verificado,
            creadoEn: usuario.creadoEn, mascotasJSON: mascotasData, actualizadoEn: .now
        )
    }

    var mascotas: [Mascota] {
        (try? JSONDecoder().decode([Mascota].self, from: mascotasJSON)) ?? []
    }

    var comoUsuario: Usuario {
        Usuario(
            id: id, nombre: nombre, email: email, telefono: telefono,
            rol: Usuario.Rol(rawValue: rol) ?? .cliente, verificado: verificado, creadoEn: creadoEn
        )
    }
}
