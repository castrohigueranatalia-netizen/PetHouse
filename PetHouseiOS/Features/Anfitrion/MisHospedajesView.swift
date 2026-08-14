//
//  MisHospedajesView.swift
//  Features/Anfitrion
//

import SwiftUI

struct MisHospedajesView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = MisHospedajesViewModel()
    @State private var mostrarPublicar = false
    @State private var hospedajeSeleccionado: Hospedaje?
    @State private var hospedajeParaEditar: Hospedaje?

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
                            Button { hospedajeSeleccionado = hospedaje } label: {
                                PHHospedajeCard(hospedaje)
                            }
                            .buttonStyle(.plain)

                            HStack(spacing: PHSpacing.s16) {
                                NavigationLink {
                                    ReservasRecibidasView(hospedaje: hospedaje)
                                } label: {
                                    Label("Ver reservas recibidas", systemImage: "calendar")
                                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.primary)
                                }

                                Button { hospedajeParaEditar = hospedaje } label: {
                                    Label("Editar", systemImage: "pencil")
                                        .phText(PHFont.captionSM.weight(.semibold), color: PHColor.primary)
                                }
                            }
                            .padding(.horizontal, PHSpacing.s4)
                        }
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }
}
