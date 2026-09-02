//
//  Reserva.swift
//  Core/Models
//
//  La forma de "una reserva" varía según el endpoint (ver ARCHITECTURE_AUDIT.md §2.1/§3):
//   - POST /api/reservas             → id, codigo, desde, hasta, noches, mascotas,
//                                       precio_noche, limpieza, servicio, total, estado
//                                       ('pendiente' al nacer — ver EstadoReserva),
//                                       creado_en (+ `detalle` aparte, ver `NuevaReservaResponse`).
//   - GET  /api/reservas/mias        → id, codigo, desde, hasta, noches, mascotas, total,
//                                       estado, mascotas_detalle + snapshot del hospedaje
//                                       (titulo/ciudad/barrio/tipo/fotos), SIN
//                                       precio_noche/limpieza/servicio.
//   - GET  /api/reservas/:id         → `rs.*` completo + hospedaje_titulo + anfitrion_id
//                                       + mascotas_detalle.
//   - POST /api/reservas/:id/cancelar→ SOLO id, codigo, estado.
//   - POST /api/reservas/:id/aceptar → el anfitrión acepta una solicitud 'pendiente'; igual
//                                       shape que GET /api/hospedajes/:id/reservas.
//   - POST /api/reservas/:id/rechazar→ igual que /aceptar, pero a 'rechazada'.
//   - GET /api/hospedajes/:id/reservas → (vista del anfitrión) `rs.*` + hospedaje_titulo +
//                                       usuario_nombre + usuario_rating/usuario_num_resenas
//                                       + mascotas_detalle.
//  Único subconjunto garantizado en TODAS las respuestas: id, codigo, estado.
//  precio_noche/limpieza/servicio/total son NUMERIC → decodificación defensiva (String o
//  Double), igual que en Hospedaje.swift.
//

import Foundation

public enum EstadoReserva: String, Codable, Hashable {
    case pendiente
    case confirmada
    case rechazada
    case cancelada
    case completada
}

// `Decodable` (no `Codable`): tiene `init(from:)` manual (decodificación defensiva de
// columnas NUMERIC) y nunca se envía como body — ver la nota en Core/Models/Actividad.swift.
public struct Reserva: Decodable, Identifiable, Hashable {
    public let id: String
    public let codigo: String
    public let estado: EstadoReserva

    public let desde: String?   // YYYY-MM-DD
    public let hasta: String?   // YYYY-MM-DD
    public let noches: Int?
    public let mascotas: Int?
    public let total: Double?

    /// A qué hora el huésped lleva/recoge a la mascota (`HH:mm:ss`, ver
    /// db/36-horarios-entrega.sql) — `nil` en reservas creadas antes de este campo, nunca en
    /// una nueva (`POST /api/reservas` las exige, ver `NuevaReservaViewModel`).
    public let horaEntrega: String?
    public let horaRecogida: String?

    public let precioNoche: Double?
    /// `true` cuando esta reserva es de UN SOLO DÍA (entrega y recogida el mismo día, sin
    /// pasar la noche) — cambia cómo se muestra la duración ("mismo día" en vez de "N
    /// noches") y qué precio ver: `precioDia`, no `precioNoche` (ver
    /// db/35-reserva-mismo-dia.sql). `nil` en respuestas que no lo traen: tratar igual que
    /// `false`.
    public let mismoDia: Bool?
    /// Precio de día cobrado — solo tiene sentido cuando `mismoDia == true`.
    public let precioDia: Double?
    public let limpieza: Double?
    public let servicio: Double?
    /// % de comisión de PetHouse que aplicaba cuando se creó esta reserva, y su desglose ya
    /// calculado — vienen del pago asociado (ver db/27-comision.sql), solo presentes cuando
    /// el endpoint hace JOIN con `pagos` (historial/reservas recibidas del anfitrión). Todavía
    /// es informativo: no hay pasarela de pagos conectada, PetHouse no cobra nada de verdad.
    public let comisionPorcentaje: Double?
    public let comisionMonto: Double?
    public let montoAnfitrion: Double?
    public let creadoEn: String?

    public let usuarioId: String?
    public let hospedajeId: String?
    public let anfitrionId: String?
    public let hospedajeTitulo: String?
    /// Nombre del huésped que reservó — solo presente en `GET /api/hospedajes/:id/reservas`
    /// (la vista del anfitrión, `ReservasRecibidasView`). El anfitrión lo necesita para
    /// saber a quién le está escribiendo al tocar "Escribir al huésped".
    public let usuarioNombre: String?
    /// Evaluación del huésped (promedio de `resenas_usuario`) — igual que `usuarioNombre`,
    /// solo presente en `GET /api/hospedajes/:id/reservas`. El anfitrión la ve de un vistazo
    /// al revisar una solicitud, antes de aceptar o rechazar (ver `EvaluacionHuespedView`
    /// para el detalle completo de comentarios).
    public let usuarioRating: Double?
    public let usuarioNumResenas: Int?
    /// Mascotas concretas de esta reserva (raza, peso, vacunas, notas/requerimientos) — el
    /// anfitrión las necesita para decidir si acepta o rechaza la solicitud. Viene en todas
    /// las respuestas salvo `POST /api/reservas/:id/cancelar` (solo id/codigo/estado).
    public let mascotasDetalle: [Mascota]?

