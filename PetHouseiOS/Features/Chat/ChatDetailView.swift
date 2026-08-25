//
//  ChatDetailView.swift
//  Features/Chat
//

import SwiftUI
import PhotosUI

struct ChatDetailView: View {
    let conversacion: Conversacion
    @State private var viewModel: ChatDetailViewModel
    @Environment(SessionStore.self) private var session
    @FocusState private var campoActivo: Bool
    @State private var mostrarReportarPersona = false
    @State private var mensajeAReportar: Mensaje?
    @State private var fotoSeleccionada: PhotosPickerItem?
    @State private var fotoAmpliada: FotoVisorItem?

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
        .onChange(of: fotoSeleccionada) { _, item in
            guard let item else { return }
            Task {
                if let datos = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.enviarFoto(datos)
                }
                fotoSeleccionada = nil
            }
        }
        .fullScreenCover(item: $fotoAmpliada) { item in
            PHVisorFotos(urls: item.urls, indiceInicial: item.indiceInicial)
        }
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
                textoCitado: mensaje.texto ?? mensaje.fotoUrl.map { _ in "📷 Foto" }
            )
        }
    }

    private func burbuja(_ mensaje: Mensaje) -> some View {
        let esMio = mensaje.remitenteId == session.usuario?.id
        return HStack {
            if esMio { Spacer(minLength: 40) }
            VStack(alignment: esMio ? .trailing : .leading, spacing: PHSpacing.s4) {
                if let fotoUrl = mensaje.fotoUrl {
                    Button {
                        fotoAmpliada = FotoVisorItem(urls: [fotoUrl])
                    } label: {
                        PHCachedAsyncImage(urlString: MediaURL.resolver(fotoUrl)) {
                            Rectangle().fill(PHColor.surfaceStrong)
                        }
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                if let texto = mensaje.texto, !texto.isEmpty {
                    Text(texto)
                        .phText(PHFont.bodyMD, color: esMio ? .white : PHColor.ink)
                        .padding(.horizontal, PHSpacing.s12)
                        .padding(.vertical, PHSpacing.s8)
                        .background(esMio ? PHColor.primary : PHColor.surfaceSoft)
                        .clipShape(RoundedRectangle(cornerRadius: PHRadius.md, style: .continuous))
                }
            }
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
        .accessibilityLabel("\(esMio ? "Tú" : (conversacion.otroNombre ?? "Otro usuario")): \(mensaje.texto ?? "foto")")
    }

    private var entrada: some View {
        HStack(spacing: PHSpacing.s8) {
            PhotosPicker(selection: $fotoSeleccionada, matching: .images) {
                if viewModel.subiendoFoto {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(PHColor.primary)
                }
            }
            .disabled(viewModel.subiendoFoto)
            .accessibilityLabel("Adjuntar foto")

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
