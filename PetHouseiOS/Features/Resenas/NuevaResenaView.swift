//
//  NuevaResenaView.swift
//  Features/Resenas
//

import SwiftUI

struct NuevaResenaView: View {
    @State private var viewModel: NuevaResenaViewModel
    @Environment(\.dismiss) private var dismiss

    init(reservaId: String, hospedajeTitulo: String?) {
        _viewModel = State(initialValue: NuevaResenaViewModel(reservaId: reservaId, hospedajeTituloConocido: hospedajeTitulo))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.enviado {
                    enviadoView
                } else if viewModel.cargandoDetalle {
                    PHLoadingStateView(mensaje: "Preparando tu reseña…")
                } else if let errorDetalle = viewModel.errorDetalle {
                    PHErrorStateView(error: errorDetalle) { Task { await viewModel.cargarDetalle() } }
                } else {
                    formulario
                }
            }
            .navigationTitle("Nueva reseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
        .task { await viewModel.cargarDetalle() }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                Text(viewModel.hospedajeTituloConocido ?? viewModel.reserva?.hospedajeTitulo ?? "Tu hospedaje")
                    .phText(PHFont.titleMD, color: PHColor.ink)

                VStack(spacing: PHSpacing.s8) {
                    Text("¿Cómo calificarías tu experiencia?")
                        .phText(PHFont.bodyMD, color: PHColor.body)
                    PHStarRatingInput(rating: $viewModel.rating)
                }
                .frame(maxWidth: .infinity)

                PHTextField(label: "Título (opcional)", placeholder: "Ej. Excelente cuidado", text: $viewModel.titulo)

                VStack(alignment: .leading, spacing: PHSpacing.s4) {
                    Text("Comentario (opcional)")
                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.muted)
                    TextEditor(text: $viewModel.texto)
                        .frame(minHeight: 120)
                        .padding(PHSpacing.s8)
                        .background(PHColor.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                }

                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }

                PHPrimaryButton("Enviar reseña", isLoading: viewModel.isLoading) {
                    Task { await viewModel.enviar() }
                }
                .disabled(!viewModel.puedeEnviar)
            }
            .padding(PHSpacing.s16)
        }
    }

    private var enviadoView: some View {
        VStack(spacing: PHSpacing.s16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(PHColor.success)
            Text("¡Gracias por tu reseña!")
                .phText(PHFont.displaySM, color: PHColor.ink)
            PHPrimaryButton("Listo") { dismiss() }
                .padding(.horizontal, PHSpacing.s32)
        }
        .padding(.top, PHSpacing.s32)
        .frame(maxWidth: .infinity)
    }
}
