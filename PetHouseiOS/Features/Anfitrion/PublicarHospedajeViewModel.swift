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
    public var ciudad = ""
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

    public init(service: HospedajesServicing = HospedajesService(), locationProvider: LocationProvider = LocationProvider()) {
        self.service = service
        self.locationProvider = locationProvider
    }

    public var puedeUsarUbicacionActual: Bool { true }

    public func usarUbicacionActual() async {
        guard let coordenada = await locationProvider.solicitarUbicacion() else { return }
        latTexto = String(coordenada.latitude)
        lngTexto = String(coordenada.longitude)
    }

    public var puedePublicar: Bool {
        !titulo.isEmpty && !descripcion.isEmpty && !ciudad.isEmpty
            && Double(latTexto) != nil && Double(lngTexto) != nil
            && Double(precioNocheTexto) != nil && !isLoading
    }

    public func publicar() async {
        guard puedePublicar,
              let lat = Double(latTexto), let lng = Double(lngTexto),
              let precio = Double(precioNocheTexto) else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let payload = CrearHospedajeRequest(
            titulo: titulo, tipo: tipo, descripcion: descripcion, ciudad: ciudad,
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
