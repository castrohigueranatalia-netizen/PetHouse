//
//  MapaView.swift
//  Features/Search
//
//  MapKit nativo mostrando los hospedajes con `lat`/`lng` que ya devuelve la API — el
//  prototipo HTML usaba un SVG de Colombia hecho a mano (`colombia.geo.json`), que aquí
//  se reemplaza por completo por un mapa real (ver ARCHITECTURE_AUDIT.md §6, gap 🟢
//  "no bloqueante", decisión ya tomada de ir directo a MapKit).
//

import SwiftUI
import MapKit

struct MapaView: View {
    let hospedajes: [Hospedaje]

    @Environment(\.dismiss) private var dismiss
    @State private var camara: MapCameraPosition
    @State private var seleccionado: Hospedaje?

    init(hospedajes: [Hospedaje]) {
        self.hospedajes = hospedajes
        let coordenadasValidas = hospedajes.compactMap { hospedaje -> CLLocationCoordinate2D? in
            guard let lat = hospedaje.lat, let lng = hospedaje.lng else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        if let primera = coordenadasValidas.first {
            _camara = State(initialValue: .region(
                MKCoordinateRegion(center: primera, span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
            ))
        } else {
            // Centro por defecto: Colombia (Bogotá), igual que el mapa del prototipo.
            _camara = State(initialValue: .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 4.7110, longitude: -74.0721),
                    span: MKCoordinateSpan(latitudeDelta: 6, longitudeDelta: 6)
                )
            ))
        }
    }

    var body: some View {
        Map(position: $camara, selection: $seleccionado) {
            ForEach(hospedajesConUbicacion) { hospedaje in
                Marker(hospedaje.titulo, systemImage: "pawprint.fill", coordinate: coordenada(de: hospedaje)!)
                    .tint(Color(uiColor: .systemPink))
                    .tag(hospedaje)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .navigationTitle("Mapa")
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
                Text("Ninguno de estos hospedajes tiene coordenadas cargadas todavía.")
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
}
