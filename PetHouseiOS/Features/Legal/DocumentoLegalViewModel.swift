//
//  DocumentoLegalViewModel.swift
//  Features/Legal
//

import Foundation

@MainActor
@Observable
public final class DocumentoLegalViewModel {
    public let tipo: TipoDocumentoLegal
    public private(set) var contenido: String?
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    private let service: LegalServicing

    public init(tipo: TipoDocumentoLegal, service: LegalServicing = LegalService()) {
        self.tipo = tipo
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            contenido = try await service.documento(tipo).contenido
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
