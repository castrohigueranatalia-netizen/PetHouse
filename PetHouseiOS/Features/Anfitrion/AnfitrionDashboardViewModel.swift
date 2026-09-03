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

/// Una sugerencia concreta y accionable ("agrega fotos a X"), no una idea genérica — cada
/// una nace de un chequeo real contra los datos de un hospedaje propio o del historial de
/// solicitudes. Sin backend de analítica de búsquedas: las reglas usan solo lo que el
/// anfitrión ya puede ver y corregir él mismo.
public struct RecomendacionAnfitrion: Identifiable, Hashable {
    public let id = UUID()
    public let icono: String
    public let texto: String
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

    public var solicitudesPendientes: Int {
        historial.filter { $0.estado == .pendiente }.count
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
                    texto: "Agrega fotos a “\(hospedaje.titulo)” — los hospedajes con fotos reciben más reservas."
                ))
            }
            if hospedaje.precioDia == nil {
                lista.append(RecomendacionAnfitrion(
                    icono: "sun.max",
                    texto: "Ofrece la opción de reservar por un solo día en “\(hospedaje.titulo)” para aparecer en más búsquedas."
                ))
            }
            if (hospedaje.descripcion?.count ?? 0) < 40 {
                lista.append(RecomendacionAnfitrion(
                    icono: "text.alignleft",
                    texto: "Cuenta más sobre “\(hospedaje.titulo)” — una descripción más completa genera más confianza."
                ))
            }
            if (hospedaje.servicios ?? []).isEmpty {
                lista.append(RecomendacionAnfitrion(
                    icono: "checklist",
                    texto: "Agrega los servicios que ofreces en “\(hospedaje.titulo)” (paseos, alimentación, monitoreo…)."
                ))
            }
            if hospedaje.activo == false {
                lista.append(RecomendacionAnfitrion(
                    icono: "pause.circle",
                    texto: "“\(hospedaje.titulo)” está pausado — actívalo para volver a aparecer en Buscar."
                ))
            }
        }

        if solicitudesPendientes > 0 {
            lista.append(RecomendacionAnfitrion(
                icono: "clock.badge.exclamationmark",
                texto: "Tienes \(solicitudesPendientes) solicitud\(solicitudesPendientes == 1 ? "" : "es") pendiente\(solicitudesPendientes == 1 ? "" : "s") por aceptar o rechazar."
            ))
        }

        if hospedajes.isEmpty {
            lista.append(RecomendacionAnfitrion(
                icono: "plus.circle",
                texto: "Publica tu primer hospedaje para empezar a recibir huéspedes."
            ))
        }

        return lista
    }
}
