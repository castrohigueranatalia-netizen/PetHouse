//
//  ActualizacionesReservaViewModel.swift
//  Features/Anfitrion
//
//  Composer + historial de las actualizaciones que el anfitrión publica MIENTRAS una reserva
//  está 'confirmada' (ver db/38-actualizaciones-reserva.sql) — el huésped las ve en su
//  detalle de reserva (ver ReservaDetailViewModel), pero acá el anfitrión también ve las que
//  ya publicó, no solo el formulario para agregar una nueva.
//

import Foundation

@MainActor
@Observable
public final class ActualizacionesReservaViewModel {
    public let reserva: Reserva

    public private(set) var actualizaciones: [ActualizacionReserva] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var publicando = false

    public var notas = ""
    public var fotos: [String] = []

    private let service: ReservasServicing
    private let imagenesService: ImagenesServicing

    public init(
        reserva: Reserva,
        service: ReservasServicing = ReservasService(),
        imagenesService: ImagenesServicing = ImagenesService()
    ) {
        self.reserva = reserva
        self.service = service
        self.imagenesService = imagenesService
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            actualizaciones = try await service.actualizaciones(reservaId: reserva.id)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    public var puedePublicar: Bool {
        (!notas.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !fotos.isEmpty) && !publicando
    }

    /// Pasado a `PHAdjuntarFotos` — mismo patrón que `MascotaFormViewModel.subirFoto`/
    /// `PublicarHospedajeViewModel.subirFoto`.
    public func subirFoto(_ datos: Data) async -> String? {
        try? await imagenesService.subir(datos: datos, nombreArchivo: "actualizacion.jpg", mimeType: "image/jpeg")
    }

    public func publicar() async {
        guard puedePublicar else { return }
        publicando = true
        error = nil
        defer { publicando = false }
        do {
            let notasLimpias = notas.trimmingCharacters(in: .whitespacesAndNewlines)
            let nueva = try await service.crearActualizacion(
                reservaId: reserva.id,
                notas: notasLimpias.isEmpty ? nil : notasLimpias,
                fotos: fotos
            )
            // Se agrega al final, no se recarga toda la lista — evita perder de vista lo que
            // ya se estaba viendo mientras se publicaba.
            actualizaciones.append(nueva)
            notas = ""
            fotos = []
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
