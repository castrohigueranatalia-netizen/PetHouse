//
//  FavoritosView.swift
//  Features/Favoritos
//

import SwiftUI

struct FavoritosView: View {
    @State private var viewModel = FavoritosViewModel()
    @State private var hospedajeSeleccionado: Hospedaje?

    var body: some View {
        content
            .navigationTitle("Favoritos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHLogo(height: 28)
                }
            }
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .navigationDestination(item: $hospedajeSeleccionado) { hospedaje in
                HospedajeDetailView(hospedajeId: hospedaje.id)
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.hospedajes.isEmpty {
            PHLoadingStateView(mensaje: "Cargando favoritos…")
        } else if let error = viewModel.error, viewModel.hospedajes.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.hospedajes.isEmpty {
            PHEmptyStateView(
                systemImage: "heart",
                titulo: "Sin favoritos todavía",
                mensaje: "Toca el corazón en un hospedaje para guardarlo aquí."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: PHSpacing.s16) {
                    ForEach(viewModel.hospedajes) { hospedaje in
                        Button { hospedajeSeleccionado = hospedaje } label: {
                            PHHospedajeCard(
                                hospedaje,
                                esFavorito: true,
                                onToggleFavorito: { Task { await viewModel.alternar(hospedaje) } }
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }
}
