//
//  KeychainStore.swift
//  Core/Security
//
//  Guarda accessToken/refreshToken en el Keychain de iOS — NUNCA en UserDefaults, que no
//  está cifrado y es legible por cualquier proceso con acceso al contenedor de la app en
//  un dispositivo con jailbreak. `kSecAttrAccessibleAfterFirstUnlock` permite que la app
//  lea el token en segundo plano/al arrancar sin que el usuario haya desbloqueado el
//  teléfono en esa sesión (necesario para refrescar sesión en background), pero sigue
//  cifrado en reposo antes del primer desbloqueo tras un reinicio.
//
//  Nada en este archivo importa SwiftUI ni Networking: es una utilidad de bajo nivel.
//

import Foundation
import Security

public protocol KeychainStoring: Sendable {
    func guardar(_ valor: String, para llave: KeychainStore.Llave) throws
    func leer(_ llave: KeychainStore.Llave) -> String?
    func borrar(_ llave: KeychainStore.Llave) throws
    func borrarTodo()
}

/// `@unchecked Sendable`: no tiene estado mutable propio, solo llama a la API de
/// Keychain (Security framework), que ya es thread-safe.
public final class KeychainStore: KeychainStoring, @unchecked Sendable {
    public enum Llave: String {
        case accessToken = "co.pethouse.accessToken"
        case refreshToken = "co.pethouse.refreshToken"
        // Credenciales de "Recuérdame" (ver LoginViewModel) — a propósito NO se borran en
        // `borrarTodo()`: esa función se llama al cerrar sesión o cuando el refresh token
        // expira, y el punto de "Recuérdame" es que el correo/contraseña sigan precargados
        // la próxima vez que la persona vuelva a la pantalla de inicio de sesión, aunque
        // haya cerrado sesión mientras tanto. Solo se borran si la persona desmarca la
        // casilla y vuelve a iniciar sesión (ver LoginViewModel.iniciarSesion()).
        case emailRecordado = "co.pethouse.emailRecordado"
        case passwordRecordada = "co.pethouse.passwordRecordada"
    }

    public enum KeychainError: Error {
        case noPudoGuardar(OSStatus)
        case noPudoBorrar(OSStatus)
    }

    public static let shared = KeychainStore()

    private let service = "co.pethouse.app"

    public init() {}

    public func guardar(_ valor: String, para llave: Llave) throws {
        let data = Data(valor.utf8)

        var query = baseQuery(for: llave)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        // Si ya existe, se borra primero para evitar errSecDuplicateItem.
        SecItemDelete(baseQuery(for: llave) as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.noPudoGuardar(status)
        }
    }

    public func leer(_ llave: Llave) -> String? {
        var query = baseQuery(for: llave)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func borrar(_ llave: Llave) throws {
        let status = SecItemDelete(baseQuery(for: llave) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.noPudoBorrar(status)
        }
    }

    /// Borra ambos tokens — usado en logout y cuando el refresh falla definitivamente.
    public func borrarTodo() {
        try? borrar(.accessToken)
        try? borrar(.refreshToken)
    }

    private func baseQuery(for llave: Llave) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: llave.rawValue
        ]
    }
}