    // Snapshot del hospedaje, solo presente en GET /api/reservas/mias.
    public let ciudad: String?
    public let barrio: String?
    public let tipo: TipoHospedaje?
    public let fotos: [String]?

    enum CodingKeys: String, CodingKey {
        case id, codigo, estado, desde, hasta, noches, mascotas, total
        case horaEntrega = "hora_entrega"
        case horaRecogida = "hora_recogida"
        case precioNoche = "precio_noche"
        case mismoDia = "mismo_dia"
        case precioDia = "precio_dia"
        case limpieza, servicio
        case comisionPorcentaje = "comision_porcentaje"
        case comisionMonto = "comision_monto"
        case montoAnfitrion = "monto_anfitrion"
        case creadoEn = "creado_en"
        case usuarioId = "usuario_id"
        case hospedajeId = "hospedaje_id"
        case anfitrionId = "anfitrion_id"
        case hospedajeTitulo = "hospedaje_titulo"
        case usuarioNombre = "usuario_nombre"
        case usuarioRating = "usuario_rating"
        case usuarioNumResenas = "usuario_num_resenas"
        case mascotasDetalle = "mascotas_detalle"
        case ciudad, barrio, tipo, fotos
    }

    /// Memberwise explícito — Swift no lo sintetiza porque hay un `init(from:)` manual.
    /// Usado principalmente para reconstruir un `Reserva` desde `ReservaCache` (offline),
    /// sin pasar por JSON. Ver `ReservaCache.comoReserva`.
    public init(
        id: String, codigo: String, estado: EstadoReserva, desde: String?, hasta: String?,
        noches: Int?, mascotas: Int?, total: Double?, horaEntrega: String? = nil,
        horaRecogida: String? = nil, precioNoche: Double?,
        mismoDia: Bool? = nil, precioDia: Double? = nil, limpieza: Double?,
        servicio: Double?, comisionPorcentaje: Double? = nil, comisionMonto: Double? = nil,
        montoAnfitrion: Double? = nil, creadoEn: String?, usuarioId: String?, hospedajeId: String?,
        anfitrionId: String?, hospedajeTitulo: String?, usuarioNombre: String? = nil,
        usuarioRating: Double? = nil, usuarioNumResenas: Int? = nil,
        mascotasDetalle: [Mascota]? = nil,
        ciudad: String?, barrio: String?, tipo: TipoHospedaje?, fotos: [String]?
    ) {
        self.id = id
        self.codigo = codigo
        self.estado = estado
        self.desde = desde
        self.hasta = hasta
        self.noches = noches
        self.mascotas = mascotas
        self.total = total
        self.horaEntrega = horaEntrega
        self.horaRecogida = horaRecogida
        self.precioNoche = precioNoche
        self.mismoDia = mismoDia
        self.precioDia = precioDia
        self.limpieza = limpieza
        self.servicio = servicio
        self.comisionPorcentaje = comisionPorcentaje
        self.comisionMonto = comisionMonto
        self.montoAnfitrion = montoAnfitrion
        self.creadoEn = creadoEn
        self.usuarioId = usuarioId
        self.hospedajeId = hospedajeId
        self.anfitrionId = anfitrionId
        self.hospedajeTitulo = hospedajeTitulo
        self.usuarioNombre = usuarioNombre
        self.usuarioRating = usuarioRating
        self.usuarioNumResenas = usuarioNumResenas
        self.mascotasDetalle = mascotasDetalle
        self.ciudad = ciudad
        self.barrio = barrio
        self.tipo = tipo
        self.fotos = fotos
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        codigo = try c.decode(String.self, forKey: .codigo)
        estado = try c.decode(EstadoReserva.self, forKey: .estado)
        desde = try c.decodeIfPresent(String.self, forKey: .desde)
        hasta = try c.decodeIfPresent(String.self, forKey: .hasta)
        noches = try c.decodeIfPresent(Int.self, forKey: .noches)
        mascotas = try c.decodeIfPresent(Int.self, forKey: .mascotas)
        total = try c.decodeFlexibleDoubleIfPresent(forKey: .total)
        horaEntrega = try c.decodeIfPresent(String.self, forKey: .horaEntrega)
        horaRecogida = try c.decodeIfPresent(String.self, forKey: .horaRecogida)
        precioNoche = try c.decodeFlexibleDoubleIfPresent(forKey: .precioNoche)
        mismoDia = try c.decodeIfPresent(Bool.self, forKey: .mismoDia)
        precioDia = try c.decodeFlexibleDoubleIfPresent(forKey: .precioDia)
        limpieza = try c.decodeFlexibleDoubleIfPresent(forKey: .limpieza)
        servicio = try c.decodeFlexibleDoubleIfPresent(forKey: .servicio)
        comisionPorcentaje = try c.decodeFlexibleDoubleIfPresent(forKey: .comisionPorcentaje)
        comisionMonto = try c.decodeFlexibleDoubleIfPresent(forKey: .comisionMonto)
        montoAnfitrion = try c.decodeFlexibleDoubleIfPresent(forKey: .montoAnfitrion)
        creadoEn = try c.decodeIfPresent(String.self, forKey: .creadoEn)
        usuarioId = try c.decodeIfPresent(String.self, forKey: .usuarioId)
        hospedajeId = try c.decodeIfPresent(String.self, forKey: .hospedajeId)
        anfitrionId = try c.decodeIfPresent(String.self, forKey: .anfitrionId)
        hospedajeTitulo = try c.decodeIfPresent(String.self, forKey: .hospedajeTitulo)
        usuarioNombre = try c.decodeIfPresent(String.self, forKey: .usuarioNombre)
        usuarioRating = try c.decodeFlexibleDoubleIfPresent(forKey: .usuarioRating)
        usuarioNumResenas = try c.decodeIfPresent(Int.self, forKey: .usuarioNumResenas)
        mascotasDetalle = try c.decodeIfPresent([Mascota].self, forKey: .mascotasDetalle)
        ciudad = try c.decodeIfPresent(String.self, forKey: .ciudad)
        barrio = try c.decodeIfPresent(String.self, forKey: .barrio)
        tipo = try c.decodeIfPresent(TipoHospedaje.self, forKey: .tipo)
        fotos = try c.decodeIfPresent([String].self, forKey: .fotos)
    }

