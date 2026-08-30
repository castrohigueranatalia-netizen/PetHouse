//
//  Mascota.swift
//  Core/Models
//
//  Refleja la tabla `mascotas` — la "ficha" completa que el anfitrión ve al recibir una
//  solicitud de reserva para decidir si puede aceptar a esa mascota (ver
//  Features/Anfitrion/FichaMascotaView.swift). `GET /api/auth/me` trae la ficha completa
//  desde este mismo endpoint, así que en la práctica solo `usuarioId` suele venir ausente.
//

import Foundation

public struct Mascota: Codable, Identifiable, Hashable {
    public let id: String
    public let nombre: String
    public let especie: String
    public let raza: String?
    /// Edad en años.
    public let edad: Int?
    /// "pequeno" / "mediano" / "grande" — mismo vocabulario que
    /// `PreferenciasAnfitrion.tamanos` (ver `tamanosSugeridos`).
    public let tamano: String?
    public let pesoKg: Double?
    public let vacunasDia: Bool
    /// Si necesita tomar medicamentos — cuando es `true`, `notas` suele traer el detalle
    /// (cuál medicamento, dosis, horario).
    public let necesitaMedicamentos: Bool
    public let notas: String?
    /// URLs devueltas por `POST /api/subidas` — mismo patrón que `Hospedaje.fotos`, no se
    /// suben bytes acá. `[]` (no `nil`) cuando no tiene fotos, así las vistas no necesitan
    /// desenvolver un opcional para mostrar "sin fotos".
    public let fotos: [String]
    public let usuarioId: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, especie, raza, edad, tamano, notas, fotos
        case pesoKg = "peso_kg"
        case vacunasDia = "vacunas_dia"
        case necesitaMedicamentos = "necesita_medicamentos"
        case usuarioId = "usuario_id"
    }

    public init(
        id: String,
        nombre: String,
        especie: String,
        raza: String? = nil,
        edad: Int? = nil,
        tamano: String? = nil,
        pesoKg: Double? = nil,
        vacunasDia: Bool = false,
        necesitaMedicamentos: Bool = false,
        notas: String? = nil,
        fotos: [String] = [],
        usuarioId: String? = nil
    ) {
        self.id = id
        self.nombre = nombre
        self.especie = especie
        self.raza = raza
        self.edad = edad
        self.tamano = tamano
        self.pesoKg = pesoKg
        self.vacunasDia = vacunasDia
        self.necesitaMedicamentos = necesitaMedicamentos
        self.notas = notas
        self.fotos = fotos
        self.usuarioId = usuarioId
    }

    // `peso_kg` es NUMERIC(5,2) en Postgres → puede llegar como string desde `pg`
    // (ver Core/Utils/FlexibleDecoding.swift). Se escriben AMBOS `init(from:)` y
    // `encode(to:)` a mano (no solo uno) porque `Mascota` se codifica Y decodifica de
    // verdad en este cliente (round-trip con `UsuarioCache.mascotasJSON`, no solo
    // respuestas del servidor) — dejar que el compilador sintetice solo una mitad sería
    // ambiguo aquí.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nombre = try c.decode(String.self, forKey: .nombre)
        especie = try c.decode(String.self, forKey: .especie)
        raza = try c.decodeIfPresent(String.self, forKey: .raza)
        edad = try c.decodeIfPresent(Int.self, forKey: .edad)
        tamano = try c.decodeIfPresent(String.self, forKey: .tamano)
        pesoKg = try c.decodeFlexibleDoubleIfPresent(forKey: .pesoKg)
        vacunasDia = try c.decodeIfPresent(Bool.self, forKey: .vacunasDia) ?? false
        necesitaMedicamentos = try c.decodeIfPresent(Bool.self, forKey: .necesitaMedicamentos) ?? false
        notas = try c.decodeIfPresent(String.self, forKey: .notas)
        fotos = try c.decodeIfPresent([String].self, forKey: .fotos) ?? []
        usuarioId = try c.decodeIfPresent(String.self, forKey: .usuarioId)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(nombre, forKey: .nombre)
        try c.encode(especie, forKey: .especie)
        try c.encodeIfPresent(raza, forKey: .raza)
        try c.encodeIfPresent(edad, forKey: .edad)
        try c.encodeIfPresent(tamano, forKey: .tamano)
        try c.encodeIfPresent(pesoKg, forKey: .pesoKg)
        try c.encode(vacunasDia, forKey: .vacunasDia)
        try c.encode(necesitaMedicamentos, forKey: .necesitaMedicamentos)
        try c.encodeIfPresent(notas, forKey: .notas)
        try c.encode(fotos, forKey: .fotos)
        try c.encodeIfPresent(usuarioId, forKey: .usuarioId)
    }

    /// Especies sugeridas en el formulario — el backend acepta cualquier `TEXT`, no es un enum en BD.
    public static let especiesSugeridas = ["perro", "gato", "otro"]

    /// Tamaños sugeridos — mismo vocabulario que `preferencias_anfitrion.tamanos`
    /// (db/06-verificacion-anfitrion.sql).
    public static let tamanosSugeridos = ["pequeno", "mediano", "grande"]

    public var tamanoLegible: String? {
        switch tamano {
        case "pequeno": "Pequeño"
        case "mediano": "Mediano"
        case "grande": "Grande"
        default: nil
        }
    }

    /// `true` solo cuando el anfitrión tiene todo lo que necesita para decidir con
    /// confianza si acepta cuidar a esta mascota — no basta con el nombre. Se usa para
    /// bloquear la selección al reservar (ver NuevaReservaViewModel); el servidor valida
    /// exactamente lo mismo en POST /api/reservas, por si se llama a la API directo.
    public var fichaCompleta: Bool { camposFaltantes.isEmpty }

    /// Qué le falta exactamente a la ficha, en español y listo para mostrar (ej. "raza,
    /// peso") — antes NuevaReservaView solo decía "Completa su ficha (con foto)" sin decir
    /// QUÉ faltaba, y el caso de "Necesita tomar medicamentos" activado sin describir cuál
    /// (ver el toggle en MascotaFormView) era el más confuso: la foto y el resto podían
    /// estar completos y aun así no dejaba reservar, sin pista de por qué.
    public var camposFaltantes: [String] {
        var faltantes: [String] = []
        if raza?.trimmingCharacters(in: .whitespaces).isEmpty ?? true { faltantes.append("raza") }
        if edad == nil { faltantes.append("edad") }
        if tamano?.isEmpty ?? true { faltantes.append("tamaño") }
        if pesoKg == nil { faltantes.append("peso") }
        if fotos.isEmpty { faltantes.append("una foto") }
        if necesitaMedicamentos && (notas?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) {
            faltantes.append("qué medicamento necesita y cuándo")
        }
        return faltantes
    }
}

