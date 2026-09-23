//
//  PHTextField.swift
//  DesignSystem/Components
//
//  Campo de texto reutilizable con label, mensaje de error inline y soporte para
//  contraseñas (SecureField con botón de mostrar/ocultar).
//

import SwiftUI
import UIKit

public struct PHTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var errorMessage: String?
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType?
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .sentences

    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    public init(
        label: String,
        placeholder: String,
        text: Binding<String>,
        errorMessage: String? = nil,
        keyboardType: UIKeyboardType = .default,
        textContentType: UITextContentType? = nil,
        isSecure: Bool = false,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.errorMessage = errorMessage
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.isSecure = isSecure
        self.autocapitalization = autocapitalization
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s4) {
            Text(label)
                .font(PHFont.captionSM.weight(.semibold))
                .foregroundStyle(PHColor.muted)

            HStack {
                Group {
                    if isSecure && !isRevealed {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .focused($isFocused)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(isSecure || keyboardType == .emailAddress)
                .font(PHFont.bodyMD)
                .foregroundStyle(PHColor.ink)
                .accessibilityLabel(label)

                if isSecure {
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Image(systemName: isRevealed ? "eye.slash" : "eye")
                            .foregroundStyle(PHColor.muted)
                    }
                    .accessibilityLabel(isRevealed ? "Ocultar contraseña" : "Mostrar contraseña")
                }
            }
            .padding(.horizontal, PHSpacing.s16)
            .padding(.vertical, PHSpacing.s12)
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: isFocused || errorMessage != nil ? 1.5 : 0)
            )

            if let errorMessage {
                Text(errorMessage)
                    .font(PHFont.micro)
                    .foregroundStyle(PHColor.error)
                    .accessibilityLabel("Error: \(errorMessage)")
            }
        }
    }

    private var borderColor: Color {
        if errorMessage != nil { return PHColor.error }
        if isFocused { return PHColor.primary }
        return .clear
    }
}

#Preview {
    VStack(spacing: 16) {
        PHTextField(label: "Correo", placeholder: "tú@correo.com", text: .constant(""), keyboardType: .emailAddress)
        PHTextField(label: "Contraseña", placeholder: "••••••", text: .constant("123"), errorMessage: "La contraseña debe tener al menos 6 caracteres.", isSecure: true)
    }
    .padding()
}
