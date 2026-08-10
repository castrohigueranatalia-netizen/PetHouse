//
//  PerfilViewModel.swift
//  Features/Perfil
//
//  El perfil y las mascotas ya viven en `SessionStore` (se cargan en login/arranque desde
//  `GET /api/auth/me`) — este ViewModel solo agrega la posibilidad de refrescar bajo
//  demanda (pull-to-refresh) y expone el estado de "eliminar mascota", que sí depende de
//  un endpoint 🔴 pendiente (ver `MascotasService`).
//

import Foundation

@MainActor
@Observable
public final class PerfilViewModel {
    public private(set) var isRefreshing = false
    public private(set) var eliminandoMascotaId: String?
    public private(set) var errorEliminarMascota: AppError?
    public private(set) var activandoAnfitrion = false
    public private(set) var errorActivarAnfitrion: String?

    private let mascotasService: MascotasServicing
    private let authService: AuthServicing
    private let session: SessionStore

    public init(
        session: SessionStore, mascotasService: MascotasServicing = MascotasService(),
        authService: AuthServicing = AuthService()
    ) {
        self.session = session
        self.mascotasService = mascotasService
        self.authService = authService
    }

    /// "Conviértete en anfitrión" — aditivo (ver Usuario.esAnfitrion), no crea otra cuenta.
    public func convertirseEnAnfitrion() async {
        activandoAnfitrion = true
        errorActivarAnfitrion = nil
        defer { activandoAnfitrion = false }
        do {
            try await session.convertirseEnAnfitrion()
        } catch let appError as AppError {
            errorActivarAnfitrion = appError.localizedDescription
        } catch {
            errorActivarAnfitrion = error.localizedDescription
        }
    }

    public func refrescar() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await session.refrescarPerfilCompleto()
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
