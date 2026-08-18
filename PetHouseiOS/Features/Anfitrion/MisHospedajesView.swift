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
                    botonHistorial

                    ForEach(viewModel.hospedajes) { hospedaje in
                        VStack(alignment: .leading, spacing: PHSpacing.s8) {
                            // El botón de editar va ARRIBA de la imagen, a la derecha — un
                            // ícono de 40pt, mucho más fácil de ver y de tocar que el texto
                            // chico que tenía antes debajo de la tarjeta.
                            HStack {
                                Spacer()
                                PHIconButton(systemImage: "pencil", accessibilityLabel: "Editar \(hospedaje.titulo)") {
                                    hospedajeParaEditar = hospedaje
                                }
                            }

                            Button { hospedajeSeleccionado = hospedaje } label: {
                                PHHospedajeCard(hospedaje)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                ReservasRecibidasView(hospedaje: hospedaje)
                            } label: {
                                Label("Ver reservas recibidas", systemImage: "calendar")
                                    .phText(PHFont.captionSM.weight(.semibold), color: PHColor.primary)
                            }
                            .padding(.horizontal, PHSpacing.s4)
                        }
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }

    /// Botón mediano al principio de la lista — lleva al historial de TODAS las reservas de
    /// TODOS los hospedajes (ver HistorialReservasView), a diferencia de "Ver reservas
    /// recibidas" de cada tarjeta, que es solo de ese hospedaje y solo pensada para
    /// aceptar/rechazar solicitudes pendientes.
    private var botonHistorial: some View {
        NavigationLink {
            HistorialReservasView()
        } label: {
            Label("Historial de reservas", systemImage: "clock.arrow.circlepath")
                .frame(maxWidth: .infinity)
                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.primary)
                .padding(.vertical, PHSpacing.s12)
                .background(PHColor.primaryContainer)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
