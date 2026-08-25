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
    @State private var mostrarReportarPersona = false
    @State private var mensajeAReportar: Mensaje?

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
        .toolbar {
            if conversacion.otroId != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    PHIconButton(systemImage: "flag", accessibilityLabel: "Reportar a \(conversacion.otroNombre ?? "esta persona")") {
                        mostrarReportarPersona = true
                    }
                }
            }
        }
        .task {
            await viewModel.iniciar()
            // `iniciar()` ya marcó esta conversación como leída — descuenta del badge de la
            // pestaña Mensajes lo que tenía sin leer, sin pedir todas las conversaciones de
            // nuevo por red solo para recalcular una resta.
            session.marcarConversacionLeida(conversacion)
        }
        .onDisappear { viewModel.detener() }
        .sheet(isPresented: $mostrarReportarPersona) {
            if let otroId = conversacion.otroId {
                ReportarSheet(
                    usuarioDenunciadoId: otroId,
                    usuarioDenunciadoNombre: conversacion.otroNombre ?? "Usuario",
                    tipo: .usuario
                )
            }
        }
        .sheet(item: $mensajeAReportar) { mensaje in
            ReportarSheet(
                usuarioDenunciadoId: mensaje.remitenteId,
                usuarioDenunciadoNombre: conversacion.otroNombre ?? "Usuario",
                tipo: .mensaje,
                mensajeId: mensaje.id,
                mensajeTexto: mensaje.texto
            )
        }
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
                // Solo mensajes ajenos: no tiene sentido reportarse un mensaje propio.
                .contextMenu {
                    if !esMio {
                        Button(role: .destructive) { mensajeAReportar = mensaje } label: {
                            Label("Reportar mensaje", systemImage: "flag")
                        }
                    }
                }
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
