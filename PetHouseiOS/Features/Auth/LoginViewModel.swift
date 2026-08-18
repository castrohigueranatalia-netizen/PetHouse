//
//  LoginViewModel.swift
//  Features/Auth
//
//  Validación de cliente ADEMÁS de la del servidor (nunca en vez de) — mismas reglas que
//  `pethouse-api/src/routes/auth.js`: correo con formato válido, contraseña de 6+
//  caracteres. El servidor sigue siendo la autoridad final; esto solo evita un viaje de
//  red para errores obvios y da feedback inmediato en el campo.
//
//  "Recuérdame": el correo Y la contraseña se guardan en el Keychain de iOS (cifrado,
//  igual que los tokens de sesión — NUNCA en UserDefaults, que no está cifrado). No
//  reemplaza el inicio de sesión automático que ya existe vía el refresh token (eso sigue
//  siendo lo normal mientras la sesión siga activa); esto es para cuando la persona vuelve
//  a esta pantalla — después de cerrar sesión a propósito, o porque el refresh expiró —
//  y no tiene que volver a escribir su correo y contraseña desde cero.
//

import Foundation

@MainActor
@Observable
public final class LoginViewModel {
    public var email = ""
    public var password = ""
    public var recuerdame = false

    public private(set) var isLoading = false
    public private(set) var errorGeneral: String?
    public private(set) var errorEmail: String?
    public private(set) var errorPassword: String?

    private let session: SessionStore
    private let keychain: KeychainStoring

    public init(session: SessionStore, keychain: KeychainStoring = KeychainStore.shared) {
        self.session = session
        self.keychain = keychain

        if let emailGuardado = keychain.leer(.emailRecordado),
           let passwordGuardada = keychain.leer(.passwordRecordada) {
            email = emailGuardado
            password = passwordGuardada
            recuerdame = true
        }
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
            let correo = email.trimmingCharacters(in: .whitespaces)
            try await session.login(email: correo, password: password)
            guardarORecordarCredenciales(correo: correo)
        } catch {
            errorGeneral = (error as? AppError)?.localizedDescription ?? error.localizedDescription
        }
    }

    /// Se llama SOLO tras un login exitoso — no tiene sentido recordar una contraseña que
    /// ni siquiera es correcta.
    private func guardarORecordarCredenciales(correo: String) {
        if recuerdame {
            try? keychain.guardar(correo, para: .emailRecordado)
            try? keychain.guardar(password, para: .passwordRecordada)
        } else {
            try? keychain.borrar(.emailRecordado)
            try? keychain.borrar(.passwordRecordada)
        }
    }

    private func validar() -> Bool {
        errorEmail = PHValidacion.email(email)
        errorPassword = PHValidacion.password(password)
        return errorEmail == nil && errorPassword == nil
    }
}
