//
//  PHChip.swift
//  DesignSystem/Components
//

import SwiftUI

/// Chip seleccionable — usado en filtros de búsqueda (tipo, convivencia, orden).
public struct PHChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    public init(_ title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(PHFont.bodySM.weight(.medium))
                .padding(.horizontal, PHSpacing.s16)
                .padding(.vertical, PHSpacing.s8)
                .foregroundStyle(isSelected ? .white : PHColor.ink)
                .background(isSelected ? PHColor.primary : PHColor.surfaceSoft)
                .clipShape(Capsule())
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// Insignia pequeña de estado (ej. "Verificado", "Pendiente en el servidor").
public struct PHBadge: View {
    public enum Style {
        case primary, success, warning, error, neutral
    }

    let text: String
    let style: Style

    public init(_ text: String, style: Style = .neutral) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(PHFont.micro.weight(.semibold))
            .padding(.horizontal, PHSpacing.s8)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case .primary: PHColor.onPrimaryContainer
        case .success: PHColor.success
        case .warning: PHColor.warning
        case .error: PHColor.error
        case .neutral: PHColor.muted
        }
    }

    private var background: Color {
        switch style {
        case .primary: PHColor.primaryContainer
        case .success: PHColor.successContainer
        case .warning: PHColor.warningContainer
        case .error: PHColor.errorContainer
        case .neutral: PHColor.surfaceStrong
        }
    }
}

/// Avatar circular con iniciales de respaldo cuando no hay foto (URL o `AsyncImage`).
public struct PHAvatar: View {
    let name: String
    let urlString: String?
    let size: CGFloat

    public init(name: String, urlString: String? = nil, size: CGFloat = 44) {
        self.name = name
        self.urlString = urlString
        self.size = size
    }

    private var initials: String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "?" : String(letters).uppercased()
    }

    public var body: some View {
        PHCachedAsyncImage(urlString: urlString) {
            Circle()
                .fill(PHColor.primaryContainer)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(PHColor.onPrimaryContainer)
                )
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityLabel("Foto de perfil de \(name)")
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            PHChip("Todos", isSelected: true) {}
            PHChip("Guardería", isSelected: false) {}
        }
        HStack {
            PHBadge("Verificado", style: .success)
            PHBadge("Función pendiente", style: .warning)
        }
        PHAvatar(name: "Natalia Castro")
    }
    .padding()
}
