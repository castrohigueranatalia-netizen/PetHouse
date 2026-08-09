//
//  RegistroView.swift
//  Features/Auth
//

import SwiftUI

struct RegistroView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: RegistroViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                Text("Crea tu cuenta")
                    .phText(PHFont.displayMD, color: PHColor.ink)
                    .padding(.top, PHSpacing.s16)

                if let viewModel {
                    Picker("Tipo de cuenta", selection: Binding(get: { viewModel.rol }, set: { viewModel.rol = $0 })) {
                        Text("Dueño de mascota").tag(Usuario.Rol.cliente)
                        Text("Anfitrión").tag(Usuario.Rol.anfitrion)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Tipo de cuenta")

                    PHTextField(
                        label: "Nombre completo",
                        placeholder: "Tu nombre",
                        text: Binding(get: { viewModel.nombre }, set: { viewModel.nombre = $0 }),
                        errorMessage: viewModel.nombre.isEmpty ? nil : viewModel.errorNombre,
                        textContentType: .name
                    )

                    PHTextField(
                        label: "Correo",
                        placeholder: "tú@correo.com",
                        text: Binding(get: { viewModel.email }, set: { viewModel.email = $0 }),
                        errorMessage: viewModel.email.isEmpty ? nil : viewModel.errorEmail,
                        keyboardType: .emailAddress,
                        textContentType: .username,
                        autocapitalization: .never
                    )

                    PHTextField(
                        label: "Contraseña",
                        placeholder: "Mínimo 6 caracteres",
                        text: Binding(get: { viewModel.password }, set: { viewModel.password = $0 }),
                        errorMessage: viewModel.password.isEmpty ? nil : viewModel.errorPassword,
                        textContentType: .newPassword,
                        isSecure: true
                    )

                    PHTextField(
                        label: "Teléfono (opcional)",
                        placeholder: "300 123 4567",
                        text: Binding(get: { viewModel.telefono }, set: { viewModel.telefono = $0 }),
                        keyboardType: .phonePad
                    )

                    if viewModel.rol == .cliente {
                        PHTextField(
                            label: "Nombre de tu mascota (opcional)",
                            placeholder: "Ej. Firulais",
                            text: Binding(get: { viewModel.mascotaNombre }, set: { viewModel.mascotaNombre = $0 })
                        )
                        Text("Podrás agregar la especie, raza y más mascotas después desde tu perfil.")
                            .phText(PHFont.micro, color: PHColor.mutedSoft)
                    }

                    if let errorGeneral = viewModel.errorGeneral {
                        Text(errorGeneral)
                            .phText(PHFont.bodySM, color: PHColor.error)
                    }

                    PHPrimaryButton("Crear cuenta", isLoading: viewModel.isLoading) {
                        Task {
                            if await viewModel.registrar() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.puedeEnviar)
                    .padding(.top, PHSpacing.s8)
                }
            }
            .padding(PHSpacing.s24)
        }
        .background(PHColor.canvas)
        .navigationTitle("Registro")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if viewModel == nil { viewModel = RegistroViewModel(session: session) }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}
