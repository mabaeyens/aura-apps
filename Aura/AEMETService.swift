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
        // Fetch each distinct avisos area at most once, then resolve per location by province.
        let areas = Set(stale.compactMap { AvisoArea.forProvincia($0.provinciaCode) })
        var alertsByArea: [String: [WeatherAlert]] = [:]
        for area in areas {
            alertsByArea[area] = (try? await client.avisos(area: area)) ?? []
        }
        // The Watch shows the primary location, so fetch its community bulletin once and attach it
        // there (only that snapshot carries the narrative — it's what the Watch renders).
        let primary = locations.first
        var primaryBulletin: ForecastBulletin?
        if let primary, stale.contains(where: { $0.ine == primary.ine }), let comunidad = primary.comunidad {
            primaryBulletin = try? await client.comunidadBulletin(comunidad)
        }
        var didUpdate = false
        for location in stale {
            guard let daily = try? await client.municipioDiaria(location.ine) else { continue }
            let hourly = try? await client.municipioHoraria(location.ine)
            let observed = StationObservation.nearest(toLatitude: location.latitude,
                                                      longitude: location.longitude,
                                                      in: observations)
            let alert = AvisoArea.forProvincia(location.provinciaCode)
                .flatMap { alertsByArea[$0] }?
                .topActive(forProvince: location.provinciaCode)
            let bulletin = location.ine == primary?.ine ? primaryBulletin : nil
            SharedCache.upsert(WeatherSnapshot.make(location: location, daily: daily, hourly: hourly,
                                                    observed: observed, alert: alert, bulletin: bulletin,
                                                    timeZone: location.timeZone))
            didUpdate = true
        }
        if didUpdate {
            WidgetCenter.shared.reloadAllTimelines()
            // Keep the Watch fed even if the user never opens "Hoy": push the primary location.
            if let primary = locations.first,
               let snapshot = SharedCache.snapshot(forINE: primary.ine) {
                WatchSync.shared.send(snapshot)
            }
        }
    }

    /// The most severe active warning for one location's province, or nil. Best-effort.
    static func topAlert(for location: Location, using client: AEMETClient) async -> WeatherAlert? {
        guard let area = AvisoArea.forProvincia(location.provinciaCode),
              let alerts = try? await client.avisos(area: area) else { return nil }
        return alerts.topActive(forProvince: location.provinciaCode)
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
