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
    ///
    /// Usa la zona horaria LOCAL del dispositivo, no UTC: estas fechas representan un día
    /// calendario (el que el usuario ve y elige en el `DatePicker`), no un instante. Si se
    /// formateara en UTC, un `Date` de la tarde/noche en zonas con offset negativo (ej.
    /// Bogotá, UTC-5) ya cae en el día UTC siguiente y la reserva se crearía para el día
    /// equivocado.
    public static let apiDateOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
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

    /// Tiempo relativo en español, ej. "hace 2 horas" — usado por el historial de
    /// notificaciones (ver NotificacionesView). Si el timestamp no se puede interpretar,
    /// cae al string original en vez de mostrar algo confuso.
    public static func displayRelative(_ raw: String) -> String {
        guard let date = parseTimestamp(raw) else { return raw }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}
