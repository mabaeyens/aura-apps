import AuraKit
import Foundation
import WidgetKit

/// Bridges the app to `AEMETClient`: builds a client from the stored key, runs the one shared refresh
/// that feeds the App Group cache, and turns low-level client errors into Spanish messages.
///
/// There is a single fetch path — `refreshAllForWidgets` — and it is *coalesced*: if a refresh is
/// already running, every other caller (the launch task, the scene-active handler, the "Hoy" screen)
/// awaits that same run instead of starting its own. That's what keeps a cold rebuild from firing two
/// or three overlapping bursts of AEMET requests and tripping the rate limit. AEMET has no bulk
/// municipal-forecast endpoint, so each location is still its own call; the national observations,
/// though, are fetched once and sliced locally.
enum AEMETService {
    /// A client built from the Keychain key, or nil if no key has been entered yet.
    static func client() -> AEMETClient? {
        guard let key = AuraKeychain.apiKey(), !key.isEmpty else { return nil }
        return AEMETClient(apiKey: key)
    }

    private static let refreshGate = RefreshGate()

    /// Refresh and cache a snapshot for every saved location, then reload widgets and push the primary
    /// to the Watch. Coalesced (see the type note) and, unless `force`, skips locations cached within
    /// the last hour to stay well under AEMET's rate limit. Returns a Spanish error message if the
    /// refresh hit a problem worth showing (e.g. rate-limited, offline), else nil.
    @discardableResult
    static func refreshAllForWidgets(_ locations: [Location], force: Bool = false) async -> String? {
        await refreshGate.run { await performRefresh(locations, force: force) }
    }

    private static func performRefresh(_ locations: [Location], force: Bool) async -> String? {
        guard let client = client() else { return nil }
        var firstError: String?
        func note(_ error: Error) { if firstError == nil { firstError = message(for: error) } }

        // Locations that need fetching: everything on `force`, otherwise those older than an hour or
        // cached by a build before the daily sky/wind fields existed (their days decode with sky == nil,
        // which is why every day rendered as a generic cloud until the next refresh).
        let stale = force ? locations : locations.filter { location in
            guard let existing = SharedCache.snapshot(forINE: location.ine) else { return true }
            if Date().timeIntervalSince(existing.updated) >= 3600 { return true }
            if !existing.days.isEmpty, existing.days.allSatisfy({ $0.sky == nil }) { return true }
            return false
        }
        guard !stale.isEmpty else { return nil }

        // One national observation fetch serves every location; nearest station is resolved locally.
        var observations: [StationObservation] = []
        do { observations = try await client.observacionTodas() } catch { note(error) }

        // Fetch each distinct avisos area at most once, then resolve per location by province.
        let areas = Set(stale.compactMap { AvisoArea.forProvincia($0.provinciaCode) })
        var alertsByArea: [String: [WeatherAlert]] = [:]
        for area in areas {
            do { alertsByArea[area] = try await client.avisos(area: area) }
            catch { note(error); alertsByArea[area] = [] }
        }

        // The Watch shows the primary location, so fetch its community bulletin once and attach it
        // there (only that snapshot carries the narrative — it's what the Watch renders).
        let primary = locations.first
        var primaryBulletin: ForecastBulletin?
        if let primary, stale.contains(where: { $0.ine == primary.ine }), let comunidad = primary.comunidad {
            do { primaryBulletin = try await client.comunidadBulletin(comunidad) } catch { note(error) }
        }

        var didUpdate = false
        for location in stale {
            let daily: MunicipioForecast
            do { daily = try await client.municipioDiaria(location.ine) }
            catch { note(error); continue }
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
            if let primary, let snapshot = SharedCache.snapshot(forINE: primary.ine) {
                WatchSync.shared.send(snapshot)
            }
        }
        return firstError
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

/// Serializes refreshes: the first caller runs the work; concurrent callers await that same run and
/// share its result, so overlapping triggers never fan out into duplicate AEMET requests.
private actor RefreshGate {
    private var current: Task<String?, Never>?

    func run(_ operation: @Sendable @escaping () async -> String?) async -> String? {
        if let current { return await current.value }
        let task = Task { await operation() }
        current = task
        let result = await task.value
        current = nil
        return result
    }
}
