//
//  NotificacionesViewModel.swift
//  Features/Notificaciones
//

import Foundation

@MainActor
@Observable
public final class NotificacionesViewModel {
    public private(set) var notificaciones: [Notificacion] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    private let service: NotificacionesServicing

    public init(service: NotificacionesServicing = NotificacionesService()) {
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let respuesta = try await service.listar()
            notificaciones = respuesta.notificaciones
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    /// Marca TODAS como leídas — se llama apenas se abre la pantalla, como cualquier
    /// bandeja de notificaciones real: el badge de la campana se apaga al revisarlas, sin
    /// depender de que se toque cada una por separado.
    public func marcarTodasLeidas() async {
        guard notificaciones.contains(where: { !$0.leida }) else { return }
        notificaciones = notificaciones.map { marcarLeidaLocal($0) }
        try? await service.marcarTodasLeidas()
    }

    /// Respaldo defensivo por si `marcarTodasLeidas()` falló en silencio (sin conexión,
    /// etc.) — se llama también al tocar una notificación puntual para abrirla.
    public func marcarLeida(_ id: String) async {
        guard let index = notificaciones.firstIndex(where: { $0.id == id }), !notificaciones[index].leida else { return }
        notificaciones[index] = marcarLeidaLocal(notificaciones[index])
        try? await service.marcarLeida(id: id)
    }

    private func marcarLeidaLocal(_ n: Notificacion) -> Notificacion {
        Notificacion(
            id: n.id, tipo: n.tipo, titulo: n.titulo, mensaje: n.mensaje, leida: true,
            reservaId: n.reservaId, hospedajeId: n.hospedajeId, creadoEn: n.creadoEn
        )
    }
}
