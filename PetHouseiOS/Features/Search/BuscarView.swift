//
//  BuscarView.swift
//  Features/Search
//

import SwiftUI

struct BuscarView: View {
    @State private var viewModel = BuscarViewModel()
    @State private var favoritosViewModel = FavoritosViewModel()
    @State private var mostrarBuscador = false
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
            ToolbarItem(placement: .topBarLeading) {
                PHLogo(height: 28)
            }
            ToolbarItem(placement: .topBarTrailing) {
                PHIconButton(systemImage: "map", accessibilityLabel: "Ver en el mapa") {
                    mostrarMapa = true
                }
            }
        }
        .sheet(isPresented: $mostrarBuscador) {
            BuscadorSheet(viewModel: viewModel) {
                Task { await viewModel.buscar() }
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

    /// Barra principal: ciudad + fechas + convivencia, en un solo control tocable que abre
    /// `BuscadorSheet` — mismo patrón que el buscador de Airbnb (un resumen colapsado que
    /// se expande a un formulario completo), en vez de 3 campos sueltos compitiendo por
    /// espacio en una sola fila. "Filtros" (tipo, orden, cerca de mí) queda aparte, como
    /// opciones secundarias.
    private var barraBusqueda: some View {
        HStack(spacing: PHSpacing.s8) {
            Button {
                mostrarBuscador = true
            } label: {
                HStack(spacing: PHSpacing.s8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(PHColor.primary)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Buscar hospedaje")
                            .phText(PHFont.captionSM, color: PHColor.muted)
                        Text(viewModel.resumenBusqueda)
                            .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .padding(.horizontal, PHSpacing.s16)
                .padding(.vertical, PHSpacing.s12)
                .background(PHColor.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.full, style: .continuous))
                .phShadow(PHShadow.level1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Buscar hospedaje: \(viewModel.resumenBusqueda)")
            .accessibilityHint("Abre el buscador de ciudad, fechas y convivencia")

            PHIconButton(systemImage: "line.3.horizontal.decrease.circle", accessibilityLabel: "Más filtros") {
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
