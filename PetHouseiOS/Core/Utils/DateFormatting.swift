//
//  DateFormatting.swift
//  Core/Utils
//
//  El backend usa dos formatos de fecha distintos (ver ARCHITECTURE_AUDIT.md §5):
//  - `DATE` puro `YYYY-MM-DD` para `desde/hasta` de reservas.
//  - `TIMESTAMPTZ` ISO 8601 completo para `creado_en`.
//  Este archivo centraliza ambos formateadores para no repetirlos por toda la app.
//

import Foundation

public enum PHDate {

    /// `YYYY-MM-DD`, sin hora — usado por `reservas.desde` / `reservas.hasta`.
    public static let apiDateOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// ISO 8601 completo con fracción de segundos — usado por `creado_en` (TIMESTAMPTZ).
    public static let apiTimestamp: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// `ISO8601DateFormatter` sin fracción de segundos, como respaldo cuando el backend
    /// no incluye milisegundos (algunas respuestas de Postgres varían en precisión).
    public static let apiTimestampNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Decodifica un `TIMESTAMPTZ` probando con y sin fracción de segundos.
    public static func parseTimestamp(_ raw: String) -> Date? {
        apiTimestamp.date(from: raw) ?? apiTimestampNoFraction.date(from: raw)
    }

    /// Formato legible para UI, ej. "9 ago 2026".
    public static let display: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "d MMM yyyy"
        return f
    }()

    /// Formato corto legible, ej. "9 ago".
    public static let displayShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "d MMM"
        return f
    }()

    /// Convierte un `Date` al formato `YYYY-MM-DD` que espera la API.
    public static func toAPIDateOnly(_ date: Date) -> String {
        apiDateOnly.string(from: date)
    }

    /// Formatea un string `YYYY-MM-DD` recibido de la API a texto legible en español.
    public static func displayFromAPIDateOnly(_ raw: String) -> String {
        guard let date = apiDateOnly.date(from: raw) else { return raw }
        return display.string(from: date)
    }
}