// MARK: - CRUD de mascotas
//
// POST   /api/mascotas       { nombre, especie, raza?, edad?, tamano?, peso_kg?,
//                               vacunas_dia?, necesita_medicamentos?, notas?, fotos? }
//                             → 201 { mascota: Mascota }
// PATCH  /api/mascotas/:id   { mismos campos, todos opcionales } → 200 { mascota: Mascota }
// DELETE /api/mascotas/:id   → 200 { ok: true }

public struct GuardarMascotaRequest: Encodable {
    public let nombre: String
    public let especie: String
    public let raza: String?
    public let edad: Int?
    public let tamano: String?
    public let pesoKg: Double?
    public let vacunasDia: Bool?
    public let necesitaMedicamentos: Bool?
    public let notas: String?
    public let fotos: [String]?

    enum CodingKeys: String, CodingKey {
        case nombre, especie, raza, edad, tamano, notas, fotos
        case pesoKg = "peso_kg"
        case vacunasDia = "vacunas_dia"
        case necesitaMedicamentos = "necesita_medicamentos"
    }

    public init(
        nombre: String,
        especie: String,
        raza: String? = nil,
        edad: Int? = nil,
        tamano: String? = nil,
        pesoKg: Double? = nil,
        vacunasDia: Bool? = nil,
        necesitaMedicamentos: Bool? = nil,
        notas: String? = nil,
        fotos: [String]? = nil
    ) {
        self.nombre = nombre
        self.especie = especie
        self.raza = raza
        self.edad = edad
        self.tamano = tamano
        self.pesoKg = pesoKg
        self.vacunasDia = vacunasDia
        self.necesitaMedicamentos = necesitaMedicamentos
        self.notas = notas
        self.fotos = fotos
    }
}

public struct MascotaResponse: Codable {
    public let mascota: Mascota
}

public struct EliminarOKResponse: Codable {
    public let ok: Bool
}
