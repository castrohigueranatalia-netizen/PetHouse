//
//  SolicitudPrivacidadListViewModel.swift
//  Features/Privacidad
//

import Foundation

@MainActor
@Observable
public final class SolicitudPrivacidadListViewModel {
    public private(set) var solicitudes: [SolicitudPrivacidad] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    // Estado del formulario "nueva solicitud" — vive acá, igual que en SoporteListViewModel,
    // porque es simple y evita coordinar dos ViewModels para un solo sheet.
    public var nuevaCategoria: CategoriaPrivacidad = .conocer
    public var nuevoMensaje = ""
    public private(set) var creando = false
    public private(set) var errorCrear: AppError?

    private let service: PrivacidadServicing

    public init(service: PrivacidadServicing = PrivacidadService()) {
        self.service = service
    }

    public var puedeCrear: Bool {
        !nuevoMensaje.trimmingCharacters(in: .whitespaces).isEmpty && !creando
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            solicitudes = try await service.misSolicitudes()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    /// Devuelve `true` si se creó con éxito, para que la vista sepa cuándo cerrar el sheet.
    public func crearSolicitud() async -> Bool {
        errorCrear = nil
        creando = true
        defer { creando = false }
        do {
            let solicitud = try await service.crear(
                categoria: nuevaCategoria,
                mensaje: nuevoMensaje.trimmingCharacters(in: .whitespaces)
            )
            solicitudes.insert(solicitud, at: 0)
            nuevaCategoria = .conocer
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
