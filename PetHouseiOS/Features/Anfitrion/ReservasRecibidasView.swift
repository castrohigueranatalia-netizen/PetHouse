//
//  ReservasRecibidasView.swift
//  Features/Anfitrion
//
//  Reservas que llegaron a un hospedaje del anfitrión (GET /api/hospedajes/:id/reservas,
//  que sí existe y ya devuelve usuario_nombre — ver Core/Models/AnfitrionDTO.swift). Muestra
//  el huésped, fechas, mascotas y total de cada reserva, con un botón para escribirle
//  directamente: antes solo el huésped podía iniciar un chat (ver ReservaDetailViewModel),
//  el anfitrión no tenía ninguna forma de hacerlo.
//

import SwiftUI

@MainActor
@Observable
final class ReservasRecibidasViewModel {
    private(set) var reservas: [Reserva] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    private(set) var iniciandoChatId: String?
    /// `!= nil` justo después de obtener/crear la conversación con un huésped — la vista lo
    /// usa como destino de navegación (mismo patrón que `ReservaDetailViewModel`).
    private(set) var conversacion: Conversacion?

    private let service: AnfitrionServicing
    private let chatService: ChatServicing

    init(service: AnfitrionServicing = AnfitrionService(), chatService: ChatServicing = ChatService()) {
        self.service = service
        self.chatService = chatService
    }

    func cargar(hospedajeId: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            reservas = try await service.reservasRecibidas(hospedajeId: hospedajeId)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    func limpiarConversacion() {
        conversacion = nil
    }

    func escribirA(_ reserva: Reserva, hospedajeId: String) async {
        guard let usuarioId = reserva.usuarioId, iniciandoChatId == nil else { return }
        iniciandoChatId = reserva.id
        defer { iniciandoChatId = nil }
        do {
            // El backend solo pide "el id de la otra persona" y empareja por par de ids sin
            // importar quién es usuario_id/anfitrion_id (ver POST /api/conversaciones) — así
            // que pasar el id del huésped aquí crea/recupera la conversación correcta aunque
            // el parámetro se llame `anfitrionId`.
            conversacion = try await chatService.obtenerOCrear(anfitrionId: usuarioId, hospedajeId: hospedajeId)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}

struct ReservasRecibidasView: View {
    let hospedaje: Hospedaje
    @State private var viewModel = ReservasRecibidasViewModel()

    var body: some View {
        content
            .navigationTitle("Reservas recibidas")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.cargar(hospedajeId: hospedaje.id) }
            .refreshable { await viewModel.cargar(hospedajeId: hospedaje.id) }
            .navigationDestination(item: Binding(get: { viewModel.conversacion }, set: { _ in })) { conversacion in
                ChatDetailView(conversacion: conversacion)
                    .onDisappear { viewModel.limpiarConversacion() }
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.reservas.isEmpty {
            PHLoadingStateView(mensaje: "Cargando reservas recibidas…")
        } else if let error = viewModel.error, viewModel.reservas.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar(hospedajeId: hospedaje.id) } }
        } else if viewModel.reservas.isEmpty {
            PHEmptyStateView(
                systemImage: "calendar",
                titulo: "Sin reservas todavía",
                mensaje: "Las reservas que reciba \(hospedaje.titulo) aparecerán aquí."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: PHSpacing.s12) {
                    ForEach(viewModel.reservas) { reserva in
                        reservaCard(reserva)
                    }
                }
                .padding(PHSpacing.s16)
            }
        }
    }

    private func reservaCard(_ reserva: Reserva) -> some View {
        VStack(alignment: .leading, spacing: PHSpacing.s8) {
            HStack(spacing: PHSpacing.s8) {
                PHAvatar(name: reserva.usuarioNombre ?? "Huésped", size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(reserva.usuarioNombre ?? "Huésped")
                        .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                    Text(reserva.codigo)
                        .phText(PHFont.micro, color: PHColor.mutedSoft)
                }
                Spacer()
                estadoBadge(reserva.estado)
            }

            if let desde = reserva.desde, let hasta = reserva.hasta {
                Label(
                    "\(PHDate.displayFromAPIDateOnly(desde)) → \(PHDate.displayFromAPIDateOnly(hasta))",
                    systemImage: "calendar"
                )
                .phText(PHFont.captionSM, color: PHColor.body)
            }

            HStack {
                if let mascotas = reserva.mascotas {
                    Label("\(mascotas) mascota\(mascotas == 1 ? "" : "s")", systemImage: "pawprint")
                        .phText(PHFont.captionSM, color: PHColor.muted)
                }
                Spacer()
                if let total = reserva.total {
                    Text(PHFormato.precio(total))
                        .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                }
            }

            if reserva.estado != .cancelada {
                HStack(spacing: PHSpacing.s8) {
                    PHSecondaryButton("Escribir al huésped", systemImage: "message") {
                        Task { await viewModel.escribirA(reserva, hospedajeId: hospedaje.id) }
                    }
                    if viewModel.iniciandoChatId == reserva.id {
                        ProgressView().controlSize(.small)
                    }
                }
                .padding(.top, PHSpacing.s4)
            }
        }
        .padding(PHSpacing.s16)
        .background(PHColor.canvas)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.lg, style: .continuous))
        .phShadow(PHShadow.level1)
    }

    private func estadoBadge(_ estado: EstadoReserva) -> some View {
        switch estado {
        case .confirmada: PHBadge("Confirmada", style: .success)
        case .cancelada: PHBadge("Cancelada", style: .error)
        case .completada: PHBadge("Completada", style: .primary)
        }
    }
}
