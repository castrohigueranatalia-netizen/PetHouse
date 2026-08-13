//
//  MisReservasView.swift
//  Features/Reserva
//

import SwiftUI
import SwiftData

struct MisReservasView: View {
    @Environment(SessionStore.self) private var session
    @State private var viewModel = MisReservasViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var reservaParaResena: Reserva?
    @State private var reservaSeleccionada: Reserva?

    var body: some View {
        content
            .navigationTitle("Mis reservas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { session.volverABuscar = true } label: {
                        PHLogo(height: 28)
                    }
                    .accessibilityLabel("Ir al listado de hospedajes")
                }
            }
            .task { await viewModel.cargar(modelContext: modelContext) }
            .refreshable { await viewModel.cargar(modelContext: modelContext) }
            .sheet(item: $reservaParaResena) { reserva in
                NuevaResenaView(reservaId: reserva.id, hospedajeTitulo: reserva.hospedajeTitulo)
            }
            .navigationDestination(item: $reservaSeleccionada) { reserva in
                ReservaDetailView(reserva: reserva)
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.reservas.isEmpty {
            PHLoadingStateView(mensaje: "Cargando tus reservas…")
        } else if let error = viewModel.error, viewModel.reservas.isEmpty {
            PHErrorStateView(error: error) {
                Task { await viewModel.cargar(modelContext: modelContext) }
            }
        } else if viewModel.reservas.isEmpty {
            PHEmptyStateView(
                systemImage: "calendar.badge.exclamationmark",
                titulo: "Aún no tienes reservas",
                mensaje: "Cuando reserves un hospedaje para tu mascota, aparecerá aquí."
            )
        } else {
            ScrollView {
                if viewModel.mostrandoDatosDeCache {
                    PHBadge("Mostrando datos guardados sin conexión", style: .warning)
                        .padding(.top, PHSpacing.s8)
                }
                LazyVStack(spacing: PHSpacing.s12) {
                    ForEach(viewModel.reservas) { reserva in
                        reservaFila(reserva)
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }

    private func reservaFila(_ reserva: Reserva) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            Button { reservaSeleccionada = reserva } label: {
                VStack(alignment: .leading, spacing: PHSpacing.s8) {
                    HStack {
                        Text(reserva.hospedajeTitulo ?? "Hospedaje")
                            .phText(PHFont.titleMD, color: PHColor.ink)
                        Spacer()
                        estadoBadge(reserva.estado)
                    }

                    if let ciudad = reserva.ciudad {
                        Text([reserva.barrio, ciudad].compactMap { $0 }.joined(separator: ", "))
                            .phText(PHFont.bodySM, color: PHColor.muted)
                    }

                    HStack {
                        if let desde = reserva.desde, let hasta = reserva.hasta {
                            Label(
                                "\(PHDate.displayFromAPIDateOnly(desde)) → \(PHDate.displayFromAPIDateOnly(hasta))",
                                systemImage: "calendar"
                            )
                            .phText(PHFont.captionSM, color: PHColor.body)
                        }
                        Spacer()
                        if let total = reserva.total {
                            Text(PHFormato.precio(total))
                                .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                        }
                    }

                    Text("Código \(reserva.codigo)")
                        .phText(PHFont.micro, color: PHColor.mutedSoft)
                }
            }
            .buttonStyle(.plain)

            if reserva.estado == .pendiente || reserva.estado == .confirmada {
                HStack {
                    PHTextButton("Cancelar", role: .destructive) {
                        Task { await viewModel.cancelar(reserva, modelContext: modelContext) }
                    }
                    if viewModel.cancelandoId == reserva.id {
                        ProgressView().controlSize(.small)
                    }
                    Spacer()
                }
            } else if reserva.estado == .completada {
                PHTextButton("Dejar una reseña") {
                    reservaParaResena = reserva
                }
            }
        }
        .padding(PHSpacing.s16)
        .background(PHColor.canvas)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
        .phShadow(PHShadow.level1)
    }

    private func estadoBadge(_ estado: EstadoReserva) -> some View {
        switch estado {
        case .pendiente: PHBadge("Pendiente de aprobación", style: .warning)
        case .confirmada: PHBadge("Confirmada", style: .success)
        case .rechazada: PHBadge("Rechazada", style: .error)
        case .cancelada: PHBadge("Cancelada", style: .error)
        case .completada: PHBadge("Completada", style: .primary)
        }
    }
}
