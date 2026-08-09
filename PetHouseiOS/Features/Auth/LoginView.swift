//
//  LoginView.swift
//  Features/Auth
//

import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel: LoginViewModel?
    @State private var mostrarRegistro = false
    @FocusState private var campoActivo: Campo?

    private enum Campo { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s24) {
                encabezado

                if let viewModel {
                    VStack(spacing: PHSpacing.s16) {
                        PHTextField(
                            label: "Correo",
                            placeholder: "tú@correo.com",
                            text: Binding(get: { viewModel.email }, set: { viewModel.email = $0 }),
                            errorMessage: viewModel.errorEmailMostrable,
                            keyboardType: .emailAddress,
                            textContentType: .username,
                            autocapitalization: .never
                        )
                        .focused($campoActivo, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { campoActivo = .password }

                        PHTextField(
                            label: "Contraseña",
                            placeholder: "••••••",
                            text: Binding(get: { viewModel.password }, set: { viewModel.password = $0 }),
                            errorMessage: viewModel.errorPasswordMostrable,
                            textContentType: .password,
                            isSecure: true
                        )
                        .focused($campoActivo, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { enviar(viewModel) }

                        if let errorGeneral = viewModel.errorGeneral {
                            Text(errorGeneral)
                                .phText(PHFont.bodySM, color: PHColor.error)
                                .accessibilityLabel("Error: \(errorGeneral)")
                        }

                        PHPrimaryButton("Iniciar sesión", isLoading: viewModel.isLoading) {
                            enviar(viewModel)
                        }
                        .disabled(!viewModel.puedeEnviar)
                    }

                    HStack {
                        Text("¿No tienes cuenta?")
                            .phText(PHFont.bodySM, color: PHColor.muted)
                        PHTextButton("Regístrate") { mostrarRegistro = true }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, PHSpacing.s8)
                }
            }
            .padding(PHSpacing.s24)
        }
        .background(PHColor.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $mostrarRegistro) {
            RegistroView()
        }
        .onAppear {
            if viewModel == nil { viewModel = LoginViewModel(session: session) }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text("🐾")
                .font(.system(size: 40))
                .accessibilityHidden(true)
            Text("Bienvenido a PetHouse")
                .phText(PHFont.displayMD, color: PHColor.ink)
            Text("Encuentra el mejor hospedaje para tu mascota.")
                .phText(PHFont.bodyMD, color: PHColor.muted)
        }
        .padding(.top, PHSpacing.s32)
    }

    private func enviar(_ viewModel: LoginViewModel) {
        campoActivo = nil
        Task { await viewModel.iniciarSesion() }
    }
}

private extension LoginViewModel {
    /// Solo se muestra el error de un campo si el usuario ya escribió algo en él —
    /// evita mostrar errores antes de que el usuario intente enviar el formulario.
    var errorEmailMostrable: String? { email.isEmpty ? nil : errorEmail }
    var errorPasswordMostrable: String? { password.isEmpty ? nil : errorPassword }
}
