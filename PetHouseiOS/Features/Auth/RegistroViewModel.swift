//
//  RegistroViewModel.swift
//  Features/Auth
//
//  El registro solo permite crear UNA mascota al vuelo (`mascotaNombre`, especie fija
//  'perro' en el servidor — ver `pethouse-api/src/routes/auth.js` línea 36). Agregar más
//  mascotas o cambiar la especie queda para después, en Perfil (CRUD "pendiente backend").
//
//  "Ofrecer hospedaje" es ADITIVO, no un tipo de cuenta exclusivo: cualquiera puede
//  reservar Y publicar hospedajes con la MISMA cuenta (ver db/05-multi-rol.sql). Pero
//  activarlo de verdad SIEMPRE requiere pasar por la verificación de seguridad
//  (VerificacionAnfitrionView) — el registro nunca activa `es_anfitrion` directo, el
//  servidor ignora cualquier intento de hacerlo desde aquí. `quiereOfrecerHospedaje` es
//  puramente una señal local: si está marcado, `RegistroView` navega a la verificación
//  justo después de crear la cuenta, en vez de cerrar el formulario.
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
    /// Toggle "También quiero ofrecer hospedaje" — aditivo, no exclusivo con `rol`.
    public var quiereOfrecerHospedaje: Bool
    public var mascotaNombre = ""

    public private(set) var isLoading = false
    public private(set) var errorGeneral: String?
    public private(set) var errorNombre: String?
    public private(set) var errorEmail: String?
    public private(set) var errorPassword: String?

    private let session: SessionStore

    public init(session: SessionStore) {
        self.session = session
        self.rol = .cliente
        self.quiereOfrecerHospedaje = false
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
            if quiereOfrecerHospedaje {
                session.abrirVerificacionAlEntrar = true
            }
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
