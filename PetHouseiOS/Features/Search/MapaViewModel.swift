//
//  MapaViewModel.swift
//  Features/Search
//
//  Trae el conteo de hospedajes por localidad (GET /api/hospedajes/localidades) para la
//  lista que acompaña al mapa en MapaView — independiente de qué página de resultados
//  esté cargada en BuscarView, así el conteo siempre refleja el total real de Bogotá.
//

import Foundation

@MainActor
@Observable
public final class MapaViewModel {
    public private(set) var localidades: [LocalidadConteo] = []
    public private(set) var isLoading = false

    private let service: HospedajesServicing

    public init(service: HospedajesServicing = HospedajesService()) {
        self.service = service
    }

    public func cargar() async {
        isLoading = true
        defer { isLoading = false }
        // Silencioso a propósito: si falla, el mapa sigue siendo útil sin la lista de
        // localidades (simplemente no se muestra), no vale la pena un estado de error
        // encima del mapa por esto.
        localidades = (try? await service.localidades()) ?? []
    }
}
