//
//  AnfitrionDashboardViewModel.swift
//  Features/Anfitrion
//
//  Junta dos llamadas que ya existían por separado (`AnfitrionServicing.misHospedajes` y
//  `.historial`, ver GET /api/hospedajes/mios y GET /api/hospedajes/mios/reservas) para
//  calcular, del lado del cliente, las métricas del dashboard del anfitrión — no hay
//  endpoint nuevo de "estadísticas": todo sale de sumar/filtrar lo que ya devuelve el
//  servidor, igual que el estimado de precio en NuevaReservaViewModel.
//

import Foundation

/// Un punto de la gráfica de "Ingresos por mes" (ver `AnfitrionDashboardViewModel.ingresosPorMes`).
public struct IngresoMensual: Identifiable {
    public var id: Date { mes }
    public let mes: Date
    public let monto: Double
}

/// Una fila de "Tus hospedajes" (ver `AnfitrionDashboardViewModel.resumenPorHospedaje`) —
/// solo se muestra cuando hay más de uno, para comparar cuál rinde mejor.
public struct ResumenHospedaje: Identifiable {
    public let id: String
    public let hospedaje: Hospedaje
    public let estadias: Int
    public let ganado: Double
}

/// A dónde lleva tocar una recomendación — cada regla en `recomendaciones` sabe exactamente
/// qué corrige y elige la acción que va DIRECTO a esa solución, no a una pantalla genérica:
///  - `.editar`: el dato que falta (fotos, precio de día, descripción, servicios) se llena
///    en el formulario de publicar/editar — ver `AnfitrionDashboardView`.
///  - `.verHospedaje`: para "pausado", cuyo botón de reactivar vive en el detalle del
///    hospedaje (`HospedajeDetailView.barraAnfitrion`), no en el formulario de edición.
///  - `.verReservasRecibidas`: solicitudes pendientes de UN hospedaje concreto — directo a
///    aceptar/rechazar, sin pasar por el detalle primero.
///  - `.publicarHospedaje`: cuando el anfitrión todavía no tiene ningún hospedaje.
public enum AccionRecomendacion: Hashable {
    case editar(Hospedaje)
    case verHospedaje(Hospedaje)
    case verReservasRecibidas(Hospedaje)
    case publicarHospedaje
}

/// Una sugerencia concreta y accionable ("agrega fotos a X"), no una idea genérica — cada
/// una nace de un chequeo real contra los datos de un hospedaje propio o del historial de
/// solicitudes. Sin backend de analítica de búsquedas: las reglas usan solo lo que el
/// anfitrión ya puede ver y corregir él mismo.
public struct RecomendacionAnfitrion: Identifiable, Hashable {
    public let id = UUID()
    public let icono: String
    public let texto: String
    public let accion: AccionRecomendacion
}

@MainActor
@Observable
public final class AnfitrionDashboardViewModel {
    public private(set) var isLoading = false
    public private(set) var error: AppError?

    public private(set) var hospedajes: [Hospedaje] = []
    public private(set) var historial: [Reserva] = []

    private let service: AnfitrionServicing

