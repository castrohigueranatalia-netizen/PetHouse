//
//  ReservaDetailViewModel.swift
//  Features/Reserva
//
//  Trae el detalle completo de la reserva (GET /api/reservas/:id, que sí incluye
//  precio_noche/limpieza/servicio/plan de actividades — GET /mias no) y, si hay
//  `hospedajeId`, el hospedaje completo (fotos, servicios, reglas, anfitrión — el mismo
//  contrato que usa HospedajeDetailView). También arranca el chat con el anfitrión: no
//  existía ningún punto de entrada para iniciar una conversación nueva en toda la app
//  (ChatService.obtenerOCrear ya existía pero nada lo llamaba) — este es el primero.
//

import Foundation

@MainActor
@Observable
public final class ReservaDetailViewModel {
    public private(set) var reserva: Reserva
    public private(set) var hospedaje: Hospedaje?
    public private(set) var plan: [PlanActividad] = []
    /// Notas/fotos que el anfitrión publicó durante la estadía (ver
    /// db/38-actualizaciones-reserva.sql) — vacío para reservas que nunca llegaron a
    /// 'confirmada' o donde el anfitrión no publicó nada.
    public private(set) var actualizaciones: [ActualizacionReserva] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    public private(set) var iniciandoChat = false
    /// `!= nil` justo después de que `iniciarChat()` obtiene/crea la conversación — la vista
    /// lo usa como destino de navegación y lo apaga al llegar (ver `.navigationDestination(item:)`).
    public private(set) var conversacion: Conversacion?

    private let reservasService: ReservasServicing
    private let hospedajesService: HospedajesServicing
    private let chatService: ChatServicing

    public init(
        reserva: Reserva,
        reservasService: ReservasServicing = ReservasService(),
        hospedajesService: HospedajesServicing = HospedajesService(),
        chatService: ChatServicing = ChatService()
    ) {
        self.reserva = reserva
        self.reservasService = reservasService
        self.hospedajesService = hospedajesService
        self.chatService = chatService
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let detalle = try await reservasService.detalle(id: reserva.id)
            reserva = detalle.reserva
            plan = detalle.plan
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }

        // Silencioso a propósito: sin esto la pantalla sigue siendo útil con los datos que
        // ya traía la reserva (título/ciudad/barrio/fotos, snapshot de GET /mias).
        if let hospedajeId = reserva.hospedajeId {
            hospedaje = try? await hospedajesService.detalle(id: hospedajeId).hospedaje
        }
        // También silencioso: la mayoría de las reservas nunca tienen ninguna (pendiente,
        // rechazada, o el anfitrión no publicó nada) — no vale la pena mostrar un error por
        // esto si falla, la sección simplemente no aparece (ver ReservaDetailView).
        actualizaciones = (try? await reservasService.actualizaciones(reservaId: reserva.id)) ?? []
    }

    public func limpiarConversacion() {
        conversacion = nil
    }

    public func iniciarChat() async {
        guard let anfitrionId = reserva.anfitrionId, !iniciandoChat else { return }
        iniciandoChat = true
        defer { iniciandoChat = false }
        do {
            conversacion = try await chatService.obtenerOCrear(anfitrionId: anfitrionId, hospedajeId: reserva.hospedajeId)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
