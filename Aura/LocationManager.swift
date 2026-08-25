import AuraKit
import CoreLocation

/// Thin Core Location wrapper: requests a one-shot fix and reports the nearest municipality
/// from the full bundled table (`MunicipioDatabase`) by great-circle distance.
@MainActor
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isResolving = false
    @Published var authorizationDenied = false

    private let manager = CLLocationManager()
    private var completion: ((Location?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Requests permission (if needed) and resolves the nearest bundled city.
    func resolveNearestCity(_ completion: @escaping (Location?) -> Void) {
        self.completion = completion
        authorizationDenied = false
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            authorizationDenied = true
            finish(nil)
        default:
            isResolving = true
            manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            isResolving = true
            manager.requestLocation()
        case .denied, .restricted:
            authorizationDenied = true
            finish(nil)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { finish(nil); return }
        finish(Self.nearestCity(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }

    private func finish(_ location: Location?) {
        isResolving = false
        completion?(location)
        completion = nil
    }

    /// Nearest municipality by great-circle distance, across the full bundled table.
    static func nearestCity(latitude: Double, longitude: Double) -> Location? {
        let here = CLLocation(latitude: latitude, longitude: longitude)
        return MunicipioDatabase.all.min { a, b in
            here.distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude)) <
            here.distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
        }
    }
}
