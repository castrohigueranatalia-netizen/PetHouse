//
//  RegistroViewModel.swift
//  Features/Auth
//
//  El registro solo permite crear UNA mascota al vuelo (`mascotaNombre`, especie fija
//  'perro' en el servidor — ver `pethouse-api/src/routes/auth.js` línea 36). Agregar más
//  mascotas o cambiar la especie queda para después, en Perfil (CRUD "pendiente backend").
//

import Foundation

@MainActor
@Observable
public final class RegistroViewModel {
    public var nombre = ""
    public var email = ""
    public var password = ""
    public var telefono = ""
    public var rol: Usuario.Rol
    public var mascotaNombre = ""

    public private(set) var isLoading = false
    public private(set) var errorGeneral: String?
    public private(set) var errorNombre: String?
    public private(set) var errorEmail: String?
    public private(set) var errorPassword: String?

    private let session: SessionStore

    /// `rolInicial`: qué eligió el usuario en la pantalla de bienvenida (ver
    /// `BienvenidaView`) antes de llegar aquí — sigue siendo editable en el formulario
    /// (el Picker de RegistroView), esto solo evita que tenga que elegirlo dos veces.
    public init(session: SessionStore, rolInicial: Usuario.Rol = .cliente) {
        self.session = session
        self.rol = rolInicial
    }

    public var puedeEnviar: Bool {
        !nombre.isEmpty && !email.isEmpty && !password.isEmpty && !isLoading
    }

    public func registrar() async -> Bool {
        errorGeneral = nil
        guard validar() else { return false }

        isLoading = true
        defer { isLoading = false }

        do {
            try await session.registro(
                nombre: nombre.trimmingCharacters(in: .whitespaces),
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                telefono: telefono.isEmpty ? nil : telefono,
                rol: rol,
                mascotaNombre: mascotaNombre.isEmpty ? nil : mascotaNombre
            )
            return true
        } catch {
            errorGeneral = (error as? AppError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    private func validar() -> Bool {
        errorNombre = PHValidacion.nombre(nombre)
        errorEmail = PHValidacion.email(email)
        errorPassword = PHValidacion.password(password)
        return errorNombre == nil && errorEmail == nil && errorPassword == nil
    }
}
