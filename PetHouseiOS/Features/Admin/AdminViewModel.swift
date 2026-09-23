//
//  AdminViewModel.swift
//  Features/Admin
//
//  Panel de control: estadísticas generales (ver AdminView). La lista de solicitudes vive
//  en su propio ViewModel (AdminSolicitudesViewModel) — esta pantalla solo enlaza a ella.
//

import Foundation

@MainActor
@Observable
public final class AdminViewModel {
    public private(set) var estadisticas: EstadisticasAdmin?
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    private let adminService: AdminServicing

    public init(adminService: AdminServicing = AdminService()) {
        self.adminService = adminService
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            estadisticas = try await adminService.estadisticas()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
