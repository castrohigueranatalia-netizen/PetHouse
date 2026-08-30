//
//  HospedajeDetailViewModel.swift
//  Features/HospedajeDetail
//

import Foundation

@MainActor
@Observable
public final class HospedajeDetailViewModel {
    public let hospedajeId: String

    public private(set) var hospedaje: Hospedaje?
    public private(set) var resenas: [Resena] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var alternandoActivo = false

    private let service: HospedajesServicing

    public init(hospedajeId: String, service: HospedajesServicing = HospedajesService()) {
        self.hospedajeId = hospedajeId
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let respuesta = try await service.detalle(id: hospedajeId)
            hospedaje = respuesta.hospedaje
            resenas = respuesta.resenas
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    /// Reemplaza una reseña local tras publicar/editar la respuesta del anfitrión — así se
    /// ve de inmediato sin volver a pedir el hospedaje completo.
    public func actualizarResenaLocal(_ resena: Resena) {
        guard let indice = resenas.firstIndex(where: { $0.id == resena.id }) else { return }
        resenas[indice] = resena
    }

    /// Reemplaza el hospedaje local tras editarlo (ver `PublicarHospedajeView`) — así se ve
    /// de inmediato sin volver a pedirlo al servidor.
    public func actualizarLocal(_ hospedaje: Hospedaje) {
        self.hospedaje = hospedaje
    }

    /// Pausa (deja de salir en Buscar/mapa) o reactiva este hospedaje propio, sin borrarlo
    /// ni perder su historial de reservas y reseñas.
    public func alternarActivo() async {
        guard let hospedaje else { return }
        alternandoActivo = true
        defer { alternandoActivo = false }
        do {
            self.hospedaje = try await service.alternarActivo(id: hospedaje.id, activo: !(hospedaje.activo ?? true))
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
