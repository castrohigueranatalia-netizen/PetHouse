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
                PHLogo(height: 40)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, PHSpacing.s16)

                Text("Crea tu cuenta")
                    .phText(PHFont.displayMD, color: PHColor.ink)

                if let viewModel {
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

                    PHTextField(
                        label: "Nombre de tu mascota (opcional)",
                        placeholder: "Ej. Firulais",
                        text: Binding(get: { viewModel.mascotaNombre }, set: { viewModel.mascotaNombre = $0 })
                    )
                    Text("Podrás agregar la especie, raza y más mascotas después desde tu perfil.")
                        .phText(PHFont.micro, color: PHColor.mutedSoft)

                    // Aditivo, no exclusivo: marcarlo no le quita a la cuenta la
                    // posibilidad de reservar — ambas cosas conviven en el mismo perfil.
                    // No activa nada directo: crea la cuenta y de una vez lleva a la
                    // verificación de seguridad obligatoria (ver RegistroViewModel /
                    // SessionStore.abrirVerificacionAlEntrar). Quien no lo marque aquí
                    // puede hacer lo mismo después desde Perfil.
                    Toggle(isOn: Binding(get: { viewModel.quiereOfrecerHospedaje }, set: { viewModel.quiereOfrecerHospedaje = $0 })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("También quiero ofrecer hospedaje")
                                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                            Text("Después de crear tu cuenta te pedimos algunos datos de verificación. Se puede activar después desde tu perfil si prefieres.")
                                .phText(PHFont.captionSM, color: PHColor.muted)
                        }
                    }
                    .tint(PHColor.primary)
                    .padding(PHSpacing.s12)
                    .background(PHColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))

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
