//
//  MisReservasViewModel.swift
//  Features/Reserva
//
//  Lee `GET /api/reservas/mias` y guarda una copia en SwiftData (`ReservaCache`) para
//  poder mostrar algo cuando no hay red. El `ModelContext` se recibe por parámetro desde
//  la vista (vía `@Environment(\.modelContext)`) en vez de vivir dentro del ViewModel,
//  para no atar este archivo a SwiftUI más de lo necesario.
//

import Foundation
import SwiftData

@MainActor
@Observable
public final class MisReservasViewModel {
    public private(set) var reservas: [Reserva] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var mostrandoDatosDeCache = false
    public private(set) var cancelandoId: String?
    public private(set) var ocultandoId: String?

    private let service: ReservasServicing

    public init(service: ReservasServicing = ReservasService()) {
        self.service = service
    }

    public func cargar(modelContext: ModelContext) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let respuesta = try await service.mias()
            reservas = respuesta.reservas
            mostrandoDatosDeCache = false
            guardarEnCache(respuesta.reservas, modelContext: modelContext)
        } catch AppError.sinConexion {
            let cache = leerCache(modelContext: modelContext)
            if !cache.isEmpty {
                reservas = cache
                mostrandoDatosDeCache = true
            } else {
                error = .sinConexion
            }
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    public func cancelar(_ reserva: Reserva, modelContext: ModelContext) async {
        cancelandoId = reserva.id
        defer { cancelandoId = nil }
        do {
            let respuesta = try await service.cancelar(id: reserva.id)
            if let index = reservas.firstIndex(where: { $0.id == reserva.id }) {
                reservas[index] = respuesta.reserva
            }
            guardarEnCache(reservas, modelContext: modelContext)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    /// Quita del panel una reserva ya resuelta ('completada'/'cancelada'/'rechazada') — el
    /// servidor la marca oculta (ver ReservasService.ocultar) en vez de borrarla de verdad;
    /// acá, si el servidor confirma, se saca de la lista local y de la caché igual que si se
    /// hubiera vuelto a cargar.
    public func ocultar(_ reserva: Reserva, modelContext: ModelContext) async {
        ocultandoId = reserva.id
        defer { ocultandoId = nil }
        do {
            try await service.ocultar(id: reserva.id)
            reservas.removeAll { $0.id == reserva.id }
            guardarEnCache(reservas, modelContext: modelContext)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    private func guardarEnCache(_ reservas: [Reserva], modelContext: ModelContext) {
        (try? modelContext.fetch(FetchDescriptor<ReservaCache>()))?.forEach(modelContext.delete)
        for reserva in reservas {
            modelContext.insert(ReservaCache(reserva: reserva))
        }
        try? modelContext.save()
    }

    private func leerCache(modelContext: ModelContext) -> [Reserva] {
        let cachadas = (try? modelContext.fetch(FetchDescriptor<ReservaCache>())) ?? []
        return cachadas.map(\.comoReserva)
    }
}
