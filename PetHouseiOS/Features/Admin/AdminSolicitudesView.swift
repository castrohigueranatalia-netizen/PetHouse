//
//  AdminSolicitudesView.swift
//  Features/Admin
//

import SwiftUI

struct AdminSolicitudesView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = AdminSolicitudesViewModel()
    @State private var solicitudSeleccionada: SolicitudAnfitrion?

    var body: some View {
        VStack(spacing: 0) {
            filtros

            content
        }
        .background(PHColor.canvas)
        .navigationTitle("Solicitudes de anfitrión")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.cargar() }
        .navigationDestination(item: $solicitudSeleccionada) { solicitud in
            AdminSolicitudDetailView(solicitud: solicitud) {
                Task {
                    await viewModel.cargar()
                    // La solicitud resuelta ya no cuenta como pendiente — refresca el
                    // badge de la pestaña Admin.
                    await session.actualizarContadores()
                }
            }
        }
    }

    private var filtros: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PHSpacing.s8) {
                PHChip("Pendientes", isSelected: viewModel.filtro == .pendiente) {
                    viewModel.cambiarFiltro(.pendiente)
                }
                PHChip("Aprobadas", isSelected: viewModel.filtro == .aprobado) {
                    viewModel.cambiarFiltro(.aprobado)
                }
                PHChip("Rechazadas", isSelected: viewModel.filtro == .rechazado) {
                    viewModel.cambiarFiltro(.rechazado)
                }
                PHChip("Todas", isSelected: viewModel.filtro == nil) {
                    viewModel.cambiarFiltro(nil)
                }
            }
            .padding(PHSpacing.s16)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.solicitudes.isEmpty {
            PHLoadingStateView(mensaje: "Cargando solicitudes…")
        } else if let error = viewModel.error {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.solicitudes.isEmpty {
            PHEmptyStateView(
                systemImage: "checklist",
                titulo: "Sin solicitudes",
                mensaje: "No hay solicitudes de anfitrión con este filtro."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: PHSpacing.s8) {
                    ForEach(viewModel.solicitudes) { solicitud in
                        Button {
                            solicitudSeleccionada = solicitud
                        } label: {
                            fila(solicitud)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(PHSpacing.s16)
            }
            .refreshable { await viewModel.cargar() }
        }
    }

    private func fila(_ solicitud: SolicitudAnfitrion) -> some View {
        HStack(spacing: PHSpacing.s12) {
            PHAvatar(name: solicitud.usuarioNombre, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(solicitud.usuarioNombre)
                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                Text(solicitud.usuarioEmail)
                    .phText(PHFont.captionSM, color: PHColor.muted)
            }
            Spacer()
            estadoBadge(solicitud.estado)
        }
        .padding(PHSpacing.s12)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }

    private func estadoBadge(_ estado: EstadoVerificacion) -> some View {
        switch estado {
        case .pendiente: PHBadge(estado.etiqueta, style: .warning)
        case .aprobado: PHBadge(estado.etiqueta, style: .success)
        case .rechazado: PHBadge(estado.etiqueta, style: .error)
        }
    }
}
