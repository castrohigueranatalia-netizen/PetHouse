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

    /// Barra de búsqueda principal (ver BuscarView/BuscadorSheet): ciudad + fechas +
    /// convivencia — a diferencia de `ciudad`/`convivencia` de arriba (que ya existían para
    /// el sheet de "Filtros" avanzados), estos son los 3 campos prominentes que arman el
    /// filtro principal, junto con las fechas, que antes no se usaban en la búsqueda para
    /// nada (solo en el flujo de reserva). `usarFechas` es explícito: sin fechas es una
    /// búsqueda válida ("cualquier fecha"), no hay forma de "vaciar" un DatePicker.
    public var usarFechas = false
    public var desde: Date = .now
    public var hasta: Date = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now

    /// Texto corto para mostrar en la barra colapsada (ver BuscarView).
    public var resumenBusqueda: String {
        var partes: [String] = []
        partes.append(ciudad.isEmpty ? "Cualquier ciudad" : ciudad)
        if usarFechas {
            partes.append("\(PHDate.displayShort.string(from: desde)) – \(PHDate.displayShort.string(from: hasta))")
        }
        if let convivencia, convivencia != .cualquiera {
            partes.append(convivencia.etiqueta)
        }
        return partes.joined(separator: " · ")
    }

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

    // `locationProvider` NO puede tener `LocationProvider()` como valor por defecto en la
    // firma del init: Swift no trata las expresiones de valores por defecto como aisladas
    // al MainActor aunque la clase entera lo sea, así que llamar ahí al init de
    // `LocationProvider` (también @MainActor) falla en compilación ("Call to main
    // actor-isolated initializer in a synchronous nonisolated context"). Se resuelve
    // aceptando `nil` como default y creándolo dentro del cuerpo del init, que sí corre
    // aislado al MainActor.
    public init(service: HospedajesServicing = HospedajesService(), locationProvider: LocationProvider? = nil) {
        self.service = service
        self.locationProvider = locationProvider ?? LocationProvider()
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
            desde: usarFechas ? PHDate.toAPIDateOnly(desde) : nil,
            hasta: usarFechas ? PHDate.toAPIDateOnly(hasta) : nil,
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
        usarFechas = false
        desde = .now
        hasta = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    }
}
