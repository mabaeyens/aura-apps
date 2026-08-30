import AuraKit
import CoreLocation

/// One-shot Core Location on the wrist: request a single fix and resolve the nearest bundled
/// municipality, so the Watch can fetch weather for wherever it physically is, standalone, with no
/// paired iPhone in the loop. Deliberately one-shot (`requestLocation`), never continuous tracking,
/// matching the phone's `LocationManager` and the decision not to ask for Always-location. Auth is
/// When In Use, requested lazily the first time current location is used.
@MainActor
final class WatchLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isResolving = false
    @Published var authorizationDenied = false

    private let manager = CLLocationManager()
    private var completion: ((Location?) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Request permission if needed and resolve the nearest municipality once. The completion fires with
    /// the resolved `Location`, or nil if permission was denied or the fix failed.
    func resolveNearest(_ completion: @escaping (Location?) -> Void) {
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
        finish(MunicipioDatabase.nearest(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(nil)
    }

    private func finish(_ location: Location?) {
        isResolving = false
        completion?(location)
        completion = nil
    }
}
