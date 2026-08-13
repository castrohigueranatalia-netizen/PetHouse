//
//  NuevaReservaViewModel.swift
//  Features/Reserva
//
//  El precio final SIEMPRE lo calcula el servidor (`noches`/`total` son columnas
//  GENERATED en Postgres, ver ARCHITECTURE_AUDIT.md §3 — "cero riesgo de
//  desincronización cliente/servidor"). El cálculo de aquí es solo un ESTIMADO para
//  mostrar antes de confirmar, replicando la fórmula real
//  (`limpieza = round(precio*0.6)`, `servicio = round(precio*noches*0.1)`,
//  ver `pethouse-api/src/routes/reservas.js`); el monto que se muestra en la
//  confirmación final es siempre el que devuelve `POST /api/reservas`, no este estimado.
//
//  Sin cobro real (ADR-7, decisión de producto ya cerrada): la reserva se confirma sin
//  pasarela de pago — el mensaje de éxito lo deja explícito.
//
//  El huésped elige mascotas CONCRETAS (no solo un número): el backend guarda ese vínculo
//  (tabla reserva_mascotas) para que el anfitrión vea raza/notas antes de aceptar o
//  rechazar la solicitud — ver ReservasRecibidasView.
//

import Foundation

@MainActor
@Observable
public final class NuevaReservaViewModel {
    public let hospedaje: Hospedaje
    public let mascotasDisponibles: [Mascota]

    public var desde: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    public var hasta: Date = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
    public var mascotaIdsSeleccionadas: Set<String> = []

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var reservaConfirmada: CrearReservaResponse?

    private let service: ReservasServicing

    public init(hospedaje: Hospedaje, mascotasDisponibles: [Mascota], service: ReservasServicing = ReservasService()) {
        self.hospedaje = hospedaje
        self.mascotasDisponibles = mascotasDisponibles
        self.service = service
        if let primera = mascotasDisponibles.first {
            mascotaIdsSeleccionadas = [primera.id]
        }
    }

    public var maxMascotas: Int { hospedaje.maxMascotas ?? 1 }

    public var noches: Int {
        max(0, Calendar.current.dateComponents([.day], from: desde, to: hasta).day ?? 0)
    }

    public var fechasValidas: Bool {
        noches > 0
    }

    public func alternar(_ mascota: Mascota) {
        if mascotaIdsSeleccionadas.contains(mascota.id) {
            mascotaIdsSeleccionadas.remove(mascota.id)
        } else if mascotaIdsSeleccionadas.count < maxMascotas {
            mascotaIdsSeleccionadas.insert(mascota.id)
        }
    }

    /// Estimado — ver el comentario del archivo. No es el monto final.
    public var estimadoLimpieza: Double {
        (hospedaje.precioNoche * 0.6).rounded()
    }

    public var estimadoServicio: Double {
        (hospedaje.precioNoche * Double(noches) * 0.1).rounded()
    }

    public var estimadoTotal: Double {
        hospedaje.precioNoche * Double(noches) + estimadoLimpieza + estimadoServicio
    }

    public var puedeReservar: Bool {
        fechasValidas && !mascotaIdsSeleccionadas.isEmpty && mascotaIdsSeleccionadas.count <= maxMascotas && !isLoading
    }

    public func confirmar() async {
        guard puedeReservar else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let respuesta = try await service.crear(
                hospedajeId: hospedaje.id,
                desde: PHDate.toAPIDateOnly(desde),
                hasta: PHDate.toAPIDateOnly(hasta),
                mascotaIds: Array(mascotaIdsSeleccionadas)
            )
            reservaConfirmada = respuesta
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
