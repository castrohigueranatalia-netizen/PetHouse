//
//  ReservasRecibidasView.swift
//  Features/Anfitrion
//
//  🔴 `GET /api/hospedajes/:id/reservas` no existe hoy (ver `AnfitrionService` y
//  ARCHITECTURE_AUDIT.md §2.1 gap 🟡 #6). Vista mínima: solo lee y muestra el estado
//  "función pendiente" — no hay nada más que hacer aquí hasta que el backend la soporte.
//

import SwiftUI

@MainActor
@Observable
final class ReservasRecibidasViewModel {
    private(set) var reservas: [Reserva] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    private let service: AnfitrionServicing
    init(service: AnfitrionServicing = AnfitrionService()) { self.service = service }

    func cargar(hospedajeId: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            reservas = try await service.reservasRecibidas(hospedajeId: hospedajeId)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}

struct ReservasRecibidasView: View {
    let hospedaje: Hospedaje
    @State private var viewModel = ReservasRecibidasViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.reservas.isEmpty {
                PHLoadingStateView(mensaje: "Cargando reservas recibidas…")
            } else if let error = viewModel.error {
                PHErrorStateView(error: error) { Task { await viewModel.cargar(hospedajeId: hospedaje.id) } }
            } else if viewModel.reservas.isEmpty {
                PHEmptyStateView(systemImage: "calendar", titulo: "Sin reservas todavía", mensaje: "Las reservas que reciba \(hospedaje.titulo) aparecerán aquí.")
            } else {
                List(viewModel.reservas) { reserva in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reserva.codigo).phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                        if let desde = reserva.desde, let hasta = reserva.hasta {
                            Text("\(PHDate.displayFromAPIDateOnly(desde)) → \(PHDate.displayFromAPIDateOnly(hasta))")
                                .phText(PHFont.captionSM, color: PHColor.muted)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Reservas recibidas")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.cargar(hospedajeId: hospedaje.id) }
    }
}
