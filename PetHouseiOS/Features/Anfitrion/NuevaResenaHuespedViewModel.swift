//
//  NuevaResenaHuespedViewModel.swift
//  Features/Anfitrion
//
//  Espejo de `Features/Resenas/NuevaResenaViewModel` (el huésped califica el hospedaje) —
//  acá el anfitrión califica al huésped de una reserva propia ya `completada`. Más simple
//  que su espejo: `ReservasRecibidasView` ya tiene el `Reserva` completo a mano (viene de
//  `GET /api/hospedajes/:id/reservas`), así que no hace falta pedir el detalle aparte.
//

import Foundation

@MainActor
@Observable
public final class NuevaResenaHuespedViewModel {
    public let reserva: Reserva

    public var rating: Int = 5
    public var titulo: String = ""
    public var texto: String = ""

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var enviado = false

    private let reservasService: ReservasServicing

    public init(reserva: Reserva, reservasService: ReservasServicing = ReservasService()) {
        self.reserva = reserva
        self.reservasService = reservasService
    }

    public var puedeEnviar: Bool {
        rating >= 1 && rating <= 5 && !isLoading
    }

    public func enviar() async {
        guard puedeEnviar else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            _ = try await reservasService.calificarHuesped(
                reservaId: reserva.id,
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
