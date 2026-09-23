//
//  VerificarIdentidadView.swift
//  Features/Auth
//

import SwiftUI
import PhotosUI
import UIKit

struct VerificarIdentidadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: VerificarIdentidadViewModel

    init(email: String) {
        _viewModel = State(initialValue: VerificarIdentidadViewModel(email: email))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s20) {
                    if viewModel.enviado {
                        listo
                    } else {
                        formulario(viewModel)
                    }
                }
                .padding(PHSpacing.s24)
            }
            .background(PHColor.canvas)
            .navigationTitle("Verificar identidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
    }

    // `viewModel` como parámetro explícito, no capturado de `self` — mismo motivo que
    // EditarPerfilViewModel.formulario(_:): dentro de una closure anidada dos veces (get/set
    // del Binding manual), Swift infiere mal el tipo si `viewModel` viene de una propiedad
    // `@State` de `self` en vez de un parámetro plano, y termina confundiendo el Binding
    // manual con el subscript dynamicMember que SwiftUI sintetiza para `@Bindable`.
    private func formulario(_ viewModel: VerificarIdentidadViewModel) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s20) {
            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                Text("Sube una foto de tu cédula")
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text("Si no te llegó el código a \(viewModel.email), nuestro equipo puede verificar que eres tú comparando esta foto con los datos de tu cuenta. Te contactaremos con un PIN para que puedas cambiar tu contraseña.")
                    .phText(PHFont.bodyMD, color: PHColor.muted)
            }

            VStack(spacing: PHSpacing.s8) {
                if let datos = viewModel.fotoPreview, let uiImage = UIImage(data: datos) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous)
                        .fill(PHColor.surfaceSoft)
                        .frame(height: 160)
                        .overlay {
                            VStack(spacing: PHSpacing.s4) {
                                Image(systemName: "person.text.rectangle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(PHColor.muted)
                                Text("Que se vea completa y clara")
                                    .phText(PHFont.captionSM, color: PHColor.muted)
                            }
                        }
                }

                PhotosPicker(
                    selection: Binding(get: { viewModel.fotoSeleccionada }, set: { viewModel.fotoSeleccionada = $0 }),
                    matching: .images
                ) {
                    Text(viewModel.fotoPreview == nil ? "Elegir foto" : "Cambiar foto")
                        .phText(PHFont.bodySM.weight(.semibold), color: PHColor.primary)
                }
            }
            .frame(maxWidth: .infinity)

            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .phText(PHFont.bodySM, color: PHColor.error)
            }

            PHPrimaryButton("Enviar solicitud", isLoading: viewModel.isLoading) {
                Task { await viewModel.enviar() }
            }
            .disabled(!viewModel.puedeEnviar)
        }
    }

    private var listo: some View {
        VStack(alignment: .leading, spacing: PHSpacing.s20) {
            VStack(alignment: .leading, spacing: PHSpacing.s8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(PHColor.success)
                Text("Solicitud enviada")
                    .phText(PHFont.displaySM, color: PHColor.ink)
                Text("Nuestro equipo va a revisar tu foto y te va a contactar con un PIN. Cuando lo tengas, vuelve a la pantalla anterior y escríbelo donde dice \"Código de 6 dígitos\".")
                    .phText(PHFont.bodyMD, color: PHColor.muted)
            }

            PHPrimaryButton("Entendido") {
                dismiss()
            }
        }
        .frame(maxWidth: .infinity)
    }
}
