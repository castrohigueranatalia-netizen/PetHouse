//
//  HistorialReservasViewModel.swift
//  Features/Anfitrion
//

import Foundation

@MainActor
@Observable
public final class HistorialReservasViewModel {
    public private(set) var reservas: [Reserva] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    private let service: AnfitrionServicing

    public init(service: AnfitrionServicing = AnfitrionService()) {
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            reservas = try await service.historialReservas()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
