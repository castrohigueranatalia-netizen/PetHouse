//
//  Formato.swift
//  Core/Utils
//
//  Formateo de moneda. El prototipo HTML y los precios de ejemplo en `db/02-seed.sql`
//  están en pesos colombianos (COP) sin decimales de uso corriente.
//

import Foundation

public enum PHFormato {
    private static let moneda: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale(identifier: "es_CO")
        f.currencyCode = "COP"
        f.maximumFractionDigits = 0
        return f
    }()

    public static func precio(_ valor: Double) -> String {
        moneda.string(from: NSNumber(value: valor)) ?? "$\(Int(valor))"
    }
}
