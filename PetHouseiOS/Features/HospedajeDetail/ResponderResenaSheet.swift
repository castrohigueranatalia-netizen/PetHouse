//
//  ResponderResenaSheet.swift
//  Features/HospedajeDetail
//
//  Formulario chico para que el anfitrión responda (o edite su respuesta) a una reseña de
//  su hospedaje — ver ResponderResenaViewModel. Se abre desde HospedajeDetailView.
//

import SwiftUI

struct ResponderResenaSheet: View {
    @State private var viewModel: ResponderResenaViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        hospedajeId: String, resenaId: String, respuestaExistente: String? = nil,
        alGuardar: @escaping (Resena) -> Void
    ) {
        _viewModel = State(initialValue: ResponderResenaViewModel(
            hospedajeId: hospedajeId, resenaId: resenaId, respuestaExistente: respuestaExistente, alGuardar: alGuardar
        ))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: PHSpacing.s16) {
                Text("Tu respuesta es pública — cualquiera que vea esta reseña también va a ver lo que escribas.")
                    .phText(PHFont.captionSM, color: PHColor.muted)

                TextEditor(text: $viewModel.respuesta)
                    .frame(minHeight: 140)
                    .padding(PHSpacing.s8)
                    .background(PHColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))

                if let error = viewModel.error {
                    Text(error.localizedDescription)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }

                PHPrimaryButton("Publicar respuesta", isLoading: viewModel.isLoading) {
                    Task {
                        await viewModel.enviar()
                        if viewModel.enviado { dismiss() }
                    }
                }
                .disabled(!viewModel.puedeEnviar)

                Spacer()
            }
            .padding(PHSpacing.s16)
            .navigationTitle("Responder reseña")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
    }
}
