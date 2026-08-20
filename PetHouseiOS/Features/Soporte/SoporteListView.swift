//
//  SoporteListView.swift
//  Features/Soporte
//

import SwiftUI

struct SoporteListView: View {
    @State private var viewModel = SoporteListViewModel()
    @State private var mostrarNuevoTicket = false

    var body: some View {
        content
            .background(PHColor.canvas)
            .navigationTitle("Soporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    PHIconButton(systemImage: "plus", accessibilityLabel: "Nuevo ticket") {
                        mostrarNuevoTicket = true
                    }
                }
            }
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
            .sheet(isPresented: $mostrarNuevoTicket) {
                nuevoTicketSheet
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.tickets.isEmpty {
            PHLoadingStateView(mensaje: "Cargando…")
        } else if let error = viewModel.error, viewModel.tickets.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.tickets.isEmpty {
            PHEmptyStateView(
                systemImage: "bubble.left.and.bubble.right",
                titulo: "Sin mensajes de soporte",
                mensaje: "¿Tienes una pregunta o un problema? Escríbenos y te respondemos acá mismo.",
                accionTitulo: "Nuevo ticket"
            ) {
                mostrarNuevoTicket = true
            }
        } else {
            List(viewModel.tickets) { ticket in
                NavigationLink(value: ticket) {
                    filaTicket(ticket)
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: TicketSoporte.self) { ticket in
                TicketDetalleView(ticketId: ticket.id, asuntoInicial: ticket.asunto)
            }
        }
    }

    private func filaTicket(_ ticket: TicketSoporte) -> some View {
        HStack(spacing: PHSpacing.s12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ticket.asunto)
                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                Text(PHDate.displayFromTimestamp(ticket.actualizadoEn))
                    .phText(PHFont.captionSM, color: PHColor.muted)
            }
            Spacer()
            PHBadge(
                ticket.estado == "resuelto" ? "Resuelto" : "Abierto",
                style: ticket.estado == "resuelto" ? .success : .warning
            )
        }
        .padding(.vertical, 4)
    }

    private var nuevoTicketSheet: some View {
        NavigationStack {
            Form {
                Section("Asunto") {
                    TextField("Ej. No me llegó el código de verificación", text: $viewModel.nuevoAsunto)
                }
                Section("Mensaje") {
                    TextField("Cuéntanos qué pasó…", text: $viewModel.nuevoMensaje, axis: .vertical)
                        .lineLimit(4...8)
                }
                if let error = viewModel.errorCrear {
                    Text(error.localizedDescription)
                        .phText(PHFont.bodySM, color: PHColor.error)
                }
            }
            .navigationTitle("Nuevo ticket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHTextButton("Cancelar") { mostrarNuevoTicket = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    PHTextButton("Enviar") {
                        Task {
                            if await viewModel.crearTicket() { mostrarNuevoTicket = false }
                        }
                    }
                    .disabled(!viewModel.puedeCrear)
                }
            }
        }
    }
}
