//
//  OlvidePasswordViewModel.swift
//  Features/Auth
//
//  "Olvidé mi contraseña" en dos pasos: pedir el código de 6 dígitos por correo, y luego
//  confirmarlo junto con la contraseña nueva. Sin `SessionStore` de por medio a propósito
//  — esto pasa ANTES de tener sesión, y el servidor cierra cualquier sesión existente de
//  esa cuenta al restablecer, así que no tiene sentido intentar "loguear" desde acá.
//

import Foundation

@MainActor
@Observable
public final class OlvidePasswordViewModel {
    public enum Paso {
        case correo   // pidiendo el código
        case codigo   // código + contraseña nueva
        case listo    // contraseña restablecida
    }

    public private(set) var paso: Paso = .correo
    public var email = ""
    public var codigo = ""
    public var passwordNueva = ""
    public var passwordConfirmar = ""

    public private(set) var isLoading = false
    public private(set) var errorGeneral: String?
    public private(set) var errorEmail: String?

    private let authService: AuthServicing

    public init(authService: AuthServicing = AuthService()) {
        self.authService = authService
    }

    public var puedeEnviarCorreo: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading
    }

    public var puedeRestablecer: Bool {
        codigo.trimmingCharacters(in: .whitespaces).count == 6
            && PHValidacion.password(passwordNueva) == nil
            && passwordNueva == passwordConfirmar
            && !isLoading
    }

    public func pedirCodigo() async {
        errorGeneral = nil
        errorEmail = PHValidacion.email(email)
        guard errorEmail == nil else { return }

        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.olvidePassword(email: email.trimmingCharacters(in: .whitespaces))
            paso = .codigo
        } catch {
            errorGeneral = (error as? AppError)?.localizedDescription ?? error.localizedDescription
        }
    }

    public func restablecer() async {
        errorGeneral = nil
        guard passwordNueva == passwordConfirmar else {
            errorGeneral = "Las contraseñas no coinciden."
            return
        }
        guard PHValidacion.password(passwordNueva) == nil else {
            errorGeneral = PHValidacion.password(passwordNueva)
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.restablecerPassword(
                email: email.trimmingCharacters(in: .whitespaces),
                codigo: codigo.trimmingCharacters(in: .whitespaces),
                passwordNueva: passwordNueva
            )
            paso = .listo
        } catch {
            errorGeneral = (error as? AppError)?.localizedDescription ?? error.localizedDescription
        }
    }

    /// Vuelve al paso 1 (ej. "escribí mal mi correo") — limpia el código y el error, pero
    /// no las contraseñas que ya había escrito, para no hacer reescribir todo.
    public func volverAlCorreo() {
        paso = .correo
        codigo = ""
        errorGeneral = nil
    }
}
