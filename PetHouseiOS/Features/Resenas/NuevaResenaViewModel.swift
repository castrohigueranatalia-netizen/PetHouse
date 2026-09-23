//
//  NuevaResenaViewModel.swift
//  Features/Resenas
//
//  Gap real descubierto en el contrato de la API: `GET /api/reservas/mias` NO devuelve
//  `hospedaje_id` (ver `pethouse-api/src/routes/reservas.js` — el SELECT de `/mias` trae
//  `h.titulo AS hospedaje_titulo, h.ciudad, h.barrio, h.tipo, h.fotos` pero nunca
//  `rs.hospedaje_id`), y `POST /api/hospedajes/:id/resenas` lo necesita en la URL. Por eso
//  este ViewModel NO reutiliza el `Reserva` resumido que ya tiene `MisReservasView` — pide
//  el detalle completo vía `GET /api/reservas/:id` (que sí trae `rs.*`, incluyendo
//  `hospedaje_id`) antes de mostrar el formulario. Documentado también en README.md.
//

import Foundation

@MainActor
@Observable
public final class NuevaResenaViewModel {
    public let reservaId: String
    public let hospedajeTituloConocido: String?

    public private(set) var reserva: Reserva?
    public private(set) var cargandoDetalle = false
    public private(set) var errorDetalle: AppError?

    public var rating: Int = 5
    public var titulo: String = ""
    public var texto: String = ""

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var enviado = false

    private let reservasService: ReservasServicing
    private let resenasService: ResenasServicing

    public init(
        reservaId: String, hospedajeTituloConocido: String? = nil,
        reservasService: ReservasServicing = ReservasService(), resenasService: ResenasServicing = ResenasService()
    ) {
        self.reservaId = reservaId
        self.hospedajeTituloConocido = hospedajeTituloConocido
        self.reservasService = reservasService
        self.resenasService = resenasService
    }

    public func cargarDetalle() async {
        guard reserva == nil else { return }
        cargandoDetalle = true
        errorDetalle = nil
        defer { cargandoDetalle = false }
        do {
            let respuesta = try await reservasService.detalle(id: reservaId)
            reserva = respuesta.reserva
        } catch let appError as AppError {
            errorDetalle = appError
        } catch {
            errorDetalle = .desconocido(error.localizedDescription)
        }
    }

    public var puedeEnviar: Bool {
        rating >= 1 && rating <= 5 && reserva?.hospedajeId != nil && !isLoading
    }

    public func enviar() async {
        guard let hospedajeId = reserva?.hospedajeId else {
            error = .desconocido("No se pudo identificar el hospedaje de esta reserva.")
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            _ = try await resenasService.crear(
                hospedajeId: hospedajeId,
                reservaId: reservaId,
                rating: rating,
                titulo: titulo.isEmpty ? nil : titulo,
                texto: texto.isEmpty ? nil : texto
            )
            enviado = true
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
