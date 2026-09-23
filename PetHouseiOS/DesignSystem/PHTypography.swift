//
//  PHTypography.swift
//  DesignSystem
//
//  Escala tipográfica de PetHouse. El CSS original (`part1_head.html`) usa
//  'Airbnb Cereal VF' — una fuente propietaria de Airbnb que no se puede distribuir ni usar
//  en esta app. Decisión de diseño de este MVP: usar la fuente del sistema (San Francisco)
//  en vez de licenciar/empaquetar una tipografía de terceros, porque (a) es gratis y ya
//  está optimizada para iOS, (b) soporta Dynamic Type e idiomas con acentos (español) sin
//  configuración extra, y (c) evita inflar el tamaño del binario con variable fonts.
//  Se preserva la escala original (`.d-xl/lg/md/sm`, `.t-md`, `.b-md/sm`, `.cap-sm`,
//  `.micro`) mapeada a `Font.system(..., relativeTo:)` para que todo escale con
//  Dynamic Type en vez de usar tamaños de punto fijos.
//

import SwiftUI

public enum PHFont {
    // Display — títulos grandes (hero de búsqueda, pantallas de auth)
    public static let displayXL = Font.system(.largeTitle, design: .rounded).weight(.bold)
    public static let displayLG = Font.system(.title, design: .rounded).weight(.bold)
    public static let displayMD = Font.system(.title2, design: .rounded).weight(.semibold)
    public static let displaySM = Font.system(.title3, design: .rounded).weight(.semibold)

    // Título de sección / card
    public static let titleMD = Font.system(.headline).weight(.semibold)

    // Cuerpo
    public static let bodyMD = Font.system(.body)
    public static let bodySM = Font.system(.subheadline)

    // Caption / micro
    public static let captionSM = Font.system(.caption)
    public static let micro = Font.system(.caption2)
}

/// Modificador de conveniencia para aplicar tipografía + color de tinta por defecto.
public struct PHTextStyle: ViewModifier {
    let font: Font
    let color: Color

    public init(_ font: Font, color: Color = PHColor.ink) {
        self.font = font
        self.color = color
    }

    public func body(content: Content) -> some View {
        content.font(font).foregroundStyle(color)
    }
}

public extension View {
    func phText(_ font: Font, color: Color = PHColor.ink) -> some View {
        modifier(PHTextStyle(font, color: color))
    }
}
