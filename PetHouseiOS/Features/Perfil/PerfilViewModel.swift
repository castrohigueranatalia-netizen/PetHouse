//
//  PerfilViewModel.swift
//  Features/Perfil
//
//  El perfil y las mascotas ya viven en `SessionStore` (se cargan en login/arranque desde
//  `GET /api/auth/me`) — este ViewModel solo agrega la posibilidad de refrescar bajo
//  demanda (pull-to-refresh) y expone el estado de "eliminar mascota", que sí depende de
//  un endpoint 🔴 pendiente (ver `MascotasService`).
//
//  También revisa si la solicitud de anfitrión del usuario se resolvió (aprobada o
//  rechazada) sin que él se haya enterado todavía — sin push notifications (ADR-7, fase 2),
//  esto se chequea cada vez que se abre el Perfil, no en tiempo real.
//

import Foundation

@MainActor
@Observable
public final class PerfilViewModel {
    public private(set) var isRefreshing = false
    public private(set) var eliminandoMascotaId: String?
    public private(set) var errorEliminarMascota: AppError?

    /// `!= nil` cuando la solicitud de anfitrión acaba de resolverse (estado aprobado o
    /// rechazado) y el usuario todavía no lo vio — PerfilView lo usa para mostrar un
    /// aviso. `marcarResolucionVista()` lo apaga y avisa al servidor para que no vuelva.
    public private(set) var resolucionVerificacion: VerificacionAnfitrion?

    private let mascotasService: MascotasServicing
    private let anfitrionService: AnfitrionServicing
    private let session: SessionStore

    public init(
        session: SessionStore,
        mascotasService: MascotasServicing = MascotasService(),
        anfitrionService: AnfitrionServicing = AnfitrionService()
    ) {
        self.session = session
        self.mascotasService = mascotasService
        self.anfitrionService = anfitrionService
    }

    public func refrescar() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await session.refrescarPerfilCompleto()
    }

    /// Silencioso a propósito si falla (sin conexión, etc.): no vale la pena mostrar un
    /// error encima del Perfil solo por no poder chequear un aviso.
    public func revisarResolucionVerificacion() async {
        guard let verificacion = try? await anfitrionService.obtenerVerificacion() else { return }
        if verificacion.estado != .pendiente && !verificacion.notificado {
            resolucionVerificacion = verificacion
        }
    }

    public func marcarResolucionVista() async {
        resolucionVerificacion = nil
        try? await anfitrionService.marcarVerificacionNotificada()
    }

    /// 🔴 `DELETE /api/mascotas/:id` no existe hoy — ver `MascotasService`. Se llama de
    /// todas formas; si el backend responde "ruta no encontrada", se muestra el estado
    /// de función pendiente en la vista en vez de fingir que se borró.
    public func eliminarMascota(_ mascota: Mascota) async {
        eliminandoMascotaId = mascota.id
        errorEliminarMascota = nil
        defer { eliminandoMascotaId = nil }
        do {
            try await mascotasService.eliminar(id: mascota.id)
            await session.refrescarPerfilCompleto()
        } catch let appError as AppError {
            errorEliminarMascota = appError
        } catch {
            errorEliminarMascota = .desconocido(error.localizedDescription)
        }
    }
}
