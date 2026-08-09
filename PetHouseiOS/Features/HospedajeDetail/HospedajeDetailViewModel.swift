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
}
