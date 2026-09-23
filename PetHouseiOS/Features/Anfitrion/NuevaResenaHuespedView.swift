//
//  NuevaResenaHuespedView.swift
//  Features/Anfitrion
//
//  Espejo de `Features/Resenas/NuevaResenaView` — mismo formulario (estrellas + título +
//  comentario), pero acá el anfitrión califica al huésped de una reserva ya completada.
//

import SwiftUI

struct NuevaResenaHuespedView: View {
    @State private var viewModel: NuevaResenaHuespedViewModel
    @Environment(\.dismiss) private var dismiss

    init(reserva: Reserva) {
        _viewModel = State(initialValue: NuevaResenaHuespedViewModel(reserva: reserva))
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.enviado {
                    enviadoView
                } else {
                    formulario
                }
            }
            .navigationTitle("Calificar huésped")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var formulario: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s20) {
                Text(viewModel.reserva.usuarioNombre ?? "Huésped")
                    .phText(PHFont.titleMD, color: PHColor.ink)

                VStack(spacing: PHSpacing.s8) {
                    Text("¿Cómo calificarías a este huésped?")
                        .phText(PHFont.bodyMD, color: PHColor.body)
                    PHStarRatingInput(rating: $viewModel.rating)
                }
                .frame(maxWidth: .infinity)

                PHTextField(label: "Título (opcional)", placeholder: "Ej. Muy puntual y cuidadoso", text: $viewModel.titulo)

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

                PHPrimaryButton("Enviar calificación", isLoading: viewModel.isLoading) {
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
            Text("¡Gracias por tu calificación!")
                .phText(PHFont.displaySM, color: PHColor.ink)
            PHPrimaryButton("Listo") { dismiss() }
                .padding(.horizontal, PHSpacing.s32)
        }
        .padding(.top, PHSpacing.s32)
        .frame(maxWidth: .infinity)
    }
}
