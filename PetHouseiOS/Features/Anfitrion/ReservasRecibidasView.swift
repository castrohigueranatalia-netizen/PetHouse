//
//  ReservasRecibidasView.swift
//  Features/Anfitrion
//
//  Reservas que llegaron a un hospedaje del anfitrión (GET /api/hospedajes/:id/reservas).
//  Muestra el huésped, fechas, mascotas y total de cada reserva; tocar una mascota abre su
//  ficha completa (ver FichaMascotaView) para que el anfitrión pueda evaluarla ANTES de
//  aceptar o rechazar. Toda solicitud nace 'pendiente': aquí el anfitrión la acepta o la
//  rechaza (POST /api/reservas/:id/aceptar|rechazar). También puede escribirle al huésped
//  directamente: antes solo el huésped podía iniciar un chat (ver ReservaDetailViewModel),
//  el anfitrión no tenía ninguna forma de hacerlo.
//

import SwiftUI

enum AccionReserva: Equatable {
    case aceptar
    case rechazar
}

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

    private(set) var resolviendoId: String?
    private(set) var accionEnCurso: AccionReserva?

    private let service: AnfitrionServicing
    private let reservasService: ReservasServicing
    private let chatService: ChatServicing

    init(
        service: AnfitrionServicing = AnfitrionService(),
        reservasService: ReservasServicing = ReservasService(),
        chatService: ChatServicing = ChatService()
    ) {
        self.service = service
        self.reservasService = reservasService
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

    func resolver(_ reserva: Reserva, accion: AccionReserva) async {
        guard resolviendoId == nil else { return }
        resolviendoId = reserva.id
        accionEnCurso = accion
        defer { resolviendoId = nil; accionEnCurso = nil }
        do {
            let respuesta = accion == .aceptar
                ? try await reservasService.aceptar(id: reserva.id)
                : try await reservasService.rechazar(id: reserva.id)
            // La respuesta trae la fila COMPLETA (usuario_nombre, mascotas_detalle, etc.),
            // no solo id/codigo/estado — ver ReservaAccionResponse.
            if let index = reservas.firstIndex(where: { $0.id == reserva.id }) {
                reservas[index] = respuesta.reserva
            }
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
    /// Mascota cuya ficha se está mostrando — ver `FichaMascotaView`. El anfitrión la abre
    /// tocando cualquier mascota de una solicitud para evaluar si puede aceptarla.
    @State private var mascotaFicha: Mascota?

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
            .sheet(item: $mascotaFicha) { mascota in
                FichaMascotaView(mascota: mascota)
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

            if let mascotas = reserva.mascotasDetalle, !mascotas.isEmpty {
                seccionMascotas(mascotas)
            }

            HStack {
                if reserva.mascotasDetalle?.isEmpty ?? true, let mascotas = reserva.mascotas {
                    Label("\(mascotas) mascota\(mascotas == 1 ? "" : "s")", systemImage: "pawprint")
                        .phText(PHFont.captionSM, color: PHColor.muted)
                }
                Spacer()
                if let total = reserva.total {
                    Text(PHFormato.precio(total))
                        .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                }
            }

            if reserva.estado == .pendiente {
                HStack(spacing: PHSpacing.s12) {
                    PHPrimaryButton(
                        "Aceptar",
                        isLoading: viewModel.resolviendoId == reserva.id && viewModel.accionEnCurso == .aceptar
                    ) {
                        Task { await viewModel.resolver(reserva, accion: .aceptar) }
                    }
                    PHTextButton("Rechazar", role: .destructive) {
                        Task { await viewModel.resolver(reserva, accion: .rechazar) }
                    }
                    .disabled(viewModel.resolviendoId == reserva.id)
                }
                .padding(.top, PHSpacing.s4)
            } else if reserva.estado != .cancelada && reserva.estado != .rechazada {
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

    private func seccionMascotas(_ mascotas: [Mascota]) -> some View {
        VStack(spacing: PHSpacing.s4) {
            ForEach(mascotas) { mascota in
                Button { mascotaFicha = mascota } label: {
                    HStack(spacing: PHSpacing.s4) {
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: PHSpacing.s4) {
                                Image(systemName: "pawprint.fill")
                                    .font(.caption2)
                                    .foregroundStyle(PHColor.muted)
                                Text(mascota.nombre)
                                    .phText(PHFont.captionSM.weight(.semibold), color: PHColor.ink)
                                if let raza = mascota.raza, !raza.isEmpty {
                                    Text("· \(raza)")
                                        .phText(PHFont.captionSM, color: PHColor.muted)
                                }
                                if mascota.vacunasDia {
                                    Text("· Vacunas al día")
                                        .phText(PHFont.micro, color: PHColor.success)
                                }
                                if mascota.necesitaMedicamentos {
                                    Text("· Medicamentos")
                                        .phText(PHFont.micro, color: PHColor.warning)
                                }
                            }
                            if let notas = mascota.notas, !notas.isEmpty {
                                Text(notas)
                                    .phText(PHFont.micro, color: PHColor.mutedSoft)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Text("Ver ficha")
                            .phText(PHFont.micro.weight(.semibold), color: PHColor.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(PHColor.primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(PHSpacing.s8)
        .background(PHColor.surfaceSoft)
        .clipShape(RoundedRectangle(cornerRadius: PHRadius.sm, style: .continuous))
    }

    private func estadoBadge(_ estado: EstadoReserva) -> some View {
        switch estado {
        case .pendiente: PHBadge("Solicitud nueva", style: .warning)
        case .confirmada: PHBadge("Confirmada", style: .success)
        case .rechazada: PHBadge("Rechazada", style: .error)
        case .cancelada: PHBadge("Cancelada", style: .error)
        case .completada: PHBadge("Completada", style: .primary)
        }
    }
}
