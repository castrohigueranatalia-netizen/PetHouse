//
//  MisHospedajesView.swift
//  Features/Anfitrion
//

import SwiftUI

/// UN SOLO `.navigationDestination` para los dos destinos posibles desde esta pantalla —
/// ver `destino` abajo. Dos `.navigationDestination` distintos en la misma vista es un bug ya
/// visto varias veces en esta versión de SwiftUI (LoginView/NotificacionesView/
/// MisReservasView): solo el primero dispara de forma confiable.
private enum DestinoMisHospedajes: Hashable {
    case hospedaje(Hospedaje)
    case dashboard
}

struct MisHospedajesView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = MisHospedajesViewModel()
    @State private var mostrarPublicar = false
    @State private var mostrarDashboard = false
    @State private var hospedajeSeleccionado: Hospedaje?

    private var destino: Binding<DestinoMisHospedajes?> {
        Binding(
            get: {
                if let hospedajeSeleccionado { return .hospedaje(hospedajeSeleccionado) }
                if mostrarDashboard { return .dashboard }
                return nil
            },
            set: { nuevo in
                switch nuevo {
                case .none:
                    hospedajeSeleccionado = nil
                    mostrarDashboard = false
                case .hospedaje(let hospedaje):
                    hospedajeSeleccionado = hospedaje
                case .dashboard:
                    mostrarDashboard = true
                }
            }
        )
    }

    var body: some View {
        content
            .navigationTitle("Mis hospedajes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { session.volverABuscar = true } label: {
                        PHLogo(height: 28)
                    }
                    .accessibilityLabel("Ir al listado de hospedajes")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PHIconButton(systemImage: "chart.bar.fill", accessibilityLabel: "Tu panel — mascotas hospedadas, ganancias y recomendaciones") {
                        mostrarDashboard = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PHIconButton(systemImage: "plus", accessibilityLabel: "Publicar hospedaje") {
                        mostrarPublicar = true
                    }
                }
            }
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .sheet(isPresented: $mostrarPublicar) {
                PublicarHospedajeView { guardado in
                    viewModel.guardarLocal(guardado)
                }
            }
            .navigationDestination(item: destino) { destino in
                switch destino {
                case .hospedaje(let hospedaje):
                    HospedajeDetailView(hospedajeId: hospedaje.id, esPropio: true) { editado in
                        viewModel.guardarLocal(editado)
                    }
                case .dashboard:
                    AnfitrionDashboardView()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.hospedajes.isEmpty {
            PHLoadingStateView(mensaje: "Cargando tus hospedajes…")
        } else if let error = viewModel.error, viewModel.hospedajes.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.hospedajes.isEmpty {
            PHEmptyStateView(
                systemImage: "building.2",
                titulo: "Aún no has publicado hospedajes",
                mensaje: "Publica tu primer hospedaje para empezar a recibir huéspedes.",
                accionTitulo: "Publicar hospedaje"
            ) {
                mostrarPublicar = true
            }
        } else {
            ScrollView {
                LazyVStack(spacing: PHSpacing.s16) {
                    ForEach(viewModel.hospedajes) { hospedaje in
                        VStack(alignment: .leading, spacing: PHSpacing.s8) {
                            // Tocar la tarjeta lleva al detalle — como es un hospedaje
                            // propio, ahí mismo (en vez de "Reservar") están las acciones de
                            // manejo: ver reservas recibidas, ver calendario, pausar/
                            // reactivar y editar (ver HospedajeDetailView.barraAnfitrion
                            // y el botón de editar en su toolbar). Si está pausado, la
                            // propia tarjeta ya se ve en gris con su badge (ver
                            // PHHospedajeCard).
                            Button { hospedajeSeleccionado = hospedaje } label: {
                                PHHospedajeCard(hospedaje)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }
}
