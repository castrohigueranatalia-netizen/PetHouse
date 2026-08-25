//
//  ReportarViewModel.swift
//  Features/Denuncias
//
//  Un solo formulario reutilizable para las 3 formas de reportar que pide la app: un
//  anfitrión (desde su hospedaje), cualquier usuario (ej. un huésped desde una solicitud de
//  reserva) o un mensaje puntual del chat — ver ReportarSheet.swift y
//  pethouse-api/src/routes/denuncias.js.
//

import Foundation

@MainActor
@Observable
public final class ReportarViewModel {
    public let usuarioDenunciadoId: String
    public let usuarioDenunciadoNombre: String
    public let tipo: TipoDenuncia
    public let mensajeId: String?
    public let mensajeTexto: String?
    public let hospedajeId: String?

    public var motivo: MotivoDenuncia?
    public var comentario: String = ""

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var enviado = false

    private let service: DenunciasServicing

    public init(
        usuarioDenunciadoId: String, usuarioDenunciadoNombre: String, tipo: TipoDenuncia,
        mensajeId: String? = nil, mensajeTexto: String? = nil, hospedajeId: String? = nil,
        service: DenunciasServicing = DenunciasService()
    ) {
        self.usuarioDenunciadoId = usuarioDenunciadoId
        self.usuarioDenunciadoNombre = usuarioDenunciadoNombre
        self.tipo = tipo
        self.mensajeId = mensajeId
        self.mensajeTexto = mensajeTexto
        self.hospedajeId = hospedajeId
        self.service = service
    }

    public var puedeEnviar: Bool {
        motivo != nil && !isLoading
    }

    public func enviar() async {
        guard let motivo, puedeEnviar else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            try await service.crear(CrearDenunciaRequest(
                usuarioDenunciadoId: usuarioDenunciadoId,
                tipo: tipo,
                motivo: motivo,
                comentario: comentario.isEmpty ? nil : comentario,
                mensajeId: mensajeId,
                hospedajeId: hospedajeId
            ))
            enviado = true
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
