//
//  MisHospedajesViewModel.swift
//  Features/Anfitrion
//
//  🔴 `GET /api/hospedajes/mios` no existe hoy (ver `AnfitrionService`). El botón
//  "Publicar" SÍ funciona de verdad porque `POST /api/hospedajes` existe — ver
//  `PublicarHospedajeViewModel`.
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

    /// Inserta localmente el hospedaje recién publicado para que aparezca de inmediato,
    /// sin esperar a que `GET /api/hospedajes/mios` exista para poder refrescar la lista.
    public func agregarLocal(_ hospedaje: HospedajeCreado) {
        // `HospedajeCreado` es un subconjunto de `Hospedaje` (ver Hospedaje.swift) — se
        // envuelve en un `Hospedaje` "placeholder" con el resto de campos en `nil`/default
        // para poder reusar `PHHospedajeCard` sin cambios.
        let placeholder = Hospedaje(
            id: hospedaje.id, titulo: hospedaje.titulo, tipo: hospedaje.tipo,
            ciudad: hospedaje.ciudad, localidad: hospedaje.localidad, precioNoche: hospedaje.precioNoche
        )
        hospedajes.insert(placeholder, at: 0)
    }
}
