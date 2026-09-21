//
//  FavoritosView.swift
//  Features/Favoritos
//

import SwiftUI

struct FavoritosView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = FavoritosViewModel()
    @State private var hospedajeSeleccionado: Hospedaje?
    @State private var mostrarMapa = false
    /// Elegir 2-3 favoritos y verlos lado a lado (ver `CompararFavoritosSheet`) — en este
    /// modo tocar una tarjeta selecciona/deselecciona en vez de abrir el detalle.
    @State private var modoComparar = false
    @State private var seleccionados: Set<String> = []
    @State private var mostrarComparar = false

    var body: some View {
        content
            .navigationTitle("Favoritos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { session.volverABuscar = true } label: {
                        PHLogo(height: 28)
                    }
                    .accessibilityLabel("Ir al listado de hospedajes")
                }
                if !viewModel.hospedajes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        PHIconButton(systemImage: "mappin.and.ellipse", accessibilityLabel: "Ver favoritos en el mapa") {
                            mostrarMapa = true
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        PHTextButton(modoComparar ? "Listo" : "Comparar") {
                            modoComparar.toggle()
                            if !modoComparar { seleccionados.removeAll() }
                        }
                    }
                }
            }
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .navigationDestination(item: $hospedajeSeleccionado) { hospedaje in
                HospedajeDetailView(hospedajeId: hospedaje.id)
            }
            .sheet(isPresented: $mostrarMapa) {
                NavigationStack {
                    MapaFavoritosView(hospedajes: viewModel.hospedajes)
                }
            }
            .sheet(isPresented: $mostrarComparar) {
                CompararFavoritosSheet(hospedajes: viewModel.hospedajes.filter { seleccionados.contains($0.id) })
            }
            .safeAreaInset(edge: .bottom) {
                if modoComparar, seleccionados.count >= 2 {
                    PHPrimaryButton("Comparar (\(seleccionados.count))") {
                        mostrarComparar = true
                    }
                    .padding(PHSpacing.s16)
                    .background(.ultraThinMaterial)
                }
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
                        Button {
                            if modoComparar {
                                alternarSeleccion(hospedaje)
                            } else {
                                hospedajeSeleccionado = hospedaje
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                PHHospedajeCard(
                                    hospedaje,
                                    esFavorito: true,
                                    onToggleFavorito: { Task { await viewModel.alternar(hospedaje) } }
                                )
                                if modoComparar {
                                    Image(systemName: seleccionados.contains(hospedaje.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(seleccionados.contains(hospedaje.id) ? PHColor.primary : PHColor.mutedSoft)
                                        .background(Circle().fill(.white))
                                        .padding(PHSpacing.s8)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PHSpacing.s16)
                .padding(.bottom, modoComparar && seleccionados.count >= 2 ? PHSpacing.s64 : 0)
            }
        }
    }

    private func alternarSeleccion(_ hospedaje: Hospedaje) {
        if seleccionados.contains(hospedaje.id) {
            seleccionados.remove(hospedaje.id)
        } else if seleccionados.count < 3 {
            seleccionados.insert(hospedaje.id)
        }
    }
}
