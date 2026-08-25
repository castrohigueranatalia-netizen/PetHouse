//
//  CalendarioMes.swift
//  Core/Utils
//
//  Arma la grilla de un mes (6 semanas x 7 días, lunes a domingo) — compartido por
//  `CalendarioHospedajeViewModel` (el anfitrión ve sus fechas reservadas) y
//  `PHSelectorRangoFechas` (el huésped elige fechas viendo cuáles ya están ocupadas), para
//  no repetir el mismo cálculo de "día de la semana en que cae el 1º del mes" dos veces.
//

import Foundation

public enum CalendarioMes {
    /// Los 42 casilleros de la grilla — `nil` para los días de relleno antes del 1 y
    /// después del último día del mes. `mes` puede ser cualquier `Date` dentro del mes que
    /// se quiere mostrar (no hace falta que sea el día 1).
    public static func diasDeLaGrilla(paraMes mes: Date, calendario: Calendar = .current) -> [Date?] {
        guard let inicioMes = calendario.date(from: calendario.dateComponents([.year, .month], from: mes)),
              let rangoDias = calendario.range(of: .day, in: .month, for: inicioMes) else { return [] }
        let primerDiaSemana = calendario.component(.weekday, from: inicioMes) // 1=domingo…7=sábado
        // Semana empieza en lunes: domingo(1) queda al final (offset 6), lunes(2) al principio (offset 0).
        let relleno = (primerDiaSemana + 5) % 7
        var dias: [Date?] = Array(repeating: nil, count: relleno)
        for numeroDia in rangoDias {
            if let fecha = calendario.date(byAdding: .day, value: numeroDia - 1, to: inicioMes) {
                dias.append(fecha)
            }
        }
        while dias.count % 7 != 0 { dias.append(nil) }
        return dias
    }
}
