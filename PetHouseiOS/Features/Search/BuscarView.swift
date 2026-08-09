//
//  BuscarView.swift
//  Features/Search
//

import SwiftUI

struct BuscarView: View {
    @State private var viewModel = BuscarViewModel()
    @State private var favoritosViewModel = FavoritosViewModel()
    @State private var mostrarFiltros = false
    @State private var mostrarMapa = false
    @State private var hospedajeSeleccionado: Hospedaje?

    var body: some View {
        VStack(spacing: 0) {
            barraBusqueda

            content
        }
        .background(PHColor.canvas)
        .navigationTitle("Buscar")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PHIconButton(systemImage: "map", accessibilityLabel: "Ver en el mapa") {
                    mostrarMapa = true
                }
            }
        }
        .sheet(isPresented: $mostrarFiltros) {
            FiltrosView(viewModel: viewModel) {
                Task { await viewModel.buscar() }
            }
        }
        .sheet(isPresented: $mostrarMapa) {
            NavigationStack {
                MapaView(hospedajes: viewModel.resultados)
            }
        }
        .navigationDestination(item: $hospedajeSeleccionado) { hospedaje in
            HospedajeDetailView(hospedajeId: hospedaje.id)
        }
        .task {
            if viewModel.resultados.isEmpty { await viewModel.buscar() }
        }
    }

    private var barraBusqueda: some View {
        HStack(spacing: PHSpacing.s8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PHColor.muted)
                TextField("Ciudad, tipo de hospedaje…", text: $viewModel.textoLibre)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { Task { await viewModel.buscar() } }
                    .accessibilityLabel("Buscar hospedajes")
            }
            .padding(.horizontal, PHSpacing.s12)
            .padding(.vertical, PHSpacing.s8)
            .background(PHColor.surfaceSoft)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.full, style: .continuous))

            PHIconButton(systemImage: "line.3.horizontal.decrease.circle", accessibilityLabel: "Filtros") {
                mostrarFiltros = true
            }
        }
        .padding(.horizontal, PHSpacing.s16)
        .padding(.vertical, PHSpacing.s8)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.resultados.isEmpty {
            PHLoadingStateView(mensaje: "Buscando hospedajes…")
        } else if let error = viewModel.error {
            PHErrorStateView(error: error) {
                Task { await viewModel.buscar() }
            }
        } else if viewModel.resultados.isEmpty {
            PHEmptyStateView(
                systemImage: "magnifyingglass",
                titulo: "Sin resultados",
                mensaje: "Prueba con otra ciudad, tipo de hospedaje o quita algunos filtros.",
                accionTitulo: "Limpiar filtros"
            ) {
                viewModel.limpiarFiltros()
                Task { await viewModel.buscar() }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: PHSpacing.s16) {
                    ForEach(viewModel.resultadosVisibles) { hospedaje in
                        Button {
                            hospedajeSeleccionado = hospedaje
                        } label: {
                            PHHospedajeCard(
                                hospedaje,
                                esFavorito: favoritosViewModel.esFavorito(hospedaje.id),
                                onToggleFavorito: {
                                    Task { await favoritosViewModel.alternar(hospedaje) }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear { viewModel.cargarMasSiHaceFalta(elementoActual: hospedaje) }
                    }

                    if viewModel.hayMasPorMostrar {
                        ProgressView()
                            .padding(.vertical, PHSpacing.s16)
                    }
                }
                .padding(PHSpacing.s16)
            }
            .refreshable { await viewModel.buscar() }
        }
    }
}
