//
//  LocationProvider.swift
//  Core/Utils
//
//  Envoltorio async/await sobre `CLLocationManager`. El permiso de ubicación se pide
//  SOLO cuando el usuario abre el mapa o toca "cerca de mí" — nunca al arrancar la app
//  (ver requisito de seguridad del MVP). `NSLocationWhenInUseUsageDescription` está
//  declarado en project.yml con el texto que justifica este uso puntual.
//

import CoreLocation

@MainActor
@Observable
public final class LocationProvider: NSObject, CLLocationManagerDelegate {
    public enum Estado: Equatable {
        case sinSolicitar
        case buscando
        case obtenida(CLLocationCoordinate2D)
        case denegada
        case error(String)

        public static func == (lhs: Estado, rhs: Estado) -> Bool {
            switch (lhs, rhs) {
            case (.sinSolicitar, .sinSolicitar), (.buscando, .buscando), (.denegada, .denegada):
                return true
            case let (.obtenida(a), .obtenida(b)):
                return a.latitude == b.latitude && a.longitude == b.longitude
            case let (.error(a), .error(b)):
                return a == b
            default:
                return false
            }
        }
    }

    public private(set) var estado: Estado = .sinSolicitar

    private let manager = CLLocationManager()
    private var continuacion: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Pide el permiso (si hace falta) y devuelve la coordenada actual, o `nil` si el
    /// usuario la niega o falla — nunca lanza, para que las vistas de mapa/búsqueda no
    /// tengan que tratar esto como un error de red.
    public func solicitarUbicacion() async -> CLLocationCoordinate2D? {
        let status = manager.authorizationStatus
        switch status {
        case .denied, .restricted:
            estado = .denegada
            return nil
        case .notDetermined:
            estado = .buscando
            manager.requestWhenInUseAuthorization()
            // La autorización llega vía delegate; esperamos ahí antes de pedir ubicación.
            return await esperarAutorizacionYUbicar()
        case .authorizedWhenInUse, .authorizedAlways:
            return await pedirUbicacionActual()
        @unknown default:
            estado = .error("Estado de permisos desconocido.")
            return nil
        }
    }

    private func esperarAutorizacionYUbicar() async -> CLLocationCoordinate2D? {
        // CLLocationManager entrega el cambio de autorización de forma asíncrona vía
        // delegate; sondeamos brevemente en vez de modelar un segundo continuation para
        // mantener esto simple en el MVP.
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                return await pedirUbicacionActual()
            case .denied, .restricted:
                estado = .denegada
                return nil
            default:
                continue
            }
        }
        estado = .error("No respondiste al permiso de ubicación a tiempo.")
        return nil
    }

    private func pedirUbicacionActual() async -> CLLocationCoordinate2D? {
        estado = .buscando
        return await withCheckedContinuation { continuation in
            self.continuacion = continuation
            manager.requestLocation()
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.estado = .obtenida(coordinate)
            self.continuacion?.resume(returning: coordinate)
            self.continuacion = nil
        }
    }

    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.estado = .error(error.localizedDescription)
            self.continuacion?.resume(returning: nil)
            self.continuacion = nil
        }
    }
}
