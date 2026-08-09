//
//  ChatDetailViewModel.swift
//  Features/Chat
//
//  Chat por REST + polling (no hay WebSockets, decisión ya documentada como aceptable
//  para el MVP — ver ARCHITECTURE_AUDIT.md §6). Mientras la vista está visible, se
//  vuelve a pedir `GET /mensajes` cada ~5s con un `Task` que se cancela al desaparecer.
//

import Foundation

@MainActor
@Observable
public final class ChatDetailViewModel {
    public let conversacion: Conversacion

    public private(set) var mensajes: [Mensaje] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public var texto = ""
    public private(set) var enviando = false

    private let service: ChatServicing
    private var pollingTask: Task<Void, Never>?
    private let intervaloPolling: UInt64 = 5_000_000_000 // 5s

    public init(conversacion: Conversacion, service: ChatServicing = ChatService()) {
        self.conversacion = conversacion
        self.service = service
    }

    public func iniciar() async {
        await cargar(mostrarLoading: true)
        try? await service.marcarLeidas(conversacionId: conversacion.id)
        iniciarPolling()
    }

    public func detener() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func iniciarPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self.intervaloPolling)
                if Task.isCancelled { break }
                await self.cargar(mostrarLoading: false)
            }
        }
    }

    private func cargar(mostrarLoading: Bool) async {
        if mostrarLoading { isLoading = true }
        defer { if mostrarLoading { isLoading = false } }
        do {
            let nuevos = try await service.mensajes(conversacionId: conversacion.id)
            // Compara contenido completo, no solo la cantidad: un mensaje existente puede
            // cambiar de `leido` sin que se agregue ninguno nuevo (ej. el otro participante
            // abre el chat), y ese cambio se tiene que reflejar en la UI igual.
            if nuevos != mensajes {
                mensajes = nuevos
            }
            error = nil
        } catch let appError as AppError {
            if mostrarLoading { error = appError }
        } catch {
            if mostrarLoading { self.error = .desconocido(error.localizedDescription) }
        }
    }

    public func enviar() async {
        let contenido = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !contenido.isEmpty, !enviando else { return }
        enviando = true
        defer { enviando = false }
        do {
            let mensaje = try await service.enviar(conversacionId: conversacion.id, texto: contenido)
            mensajes.append(mensaje)
            texto = ""
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
