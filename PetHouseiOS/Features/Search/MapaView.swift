//
//  MapaView.swift
//  Features/Search
//
//  MapKit nativo mostrando los hospedajes con `lat`/`lng` que ya devuelve la API — el
//  prototipo HTML usaba un SVG de Colombia hecho a mano (`colombia.geo.json`), que aquí
//  se reemplaza por completo por un mapa real (ver ARCHITECTURE_AUDIT.md §6, gap 🟢
//  "no bloqueante", decisión ya tomada de ir directo a MapKit).
//
//  La app es solo de Bogotá (ver Core/Models/Localidad.swift): la cámara siempre arranca
//  encuadrando toda la ciudad, no la primera coordenada de `hospedajes` — y se segmenta por
//  localidad con pines coloreados + una lista con el conteo de cada una (decisión de
//  producto: pines + lista, no un mapa de polígonos con límites oficiales — ver el chat).
//  Tocar una localidad de la lista recentra el mapa ahí y filtra los pines a esa localidad;
//  tocar de nuevo la misma quita el filtro.
//

import SwiftUI
import MapKit

struct MapaView: View {
    let hospedajes: [Hospedaje]

    @State private var viewModel = MapaViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var camara: MapCameraPosition
    @State private var seleccionado: Hospedaje?
    @State private var localidadSeleccionada: Localidad?

    init(hospedajes: [Hospedaje]) {
        self.hospedajes = hospedajes
        _camara = State(initialValue: .region(MapaView.regionBogota))
    }

    private static var regionBogota: MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: Localidad.centroBogota.lat, longitude: Localidad.centroBogota.lng),
            span: MKCoordinateSpan(latitudeDelta: Localidad.spanBogota.lat, longitudeDelta: Localidad.spanBogota.lng)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            listaLocalidades

            Map(position: $camara, selection: $seleccionado) {
                ForEach(hospedajesVisibles) { hospedaje in
                    Marker(hospedaje.titulo, systemImage: "pawprint.fill", coordinate: coordenada(de: hospedaje)!)
                        .tint(color(de: hospedaje))
                        .tag(hospedaje)
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
        }
        .navigationTitle("Mapa de Bogotá")
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
            } else if hospedajesVisibles.isEmpty {
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
        .task { await viewModel.cargar() }
    }

    /// Chips horizontales "Localidad (N)" — tocar una recentra el mapa ahí y filtra los
    /// pines a esa localidad; tocar la misma otra vez limpia el filtro. Ordenadas por
    /// cantidad de hospedajes (de más a menos) para que se vea de un vistazo dónde hay
    /// más oferta, no en el orden numérico oficial de las localidades.
    private var listaLocalidades: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: PHSpacing.s8) {
                ForEach(localidadesOrdenadas) { conteo in
                    let localidad = Localidad(rawValue: conteo.localidad)
                    PHChip(
                        "\(conteo.localidad) (\(conteo.hospedajes))",
                        isSelected: localidadSeleccionada == localidad
                    ) {
                        alternarLocalidad(localidad)
                    }
                }
            }
            .padding(.horizontal, PHSpacing.s16)
            .padding(.vertical, PHSpacing.s8)
        }
        .background(.bar)
    }

    private var localidadesOrdenadas: [LocalidadConteo] {
        viewModel.localidades.sorted {
            $0.hospedajes != $1.hospedajes ? $0.hospedajes > $1.hospedajes : $0.localidad < $1.localidad
        }
    }

    private func alternarLocalidad(_ localidad: Localidad?) {
        guard let localidad else { return }
        if localidadSeleccionada == localidad {
            localidadSeleccionada = nil
            withAnimation { camara = .region(MapaView.regionBogota) }
        } else {
            localidadSeleccionada = localidad
            let centro = localidad.centro
            withAnimation {
                camara = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centro.lat, longitude: centro.lng),
                    span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
                ))
            }
        }
    }

    private var hospedajesVisibles: [Hospedaje] {
        let conUbicacion = hospedajes.filter { $0.lat != nil && $0.lng != nil }
        guard let localidadSeleccionada else { return conUbicacion }
        return conUbicacion.filter { $0.localidad == localidadSeleccionada.rawValue }
    }

    private func coordenada(de hospedaje: Hospedaje) -> CLLocationCoordinate2D? {
        guard let lat = hospedaje.lat, let lng = hospedaje.lng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    /// Color determinístico por localidad (un tono distinto por índice en `allCases`, no
    /// una paleta curada a mano) para diferenciar pines de un vistazo — cae al rosa de
    /// marca si el hospedaje no tiene localidad asignada (datos viejos fuera de Bogotá).
    private func color(de hospedaje: Hospedaje) -> Color {
        guard let raw = hospedaje.localidad, let localidad = Localidad(rawValue: raw),
              let indice = Localidad.allCases.firstIndex(of: localidad) else {
            return Color(uiColor: .systemPink)
        }
        let tono = Double(indice) / Double(Localidad.allCases.count)
        return Color(hue: tono, saturation: 0.6, brightness: 0.75)
    }
}
