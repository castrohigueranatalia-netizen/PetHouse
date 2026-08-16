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
            // Consume la señal de "Ver reserva" del aviso de solicitud nueva (ver
            // SessionStore.reservaRecibidaParaAbrir y MainTabView, que ya saltó a esta
            // pestaña) empujando "Reservas recibidas" del hospedaje correspondiente — mismo
            // mecanismo de "señal + consumo" que `abrirVerificacionAlEntrar` en PerfilView.
            .navigationDestination(item: Binding(
                get: { session.reservaRecibidaParaAbrir },
                set: { session.reservaRecibidaParaAbrir = $0 }
            )) { reserva in
                ReservasRecibidasView(hospedaje: hospedajePlaceholder(reserva))
            }
    }

    /// `ReservasRecibidasView` solo necesita `hospedaje.id` (para pedir sus reservas) y
    /// `hospedaje.titulo` (para el título de la pantalla y el mensaje vacío) — el aviso de
    /// solicitud nueva no trae el resto de campos de un `Hospedaje` real, así que se arma un
    /// "placeholder" con esos dos datos, mismo patrón que el `Hospedaje` placeholder que usa
    /// `PublicarHospedajeViewModel` tras crear un hospedaje.
    private func hospedajePlaceholder(_ reserva: Reserva) -> Hospedaje {
        Hospedaje(
            id: reserva.hospedajeId ?? "",
            titulo: reserva.hospedajeTitulo ?? "Hospedaje",
            tipo: .guarderia,
            ciudad: "Bogotá",
            precioNoche: 0
        )
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

    /// Reservas ya resueltas — el huésped las puede quitar del panel con la "x" (no se
    /// borran de verdad, ver `MisReservasViewModel.ocultar`). Las activas ('pendiente',
    /// 'confirmada') no tienen esa "x": todavía se pueden cancelar, no tiene sentido
    /// "perderlas" de la lista mientras siguen vigentes.
    private func esOcultable(_ estado: EstadoReserva) -> Bool {
        estado == .completada || estado == .cancelada || estado == .rechazada
    }

    private func reservaFila(_ reserva: Reserva) -> some View {
        // La "x" para quitar la reserva queda como hermana del contenido tocable dentro del
        // mismo ZStack (arriba a la derecha), no anidada adentro de su botón — mismo patrón
        // ya usado en PHMascotaCard/PHAdjuntarFotos para que ambos toques respondan bien.
        ZStack(alignment: .topTrailing) {
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

            if esOcultable(reserva.estado) {
                if viewModel.ocultandoId == reserva.id {
                    ProgressView()
                        .controlSize(.small)
                        .padding(PHSpacing.s12)
                } else {
                    PHIconButton(systemImage: "xmark", accessibilityLabel: "Quitar esta reserva de la lista") {
                        Task { await viewModel.ocultar(reserva, modelContext: modelContext) }
                    }
                    .padding(PHSpacing.s4)
                }
            }
        }
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
