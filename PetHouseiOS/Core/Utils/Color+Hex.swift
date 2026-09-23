//
//  Color+Hex.swift
//  Core/Utils
//
//  Utilidades para construir `Color` desde valores hexadecimales y para crear colores
//  dinámicos (claro/oscuro) sin depender de un catálogo de assets — útil en este entorno
//  de desarrollo sin Xcode, donde no se puede verificar visualmente un Assets.xcassets.
//  DesignSystem/PHColor.swift es el único consumidor esperado de este archivo.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public extension Color {

    /// Crea un `Color` a partir de un hex `RRGGBB` o `#RRGGBB`.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8) / 255.0
        let b = Double(value & 0x0000FF) / 255.0

        self = Color(red: r, green: g, blue: b)
    }

    /// Color dinámico que cambia según `colorScheme` (claro/oscuro) del sistema.
    /// Evita depender de un Assets.xcassets con color sets, que no se puede validar
    /// visualmente sin Xcode/macOS durante el desarrollo de este MVP.
    static func dynamic(light: String, dark: String) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
        #else
        return Color(hex: light)
        #endif
    }
}
