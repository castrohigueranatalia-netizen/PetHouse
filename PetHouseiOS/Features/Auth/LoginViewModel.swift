//
//  LoginViewModel.swift
//  Features/Auth
//
//  Validación de cliente ADEMÁS de la del servidor (nunca en vez de) — mismas reglas que
//  `pethouse-api/src/routes/auth.js`: correo con formato válido, contraseña de 6+
//  caracteres. El servidor sigue siendo la autoridad final; esto solo evita un viaje de
//  red para errores obvios y da feedback inmediato en el campo.
//
//  "Recuérdame": guarda una LISTA de cuentas (correo + contraseña de cada una que se haya
//  usado con el interruptor activado), no solo la última — así el campo de correo puede
//  desplegar todas las guardadas (ver `LoginView`) y, al elegir una, la contraseña se
//  rellena sola sin tener que volver a escribirla. Todo va al Keychain de iOS (cifrado,
//  igual que los tokens de sesión — NUNCA en UserDefaults) como un solo JSON bajo una llave
//  (`KeychainStore.Llave.cuentasRecordadas`), no una llave por cuenta.
//
//  No reemplaza el inicio de sesión automático que ya existe vía el refresh token (eso
//  sigue siendo lo normal mientras la sesión siga activa); esto es para cuando la persona
//  SÍ vuelve a esta pantalla — después de cerrar sesión a propósito, o porque el refresh
//  expiró.
//

import Foundation

/// Una cuenta guardada por "Recuérdame" — `Identifiable` por el correo (no tiene sentido
/// guardar el mismo correo dos veces, ver `LoginViewModel.actualizarCuentasRecordadas`).
public struct CuentaRecordada: Codable, Identifiable, Hashable {
    public var id: String { email }
    public let email: String
    public let password: String
}

@MainActor
@Observable
public final class LoginViewModel {
    public var email = ""
    public var password = ""
    public var recuerdame: Bool

    public private(set) var isLoading = false
    public private(set) var errorGeneral: String?
    public private(set) var errorEmail: String?
    public private(set) var errorPassword: String?

    /// Todas las cuentas guardadas, la más reciente primero — `LoginView` las despliega
    /// como lista debajo del campo de correo.
    public private(set) var cuentasRecordadas: [CuentaRecordada]

    private let session: SessionStore
    private let keychain: KeychainStoring

    public init(session: SessionStore, keychain: KeychainStoring = KeychainStore.shared) {
        self.session = session
        self.keychain = keychain

        let cuentas = Self.cargarCuentas(keychain)
        cuentasRecordadas = cuentas
        if let primera = cuentas.first {
            email = primera.email
            password = primera.password
            recuerdame = true
        } else {
            recuerdame = false
        }
    }

    public var puedeEnviar: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }

    /// Elegir una cuenta del desplegable rellena las dos cosas de una — para que cambiar
    /// de correo no obligue a volver a escribir la contraseña.
    public func seleccionarCuenta(_ cuenta: CuentaRecordada) {
        email = cuenta.email
        password = cuenta.password
    }

    public func iniciarSesion() async {
        errorGeneral = nil
        guard validar() else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let correo = email.trimmingCharacters(in: .whitespaces)
            try await session.login(email: correo, password: password)
            actualizarCuentasRecordadas(correo: correo)
        } catch {
            errorGeneral = (error as? AppError)?.localizedDescription ?? error.localizedDescription
        }
    }

    /// Se llama SOLO tras un login exitoso — no tiene sentido recordar una contraseña que
    /// ni siquiera es correcta. Reemplaza la entrada existente para ese correo (por si la
    /// contraseña cambió) y la sube al principio de la lista; si "Recuérdame" está apagado,
    /// esa cuenta puntual se olvida (las demás guardadas quedan intactas).
    private func actualizarCuentasRecordadas(correo: String) {
        var cuentas = cuentasRecordadas
        cuentas.removeAll { $0.email.caseInsensitiveCompare(correo) == .orderedSame }
        if recuerdame {
            cuentas.insert(CuentaRecordada(email: correo, password: password), at: 0)
        }
        cuentasRecordadas = cuentas

        guard let data = try? JSONEncoder().encode(cuentas), let json = String(data: data, encoding: .utf8) else { return }
        if cuentas.isEmpty {
            try? keychain.borrar(.cuentasRecordadas)
        } else {
            try? keychain.guardar(json, para: .cuentasRecordadas)
        }
    }

    private static func cargarCuentas(_ keychain: KeychainStoring) -> [CuentaRecordada] {
        guard let json = keychain.leer(.cuentasRecordadas),
              let data = json.data(using: .utf8),
              let cuentas = try? JSONDecoder().decode([CuentaRecordada].self, from: data)
        else { return [] }
        return cuentas
    }

    private func validar() -> Bool {
        errorEmail = PHValidacion.email(email)
        errorPassword = PHValidacion.password(password)
        return errorEmail == nil && errorPassword == nil
    }
}
