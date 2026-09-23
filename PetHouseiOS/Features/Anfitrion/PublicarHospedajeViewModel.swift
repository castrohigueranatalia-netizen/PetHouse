//
//  PublicarHospedajeViewModel.swift
//  Features/Anfitrion
//
//  Sirve para publicar un hospedaje NUEVO y para editar uno existente — `hospedajeExistente`
//  distingue los dos casos (mismo patrón que `MascotaFormViewModel`): `nil` precarga el
//  formulario vacío y llama a `POST /api/hospedajes` al guardar; con un `Hospedaje`, precarga
//  sus datos y llama a `PATCH /api/hospedajes/:id`. Las fotos se suben de verdad
//  (`ImagenesService`, mismo componente `PHAdjuntarFotos` que ya usa la ficha de mascota y
//  la verificación de anfitrión) — antes había que pegar URLs a mano.
//

import Foundation

@MainActor
@Observable
public final class PublicarHospedajeViewModel {
    /// `nil` = publicando uno nuevo; con valor = editando este hospedaje existente.
    public let hospedajeExistente: Hospedaje?

    public var titulo = ""
    public var tipo: TipoHospedaje = .guarderia
    public var descripcion = ""
    /// La app es solo de Bogotá: no hay campo de ciudad, se elige la localidad directamente
    /// (ver Core/Models/Localidad.swift) — el servidor rechaza la publicación sin esto.
    public var localidad: Localidad?
    public var barrio = ""
    public var latTexto = ""
    public var lngTexto = ""
    public var precioNocheTexto = ""
    /// Opcional — vacío significa que este hospedaje NO ofrece la opción de reservar por un
    /// solo día (entrega y recogida el mismo día, ver db/35-reserva-mismo-dia.sql).
    public var precioDiaTexto = ""
    /// Rango en que este hospedaje acepta entrega/recogida (ver db/37-horarios-hospedaje.sql)
    /// — los cuatro vacíos = sin restricción, el huésped puede elegir cualquier hora. Si se
    /// llena uno de un par, hay que llenar el otro (ver `puedeGuardar`).
    public var horarioEntregaDesde: Date?
    public var horarioEntregaHasta: Date?
    public var horarioRecogidaDesde: Date?
    public var horarioRecogidaHasta: Date?
    public var convivencia: Convivencia = .cualquiera
    public var maxMascotasTexto = "1"
    public var serviciosTexto = ""   // separados por coma
    public var reglasTexto = ""      // separados por coma
    public var fotos: [String] = []

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var guardado: Hospedaje?

    private let service: HospedajesServicing
    private let imagenesService: ImagenesServicing
    private let locationProvider: LocationProvider

    // Ver el comentario equivalente en BuscarViewModel.swift: `LocationProvider()` no puede
    // ser el valor por defecto del parámetro (Swift no aísla al MainActor las expresiones
    // de default aunque la clase lo sea) — se crea dentro del cuerpo del init en su lugar.
    public init(
        hospedajeExistente: Hospedaje? = nil,
        service: HospedajesServicing = HospedajesService(),
        imagenesService: ImagenesServicing = ImagenesService(),
        locationProvider: LocationProvider? = nil
    ) {
        self.hospedajeExistente = hospedajeExistente
        self.service = service
        self.imagenesService = imagenesService
        self.locationProvider = locationProvider ?? LocationProvider()

        if let h = hospedajeExistente {
            titulo = h.titulo
            tipo = h.tipo
            descripcion = h.descripcion ?? ""
            localidad = h.localidad.flatMap(Localidad.init(rawValue:))
            barrio = h.barrio ?? ""
            // `.map(String.init)` (pasando el init como referencia suelta) es ambiguo para
            // Swift acá — hay varias sobrecargas de `String.init` candidatas y no logra
            // elegir sin ver el tipo del argumento primero. Con un closure (`{ String($0) }`)
            // sí lo resuelve, porque en ese punto ya sabe que `$0` es Double/Int.
            latTexto = h.lat.map { String($0) } ?? ""
            lngTexto = h.lng.map { String($0) } ?? ""
            precioNocheTexto = String(h.precioNoche)
            precioDiaTexto = h.precioDia.map { String($0) } ?? ""
            horarioEntregaDesde = Self.parseHora(h.horarioEntregaDesde)
            horarioEntregaHasta = Self.parseHora(h.horarioEntregaHasta)
            horarioRecogidaDesde = Self.parseHora(h.horarioRecogidaDesde)
            horarioRecogidaHasta = Self.parseHora(h.horarioRecogidaHasta)
            convivencia = h.convivencia ?? .cualquiera
            maxMascotasTexto = h.maxMascotas.map { String($0) } ?? "1"
            serviciosTexto = (h.servicios ?? []).joined(separator: ", ")
            reglasTexto = (h.reglas ?? []).joined(separator: ", ")
            fotos = h.fotos ?? []
        }
    }

