import AuraKit
import BackgroundTasks
import Foundation
import os
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

    // MARK: - Background refresh

    /// The BGAppRefreshTask identifier. Must match `BGTaskSchedulerPermittedIdentifiers` in Info.plist
    /// and the `.backgroundTask(.appRefresh(...))` handler in `AuraApp`.
    static let backgroundRefreshIdentifier = "com.mab.Aura.refresh"

    /// Trace the background top-up so it can be watched on device with
    /// `log stream --predicate 'subsystem == "com.mab.Aura"'` (or Console.app) while measuring battery.
    private static let bgLog = Logger(subsystem: "com.mab.Aura", category: "background")

    /// Refresh from the favourites mirrored to the App Group, for callers with no view/store (the
    /// background task). Same coalesced fetch path as the foreground; shows new data when there is any,
    /// otherwise leaves the cached snapshots untouched.
    static func refreshFromSharedLocations() async -> String? {
        bgLog.log("Background refresh started")
        let result = await refreshAllForWidgets(SharedLocations.read())
        if let result {
            bgLog.error("Background refresh finished with error: \(result, privacy: .public)")
        } else {
            bgLog.log("Background refresh finished, cache up to date")
        }
        return result
    }

    /// Ask iOS to wake Aura in the background about half an hour from now to top up the cache. iOS
    /// decides the real timing from the system Background App Refresh setting and usage patterns, so
    /// this is a request, not a guarantee. A failed submit (simulator, or the setting off) is fine to
    /// ignore: the app still refreshes on foreground.
    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            bgLog.log("Scheduled next background refresh, earliest in ~30 min")
        } catch {
            bgLog.error("Could not schedule background refresh: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func performRefresh(_ locations: [Location], force: Bool) async -> String? {
        // Drop cached snapshots for locations the user no longer tracks (and any long-stale leftover)
        // so the App Group cache stays bounded. Runs before the early-outs below so removed favourites
        // are cleaned up even when nothing needs fetching.
        SharedCache.prune(keepINEs: Set(locations.map(\.ine)))

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
        // Bail before the network work if the trigger was already cancelled (app backgrounded, view gone).
        if Task.isCancelled { return nil }

        // One national observation fetch serves every location; nearest station is resolved locally.
        var observations: [StationObservation] = []
        do { observations = try await client.observacionTodas() } catch { note(error) }

        // Air quality comes from MITECO's national ICA feed (not AEMET), also one download for every
        // location. It never throws — an empty result on a miteco outage just leaves the card hidden and
        // never blocks the AEMET refresh.
        let airStations = await MitecoAirQuality.stations()

        // Today's forecast max UV index — one AEMET call lists every provincial capital; resolved per
        // location by INE. A failure just leaves the UV card hidden.
        var uvCities: [UVIForecast.City] = []
        do { uvCities = try await client.uviCities(dia: 0) } catch { note(error) }

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
            // Stop fetching the rest the moment the task is cancelled; whatever was already upserted still
            // reloads the widgets below, so a partial refresh isn't wasted.
            if Task.isCancelled { break }
            let daily: MunicipioForecast
            do { daily = try await client.municipioDiaria(location.ine) }
            catch { note(error); continue }
            let hourly = try? await client.municipioHoraria(location.ine)
            let observed = StationObservation.nearest(toLatitude: location.latitude,
                                                      longitude: location.longitude,
                                                      in: observations)
            // Air quality: pull each pollutant from the nearest station that measures it (O₃ and SO₂
            // often aren't at the closest, urban-traffic station), then compose the índice from the worst
            // pollutant — MITECO's own method — using its running means. A handful of POSTs to MITECO's
            // backend (a separate host, outside the AEMET budget); on a miss, fall back to the single
            // nearest station's published índice so the card still stands.
            let breakdown = await MitecoAirQuality.breakdown(toLatitude: location.latitude,
                                                             longitude: location.longitude, in: airStations)
            let airQuality = MitecoAirQuality.composite(from: breakdown)
                ?? MitecoAirQuality.nearest(toLatitude: location.latitude,
                                            longitude: location.longitude, in: airStations)
            let uvIndex = UVIndex.pick(ine: location.ine, in: uvCities)
            // Hourly UV from CAMS (via Open-Meteo) — the per-hour granularity AEMET doesn't publish;
            // AEMET's daily max stays the official headline. One call/location to a separate free host
            // (like MITECO); never throws — an empty result just hides the hourly curve. © CAMS /
            // Copernicus + Open-Meteo (both credited).
            let uvHourly = await OpenMeteoUV.fetch(latitude: location.latitude,
                                                   longitude: location.longitude)
            let alert = AvisoArea.forProvincia(location.provinciaCode)
                .flatMap { alertsByArea[$0] }?
                .topActive(forProvince: location.provinciaCode)
            let bulletin = location.ine == primary?.ine ? primaryBulletin : nil
            let snapshot = WeatherSnapshot.make(location: location, daily: daily, hourly: hourly,
                                                observed: observed, alert: alert,
                                                airQuality: airQuality, uvIndex: uvIndex,
                                                uvHourly: uvHourly,
                                                bulletin: bulletin,
                                                timeZone: location.timeZone)
            // Only the active location notifies. Compare against the still-cached snapshot (read before
            // the upsert below) so a genuinely new aviso or an updated forecast fires exactly once.
            if location.ine == primary?.ine {
                NotificationManager.evaluatePrimary(old: SharedCache.snapshot(forINE: location.ine),
                                                    new: snapshot)
            }
            SharedCache.upsert(snapshot)
            didUpdate = true
        }

        if didUpdate {
            WidgetCenter.shared.reloadAllTimelines()
            // Keep the Watch fed even if the user never opens "Hoy": push the primary location as active,
            // plus the whole favourites menu and their snapshots so the Watch can switch places on its own.
            if let primary, let snapshot = SharedCache.snapshot(forINE: primary.ine) {
                WatchSync.shared.send(active: snapshot, favorites: locations)
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
