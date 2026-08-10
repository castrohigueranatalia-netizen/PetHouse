//
//  ConversacionesView.swift
//  Features/Chat
//

import SwiftUI

struct ConversacionesView: View {
    @State private var viewModel = ConversacionesViewModel()

    var body: some View {
        content
            .navigationTitle("Mensajes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PHLogo(height: 28)
                }
            }
            .task { await viewModel.cargar() }
            .refreshable { await viewModel.cargar() }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.conversaciones.isEmpty {
            PHLoadingStateView(mensaje: "Cargando conversaciones…")
        } else if let error = viewModel.error, viewModel.conversaciones.isEmpty {
            PHErrorStateView(error: error) { Task { await viewModel.cargar() } }
        } else if viewModel.conversaciones.isEmpty {
            PHEmptyStateView(
                systemImage: "message",
                titulo: "Sin conversaciones todavía",
                mensaje: "Escríbele a un anfitrión desde el detalle de un hospedaje para empezar a chatear."
            )
        } else {
            List(viewModel.conversaciones) { conversacion in
                NavigationLink(value: conversacion) {
                    filaConversacion(conversacion)
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: Conversacion.self) { conversacion in
                ChatDetailView(conversacion: conversacion)
            }
        }
    }

    private func filaConversacion(_ conversacion: Conversacion) -> some View {
        HStack(spacing: PHSpacing.s12) {
            PHAvatar(name: conversacion.otroNombre ?? "Usuario")

            VStack(alignment: .leading, spacing: 2) {
                Text(conversacion.otroNombre ?? "Usuario de PetHouse")
                    .phText(PHFont.bodyMD.weight(.semibold), color: PHColor.ink)
                Text(conversacion.ultimoMensaje ?? "Sin mensajes todavía")
                    .phText(PHFont.captionSM, color: PHColor.muted)
                    .lineLimit(1)
            }

            Spacer()

            if let noLeidos = conversacion.noLeidos, noLeidos > 0 {
                Text("\(noLeidos)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(PHColor.primary)
                    .clipShape(Circle())
                    .accessibilityLabel("\(noLeidos) mensajes sin leer")
            }
        }
        .padding(.vertical, 4)
    }
}