    public var esEdicion: Bool { hospedajeExistente != nil }

    public var puedeUsarUbicacionActual: Bool { true }

    public func usarUbicacionActual() async {
        guard let coordenada = await locationProvider.solicitarUbicacion() else { return }
        latTexto = String(coordenada.latitude)
        lngTexto = String(coordenada.longitude)
    }

    /// Pasado a `PHAdjuntarFotos` — sube el archivo y devuelve la URL, o `nil` si falla (la
    /// vista ya muestra su propio mensaje de error en ese caso). Mismo patrón que
    /// `VerificacionAnfitrionViewModel.subirFoto`/`MascotaFormViewModel.subirFoto`.
    public func subirFoto(_ datos: Data) async -> String? {
        try? await imagenesService.subir(datos: datos, nombreArchivo: "hospedaje.jpg", mimeType: "image/jpeg")
    }

    public var puedeGuardar: Bool {
        !titulo.isEmpty && !descripcion.isEmpty && localidad != nil
            && Double(latTexto) != nil && Double(lngTexto) != nil
            && Double(precioNocheTexto) != nil
            && (precioDiaTexto.isEmpty || Double(precioDiaTexto) != nil)
            // Cada par debe estar completo o vacío — un "desde" sin "hasta" (o al revés) no
            // es un rango válido.
            && (horarioEntregaDesde == nil) == (horarioEntregaHasta == nil)
            && (horarioRecogidaDesde == nil) == (horarioRecogidaHasta == nil)
            && !isLoading
    }

    public func guardar() async {
        guard puedeGuardar,
              let localidad,
              let lat = Double(latTexto), let lng = Double(lngTexto),
              let precio = Double(precioNocheTexto) else { return }
        let precioDia = precioDiaTexto.isEmpty ? nil : Double(precioDiaTexto)

        isLoading = true
        error = nil
        defer { isLoading = false }

        let payload = CrearHospedajeRequest(
            titulo: titulo, tipo: tipo, descripcion: descripcion, localidad: localidad.rawValue,
            barrio: barrio.isEmpty ? nil : barrio, lat: lat, lng: lng, coberturaRadioM: nil,
            precioNoche: precio, precioDia: precioDia,
            horarioEntregaDesde: horarioEntregaDesde.map(PHDate.toAPITimeOnly),
            horarioEntregaHasta: horarioEntregaHasta.map(PHDate.toAPITimeOnly),
            horarioRecogidaDesde: horarioRecogidaDesde.map(PHDate.toAPITimeOnly),
            horarioRecogidaHasta: horarioRecogidaHasta.map(PHDate.toAPITimeOnly),
            convivencia: convivencia, maxMascotas: Int(maxMascotasTexto) ?? 1,
            servicios: lista(serviciosTexto), reglas: lista(reglasTexto), fotos: fotos
        )

        do {
            if let existente = hospedajeExistente {
                guardado = try await service.editar(id: existente.id, payload)
            } else {
                let respuesta = try await service.crear(payload)
                // `POST /` solo devuelve un subconjunto mínimo (ver HospedajeCreado) — se
                // envuelve en un `Hospedaje` "placeholder" para reusar el mismo tipo que la
                // edición, que sí trae la fila completa.
                let creado = respuesta.hospedaje
                guardado = Hospedaje(
                    id: creado.id, titulo: creado.titulo, tipo: creado.tipo,
                    ciudad: creado.ciudad, localidad: creado.localidad, precioNoche: creado.precioNoche
                )
            }
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    private func lista(_ texto: String) -> [String] {
        texto.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// `"HH:MM"` o `"HH:MM:SS"` (Postgres `TIME`, ver db/37-horarios-hospedaje.sql) a `Date`
    /// para el `DatePicker` del formulario — `nil` si no vino nada, o si el string no es una
    /// hora reconocible.
    private static func parseHora(_ raw: String?) -> Date? {
        guard let raw, raw.count >= 5 else { return nil }
        return PHDate.apiTimeOnly.date(from: String(raw.prefix(5)))
    }
}
