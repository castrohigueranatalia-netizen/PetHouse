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

    /// `HH:mm`, sin segundos — el formato que espera la API para `hora_entrega`/
    /// `hora_recogida` de una reserva (ver db/36-horarios-entrega.sql). Zona horaria LOCAL,
    /// igual que `apiDateOnly`: es la hora del reloj que el huésped elige, no un instante UTC.
    public static let apiTimeOnly: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    /// Formato legible de hora en español, ej. "8:30 a. m.".
    public static let displayTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_CO")
        f.dateFormat = "h:mm a"
        return f
    }()

    /// Convierte un `Date` (solo se usa su componente de hora) al `HH:mm` que espera la API.
    public static func toAPITimeOnly(_ date: Date) -> String {
        apiTimeOnly.string(from: date)
    }

    /// Formatea una hora de la API (`HH:mm` o `HH:mm:ss` — Postgres `TIME` devuelve con
    /// segundos) a texto legible en español, ej. "8:30 a. m.".
    public static func displayFromAPITimeOnly(_ raw: String) -> String {
        if let date = apiTimeOnly.date(from: raw) { return displayTime.string(from: date) }
        // Con segundos ("HH:mm:ss"): se recorta a "HH:mm" en vez de mantener un segundo
        // formateador aparte solo para esto.
        if raw.count >= 5, let date = apiTimeOnly.date(from: String(raw.prefix(5))) {
            return displayTime.string(from: date)
        }
        return raw
    }

    /// Lista de horas "HH:mm" cada `pasoMinutos` entre `desde` y `hasta` (ambos incluidos) —
    /// las opciones concretas que el huésped puede tocar para elegir hora de entrega/recogida
    /// (ver `NuevaReservaViewModel`), en vez de una rueda de reloj libre: más rápido de usar,
    /// y ya viene acotado al rango que el anfitrión configuró para su hospedaje (ver
    /// db/37-horarios-hospedaje.sql). `[]` si `desde`/`hasta` no son horas válidas.
    public static func horasEnRango(desde: String, hasta: String, pasoMinutos: Int = 30) -> [String] {
        guard let inicio = apiTimeOnly.date(from: desde), let fin = apiTimeOnly.date(from: hasta) else { return [] }
        var opciones: [String] = []
        var cursor = inicio
        while cursor <= fin {
            opciones.append(toAPITimeOnly(cursor))
            guard let siguiente = Calendar.current.date(byAdding: .minute, value: pasoMinutos, to: cursor) else { break }
            cursor = siguiente
        }
        return opciones
    }

    /// Formatea un string `YYYY-MM-DD` recibido de la API a texto legible en español.
    ///
    /// Respaldo con `parseTimestamp`: por un bug real ya corregido en el servidor (columnas
    /// `DATE` que `pg` decodificaba como objeto `Date` de JS y `res.json()` serializaba como
    /// timestamp completo, ej. "2026-12-01T05:00:00.000Z" en vez de "2026-12-01"), una
    /// reserva vieja en caché local (`ReservaCache`, para ver "Mis reservas" sin conexión)
    /// puede haber quedado con ese formato guardado de antes del arreglo. Sin este respaldo,
    /// `apiDateOnly.date(from:)` fallaba (formato estricto `yyyy-MM-dd`, no tolera la "T" ni
    /// la zona horaria) y se mostraba el string crudo tal cual — feo y confuso en la UI.
    public static func displayFromAPIDateOnly(_ raw: String) -> String {
        if let date = apiDateOnly.date(from: raw) { return display.string(from: date) }
        if let date = parseTimestamp(raw) { return display.string(from: date) }
        return raw
    }

    /// Formatea un `TIMESTAMPTZ` completo (`creado_en`) a texto legible en español, ej.
    /// "9 ago 2026" — usado donde importa CUÁNDO se creó algo (ticket de soporte, solicitud
    /// de privacidad), no una fecha de estadía.
    public static func displayFromTimestamp(_ raw: String) -> String {
        guard let date = parseTimestamp(raw) else { return raw }
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
