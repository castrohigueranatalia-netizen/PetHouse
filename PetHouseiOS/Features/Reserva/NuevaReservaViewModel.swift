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
    public private(set) var mascotasDisponibles: [Mascota]

    public var desde: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    public var hasta: Date = Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now
    /// `true` = entrega y recogida el mismo día (sin pasar la noche), cobrado a
    /// `hospedaje.precioDia` — solo se puede activar si el hospedaje la ofrece (ver
    /// `ofreceMismoDia`). Al activarla, `hasta` se iguala a `desde` (un solo día
    /// seleccionable, ver `PHSelectorRangoFechas(soloUnDia:)`); al desactivarla, si `hasta`
    /// quedó igual a `desde` se le vuelve a sumar 1 día para no dejar un rango inválido.
    public var mismoDia = false {
        didSet {
            guard mismoDia != oldValue else { return }
            if mismoDia {
                hasta = desde
            } else if hasta <= desde {
                hasta = Calendar.current.date(byAdding: .day, value: 1, to: desde) ?? desde
            }
        }
    }
    public var mascotaIdsSeleccionadas: Set<String> = []

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var reservaConfirmada: CrearReservaResponse?

    /// Días ya ocupados de este hospedaje (`YYYY-MM-DD`) — ver `PHSelectorRangoFechas`, que
    /// sombrea estos días y no deja elegirlos. Si la carga falla, simplemente queda vacío:
    /// no bloquea reservar, el servidor de todos modos rechaza un conflicto real al
    /// confirmar (ver POST /api/reservas).
    public private(set) var diasOcupados: Set<String> = []

    private let service: ReservasServicing
    private let hospedajesService: HospedajesServicing

    public init(
        hospedaje: Hospedaje, mascotasDisponibles: [Mascota],
        service: ReservasServicing = ReservasService(), hospedajesService: HospedajesServicing = HospedajesService()
    ) {
        self.hospedaje = hospedaje
        self.mascotasDisponibles = mascotasDisponibles
        self.service = service
        self.hospedajesService = hospedajesService
        // Solo se preselecciona sola si su ficha ya está completa — si no, que el usuario
        // vea el aviso y decida (completarla ahí mismo, o elegir otra mascota).
        if let primera = mascotasDisponibles.first(where: \.fichaCompleta) {
            mascotaIdsSeleccionadas = [primera.id]
        }
    }

    public func cargarDisponibilidad() async {
        do {
            let rangos = try await hospedajesService.disponibilidad(hospedajeId: hospedaje.id)
            diasOcupados = rangos.diasOcupados()
            // TEMPORAL: para diagnosticar por qué un rango realmente ocupado no aparecía
            // gris en el calendario — se quita una vez confirmado en Xcode qué llega del
            // servidor. Visible en la consola de Xcode mientras la app corre desde ahí.
            print("PetHouse/disponibilidad \(hospedaje.id): recibido=\(rangos.map { "\($0.desde)..<\($0.hasta) [\($0.estado)]" }) → diasOcupados=\(diasOcupados.sorted())")
        } catch {
            print("PetHouse/disponibilidad \(hospedaje.id): FALLÓ — \(error)")
        }
    }

    public func diaOcupado(_ dia: Date) -> Bool {
        diasOcupados.contains(PHDate.toAPIDateOnly(dia))
    }

    /// `true` si el rango elegido ahora mismo pisa un día ya ocupado — normalmente
    /// `PHSelectorRangoFechas` ya no deja tocar esos días, pero si `diasOcupados` se acaba de
    /// actualizar (ver `confirmar()`, tras un 409 real) la selección vieja puede haber
    /// quedado sobre una fecha que recién se supo ocupada. Bloquea "Enviar solicitud" hasta
    /// que se elija otra fecha, en vez de dejar reintentar el mismo conflicto.
    public var rangoOcupado: Bool {
        var cursor = desde
        let fin = mismoDia ? (Calendar.current.date(byAdding: .day, value: 1, to: desde) ?? desde) : hasta
        while cursor < fin {
            if diaOcupado(cursor) { return true }
            guard let siguiente = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = siguiente
        }
        return false
    }

    /// Se llama al volver de completar la ficha de una mascota (ver NuevaReservaView) —
    /// `mascotasDisponibles` es un snapshot tomado al abrir esta pantalla, no una referencia
    /// viva a `SessionStore.mascotas`, así que hay que refrescarlo a mano.
    public func actualizarMascotas(_ mascotas: [Mascota]) {
        mascotasDisponibles = mascotas
        mascotaIdsSeleccionadas = mascotaIdsSeleccionadas.filter { id in
            mascotas.first(where: { $0.id == id })?.fichaCompleta == true
        }
    }

    public var maxMascotas: Int { hospedaje.maxMascotas ?? 1 }

    /// `true` si este hospedaje ofrece la opción de un solo día (ver
    /// db/35-reserva-mismo-dia.sql) — controla si `NuevaReservaView` muestra el selector
    /// "Por noches" / "Mismo día".
    public var ofreceMismoDia: Bool { hospedaje.precioDia != nil }

    public var noches: Int {
        max(0, Calendar.current.dateComponents([.day], from: desde, to: hasta).day ?? 0)
    }

    /// Para el estimado y el envío: 1 "unidad" para una reserva de un solo día (aunque
    /// `noches` dé 0, porque `desde == hasta`), `noches` en cualquier otro caso — mismo
    /// criterio que usa el servidor (ver `precioBase`/`pethouse-api/src/routes/reservas.js`).
    private var unidadesParaCalculo: Int { mismoDia ? 1 : noches }

    public var fechasValidas: Bool {
        mismoDia ? true : noches > 0
    }

    public func alternar(_ mascota: Mascota) {
        guard mascota.fichaCompleta else { return }
        if mascotaIdsSeleccionadas.contains(mascota.id) {
            mascotaIdsSeleccionadas.remove(mascota.id)
        } else if mascotaIdsSeleccionadas.count < maxMascotas {
            mascotaIdsSeleccionadas.insert(mascota.id)
        }
    }

    /// `precioDia` si es de un solo día (garantizado no-nil ahí: `mismoDia` no se puede
    /// activar sin `ofreceMismoDia`), `precioNoche` si no.
    public var precioBase: Double {
        mismoDia ? (hospedaje.precioDia ?? hospedaje.precioNoche) : hospedaje.precioNoche
    }

    /// Estimado — ver el comentario del archivo. No es el monto final.
    public var estimadoLimpieza: Double {
        (precioBase * 0.6).rounded()
    }

    public var estimadoServicio: Double {
        (precioBase * Double(unidadesParaCalculo) * 0.1).rounded()
    }

    public var estimadoTotal: Double {
        precioBase * Double(unidadesParaCalculo) + estimadoLimpieza + estimadoServicio
    }

    public var puedeReservar: Bool {
        fechasValidas
            && !rangoOcupado
            && !mascotaIdsSeleccionadas.isEmpty
            && mascotaIdsSeleccionadas.count <= maxMascotas
            // Defensivo: `alternar(_:)` ya no deja seleccionar una mascota incompleta, pero
            // si de algún modo quedó una seleccionada y luego se editó dejándola incompleta,
            // esto la saca de la jugada sin depender de que la UI lo haya recalculado.
            && mascotaIdsSeleccionadas.allSatisfy { id in mascotasDisponibles.first(where: { $0.id == id })?.fichaCompleta == true }
            && !isLoading
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
                // `hasta == desde` es justamente la señal que espera el servidor para
                // reservas de un solo día (ver db/35-reserva-mismo-dia.sql) — se manda desde
                // acá, no desde el binding de `hasta`, para no depender de que
                // PHSelectorRangoFechas lo haya dejado sincronizado.
                hasta: mismoDia ? PHDate.toAPIDateOnly(desde) : PHDate.toAPIDateOnly(hasta),
                mascotaIds: Array(mascotaIdsSeleccionadas)
            )
            reservaConfirmada = respuesta
        } catch let appError as AppError {
            error = appError
            // 409 = alguien más ganó la carrera por estas fechas justo entre que se abrió el
            // calendario y se confirmó (ver EXCLUDE en db/11-reservas-pendientes-mascotas.sql)
            // — se refresca `diasOcupados` de una vez para que el día quede gris y
            // `puedeReservar` bloqueado, en vez de dejar reintentar el mismo conflicto.
            if case .servidor(409, _) = appError {
                await cargarDisponibilidad()
            }
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }
}
