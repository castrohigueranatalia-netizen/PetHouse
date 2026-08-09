//
//  PHValidacion.swift
//  Core/Utils
//
//  Validación de formularios en cliente — replica EXACTAMENTE las reglas y mensajes que
//  usa `pethouse-api/src/routes/auth.js`, para que el usuario nunca vea un mensaje
//  distinto en cliente vs. servidor. Esto es un complemento a la validación del servidor,
//  no un reemplazo: el servidor sigue validando todo de nuevo.
//

import Foundation

public enum PHValidacion {
    private static let emailRegex = try! NSRegularExpression(pattern: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#)

    /// `nil` si es válido. Mismo mensaje que el backend (auth.js línea 21).
    public static func email(_ valor: String) -> String? {
        let trimmed = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Ingresa tu correo y contraseña." }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let coincide = emailRegex.firstMatch(in: trimmed, range: range) != nil
        return coincide ? nil : "Correo electrónico inválido."
    }

    /// Mismo mensaje que el backend (auth.js línea 22): mínimo 6 caracteres.
    public static func password(_ valor: String) -> String? {
        valor.count >= 6 ? nil : "La contraseña debe tener al menos 6 caracteres."
    }

    /// Mismo mensaje que el backend (auth.js línea 20): mínimo 3 caracteres tras recortar espacios.
    public static func nombre(_ valor: String) -> String? {
        let trimmed = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 ? nil : "Ingresa tu nombre completo."
    }
}
