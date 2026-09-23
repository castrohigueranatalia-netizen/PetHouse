//
//  AdminSolicitudesViewModel.swift
//  Features/Admin
//

import Foundation

@MainActor
@Observable
public final class AdminSolicitudesViewModel {
    public var filtro: EstadoVerificacion? = .pendiente

    public private(set) var solicitudes: [SolicitudAnfitrion] = []
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
            solicitudes = try await adminService.solicitudes(estado: filtro)
        } catch let appError as AppError {
            error = appError
            solicitudes = []
        } catch {
            self.error = .desconocido(error.localizedDescription)
            solicitudes = []
        }
    }

    public func cambiarFiltro(_ nuevo: EstadoVerificacion?) {
        guard nuevo != filtro else { return }
        filtro = nuevo
        Task { await cargar() }
    }
}
