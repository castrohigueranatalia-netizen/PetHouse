//
//  AdminView.swift
//  Features/Admin
//
//  Raíz de la pestaña Admin (solo visible si Usuario.rol == .admin, ver MainTabView):
//  estadísticas generales arriba, acceso a las solicitudes de anfitrión abajo.
//

import SwiftUI

struct AdminView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = AdminViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PHSpacing.s24) {
                if viewModel.isLoading && viewModel.estadisticas == nil {
                    PHLoadingStateView(mensaje: "Cargando panel…")
                        .frame(height: 200)
                } else if let error = viewModel.error {
                    PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
                        .frame(height: 200)
                } else if let estadisticas = viewModel.estadisticas {
                    tarjetas(estadisticas)

                    NavigationLink {
                        AdminSolicitudesView()
                    } label: {
                        filaSolicitudes(pendientes: estadisticas.solicitudesPendientes)
                    }
                    .buttonStyle(.plain)

                    if !estadisticas.reservasPorCiudad.isEmpty {
                        reservasPorCiudad(estadisticas.reservasPorCiudad)
                    }
                }
            }
            .padding(PHSpacing.s16)
        }
        .background(PHColor.canvas)
        .navigationTitle("Panel de administración")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { session.volverABuscar = true } label: {
                    PHLogo(height: 28)
                }
                .accessibilityLabel("Ir al listado de hospedajes")
            }
        }
        .refreshable {
            await viewModel.cargar()
            await session.actualizarContadores()
        }
        .task {
            if viewModel.estadisticas == nil { await viewModel.cargar() }
            await session.actualizarContadores()
        }
    }

    private func tarjetas(_ estadisticas: EstadisticasAdmin) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: PHSpacing.s12) {
            tarjeta(titulo: "Usuarios", valor: estadisticas.totalUsuarios, icono: "person.2.fill")
            tarjeta(titulo: "Anfitriones", valor: estadisticas.totalAnfitriones, icono: "house.fill")
            tarjeta(titulo: "Reservas totales", valor: estadisticas.totalReservas, icono: "calendar")
            tarjeta(titulo: "Solicitudes pendientes", valor: estadisticas.solicitudesPendientes, icono: "clock.fill", destacar: estadisticas.solicitudesPendientes > 0)
        }
    }

    private func tarjeta(titulo: String, valor: Int, icono: String, destacar: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Image(systemName: icono).foregroundStyle(destacar ? PHColor.primary : PHColor.muted)
            Text("\(valor)")
                .phText(PHFont.displayLG, color: PHColor.ink)
            Text(titulo)
                .phText(PHFont.captionSM, color: PHColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PHSpacing.s16)
        .background(destacar ? PHColor.primaryContainer : PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }

    private func filaSolicitudes(pendientes: Int) -> some View {
        HStack {
            Image(systemName: "checklist").foregroundStyle(PHColor.primary)
            Text("Solicitudes de anfitrión")
                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
            Spacer()
            if pendientes > 0 {
                PHBadge("\(pendientes) pendientes", style: .warning)
            }
            Image(systemName: "chevron.right").foregroundStyle(PHColor.mutedSoft).font(.caption)
        }
        .padding(PHSpacing.s12)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
    }

    private func reservasPorCiudad(_ datos: [ReservasPorCiudad]) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Text("Reservas por ciudad")
                .phText(PHFont.titleMD, color: PHColor.ink)
            VStack(spacing: PHSpacing.s4) {
                ForEach(datos) { fila in
                    HStack {
                        Text(fila.ciudad).phText(PHFont.bodyMD, color: PHColor.ink)
                        Spacer()
                        Text("\(fila.total)").phText(PHFont.bodyMD.weight(.semibold), color: PHColor.muted)
                    }
                    .padding(.vertical, PHSpacing.s8)
                    .padding(.horizontal, PHSpacing.s12)
                    .background(PHColor.surfaceSoft)
                    .clipShape(RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous))
                }
            }
        }
    }
}