    public init(service: AnfitrionServicing = AnfitrionService()) {
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            // En paralelo — son dos peticiones independientes, no hay razón para esperar una
            // antes de pedir la otra.
            async let hospedajesTask = service.misHospedajes()
            async let historialTask = service.historial()
            hospedajes = try await hospedajesTask
            historial = try await historialTask
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    /// Se llama tras editar/reactivar un hospedaje desde una de las recomendaciones (ver
    /// `AnfitrionDashboardView`) — sin esto, la lista de sugerencias seguiría mostrando la
    /// misma recomendación ya resuelta hasta que se recargue toda la pantalla.
    public func guardarLocal(_ hospedaje: Hospedaje) {
        if let indice = hospedajes.firstIndex(where: { $0.id == hospedaje.id }) {
            hospedajes[indice] = hospedaje
        } else {
            hospedajes.insert(hospedaje, at: 0)
        }
    }

    /// Solo estadías que YA ocurrieron — 'pendiente'/'confirmada' son a futuro (o esperando
    /// respuesta), no algo que el anfitrión ya "hospedó" o "ganó" de verdad todavía.
    private var completadas: [Reserva] {
        historial.filter { $0.estado == .completada }
    }

    public var totalMascotasHospedadas: Int {
        completadas.reduce(0) { $0 + ($1.mascotas ?? 0) }
    }

    /// `montoAnfitrion` (ya descontada la comisión de PetHouse, ver db/27-comision.sql) — lo
    /// que de verdad le queda al anfitrión, no el total que pagó el huésped. Con `total` como
    /// respaldo por si alguna fila muy vieja no tiene el JOIN a `pagos` resuelto.
    public var totalGanado: Double {
        completadas.reduce(0) { $0 + ($1.montoAnfitrion ?? $1.total ?? 0) }
    }

    public var totalEstadias: Int { completadas.count }

    /// Ingresos agrupados por mes de llegada (`desde`), para la gráfica de barras del
    /// dashboard — se muestran los últimos 6 meses con al menos una estadía completada, en
    /// orden cronológico. Usa `desde` (no `creadoEn`) porque es cuándo de verdad ocurrió la
    /// estadía que generó ese ingreso, no cuándo se hizo la reserva.
    public var ingresosPorMes: [IngresoMensual] {
        var acumulado: [Date: Double] = [:]
        let calendario = Calendar.current
        for reserva in completadas {
            guard let desde = reserva.desde, let fecha = PHDate.apiDateOnly.date(from: desde) else { continue }
            guard let inicioMes = calendario.date(from: calendario.dateComponents([.year, .month], from: fecha)) else { continue }
            acumulado[inicioMes, default: 0] += reserva.montoAnfitrion ?? reserva.total ?? 0
        }
        return acumulado
            .sorted { $0.key < $1.key }
            .suffix(6)
            .map { IngresoMensual(mes: $0.key, monto: $0.value) }
    }

    /// Una fila por hospedaje propio, con cuánto ha ganado y cuántas estadías completó cada
    /// uno — para comparar cuál rinde mejor cuando el anfitrión tiene más de uno. Ordenados
    /// de mayor a menor ganancia.
    public var resumenPorHospedaje: [ResumenHospedaje] {
        hospedajes.map { hospedaje in
            let propias = completadas.filter { $0.hospedajeId == hospedaje.id }
            let ganado = propias.reduce(0) { $0 + ($1.montoAnfitrion ?? $1.total ?? 0) }
            return ResumenHospedaje(id: hospedaje.id, hospedaje: hospedaje, estadias: propias.count, ganado: ganado)
        }
        .sorted { $0.ganado > $1.ganado }
    }

    /// Consejo del día, rotando entre unos pocos fijos — sin backend de analítica de qué le
    /// falta específicamente a la cuenta (eso ya lo cubren `recomendaciones`), así que son
    /// generales pero reales: cosas que de verdad ayudan a recibir más reservas. Se elige
    /// por el día del año (no al azar en cada apertura) para que no cambie cada vez que se
    /// entra al dashboard el mismo día.
    public var tipDelDia: String {
        let tips = [
            "Los hospedajes con fotos reciben más reservas que los que no tienen ninguna.",
            "Responder rápido en el chat genera más confianza en quien te está escribiendo.",
            "Ofrecer la opción de reservar por un solo día te hace aparecer en más búsquedas.",
            "Una descripción completa y honesta genera más confianza que una corta.",
            "Mantener tu calendario de fechas bloqueadas al día evita solicitudes para fechas que no puedes recibir.",
            "Las fotos con buena luz natural transmiten más confianza que las oscuras."
        ]
        let dia = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return tips[dia % tips.count]
    }

    /// Solicitudes 'pendiente' agrupadas por hospedaje — cada grupo se convierte en UNA
    /// recomendación tocable que lleva directo a resolver las de ESE hospedaje (ver
    /// `recomendaciones`), en vez de un aviso genérico sin adónde llevar al tocarlo.
    private var pendientesPorHospedaje: [(hospedaje: Hospedaje, cantidad: Int)] {
        var conteo: [String: Int] = [:]
        for reserva in historial where reserva.estado == .pendiente {
            guard let hospedajeId = reserva.hospedajeId else { continue }
            conteo[hospedajeId, default: 0] += 1
        }
        return hospedajes.compactMap { hospedaje in
            guard let cantidad = conteo[hospedaje.id], cantidad > 0 else { return nil }
            return (hospedaje, cantidad)
        }
    }

    /// Reglas simples, cada una independiente — no hay "la mejor sugerencia", se muestran
    /// todas las que apliquen. Recorridas en el mismo orden en que un anfitrión revisaría su
    /// ficha de arriba hacia abajo (fotos → precio → descripción → servicios → estado).
    public var recomendaciones: [RecomendacionAnfitrion] {
        var lista: [RecomendacionAnfitrion] = []

        for hospedaje in hospedajes {
            if (hospedaje.fotos ?? []).isEmpty {
                lista.append(RecomendacionAnfitrion(
                    icono: "photo.on.rectangle",
                    texto: "Agrega fotos a “\(hospedaje.titulo)” — los hospedajes con fotos reciben más reservas.",
                    accion: .editar(hospedaje)
                ))
            }
            if hospedaje.precioDia == nil {
                lista.append(RecomendacionAnfitrion(
                    icono: "sun.max",
                    texto: "Ofrece la opción de reservar por un solo día en “\(hospedaje.titulo)” para aparecer en más búsquedas.",
                    accion: .editar(hospedaje)
                ))
            }
            if (hospedaje.descripcion?.count ?? 0) < 40 {
                lista.append(RecomendacionAnfitrion(
                    icono: "text.alignleft",
                    texto: "Cuenta más sobre “\(hospedaje.titulo)” — una descripción más completa genera más confianza.",
                    accion: .editar(hospedaje)
                ))
            }
            if (hospedaje.servicios ?? []).isEmpty {
                lista.append(RecomendacionAnfitrion(
                    icono: "checklist",
                    texto: "Agrega los servicios que ofreces en “\(hospedaje.titulo)” (paseos, alimentación, monitoreo…).",
                    accion: .editar(hospedaje)
                ))
            }
            if hospedaje.activo == false {
                lista.append(RecomendacionAnfitrion(
                    icono: "pause.circle",
                    texto: "“\(hospedaje.titulo)” está pausado — actívalo para volver a aparecer en Buscar.",
                    accion: .verHospedaje(hospedaje)
                ))
            }
        }

        for (hospedaje, cantidad) in pendientesPorHospedaje {
            lista.append(RecomendacionAnfitrion(
                icono: "clock.badge.exclamationmark",
                texto: "Tienes \(cantidad) solicitud\(cantidad == 1 ? "" : "es") pendiente\(cantidad == 1 ? "" : "s") en “\(hospedaje.titulo)”.",
                accion: .verReservasRecibidas(hospedaje)
            ))
        }

        if hospedajes.isEmpty {
            lista.append(RecomendacionAnfitrion(
                icono: "plus.circle",
                texto: "Publica tu primer hospedaje para empezar a recibir huéspedes.",
                accion: .publicarHospedaje
            ))
        }

        return lista
    }
}
