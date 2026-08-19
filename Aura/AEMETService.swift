import AuraKit
import Foundation
import WidgetKit

/// Bridges the app to `AEMETClient`: builds a client from the stored key and turns
/// low-level client errors into Spanish, user-facing messages.
enum AEMETService {
    /// A client built from the Keychain key, or nil if no key has been entered yet.
    static func client() -> AEMETClient? {
        guard let key = AuraKeychain.apiKey(), !key.isEmpty else { return nil }
        return AEMETClient(apiKey: key)
    }

    /// Fetch and cache a snapshot for every saved location so any widget-selected location has
    /// data, then reload the widgets. Locations cached within the last hour are skipped to stay
    /// well under AEMET's rate limit; a single failure never aborts the rest.
    static func refreshAllForWidgets(_ locations: [Location]) async {
        guard let client = client() else { return }
        // One national observation fetch serves every location; nearest station is resolved locally.
        let stale = locations.filter { location in
            guard let existing = SharedCache.snapshot(forINE: location.ine) else { return true }
            return Date().timeIntervalSince(existing.updated) >= 3600
        }
        guard !stale.isEmpty else { return }
        let observations = (try? await client.observacionTodas()) ?? []
        var didUpdate = false
        for location in stale {
            guard let daily = try? await client.municipioDiaria(location.ine) else { continue }
            let hourly = try? await client.municipioHoraria(location.ine)
            let observed = StationObservation.nearest(toLatitude: location.latitude,
                                                      longitude: location.longitude,
                                                      in: observations)
            SharedCache.upsert(WeatherSnapshot.make(location: location, daily: daily, hourly: hourly,
                                                    observed: observed, timeZone: location.timeZone))
            didUpdate = true
        }
        if didUpdate { WidgetCenter.shared.reloadAllTimelines() }
    }

    /// Spanish message for any error surfaced while talking to AEMET.
    static func message(for error: Error) -> String {
        switch error {
        case AEMETClient.ClientError.missingAPIKey:
            return "Falta la clave de AEMET. Añádela en Ajustes."
        case AEMETClient.ClientError.rateLimited:
            return "AEMET ha limitado las peticiones. Inténtalo en un minuto."
        case AEMETClient.ClientError.http(let code):
            return "Error de red (HTTP \(code))."
        case AEMETClient.ClientError.aemetStatus(let code, let desc):
            return "AEMET devolvió \(code): \(desc)"
        case AEMETClient.ClientError.decoding:
            return "No se pudieron leer los datos de AEMET."
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            return "Sin conexión. Se muestran los últimos datos disponibles."
        default:
            return "No se pudo obtener la información."
        }
    }
}
