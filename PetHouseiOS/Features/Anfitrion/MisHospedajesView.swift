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

                            Button { hospedajeSeleccionado = hospedaje } label: {
                                PHHospedajeCard(hospedaje)
                                    .opacity(hospedaje.activo == false ? 0.5 : 1)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                ReservasRecibidasView(hospedaje: hospedaje)
                            } label: {
                                Label("Ver reservas recibidas", systemImage: "calendar")
                                    .phText(PHFont.captionSM.weight(.semibold), color: PHColor.primary)
                            }
                            .padding(.horizontal, PHSpacing.s4)

                            NavigationLink {
                                CalendarioHospedajeView(hospedaje: hospedaje)
                            } label: {
                                Label("Ver calendario", systemImage: "calendar.badge.clock")
                                    .phText(PHFont.captionSM.weight(.semibold), color: PHColor.primary)
                            }
                            .padding(.horizontal, PHSpacing.s4)

                            botonPausar(hospedaje)
                        }
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }

    /// Pausar deja de mostrar el hospedaje en Buscar y en el mapa, sin borrarlo ni perder su
    /// historial de reservas y reseñas — para cuando el anfitrión no puede recibir huéspedes
    /// por un tiempo (viaje, remodelación, etc.) pero no quiere publicar de cero después.
    private func botonPausar(_ hospedaje: Hospedaje) -> some View {
        let activo = hospedaje.activo ?? true
        return Button {
            Task { await viewModel.alternarActivo(hospedaje) }
        } label: {
            HStack(spacing: PHSpacing.s4) {
                if viewModel.alternandoId == hospedaje.id {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: activo ? "pause.circle" : "play.circle")
                }
                Text(activo ? "Pausar hospedaje" : "Reactivar hospedaje")
            }
            .phText(PHFont.captionSM.weight(.semibold), color: activo ? PHColor.muted : PHColor.success)
        }
        .disabled(viewModel.alternandoId != nil)
        .padding(.horizontal, PHSpacing.s4)
    }
}
