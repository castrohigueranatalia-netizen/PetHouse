//
//  DocumentoLegalView.swift
//  Features/Legal
//
//  Muestra la política de privacidad o los términos de uso — contenido editado por un
//  administrador desde el panel web (ver admin-web/), esta pantalla solo lo lee y lo
//  presenta como texto plano (respeta saltos de línea; sin renderizar Markdown de bloque
//  como encabezados "#" — si más adelante hace falta, ahí sí vale la pena una librería).
//

import SwiftUI

struct DocumentoLegalView: View {
    let tipo: TipoDocumentoLegal
    @State private var viewModel: DocumentoLegalViewModel

    init(tipo: TipoDocumentoLegal) {
        self.tipo = tipo
        _viewModel = State(initialValue: DocumentoLegalViewModel(tipo: tipo))
    }

    private var titulo: String {
        tipo == .privacidad ? "Política de privacidad" : "Términos de uso"
    }

    var body: some View {
        content
            .background(PHColor.canvas)
            .navigationTitle(titulo)
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.cargar() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.contenido == nil {
            PHLoadingStateView(mensaje: "Cargando…")
        } else if let error = viewModel.error, viewModel.contenido == nil {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if let contenido = viewModel.contenido, !contenido.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScrollView {
                Text(contenido)
                    .phText(PHFont.bodyMD, color: PHColor.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(PHSpacing.s16)
            }
        } else {
            PHEmptyStateView(
                systemImage: "doc.text",
                titulo: "Todavía no está publicado",
                mensaje: "Este documento no se ha configurado. Vuelve a intentarlo más tarde."
            )
        }
    }
}
