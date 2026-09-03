//
//  Disponibilidad.swift
//  Core/Models
//
//  GET /api/hospedajes/:id/disponibilidad (pública) → rangos de fecha ya ocupados
//  (confirmada/pendiente), SIN datos del huésped — el huésped que va a reservar la usa para
//  ver qué fechas evitar antes de armar su solicitud (ver PHSelectorRangoFechas).
//

import Foundation

public struct RangoOcupado: Decodable {
    public let desde: String   // YYYY-MM-DD
    public let hasta: String   // YYYY-MM-DD
    public let estado: String  // "confirmada" | "pendiente"
}

public struct DisponibilidadResponse: Decodable {
    public let ocupado: [RangoOcupado]
}

public extension Array where Element == RangoOcupado {
    /// Expande estos rangos `[desde, hasta)` a un set de días individuales `YYYY-MM-DD` —
    /// mismo formato que usan `PHSelectorRangoFechas`/`diaOcupado`, para comparar por texto
    /// en vez de por `Date` (evita cualquier lío de huso horario). Compartido por
    /// `NuevaReservaViewModel` (huésped) y `BloquearFechasSheet` (anfitrión).
    func diasOcupados(calendario: Calendar = .current) -> Set<String> {
        var dias: Set<String> = []
        for rango in self {
            guard let inicio = PHDate.apiDateOnly.date(from: rango.desde),
                  let fin = PHDate.apiDateOnly.date(from: rango.hasta) else { continue }
            var cursor = inicio
            while cursor < fin {
                dias.insert(PHDate.toAPIDateOnly(cursor))
                guard let siguiente = calendario.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = siguiente
            }
        }
        return dias
    }
}
