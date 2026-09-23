//
//  TicketDetalleViewModel.swift
//  Features/Soporte
//

import Foundation

@MainActor
@Observable
public final class TicketDetalleViewModel {
    public let ticketId: String
    public private(set) var ticket: TicketSoporte?
    public private(set) var mensajes: [MensajeSoporte] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public var texto = ""
    public private(set) var enviando = false

    private let service: SoporteServicing

    public init(ticketId: String, service: SoporteServicing = SoporteService()) {
        self.ticketId = ticketId
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let detalle = try await service.detalle(id: ticketId)
            ticket = detalle.ticket
            mensajes = detalle.mensajes
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    public func responder() async {
        let contenido = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contenido.isEmpty, !enviando else { return }
        enviando = true
        defer { enviando = false }
        do {
            let mensaje = try await service.responder(id: ticketId, texto: contenido)
            mensajes.append(mensaje)
            texto = ""
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
