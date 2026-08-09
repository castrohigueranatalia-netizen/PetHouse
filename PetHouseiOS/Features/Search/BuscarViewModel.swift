//
//  BuscarViewModel.swift
//  Features/Search
//
//  GET /api/hospedajes no pagina (`LIMIT 100` fijo en el servidor, ver
//  ARCHITECTURE_AUDIT.md §5). Este ViewModel trae ese máximo de 100 en una sola llamada
//  y hace la "paginación" del lado del cliente, revelando resultados en tandas mientras
//  el usuario hace scroll (`cargarMasSiHaceFalta`) — cuando el backend agregue `page`/
//  `limit` de verdad, esto se reemplaza por fetches incrementales sin cambiar la vista.
//

import Foundation

@MainActor
@Observable
public final class BuscarViewModel {
    public enum Orden: String, CaseIterable, Identifiable {
        case relevancia = ""
        case precioAsc = "precio-asc"
        case precioDesc = "precio-desc"
        case rating = "rating"

        public var id: String { rawValue }
        public var etiqueta: String {
            switch self {
            case .relevancia: "Relevancia"
            case .precioAsc: "Precio: menor a mayor"
            case .precioDesc: "Precio: mayor a menor"
            case .rating: "Mejor calificados"
            }
        }
    }

    public var textoLibre = ""
    public var ciudad = ""
    public var tipo: TipoHospedaje?
    public var convivencia: Convivencia?
    public var orden: Orden = .relevancia
    public var cercaDeMi = false

    public private(set) var resultados: [Hospedaje] = []
    public private(set) var isLoading = false
    public private(set) var error: AppError?
    public private(set) var totalCargados = 0

    /// Cuántos elementos de `resultados` se muestran ya en la lista — crece de a
    /// `tamanoPagina` conforme el usuario llega al final (paginación de cliente).
    public private(set) var visibleCount = 0
    private let tamanoPagina = 20

    private let service: HospedajesServicing
    private let locationProvider: LocationProvider

    public init(service: HospedajesServicing = HospedajesService(), locationProvider: LocationProvider = LocationProvider()) {
        self.service = service
        self.locationProvider = locationProvider
    }

    public var resultadosVisibles: [Hospedaje] {
        Array(resultados.prefix(visibleCount))
    }

    public var hayMasPorMostrar: Bool {
        visibleCount < resultados.count
    }

    public func buscar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        var lat: Double?
        var lng: Double?
        if cercaDeMi {
            if let coordenada = await locationProvider.solicitarUbicacion() {
                lat = coordenada.latitude
                lng = coordenada.longitude
            } else {
                cercaDeMi = false // el usuario negó el permiso o falló: no bloquea la búsqueda
            }
        }

        let filtros = BuscarHospedajesFiltros(
            ciudad: ciudad.isEmpty ? nil : ciudad,
            tipo: tipo,
            convivencia: convivencia,
            lat: lat,
            lng: lng,
            radio: lat != nil ? 15_000 : nil,
            q: textoLibre.isEmpty ? nil : textoLibre,
            orden: orden == .relevancia ? nil : orden.rawValue
        )

        do {
            let respuesta = try await service.buscar(filtros)
            resultados = respuesta.hospedajes
            totalCargados = respuesta.total
            visibleCount = min(tamanoPagina, resultados.count)
        } catch let appError as AppError {
            error = appError
            resultados = []
        } catch {
            self.error = .desconocido(error.localizedDescription)
            resultados = []
        }
    }

    public func cargarMasSiHaceFalta(elementoActual: Hospedaje) {
        guard let index = resultados.firstIndex(where: { $0.id == elementoActual.id }) else { return }
        let umbral = visibleCount - 5
        if index >= umbral, hayMasPorMostrar {
            visibleCount = min(visibleCount + tamanoPagina, resultados.count)
        }
    }

    public func limpiarFiltros() {
        textoLibre = ""
        ciudad = ""
        tipo = nil
        convivencia = nil
        orden = .relevancia
        cercaDeMi = false
    }
}
