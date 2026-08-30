//
//  MisHospedajesViewModel.swift
//  Features/Anfitrion
//

import Foundation

@MainActor
@Observable
public final class MisHospedajesViewModel {
    public private(set) var hospedajes: [Hospedaje] = []
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
            hospedajes = try await service.misHospedajes()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    /// Inserta o reemplaza `hospedaje` en la lista local — recién publicado (id nuevo) se
    /// inserta primero; recién editado (id ya presente) reemplaza esa fila, así ambos casos
    /// se reflejan de inmediato sin esperar a un `cargar()` completo.
    public func guardarLocal(_ hospedaje: Hospedaje) {
        if let indice = hospedajes.firstIndex(where: { $0.id == hospedaje.id }) {
            hospedajes[indice] = hospedaje
        } else {
            hospedajes.insert(hospedaje, at: 0)
        }
    }
}
