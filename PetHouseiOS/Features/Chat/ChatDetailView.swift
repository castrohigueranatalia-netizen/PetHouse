//
//  ChatDetailView.swift
//  Features/Chat
//

import SwiftUI

struct ChatDetailView: View {
    let conversacion: Conversacion
    @State private var viewModel: ChatDetailViewModel
    @Environment(SessionStore.self) private var session
    @FocusState private var campoActivo: Bool

    init(conversacion: Conversacion) {
        self.conversacion = conversacion
        _viewModel = State(initialValue: ChatDetailViewModel(conversacion: conversacion))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.mensajes.isEmpty {
                PHLoadingStateView(mensaje: "Cargando mensajes…")
            } else if let error = viewModel.error, viewModel.mensajes.isEmpty {
                PHErrorStateView(error: error) { Task { await viewModel.iniciar() } }
            } else if viewModel.mensajes.isEmpty {
                PHEmptyStateView(systemImage: "message", titulo: "Sin mensajes todavía", mensaje: "Envía el primero.")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: PHSpacing.s8) {
                            ForEach(viewModel.mensajes) { mensaje in
                                burbuja(mensaje)
                                    .id(mensaje.id)
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
        .navigationTitle(conversacion.otroNombre ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.iniciar()
            // `iniciar()` ya marcó esta conversación como leída — refresca el badge de la
            // pestaña Mensajes para que baje sin esperar a volver a Conversaciones.
            await session.actualizarContadores()
        }
        .onDisappear { viewModel.detener() }
    }

    private func burbuja(_ mensaje: Mensaje) -> some View {
        let esMio = mensaje.remitenteId == session.usuario?.id
        return HStack {
            if esMio { Spacer(minLength: 40) }
            Text(mensaje.texto)
                .phText(PHFont.bodyMD, color: esMio ? .white : PHColor.ink)
                .padding(.horizontal, PHSpacing.s12)
                .padding(.vertical, PHSpacing.s8)
                .background(esMio ? PHColor.primary : PHColor.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
            if !esMio { Spacer(minLength: 40) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(esMio ? "Tú" : (conversacion.otroNombre ?? "Otro usuario")): \(mensaje.texto)")
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
                Task { await viewModel.enviar() }
            }
        }
        .padding(PHSpacing.s12)
        .background(.ultraThinMaterial)
    }
}
