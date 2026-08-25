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
    /// Id del hospedaje que se está pausando/reactivando ahora mismo — para mostrar su
    /// propio spinner sin bloquear el resto de la pantalla.
    public private(set) var alternandoId: String?

    private let service: AnfitrionServicing
    private let hospedajesService: HospedajesServicing

    public init(service: AnfitrionServicing = AnfitrionService(), hospedajesService: HospedajesServicing = HospedajesService()) {
        self.service = service
        self.hospedajesService = hospedajesService
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

    /// Pausa (deja de salir en Buscar/mapa) o reactiva un hospedaje propio, sin borrarlo ni
    /// perder su historial de reservas y reseñas.
    public func alternarActivo(_ hospedaje: Hospedaje) async {
        alternandoId = hospedaje.id
        defer { alternandoId = nil }
        do {
            let actualizado = try await hospedajesService.alternarActivo(id: hospedaje.id, activo: !(hospedaje.activo ?? true))
            guardarLocal(actualizado)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
