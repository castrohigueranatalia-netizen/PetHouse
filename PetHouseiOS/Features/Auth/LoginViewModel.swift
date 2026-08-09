//
//  LoginViewModel.swift
//  Features/Auth
//
//  Validación de cliente ADEMÁS de la del servidor (nunca en vez de) — mismas reglas que
//  `pethouse-api/src/routes/auth.js`: correo con formato válido, contraseña de 6+
//  caracteres. El servidor sigue siendo la autoridad final; esto solo evita un viaje de
//  red para errores obvios y da feedback inmediato en el campo.
//

import Foundation

@MainActor
@Observable
public final class LoginViewModel {
    public var email = ""
    public var password = ""

    public private(set) var isLoading = false
    public private(set) var errorGeneral: String?
    public private(set) var errorEmail: String?
    public private(set) var errorPassword: String?

    private let session: SessionStore

    public init(session: SessionStore) {
        self.session = session
    }

    public var puedeEnviar: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    public func iniciarSesion() async {
        errorGeneral = nil
        guard validar() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await session.login(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorGeneral = (error as? AppError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func validar() -> Bool {
        errorEmail = PHValidacion.email(email)
        errorPassword = PHValidacion.password(password)
        return errorEmail == nil && errorPassword == nil
    }
}
