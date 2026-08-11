//
//  AdminSolicitudDetailViewModel.swift
//  Features/Admin
//

import Foundation

@MainActor
@Observable
public final class AdminSolicitudDetailViewModel {
    public let solicitud: SolicitudAnfitrion

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var resuelto = false

    private let adminService: AdminServicing

    public init(solicitud: SolicitudAnfitrion, adminService: AdminServicing = AdminService()) {
        self.solicitud = solicitud
        self.adminService = adminService
    }

    public func aprobar() async {
        await resolver { try await $0.aprobar(solicitudId: solicitud.id) }
    }

    public func rechazar() async {
        await resolver { try await $0.rechazar(solicitudId: solicitud.id) }
    }

    private func resolver(_ accion: (AdminServicing) async throws -> Void) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            try await accion(adminService)
            resuelto = true
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
