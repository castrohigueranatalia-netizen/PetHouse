//
//  BuscarViewModel.swift
//  Features/Search
//
//  GET /api/hospedajes pagina de verdad contra la base (`pagina`/`porPagina`, ver
//  pethouse-api/README.md). Este ViewModel pide una página de `tamanoPagina` resultados por
//  vez; cuando el usuario hace scroll cerca del final (`cargarMasSiHaceFalta`) pide la
//  siguiente página al servidor y la agrega a `resultados`, en vez de revelar de a poco un
//  lote ya descargado completo.
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

    /// `true` mientras se pide una página adicional en segundo plano (scroll) — separado
    /// de `isLoading`, que es solo para la búsqueda inicial (esa sí bloquea toda la lista).
    public private(set) var cargandoMas = false
    private var paginaActual = 1
    private let tamanoPagina = 20

    /// Coordenadas capturadas al iniciar una búsqueda con `cercaDeMi` activo — se reusan al
    /// pedir páginas siguientes para no volver a pedir permiso de ubicación en cada scroll.
    private var latActual: Double?
    private var lngActual: Double?

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

    public var hayMasPorMostrar: Bool {
        resultados.count < totalCargados
    }

    public func buscar() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        latActual = nil
        lngActual = nil
        if cercaDeMi {
            if let coordenada = await locationProvider.solicitarUbicacion() {
                latActual = coordenada.latitude
                lngActual = coordenada.longitude
            } else {
                cercaDeMi = false // el usuario negó el permiso o falló: no bloquea la búsqueda
            }
        }

        paginaActual = 1
        do {
            let respuesta = try await service.buscar(construirFiltros(), pagina: paginaActual, porPagina: tamanoPagina)
            resultados = respuesta.hospedajes
            totalCargados = respuesta.total
        } catch let appError as AppError {
            error = appError
            resultados = []
            totalCargados = 0
        } catch {
            self.error = .desconocido(error.localizedDescription)
            resultados = []
            totalCargados = 0
        }
    }

    public func cargarMasSiHaceFalta(elementoActual: Hospedaje) {
        guard let index = resultados.firstIndex(where: { $0.id == elementoActual.id }) else { return }
        let umbral = resultados.count - 5
        guard index >= umbral, hayMasPorMostrar, !cargandoMas else { return }
        Task { await cargarSiguientePagina() }
    }

    private func cargarSiguientePagina() async {
        guard !cargandoMas, hayMasPorMostrar else { return }
        cargandoMas = true
        defer { cargandoMas = false }

        let siguiente = paginaActual + 1
        do {
            let respuesta = try await service.buscar(construirFiltros(), pagina: siguiente, porPagina: tamanoPagina)
            resultados.append(contentsOf: respuesta.hospedajes)
            totalCargados = respuesta.total
            paginaActual = siguiente
        } catch {
            // Silencioso a propósito: ya hay resultados visibles en pantalla, no vale la
            // pena reemplazarlos por un estado de error solo porque falló traer una página
            // más — el usuario puede reintentar volviendo a hacer scroll.
        }
    }

    private func construirFiltros() -> BuscarHospedajesFiltros {
        BuscarHospedajesFiltros(
            ciudad: ciudad.isEmpty ? nil : ciudad,
            tipo: tipo,
            convivencia: convivencia,
            desde: usarFechas ? PHDate.toAPIDateOnly(desde) : nil,
            hasta: usarFechas ? PHDate.toAPIDateOnly(hasta) : nil,
            lat: latActual,
            lng: lngActual,
            radio: latActual != nil ? 15_000 : nil,
            q: textoLibre.isEmpty ? nil : textoLibre,
            orden: orden == .relevancia ? nil : orden.rawValue
        )
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
