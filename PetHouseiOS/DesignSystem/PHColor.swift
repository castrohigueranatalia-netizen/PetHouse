//
//  PHColor.swift
//  DesignSystem
//
//  Tokens de color de la marca PetHouse, portados desde las custom properties CSS
//  de `part1_head.html` (ver ARCHITECTURE_AUDIT.md §4: --ph-primary, --ph-ink, etc).
//
//  El CSS original NO define modo oscuro (todo vive sobre --ph-canvas:#fff). La paleta
//  dark de abajo es una decisión de diseño tomada para este MVP, no una migración de algo
//  existente: se mantiene el mismo ROL semántico de cada token (mismo nombre, mismo uso)
//  pero con valores ajustados a contraste AA sobre fondo oscuro. Ver README.md → sección
//  "Decisiones de diseño no especificadas" para el detalle de esta elección.
//
//  Se usan colores dinámicos calculados en código (Color.dynamic, en Core/Utils/Color+Hex)
//  en vez de un Assets.xcassets con color sets, porque este MVP se escribe sin acceso a
//  Xcode/macOS y un catálogo de colores no se puede previsualizar ni validar a ciegas.
//  Regla de capas: este archivo solo importa SwiftUI (vía Color+Hex) — no importa
//  Networking ni conoce la forma de los modelos de Core/Models.
//

import SwiftUI

public enum PHColor {

    // MARK: - Marca / acento (coral) — la identidad no cambia entre claro y oscuro,
    // solo se aclaran los estados interactivos para mantener contraste sobre fondo oscuro.
    public static let primary = Color.dynamic(light: "FB3F57", dark: "FF5C71")
    public static let primaryHover = Color.dynamic(light: "E5324A", dark: "FF7A8C")
    public static let primaryActive = Color.dynamic(light: "CF2A40", dark: "FF98A6")
    public static let primaryContainer = Color.dynamic(light: "FFDEE3", dark: "4B111C")
    public static let onPrimaryContainer = Color.dynamic(light: "4B0E1A", dark: "FFD3DA")

    // MARK: - Texto
    public static let ink = Color.dynamic(light: "2A2F35", dark: "F2F3F5")
    public static let body = Color.dynamic(light: "3F3F3F", dark: "D8DADD")
    public static let muted = Color.dynamic(light: "6A6A6A", dark: "9A9EA6")
    public static let mutedSoft = Color.dynamic(light: "929292", dark: "6E7279")

    // MARK: - Fondos
    public static let canvas = Color.dynamic(light: "FFFFFF", dark: "16181C")
    public static let surfaceSoft = Color.dynamic(light: "F7F7F7", dark: "1E2125")
    public static let surfaceStrong = Color.dynamic(light: "F2F2F2", dark: "26292E")

    // MARK: - Bordes
    public static let hairline = Color.dynamic(light: "DDDDDD", dark: "33363B")
    public static let hairlineSoft = Color.dynamic(light: "EBEBEB", dark: "2A2D31")

    // MARK: - Estado
    public static let error = Color.dynamic(light: "C13515", dark: "FF6B57")
    public static let errorContainer = Color.dynamic(light: "FFDAD2", dark: "4A1610")
    public static let success = Color.dynamic(light: "1A7F4E", dark: "35C782")
    public static let successContainer = Color.dynamic(light: "D7F1E3", dark: "12321F")

    /// No existe en el CSS original — se añadió para los estados "función pendiente en el
    /// servidor" (ver README). Decisión de diseño propia de este MVP.
    public static let warning = Color.dynamic(light: "9A6700", dark: "E8B339")
    public static let warningContainer = Color.dynamic(light: "FFF1CF", dark: "3A2E0A")
}
