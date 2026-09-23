//
//  SolicitudPrivacidadListView.swift
//  Features/Privacidad
//

import SwiftUI

struct SolicitudPrivacidadListView: View {
    @State private var viewModel = SolicitudPrivacidadListViewModel()
    @State private var mostrarNuevaSolicitud = false

    var body: some View {
        content
            .background(PHColor.canvas)
            .navigationTitle("Privacidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PHIconButton(systemImage: "plus", accessibilityLabel: "Nueva solicitud") {
                        mostrarNuevaSolicitud = true
                    }
                }
            }
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .sheet(isPresented: $mostrarNuevaSolicitud) {
                nuevaSolicitudSheet
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.solicitudes.isEmpty {
            PHLoadingStateView(mensaje: "Cargando…")
        } else if let error = viewModel.error, viewModel.solicitudes.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.solicitudes.isEmpty {
            PHEmptyStateView(
                systemImage: "hand.raised",
                titulo: "Sin solicitudes",
                mensaje: "¿Quieres conocer, corregir o eliminar tus datos? Puedes pedirlo desde acá.",
                accionTitulo: "Nueva solicitud"
            ) {
                mostrarNuevaSolicitud = true
            }
        } else {
            List(viewModel.solicitudes) { solicitud in
                NavigationLink(value: solicitud) {
                    filaSolicitud(solicitud)
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: SolicitudPrivacidad.self) { solicitud in
                SolicitudPrivacidadDetalleView(solicitud: solicitud)
            }
        }
    }

    private func filaSolicitud(_ solicitud: SolicitudPrivacidad) -> some View {
        HStack(spacing: PHSpacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(solicitud.categoria.etiqueta)
                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                Text("Enviada el \(PHDate.displayFromTimestamp(solicitud.creadoEn))")
                    .phText(PHFont.captionSM, color: PHColor.muted)
            }
            Spacer()
            estadoBadge(solicitud.estado)
        }
        .padding(.vertical, 4)
    }

    private func estadoBadge(_ estado: String) -> some View {
        switch estado {
        case "resuelta": PHBadge("Resuelta", style: .success)
        case "en_proceso": PHBadge("En proceso", style: .primary)
        default: PHBadge("Pendiente", style: .warning)
        }
    }

    private var nuevaSolicitudSheet: some View {
        NavigationStack {
            Form {
                Section("¿Qué necesitas?") {
                    Picker("Tipo de solicitud", selection: $viewModel.nuevaCategoria) {
                        ForEach(CategoriaPrivacidad.allCases) { categoria in
                            Text(categoria.etiqueta).tag(categoria)
                        }
                    }
                    if viewModel.nuevaCategoria == .eliminar {
                        Text("Eliminar tu cuenta borra tus datos personales y no se puede deshacer. Si tienes reservas activas, resuélvelas antes.")
                            .phText(PHFont.captionSM, color: PHColor.warning)
                    }
                }
                Section("Cuéntanos más") {
                    TextField("Detalles de tu solicitud…", text: $viewModel.nuevoMensaje, axis: .vertical)
                        .lineLimit(4...8)
                }
                if let error = viewModel.errorCrear {
                    Text(error.localizedDescription)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }
            }
            .navigationTitle("Nueva solicitud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { mostrarNuevaSolicitud = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PHTextButton("Enviar") {
                        Task {
                            if await viewModel.crearSolicitud() { mostrarNuevaSolicitud = false }
                        }
                    }
                    .disabled(!viewModel.puedeCrear)
                }
            }
        }
    }
}
