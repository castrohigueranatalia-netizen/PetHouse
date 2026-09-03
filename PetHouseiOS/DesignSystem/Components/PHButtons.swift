//
//  PHButtons.swift
//  DesignSystem/Components
//

import SwiftUI

/// Botón primario de marca (coral, relleno) — para la acción principal de cada pantalla.
public struct PHPrimaryButton: View {
    let title: String
    let systemImage: String?
    let isLoading: Bool
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: PHSpacing.s8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(PHFont.titleMD)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PHSpacing.s16)
            .foregroundStyle(.white)
            .background(PHColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.85 : 1)
    }
}

/// Botón secundario (contorno, sin relleno) — para acciones alternativas.
public struct PHSecondaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: PHSpacing.s8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .font(PHFont.titleMD)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, PHSpacing.s16)
            .foregroundStyle(PHColor.primary)
            .background(
                RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous)
                    .stroke(PHColor.primary, lineWidth: 1.5)
            )
        }
    }
}

/// Botón de solo texto (sin fondo) — para acciones terciarias como "Cancelar".
public struct PHTextButton: View {
    let title: String
    let role: ButtonRole?
    let action: () -> Void

    public init(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.action = action
    }

    public var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(PHFont.bodyMD.weight(.semibold))
                .foregroundStyle(role == .destructive ? PHColor.error : PHColor.primary)
        }
    }
}

/// Botón de solo ícono — SIEMPRE requiere `accessibilityLabel` explícito porque no hay texto visible.
public struct PHIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let action: () -> Void

    public init(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PHColor.ink)
                .frame(width: 40, height: 40)
                .background(PHColor.surfaceSoft)
                .clipShape(Circle())
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    VStack(spacing: 16) {
        PHPrimaryButton("Reservar ahora", systemImage: "checkmark.circle.fill") {}
        PHPrimaryButton("Cargando…", isLoading: true) {}
        PHSecondaryButton("Ver en el mapa", systemImage: "map") {}
        PHTextButton("Cancelar reserva", role: .destructive) {}
        PHIconButton(systemImage: "heart", accessibilityLabel: "Agregar a favoritos") {}
    }
    .padding()
}
