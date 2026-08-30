//
//  MisHospedajesView.swift
//  Features/Anfitrion
//

import SwiftUI

struct MisHospedajesView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = MisHospedajesViewModel()
    @State private var mostrarPublicar = false
    @State private var hospedajeParaEditar: Hospedaje?
    @State private var hospedajeSeleccionado: Hospedaje?

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
            .sheet(item: $hospedajeParaEditar) { hospedaje in
                PublicarHospedajeView(hospedajeExistente: hospedaje) { guardado in
                    viewModel.guardarLocal(guardado)
                }
            }
            .navigationDestination(item: $hospedajeSeleccionado) { hospedaje in
                HospedajeDetailView(hospedajeId: hospedaje.id)
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
                            // El botón de editar va ARRIBA de la imagen, a la derecha — un
                            // ícono de 40pt, mucho más fácil de ver y de tocar que el texto
                            // chico que tenía antes debajo de la tarjeta.
                            HStack {
                                if hospedaje.activo == false {
                                    PHBadge("Pausado", style: .warning)
                                }
                                Spacer()
                                PHIconButton(systemImage: "pencil", accessibilityLabel: "Editar \(hospedaje.titulo)") {
                                    hospedajeParaEditar = hospedaje
                                }
                            }

                            // Tocar la tarjeta lleva al detalle — como es un hospedaje
                            // propio, ahí mismo (en vez de "Reservar") están las acciones de
                            // manejo: ver reservas recibidas, ver calendario y pausar/
                            // reactivar (ver HospedajeDetailView.barraAnfitrion).
                            Button { hospedajeSeleccionado = hospedaje } label: {
                                PHHospedajeCard(hospedaje)
                                    .opacity(hospedaje.activo == false ? 0.5 : 1)
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
