//
//  BuscarView.swift
//  Features/Search
//

import SwiftUI

struct BuscarView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = BuscarViewModel()
    @State private var favoritosViewModel = FavoritosViewModel()
    @State private var mostrarBuscador = false
    @State private var mostrarFiltros = false
    @State private var mostrarMapa = false
    @State private var mostrarNotificaciones = false
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
                // El logo es el botón de "inicio": ya estando en Buscar, vuelve al listado
                // completo (cierra cualquier hospedaje abierto) — ver el `onChange` abajo.
                Button { session.volverABuscar = true } label: {
                    PHLogo(height: 28)
                }
                .accessibilityLabel("Ir al listado de hospedajes")
            }
            ToolbarItem(placement: .topBarTrailing) {
                PHIconButton(systemImage: "map", accessibilityLabel: "Ver en el mapa") {
                    mostrarMapa = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                PHCampanaNotificaciones(noLeidas: session.notificacionesNoLeidas) {
                    mostrarNotificaciones = true
                }
            }
        }
        // `.fullScreenCover`, no `.sheet` — esta vista ya encadena tres `.sheet(isPresented:)`
        // distintos (buscador, filtros, mapa); un cuarto ahí mismo cae en el mismo riesgo de
        // presentación poco confiable que ya se vio antes en Perfil. `.fullScreenCover` es un
        // mecanismo de presentación aparte, sin ese conflicto.
        .fullScreenCover(isPresented: $mostrarNotificaciones) {
            NotificacionesView()
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
                MapaView()
            }
        }
        .navigationDestination(item: $hospedajeSeleccionado) { hospedaje in
            HospedajeDetailView(hospedajeId: hospedaje.id)
        }
        .task {
            if viewModel.resultados.isEmpty { await viewModel.buscar() }
        }
        // Consume la señal del botón de inicio (ver AppState.swift): cierra el hospedaje
        // abierto y cualquier hoja modal, para que "volver" muestre de verdad el listado
        // completo y no lo que hubiera quedado abierto en este stack.
        .onChange(of: session.volverABuscar) { _, volver in
            guard volver else { return }
            hospedajeSeleccionado = nil
            mostrarBuscador = false
            mostrarFiltros = false
            mostrarMapa = false
            session.volverABuscar = false
        }
    }

    /// Barra principal: localidad + fechas + convivencia, en un solo control tocable que abre
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
            .accessibilityHint("Abre el buscador de localidad, fechas y convivencia")

            // Solo aparece si hay algo elegido (localidad/fechas/convivencia) — quita esa
            // selección y vuelve a buscar en toda Bogotá sin tener que abrir el buscador.
            if viewModel.hayBusquedaActiva {
                PHIconButton(systemImage: "xmark.circle.fill", accessibilityLabel: "Quitar selección de búsqueda") {
                    viewModel.limpiarFiltros()
                    Task { await viewModel.buscar() }
                }
            }

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
                mensaje: "Prueba con otra localidad, tipo de hospedaje o quita algunos filtros.",
                accionTitulo: "Limpiar filtros"
            ) {
                viewModel.limpiarFiltros()
                Task { await viewModel.buscar() }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: PHSpacing.s16) {
                    ForEach(viewModel.resultados) { hospedaje in
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

                    if viewModel.cargandoMas {
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
