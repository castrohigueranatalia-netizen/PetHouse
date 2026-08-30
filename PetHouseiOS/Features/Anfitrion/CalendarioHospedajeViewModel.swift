//
//  CalendarioHospedajeViewModel.swift
//  Features/Anfitrion
//
//  Calendario mensual de un hospedaje propio: qué días ya tiene reservados, para que el
//  anfitrión los vea de un vistazo en vez de tener que leer la lista de solicitudes fecha
//  por fecha. Reusa GET /api/hospedajes/:id/reservas (mismos datos que ReservasRecibidasView,
//  ver AnfitrionService). También trae y administra las fechas que el anfitrión bloqueó a
//  mano, sin reserva real (ver GET/POST/DELETE /api/hospedajes/:id/fechas-bloqueadas y
//  db/34-fechas-bloqueadas.sql).
//

import Foundation

@MainActor
@Observable
public final class CalendarioHospedajeViewModel {
    public let hospedaje: Hospedaje

    public private(set) var reservas: [Reserva] = []
    public private(set) var fechasBloqueadas: [FechaBloqueada] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var bloqueando = false

    /// El primer día del mes que se está mostrando — siempre normalizado a las 00:00 del
    /// día 1, para que sumar/restar meses no arrastre la hora del momento en que se abrió
    /// la pantalla.
    public private(set) var mesMostrado: Date

    private let service: AnfitrionServicing
    private let hospedajesService: HospedajesServicing
    private let calendario = Calendar.current

    public init(
        hospedaje: Hospedaje, service: AnfitrionServicing = AnfitrionService(),
        hospedajesService: HospedajesServicing = HospedajesService()
    ) {
        self.hospedaje = hospedaje
        self.service = service
        self.hospedajesService = hospedajesService
        let ahora = Calendar.current.dateComponents([.year, .month], from: .now)
        self.mesMostrado = Calendar.current.date(from: ahora) ?? .now
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            async let reservasTask = service.reservasRecibidas(hospedajeId: hospedaje.id)
            async let bloqueosTask = hospedajesService.fechasBloqueadas(hospedajeId: hospedaje.id)
            reservas = try await reservasTask
            fechasBloqueadas = try await bloqueosTask
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    /// Bloquea un rango nuevo (ver `BloquearFechasSheet`) — `hasta` es exclusiva, mismo
    /// criterio que en una reserva. El servidor rechaza (409) si se cruza con una reserva
    /// real o con otro bloqueo ya creado.
    public func bloquear(desde: Date, hasta: Date, motivo: String) async -> Bool {
        bloqueando = true
        defer { bloqueando = false }
        do {
            let nuevo = try await hospedajesService.bloquearFechas(
                hospedajeId: hospedaje.id,
                desde: PHDate.toAPIDateOnly(desde),
                hasta: PHDate.toAPIDateOnly(hasta),
                motivo: motivo.isEmpty ? nil : motivo
            )
            fechasBloqueadas.append(nuevo)
            return true
        } catch let appError as AppError {
            error = appError
            return false
        } catch {
            self.error = .desconocido(error.localizedDescription)
            return false
        }
    }

    /// Quita un bloqueo (el día vuelve a estar disponible para reservar).
    public func desbloquear(_ bloqueo: FechaBloqueada) async {
        do {
            try await hospedajesService.desbloquearFechas(hospedajeId: hospedaje.id, bloqueoId: bloqueo.id)
            fechasBloqueadas.removeAll { $0.id == bloqueo.id }
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    public func mesAnterior() {
        mesMostrado = calendario.date(byAdding: .month, value: -1, to: mesMostrado) ?? mesMostrado
    }

    public func mesSiguiente() {
        mesMostrado = calendario.date(byAdding: .month, value: 1, to: mesMostrado) ?? mesMostrado
    }

    /// Los 42 casilleros de la grilla (6 semanas x 7 días, empezando en lunes) — `nil` para
    /// los días de relleno antes del 1 y después del último día del mes.
    public var diasDeLaGrilla: [Date?] {
        CalendarioMes.diasDeLaGrilla(paraMes: mesMostrado, calendario: calendario)
    }

    /// Comparación por texto (`YYYY-MM-DD`), no por `Date` — evita cualquier lío de huso
    /// horario entre cómo se arma la grilla y cómo llegan `desde`/`hasta` del servidor (ver
    /// el comentario de `PHDate.apiDateOnly` sobre por qué las fechas de reserva son "de
    /// calendario", no un instante).
    public func reserva(en dia: Date) -> Reserva? {
        let diaTexto = PHDate.toAPIDateOnly(dia)
        return reservas.first {
            guard let desde = $0.desde, let hasta = $0.hasta else { return false }
            guard $0.estado == .confirmada || $0.estado == .pendiente else { return false }
            return diaTexto >= desde && diaTexto < hasta
        }
    }

    /// Mismo criterio que `reserva(en:)`, para fechas bloqueadas a mano.
    public func bloqueo(en dia: Date) -> FechaBloqueada? {
        let diaTexto = PHDate.toAPIDateOnly(dia)
        return fechasBloqueadas.first { diaTexto >= $0.desde && diaTexto < $0.hasta }
    }

    /// `true` si el día ya tiene una reserva o ya está bloqueado — lo usa
    /// `BloquearFechasSheet` (con `PHSelectorRangoFechas`) para no dejar elegir un rango que
    /// se cruce con ninguno de los dos.
    public func diaOcupado(_ dia: Date) -> Bool {
        reserva(en: dia) != nil || bloqueo(en: dia) != nil
    }
}
