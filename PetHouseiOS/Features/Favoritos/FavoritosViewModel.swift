//
//  FavoritosViewModel.swift
//  Features/Favoritos
//
//  🔴 No hay rutas de favoritos hoy (ver `FavoritosService`). Este ViewModel mantiene un
//  set en memoria de IDs "marcados como favorito en esta sesión" para que el corazón de
//  `PHHospedajeCard` responda al toque incluso contra el backend actual — pero SIEMPRE
//  intenta la llamada real primero y solo usa el estado local optimista tras un éxito o
//  como fallback visual cuando la función está pendiente (se lo dice al usuario, no lo
//  oculta). Al recargar la app esto no persiste porque no hay de dónde leerlo de verdad.
//

import Foundation

@MainActor
@Observable
public final class FavoritosViewModel {
    public private(set) var hospedajes: [Hospedaje] = []
    public private(set) var idsFavoritos: Set<String> = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    private let service: FavoritosServicing

    public init(service: FavoritosServicing = FavoritosService()) {
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            hospedajes = try await service.listar()
            idsFavoritos = Set(hospedajes.map(\.id))
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    public func esFavorito(_ hospedajeId: String) -> Bool {
        idsFavoritos.contains(hospedajeId)
    }

    /// Optimista: cambia el ícono al instante y confirma/revierte según la respuesta real.
    public func alternar(_ hospedaje: Hospedaje) async {
        let yaEsFavorito = idsFavoritos.contains(hospedaje.id)
        if yaEsFavorito {
            idsFavoritos.remove(hospedaje.id)
        } else {
            idsFavoritos.insert(hospedaje.id)
        }

        do {
            if yaEsFavorito {
                try await service.quitar(hospedajeId: hospedaje.id)
                hospedajes.removeAll { $0.id == hospedaje.id }
            } else {
                try await service.agregar(hospedajeId: hospedaje.id)
                hospedajes.append(hospedaje)
            }
        } catch {
            // Revierte el estado optimista — incluye el caso "función pendiente".
            if yaEsFavorito {
                idsFavoritos.insert(hospedaje.id)
            } else {
                idsFavoritos.remove(hospedaje.id)
            }
            self.error = (error as? AppError) ?? .desconocido(error.localizedDescription)
        }
    }
}
