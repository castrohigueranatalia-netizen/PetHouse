//
//  TicketDetalleView.swift
//  Features/Soporte
//

import SwiftUI

struct TicketDetalleView: View {
    let ticketId: String
    let asuntoInicial: String
    @State private var viewModel: TicketDetalleViewModel
    @FocusState private var campoActivo: Bool

    init(ticketId: String, asuntoInicial: String) {
        self.ticketId = ticketId
        self.asuntoInicial = asuntoInicial
        _viewModel = State(initialValue: TicketDetalleViewModel(ticketId: ticketId))
    }

    var body: some View {
        VStack(spacing: 0) {
            if let ticket = viewModel.ticket, ticket.estado == "resuelto" {
                Text("Este ticket ya fue resuelto — igual puedes escribir si sigue el problema.")
                    .phText(PHFont.captionSM, color: PHColor.muted)
                    .padding(PHSpacing.s12)
                    .frame(maxWidth: .infinity)
                    .background(PHColor.surfaceSoft)
            }

            if viewModel.isLoading && viewModel.mensajes.isEmpty {
                PHLoadingStateView(mensaje: "Cargando…")
            } else if let error = viewModel.error, viewModel.mensajes.isEmpty {
                PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
            } else if viewModel.mensajes.isEmpty {
                PHEmptyStateView(systemImage: "bubble.left", titulo: "Sin mensajes", mensaje: "Algo salió mal cargando este ticket.")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: PHSpacing.s8) {
                            ForEach(viewModel.mensajes) { mensaje in
                                burbuja(mensaje).id(mensaje.id)
                            }
                        }
                        .padding(PHSpacing.s16)
                    }
                    .onChange(of: viewModel.mensajes.count) {
                        if let ultimo = viewModel.mensajes.last {
                            withAnimation { proxy.scrollTo(ultimo.id, anchor: .bottom) }
                        }
                    }
                }
            }

            entrada
        }
        .background(PHColor.canvas)
        .navigationTitle(asuntoInicial)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.cargar() }
    }

    private func burbuja(_ mensaje: MensajeSoporte) -> some View {
        HStack {
            if !mensaje.esAdmin { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 2) {
                if mensaje.esAdmin {
                    Text("Soporte PetHouse")
                        .phText(PHFont.micro.weight(.semibold), color: PHColor.muted)
                }
                Text(mensaje.texto)
                    .phText(PHFont.bodyMD, color: mensaje.esAdmin ? PHColor.ink : .white)
            }
            .padding(.horizontal, PHSpacing.s12)
            .padding(.vertical, PHSpacing.s8)
            .background(mensaje.esAdmin ? PHColor.surfaceSoft : PHColor.primary)
            .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
            if mensaje.esAdmin { Spacer(minLength: 40) }
        }
    }

    private var entrada: some View {
        HStack(spacing: PHSpacing.s8) {
            TextField("Escribe un mensaje…", text: $viewModel.texto, axis: .vertical)
                .focused($campoActivo)
                .padding(.horizontal, PHSpacing.s12)
                .padding(.vertical, PHSpacing.s8)
                .background(PHColor.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.full, style: .continuous))
                .lineLimit(1...4)
                .accessibilityLabel("Mensaje")

            PHIconButton(systemImage: "paperplane.fill", accessibilityLabel: "Enviar mensaje") {
                Task { await viewModel.responder() }
            }
        }
        .padding(PHSpacing.s12)
        .background(.ultraThinMaterial)
    }
}
