//
//  EvaluacionHuespedView.swift
//  Features/Anfitrion
//
//  Evaluación completa de un huésped (estrellas + comentarios de otros anfitriones que ya
//  lo alojaron) — espejo de la sección "Reseñas" de HospedajeDetailView, pero para
//  personas en vez de hospedajes. El anfitrión la abre desde ReservasRecibidasView al
//  revisar una solicitud, ANTES de aceptar o rechazar (ver db/15-resenas-huesped.sql).
//

import SwiftUI

@MainActor
@Observable
final class EvaluacionHuespedViewModel {
    private(set) var resenas: [Resena] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    private let service: UsuariosServicing
    init(service: UsuariosServicing = UsuariosService()) {
        self.service = service
    }

    func cargar(usuarioId: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            resenas = try await service.resenas(usuarioId: usuarioId)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}

struct EvaluacionHuespedView: View {
    let usuarioId: String
    let usuarioNombre: String
    let rating: Double
    let numResenas: Int
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = EvaluacionHuespedViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PHSpacing.s16) {
                    VStack(alignment: .leading, spacing: PHSpacing.s4) {
                        Text(usuarioNombre)
                            .phText(PHFont.displaySM, color: PHColor.ink)
                        PHStarRatingDisplay(rating: rating, numResenas: numResenas)
                    }

                    contenido
                }
                .padding(PHSpacing.s16)
            }
            .background(PHColor.canvas)
            .navigationTitle("Evaluación del huésped")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cerrar") { dismiss() }
                }
            }
        }
        .task { await viewModel.cargar(usuarioId: usuarioId) }
    }

    @ViewBuilder
    private var contenido: some View {
        if viewModel.isLoading && viewModel.resenas.isEmpty {
            PHLoadingStateView(mensaje: "Cargando evaluación…")
        } else if let error = viewModel.error {
            PHErrorStateView(error: error) { Task { await viewModel.cargar(usuarioId: usuarioId) } }
        } else if viewModel.resenas.isEmpty {
            Text("Todavía no hay comentarios de otros anfitriones sobre \(usuarioNombre).")
                .phText(PHFont.bodySM, color: PHColor.muted)
        } else {
            VStack(alignment: .leading, spacing: PHSpacing.s12) {
                ForEach(viewModel.resenas, id: \.identity) { resena in
                    resenaFila(resena)
                }
            }
        }
    }

    private func resenaFila(_ resena: Resena) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(resena.autor ?? "Anfitrión de PetHouse")
                    .phText(PHFont.bodySM.weight(.semibold), color: PHColor.ink)
                Spacer()
                PHStarRatingDisplay(rating: Double(resena.rating))
            }
            if let titulo = resena.titulo, !titulo.isEmpty {
                Text(titulo).phText(PHFont.bodySM.weight(.semibold), color: PHColor.body)
            }
            if let texto = resena.texto, !texto.isEmpty {
                Text(texto).phText(PHFont.bodySM, color: PHColor.muted)
            }
        }
        .padding(PHSpacing.s12)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }
}
