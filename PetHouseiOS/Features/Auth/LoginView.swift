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
                        VStack(alignment: .leading, spacing: PHSpacing.s4) {
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

                            // Desplegable de correos guardados por "Recuérdame" — solo
                            // mientras el campo de correo tiene el foco, para no tapar el
                            // resto del formulario el resto del tiempo. Elegir uno rellena
                            // también la contraseña de una (ver `seleccionarCuenta`), así
                            // cambiar de cuenta no obliga a volver a escribirla.
                            if campoActivo == .email, !viewModel.cuentasRecordadas.isEmpty {
                                cuentasGuardadas(viewModel)
                            }
                        }

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

                        Toggle(
                            "Recuérdame",
                            isOn: Binding(get: { viewModel.recuerdame }, set: { viewModel.recuerdame = $0 })
                        )
                        .toggleStyle(.switch)
                        .tint(PHColor.primary)
                        .phText(PHFont.bodySM, color: PHColor.ink)

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

    private func cuentasGuardadas(_ viewModel: LoginViewModel) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(viewModel.cuentasRecordadas) { cuenta in
                if cuenta.id != viewModel.cuentasRecordadas.first?.id {
                    Divider()
                }
                Button {
                    viewModel.seleccionarCuenta(cuenta)
                    campoActivo = .password
                } label: {
                    HStack(spacing: PHSpacing.s8) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(PHColor.muted)
                        Text(cuenta.email)
                            .phText(PHFont.bodySM, color: PHColor.ink)
                        Spacer()
                    }
                    .padding(PHSpacing.s12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            PHLogo(height: 56)
                .frame(maxWidth: .infinity, alignment: .leading)
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
