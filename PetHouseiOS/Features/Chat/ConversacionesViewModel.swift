//
//  ConversacionesViewModel.swift
//  Features/Chat
//

import Foundation

@MainActor
@Observable
public final class ConversacionesViewModel {
    public private(set) var conversaciones: [Conversacion] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    private let service: ChatServicing

    public init(service: ChatServicing = ChatService()) {
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            conversaciones = try await service.conversaciones()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
