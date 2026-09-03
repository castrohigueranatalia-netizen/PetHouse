//
//  MapaViewModel.swift
//  Features/Search
//
//  Trae, por separado de BuscarViewModel, TODOS los hospedajes activos de Bogotá con
//  coordenadas (para los pines) y el conteo por localidad (GET /api/hospedajes/localidades,
//  para la lista de chips). A propósito NO usa los resultados ya cargados en la pantalla de
//  Buscar: esos pueden venir filtrados a una sola localidad o incompletos si el usuario no
//  hizo scroll hasta el final — el mapa es una vista de exploración aparte y siempre debe
//  mostrar toda la ciudad, sin importar qué filtro tenga activo el buscador.
//

import Foundation

@MainActor
@Observable
public final class MapaViewModel {
    public private(set) var localidades: [LocalidadConteo] = []
    public private(set) var hospedajes: [Hospedaje] = []
    public private(set) var isLoading = false

    private let service: HospedajesServicing

    public init(service: HospedajesServicing = HospedajesService()) {
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        defer { isLoading = false }
        // Silenciosos a propósito: si falla alguno, el mapa sigue siendo útil con lo que sí
        // haya llegado (o vacío), no vale la pena un estado de error encima del mapa.
        localidades = (try? await service.localidades()) ?? []
        // Sin filtros (BuscarHospedajesFiltros() vacío): TODA Bogotá. 50 es el máximo que
        // acepta el servidor por página (ver pethouse-api/src/routes/hospedajes.js) — hoy
        // Bogotá tiene menos hospedajes que eso, así que entran todos en una sola llamada.
        if let respuesta = try? await service.buscar(BuscarHospedajesFiltros(), pagina: 1, porPagina: 50) {
            hospedajes = respuesta.hospedajes
        }
    }
}
