//
//  EditarPerfilView.swift
//  Features/Perfil
//
//  El picker de fotos (`PhotosPicker`) solo pide permiso de fotos cuando el usuario
//  realmente toca "Elegir foto" — nunca antes (ver requisito de seguridad del MVP).
//

import SwiftUI
import PhotosUI
import UIKit

struct EditarPerfilView: View {
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditarPerfilViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    formulario(viewModel)
                }
            }
            .navigationTitle("Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                if viewModel == nil { viewModel = EditarPerfilViewModel(session: session) }
            }
        }
    }

    @ViewBuilder
    private func formulario(_ viewModel: EditarPerfilViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                HStack {
                    Spacer()
                    VStack(spacing: PHSpacing.s8) {
                        if let data = viewModel.fotoPreview, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 96, height: 96)
                                .clipShape(Circle())
                        } else {
                            PHAvatar(name: viewModel.nombre, size: 96)
                        }
                        PhotosPicker(selection: Binding(get: { viewModel.fotoSeleccionada }, set: { viewModel.fotoSeleccionada = $0 }), matching: .images) {
                            Text("Elegir foto").phText(PHFont.bodySM.weight(.semibold), color: PHColor.primary)
                        }
                    }
                    Spacer()
                }

                PHTextField(
                    label: "Nombre completo",
                    placeholder: "Tu nombre",
                    text: Binding(get: { viewModel.nombre }, set: { viewModel.nombre = $0 }),
                    errorMessage: viewModel.errorNombre
                )

                PHTextField(
                    label: "Teléfono",
                    placeholder: "300 123 4567",
                    text: Binding(get: { viewModel.telefono }, set: { viewModel.telefono = $0 }),
                    keyboardType: .phonePad
                )

                switch viewModel.resultado {
                case .pendienteBackend:
                    PHEmptyStateView(
                        systemImage: "hourglass",
                        titulo: "Función pendiente",
                        mensaje: "Editar el perfil todavía no está disponible en el servidor. Tus cambios no se guardaron."
                    )
                case .error(let mensaje):
                    Text(mensaje).phText(PHFont.bodySM, color: PHColor.error)
                case .exito:
                    Text("Perfil actualizado.").phText(PHFont.bodySM, color: PHColor.success)
                case .ninguno:
                    EmptyView()
                }

                PHPrimaryButton("Guardar cambios", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.guardar()
                        if viewModel.resultado == .exito { dismiss() }
                    }
                }
            }
            .padding(PHSpacing.s16)
        }
    }
}
