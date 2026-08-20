//
//  OlvidePasswordView.swift
//  Features/Auth
//

import SwiftUI

struct OlvidePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = OlvidePasswordViewModel()
    @State private var mostrarVerificarIdentidad = false
    @FocusState private var campoActivo: Campo?

    private enum Campo { case email, codigo, passwordNueva, passwordConfirmar }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s24) {
                switch viewModel.paso {
                case .correo: pasoCorreo
                case .codigo: pasoCodigo
                case .listo: pasoListo
                }
            }
            .padding(PHSpacing.s24)
        }
        .background(PHColor.canvas)
        .navigationTitle("Recuperar contraseña")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Paso 1: pedir el código

    private var pasoCorreo: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s20) {
            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                Text("¿Olvidaste tu contraseña?")
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text("Escribe el correo de tu cuenta — te mandamos un código de 6 dígitos para crear una contraseña nueva.")
                    .phText(PHFont.bodyMD, color: PHColor.muted)
            }

            PHTextField(
                label: "Correo",
                placeholder: "tú@correo.com",
                text: Binding(get: { viewModel.email }, set: { viewModel.email = $0 }),
                errorMessage: viewModel.email.isEmpty ? nil : viewModel.errorEmail,
                keyboardType: .emailAddress,
                textContentType: .username,
                autocapitalization: .never
            )
            .focused($campoActivo, equals: .email)
            .submitLabel(.go)
            .onSubmit { enviarCorreo() }

            if let errorGeneral = viewModel.errorGeneral {
                Text(errorGeneral)
                    .phText(PHFont.bodySM, color: PHColor.error)
                    .accessibilityLabel("Error: \(errorGeneral)")
            }

            PHPrimaryButton("Enviar código", isLoading: viewModel.isLoading) {
                enviarCorreo()
            }
            .disabled(!viewModel.puedeEnviarCorreo)
        }
    }

    private func enviarCorreo() {
        campoActivo = nil
        Task { await viewModel.pedirCodigo() }
    }

    // MARK: - Paso 2: código + contraseña nueva

    private var pasoCodigo: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s20) {
            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                Text("Revisa tu correo")
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text("Te mandamos un código de 6 dígitos a \(viewModel.email). Vence en 15 minutos.")
                    .phText(PHFont.bodyMD, color: PHColor.muted)
            }

            PHTextField(
                label: "Código de 6 dígitos",
                placeholder: "000000",
                text: Binding(
                    get: { viewModel.codigo },
                    set: { viewModel.codigo = String($0.filter(\.isNumber).prefix(6)) }
                ),
                keyboardType: .numberPad
            )
            .focused($campoActivo, equals: .codigo)

            PHTextField(
                label: "Contraseña nueva",
                placeholder: "••••••",
                text: Binding(get: { viewModel.passwordNueva }, set: { viewModel.passwordNueva = $0 }),
                textContentType: .newPassword,
                isSecure: true
            )
            .focused($campoActivo, equals: .passwordNueva)
            .submitLabel(.next)
            .onSubmit { campoActivo = .passwordConfirmar }

            PHTextField(
                label: "Confirma la contraseña nueva",
                placeholder: "••••••",
                text: Binding(get: { viewModel.passwordConfirmar }, set: { viewModel.passwordConfirmar = $0 }),
                textContentType: .newPassword,
                isSecure: true
            )
            .focused($campoActivo, equals: .passwordConfirmar)
            .submitLabel(.go)
            .onSubmit { restablecer() }

            if let errorGeneral = viewModel.errorGeneral {
                Text(errorGeneral)
                    .phText(PHFont.bodySM, color: PHColor.error)
                    .accessibilityLabel("Error: \(errorGeneral)")
            }

            PHPrimaryButton("Restablecer contraseña", isLoading: viewModel.isLoading) {
                restablecer()
            }
            .disabled(!viewModel.puedeRestablecer)

            PHTextButton("¿No te llegó el código? Verifica tu identidad con tu cédula") {
                campoActivo = nil
                mostrarVerificarIdentidad = true
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)

            PHTextButton("Usar otro correo") {
                campoActivo = nil
                viewModel.volverAlCorreo()
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .sheet(isPresented: $mostrarVerificarIdentidad) {
            VerificarIdentidadView(email: viewModel.email)
        }
    }

    private func restablecer() {
        campoActivo = nil
        Task { await viewModel.restablecer() }
    }

    // MARK: - Paso 3: listo

    private var pasoListo: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s20) {
            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(PHColor.success)
                Text("¡Listo!")
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text("Tu contraseña quedó actualizada. Ya puedes iniciar sesión con la nueva.")
                    .phText(PHFont.bodyMD, color: PHColor.muted)
            }

            PHPrimaryButton("Volver a iniciar sesión") {
                dismiss()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
