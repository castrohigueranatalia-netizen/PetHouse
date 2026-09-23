//
//  ResponderResenaViewModel.swift
//  Features/HospedajeDetail
//
//  El anfitrión dueño del hospedaje responde públicamente a una reseña — ver
//  db/33-respuesta-resena.sql y ResenasService.responder(...). Una sola respuesta por
//  reseña: si ya existía, este mismo formulario la reemplaza (no es un hilo).
//

import Foundation

@MainActor
@Observable
public final class ResponderResenaViewModel {
    public let hospedajeId: String
    public let resenaId: String

    public var respuesta: String
    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var enviado = false

    private let service: ResenasServicing
    private let alGuardar: (Resena) -> Void

    public init(
        hospedajeId: String, resenaId: String, respuestaExistente: String? = nil,
        service: ResenasServicing = ResenasService(), alGuardar: @escaping (Resena) -> Void
    ) {
        self.hospedajeId = hospedajeId
        self.resenaId = resenaId
        self.respuesta = respuestaExistente ?? ""
        self.service = service
        self.alGuardar = alGuardar
    }

    public var puedeEnviar: Bool {
        !respuesta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    public func enviar() async {
        guard puedeEnviar else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let actualizada = try await service.responder(
                hospedajeId: hospedajeId,
                resenaId: resenaId,
                respuesta: respuesta.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            alGuardar(actualizada)
            enviado = true
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
