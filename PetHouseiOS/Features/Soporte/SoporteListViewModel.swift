//
//  SoporteListViewModel.swift
//  Features/Soporte
//

import Foundation

@MainActor
@Observable
public final class SoporteListViewModel {
    public private(set) var tickets: [TicketSoporte] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    // Estado del formulario "nuevo ticket" — vive acá (no en una vista aparte) porque es
    // simple y evita coordinar dos ViewModels para un solo sheet.
    public var nuevoAsunto = ""
    public var nuevoMensaje = ""
    public private(set) var creando = false
    public private(set) var errorCrear: AppError?

    private let service: SoporteServicing

    public init(service: SoporteServicing = SoporteService()) {
        self.service = service
    }

    public var puedeCrear: Bool {
        !nuevoAsunto.trimmingCharacters(in: .whitespaces).isEmpty
            && !nuevoMensaje.trimmingCharacters(in: .whitespaces).isEmpty
            && !creando
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            tickets = try await service.misTickets()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    /// Devuelve `true` si se creó con éxito, para que la vista sepa cuándo cerrar el sheet.
    public func crearTicket() async -> Bool {
        errorCrear = nil
        creando = true
        defer { creando = false }
        do {
            let ticket = try await service.crear(
                asunto: nuevoAsunto.trimmingCharacters(in: .whitespaces),
                mensaje: nuevoMensaje.trimmingCharacters(in: .whitespaces)
            )
            tickets.insert(ticket, at: 0)
            nuevoAsunto = ""
            nuevoMensaje = ""
            return true
        } catch let appError as AppError {
            errorCrear = appError
            return false
        } catch {
            errorCrear = .desconocido(error.localizedDescription)
            return false
        }
    }
}