    /// `mismoDia` es `Bool?` porque no todas las respuestas lo traen — acá se trata la
    /// ausencia igual que `false`, para no repetir `reserva.mismoDia == true` en cada vista.
    public var esMismoDia: Bool { mismoDia == true }
}

public struct CrearReservaRequest: Encodable {
    public let hospedajeId: String
    public let desde: String
    public let hasta: String
    /// `HH:mm` — a qué hora el huésped lleva/recoge a la mascota (ver
    /// db/36-horarios-entrega.sql). El servidor las exige, no son opcionales.
    public let horaEntrega: String
    public let horaRecogida: String
    public let mascotaIds: [String]

    enum CodingKeys: String, CodingKey {
        case hospedajeId = "hospedaje_id"
        case desde, hasta
        case horaEntrega = "hora_entrega"
        case horaRecogida = "hora_recogida"
        case mascotaIds = "mascota_ids"
    }

    public init(hospedajeId: String, desde: String, hasta: String, horaEntrega: String, horaRecogida: String, mascotaIds: [String]) {
        self.hospedajeId = hospedajeId
        self.desde = desde
        self.hasta = hasta
        self.horaEntrega = horaEntrega
        self.horaRecogida = horaRecogida
        self.mascotaIds = mascotaIds
    }
}

public struct ReservaDetalleCotizacion: Decodable, Hashable {
    public let hospedaje: String
    public let noches: Int
    public let limpieza: Double
    public let servicio: Double

    enum CodingKeys: String, CodingKey {
        case hospedaje, noches, limpieza, servicio
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hospedaje = try c.decode(String.self, forKey: .hospedaje)
        noches = try c.decode(Int.self, forKey: .noches)
        limpieza = try c.decodeFlexibleDouble(forKey: .limpieza)
        servicio = try c.decodeFlexibleDouble(forKey: .servicio)
    }
}

public struct CrearReservaResponse: Decodable {
    public let reserva: Reserva
    public let detalle: ReservaDetalleCotizacion
}

public struct MisReservasResponse: Decodable {
    public let reservas: [Reserva]
}

public struct PlanActividad: Decodable, Identifiable, Hashable {
    public let id: String
    public let fecha: String?
    public let precio: Double
    public let nombre: String
    public let tipo: String

    enum CodingKeys: String, CodingKey {
        case id, fecha, precio, nombre, tipo
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        fecha = try c.decodeIfPresent(String.self, forKey: .fecha)
        precio = try c.decodeFlexibleDouble(forKey: .precio)
        nombre = try c.decode(String.self, forKey: .nombre)
        tipo = try c.decode(String.self, forKey: .tipo)
    }
}

public struct ReservaDetailResponse: Decodable {
    public let reserva: Reserva
    public let plan: [PlanActividad]
}

public struct CancelarReservaResponse: Decodable {
    public let reserva: Reserva
}

/// Respuesta de `POST /api/reservas/:id/aceptar` y `/rechazar` — a diferencia de
/// `CancelarReservaResponse`, viene con la reserva COMPLETA (mismo shape que
/// `GET /api/hospedajes/:id/reservas`), para que `ReservasRecibidasView` pueda reemplazar
/// la fila en su lista sin perder usuario_nombre/mascotasDetalle/fechas.
public struct ReservaAccionResponse: Decodable {
    public let reserva: Reserva
}

/// Body de `POST /api/reservas/:id/resena-huesped` — el `reserva_id` va en la URL, no acá
/// (a diferencia de `CrearResenaRequest`, que sí lo lleva en el body).
public struct CalificarHuespedRequest: Encodable {
    public let rating: Int
    public let titulo: String?
    public let texto: String?

    public init(rating: Int, titulo: String?, texto: String?) {
        self.rating = rating
        self.titulo = titulo
        self.texto = texto
    }
}
