//
//  CalendarioHospedajeViewModel.swift
//  Features/Anfitrion
//
//  Calendario mensual de un hospedaje propio: qué días ya tiene reservados, para que el
//  anfitrión los vea de un vistazo en vez de tener que leer la lista de solicitudes fecha
//  por fecha. Reusa GET /api/hospedajes/:id/reservas (mismos datos que ReservasRecibidasView,
//  ver AnfitrionService) — no hace falta ningún endpoint nuevo.
//

import Foundation

@MainActor
@Observable
public final class CalendarioHospedajeViewModel {
    public let hospedaje: Hospedaje

    public private(set) var reservas: [Reserva] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    /// El primer día del mes que se está mostrando — siempre normalizado a las 00:00 del
    /// día 1, para que sumar/restar meses no arrastre la hora del momento en que se abrió
    /// la pantalla.
    public private(set) var mesMostrado: Date

    private let service: AnfitrionServicing
    private let calendario = Calendar.current

    public init(hospedaje: Hospedaje, service: AnfitrionServicing = AnfitrionService()) {
        self.hospedaje = hospedaje
        self.service = service
        let ahora = Calendar.current.dateComponents([.year, .month], from: .now)
        self.mesMostrado = Calendar.current.date(from: ahora) ?? .now
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            reservas = try await service.reservasRecibidas(hospedajeId: hospedaje.id)
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
        guard let rangoDias = calendario.range(of: .day, in: .month, for: mesMostrado) else { return [] }
        let primerDiaSemana = calendario.component(.weekday, from: mesMostrado) // 1=domingo…7=sábado
        // Semana empieza en lunes: domingo(1) queda al final (offset 6), lunes(2) al principio (offset 0).
        let relleno = (primerDiaSemana + 5) % 7
        var dias: [Date?] = Array(repeating: nil, count: relleno)
        for numeroDia in rangoDias {
            if let fecha = calendario.date(byAdding: .day, value: numeroDia - 1, to: mesMostrado) {
                dias.append(fecha)
            }
        }
        while dias.count % 7 != 0 { dias.append(nil) }
        return dias
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
}
