//
//  MapaFavoritosView.swift
//  Features/Favoritos
//
//  Mapa mostrando SOLO los hospedajes favoritos (a diferencia de MapaView, que a propósito
//  siempre muestra TODA Bogotá sin importar filtros, ver su comentario) — la cámara arranca
//  encuadrando todos los favoritos con coordenadas, no la ciudad completa. Recibe la lista
//  ya cargada de FavoritosView/FavoritosViewModel, no pide nada por su cuenta.
//

import SwiftUI
import MapKit

struct MapaFavoritosView: View {
    let hospedajes: [Hospedaje]
    @Environment(\.dismiss) private var dismiss
    @State private var camara: MapCameraPosition
    @State private var seleccionado: Hospedaje?

    init(hospedajes: [Hospedaje]) {
        self.hospedajes = hospedajes
        _camara = State(initialValue: .region(Self.regionQueAbarcaTodos(hospedajes)))
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $camara, selection: $seleccionado) {
                ForEach(hospedajesConUbicacion) { hospedaje in
                    Marker(hospedaje.titulo, systemImage: "heart.fill", coordinate: coordenada(de: hospedaje)!)
                        .tint(PHColor.primary)
                        .tag(hospedaje)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
        }
        .navigationTitle("Tus favoritos en el mapa")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                PHTextButton("Cerrar") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let seleccionado {
                NavigationLink(value: seleccionado) {
                    PHHospedajeCard(seleccionado)
                        .padding(PHSpacing.s16)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial)
            } else if hospedajesConUbicacion.isEmpty {
                Text("Ninguno de tus favoritos tiene coordenadas cargadas todavía.")
                    .phText(PHFont.captionSM, color: PHColor.muted)
                    .padding(PHSpacing.s16)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .navigationDestination(for: Hospedaje.self) { hospedaje in
            HospedajeDetailView(hospedajeId: hospedaje.id)
        }
    }

    private var hospedajesConUbicacion: [Hospedaje] {
        hospedajes.filter { $0.lat != nil && $0.lng != nil }
    }

    private func coordenada(de hospedaje: Hospedaje) -> CLLocationCoordinate2D? {
        guard let lat = hospedaje.lat, let lng = hospedaje.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Región que encuadra todos los favoritos con coordenadas, con un margen del 40% para
    /// que ningún pin quede pegado al borde — cae a toda Bogotá (mismo centro/span que usa
    /// MapaView) si ninguno tiene coordenadas cargadas todavía.
    private static func regionQueAbarcaTodos(_ hospedajes: [Hospedaje]) -> MKCoordinateRegion {
        let coords: [CLLocationCoordinate2D] = hospedajes.compactMap {
            guard let lat = $0.lat, let lng = $0.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        guard let primerLat = coords.first?.latitude else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: Localidad.centroBogota.lat, longitude: Localidad.centroBogota.lng),
                span: MKCoordinateSpan(latitudeDelta: Localidad.spanBogota.lat, longitudeDelta: Localidad.spanBogota.lng)
            )
        }
        var minLat = primerLat, maxLat = primerLat
        var minLng = coords[0].longitude, maxLng = coords[0].longitude
        for coordenada in coords {
            minLat = min(minLat, coordenada.latitude)
            maxLat = max(maxLat, coordenada.latitude)
            minLng = min(minLng, coordenada.longitude)
            maxLng = max(maxLng, coordenada.longitude)
        }
        let centro = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLng + maxLng) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.4, 0.05),
            longitudeDelta: max((maxLng - minLng) * 1.4, 0.05)
        )
        return MKCoordinateRegion(center: centro, span: span)
    }
}
