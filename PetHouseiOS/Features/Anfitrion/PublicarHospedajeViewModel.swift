//
//  PublicarHospedajeViewModel.swift
//  Features/Anfitrion
//
//  `POST /api/hospedajes` SÍ existe hoy — a diferencia del resto de este módulo. Pero
//  como no hay endpoint de subida de imágenes (gap bloqueante #1, ver
//  ARCHITECTURE_AUDIT.md §6 y `ImagenesService`), `fotos` se manda como URLs que el
//  anfitrión debe pegar a mano (ya alojadas en otro lado) — se lo decimos explícito en
//  la UI en vez de fingir que hay un selector de fotos funcional.
//

import Foundation

@MainActor
@Observable
public final class PublicarHospedajeViewModel {
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
    public var convivencia: Convivencia = .cualquiera
    public var maxMascotasTexto = "1"
    public var serviciosTexto = ""   // separados por coma
    public var reglasTexto = ""      // separados por coma
    public var fotosURLsTexto = ""   // separados por coma — sin subida real, ver arriba

    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var publicado: HospedajeCreado?

    private let service: HospedajesServicing
    private let locationProvider: LocationProvider

    // Ver el comentario equivalente en BuscarViewModel.swift: `LocationProvider()` no puede
    // ser el valor por defecto del parámetro (Swift no aísla al MainActor las expresiones
    // de default aunque la clase lo sea) — se crea dentro del cuerpo del init en su lugar.
    public init(service: HospedajesServicing = HospedajesService(), locationProvider: LocationProvider? = nil) {
        self.service = service
        self.locationProvider = locationProvider ?? LocationProvider()
    }

    public var puedeUsarUbicacionActual: Bool { true }

    public func usarUbicacionActual() async {
        guard let coordenada = await locationProvider.solicitarUbicacion() else { return }
        latTexto = String(coordenada.latitude)
        lngTexto = String(coordenada.longitude)
    }

    public var puedePublicar: Bool {
        !titulo.isEmpty && !descripcion.isEmpty && localidad != nil
            && Double(latTexto) != nil && Double(lngTexto) != nil
            && Double(precioNocheTexto) != nil && !isLoading
    }

    public func publicar() async {
        guard puedePublicar,
              let localidad,
              let lat = Double(latTexto), let lng = Double(lngTexto),
              let precio = Double(precioNocheTexto) else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let payload = CrearHospedajeRequest(
            titulo: titulo, tipo: tipo, descripcion: descripcion, localidad: localidad.rawValue,
            barrio: barrio.isEmpty ? nil : barrio, lat: lat, lng: lng, coberturaRadioM: nil,
            precioNoche: precio, convivencia: convivencia, maxMascotas: Int(maxMascotasTexto) ?? 1,
            servicios: lista(serviciosTexto), reglas: lista(reglasTexto), fotos: lista(fotosURLsTexto)
        )

        do {
            let respuesta = try await service.crear(payload)
            publicado = respuesta.hospedaje
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .desconocido(error.localizedDescription)
        }
    }

    private func lista(_ texto: String) -> [String] {
        texto.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
