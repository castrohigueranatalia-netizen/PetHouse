//
//  PHMetrics.swift
//  DesignSystem
//
//  Espaciado, radios y sombras — tomados 1:1 de las custom properties CSS
//  (--ph-s-4…--ph-s-64, --ph-r-xs…--ph-r-xl/full, shadow-1/2/3) documentadas en
//  ARCHITECTURE_AUDIT.md §4.
//

import SwiftUI

/// Escala de espaciado (4/8pt), igual que `--ph-s-4` … `--ph-s-64` en el CSS original.
public enum PHSpacing {
    public static let s4: CGFloat = 4
    public static let s8: CGFloat = 8
    public static let s12: CGFloat = 12
    public static let s16: CGFloat = 16
    public static let s20: CGFloat = 20
    public static let s24: CGFloat = 24
    public static let s32: CGFloat = 32
    public static let s40: CGFloat = 40
    public static let s48: CGFloat = 48
    public static let s64: CGFloat = 64
}

/// Radios de esquina, igual que `--ph-r-xs` … `--ph-r-xl` / `--ph-r-full`.
public enum PHRadius {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 18
    public static let xl: CGFloat = 28
    public static let full: CGFloat = 9999
}

/// 3 niveles de elevación tipo Material, sutiles — para cards y hojas modales.
public enum PHShadow {
    public struct Spec {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }

    public static let level1 = Spec(color: .black.opacity(0.08), radius: 4, x: 0, y: 1)
    public static let level2 = Spec(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
    public static let level3 = Spec(color: .black.opacity(0.16), radius: 20, x: 0, y: 10)
}

public extension View {
    func phShadow(_ spec: PHShadow.Spec) -> some View {
        shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
