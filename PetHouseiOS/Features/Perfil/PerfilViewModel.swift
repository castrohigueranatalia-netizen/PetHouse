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

    private let mascotasService: MascotasServicing
    private let session: SessionStore

    public init(session: SessionStore, mascotasService: MascotasServicing = MascotasService()) {
        self.session = session
        self.mascotasService = mascotasService
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
