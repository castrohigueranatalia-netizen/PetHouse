//
//  ReportarViewModel.swift
//  Features/Denuncias
//
//  Un solo formulario reutilizable para las formas de reportar que pide la app: un
//  anfitrión (desde su hospedaje), cualquier usuario (ej. un huésped desde una solicitud de
//  reserva), un mensaje puntual del chat o una reseña — ver ReportarSheet.swift y
//  pethouse-api/src/routes/denuncias.js.
//

import Foundation

@MainActor
@Observable
public final class ReportarViewModel {
    /// `nil` solo es válido para `.resena` — el servidor lo resuelve a partir de
    /// `resenaId` (ver CrearDenunciaRequest).
    public let usuarioDenunciadoId: String?
    public let usuarioDenunciadoNombre: String
    public let tipo: TipoDenuncia
    public let mensajeId: String?
    public let resenaId: String?
    /// Vista previa de lo que se está reportando (el texto del mensaje o de la reseña) —
    /// solo para mostrarla citada en el formulario, el servidor guarda su propia copia
    /// independiente al recibir la denuncia.
    public let textoCitado: String?
    public let hospedajeId: String?

    public var motivo: MotivoDenuncia?
    public var comentario: String = ""

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var enviado = false

    private let service: DenunciasServicing

    public init(
        usuarioDenunciadoId: String? = nil, usuarioDenunciadoNombre: String, tipo: TipoDenuncia,
        mensajeId: String? = nil, resenaId: String? = nil, textoCitado: String? = nil, hospedajeId: String? = nil,
        service: DenunciasServicing = DenunciasService()
    ) {
        self.usuarioDenunciadoId = usuarioDenunciadoId
        self.usuarioDenunciadoNombre = usuarioDenunciadoNombre
        self.tipo = tipo
        self.mensajeId = mensajeId
        self.resenaId = resenaId
        self.textoCitado = textoCitado
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
                hospedajeId: hospedajeId,
                resenaId: resenaId
            ))
            enviado = true
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
