import Foundation
import os

/// The one fetch → normalize → cache path, shared by the app and the widget extension.
///
/// This is the body that used to live inside `AEMETService.performRefresh`, lifted into AuraKit so the
/// widget's timeline provider can reuse it verbatim instead of growing a second implementation that
/// could resolve differently (the spec's hard rule: one fetch path, one cache). Everything it touches
/// — `AEMETClient`, `SharedCache`, `MitecoAirQuality`, `WeatherSnapshot.make`, the avisos/UV/bulletin
/// feeds — already lives in AuraKit. The two app-only side effects that used to run inline do **not**:
/// posting a local notification and pushing to the Watch both depend on app-target types
/// (`NotificationManager`, and `WCSession`, which is unavailable in an extension). So the core no longer
/// performs them — it returns a `RefreshOutcome` describing what changed, and each caller applies its own
/// side effects: the app fires notifications, reloads widgets and syncs the Watch; the widget simply
/// reads the freshened cache for its timeline.
public enum AuraRefreshCore {
    /// One location's before/after, so a caller can decide whether to notify. `old` is the snapshot that
    /// was cached before this refresh (read before the upsert), `new` is what we computed for it.
    public struct RefreshEvent: Sendable {
        public let old: WeatherSnapshot?
        public let new: WeatherSnapshot
        public let isPrimary: Bool
    }

    /// The result of a refresh, so callers can apply side effects without re-deriving anything.
    /// `didUpdate` mirrors the old `performRefresh` flag: at least one location was processed and the
    /// widgets/Watch should be refreshed. `errorMessage` is the first Spanish error worth showing, or nil.
    public struct RefreshOutcome: Sendable {
        public let events: [RefreshEvent]
        public let didUpdate: Bool
        public let errorMessage: String?

        static let noop = RefreshOutcome(events: [], didUpdate: false, errorMessage: nil)
    }

    /// A client built from the Keychain key, or nil if no key has been entered yet. Both the app and the
    /// widget build their client here so there is one definition of "how Aura talks to AEMET".
    public static func makeClient() -> AEMETClient? {
        guard let key = AuraKeychain.apiKey(), !key.isEmpty else { return nil }
        return AEMETClient(apiKey: key)
    }

    /// The refresh gate, made a pure function so it can be tested and so the app and the widget agree on
    /// exactly when a location is worth a network call. A location is stale — and so worth refetching —
    /// when its cached snapshot is absent, older than the one-hour rate-limit window, or was written by a
    /// build from before the daily sky/wind fields existed (every day decodes with `sky == nil`, which is
    /// why such a cache rendered every day as a generic cloud until the next refresh). This is the "lead
    /// with cache" rule the widget must honour so app and widget never diverge and never double-pull.
    public static let staleWindow: TimeInterval = 3600

    public static func isStale(_ existing: WeatherSnapshot?, now: Date = Date()) -> Bool {
        guard let existing else { return true }
        if now.timeIntervalSince(existing.updated) >= staleWindow { return true }
        // A snapshot with no hourly strip is "thin": the hourly fetch failed or returned nothing when it was
        // built, so it carries no current-hour data to resolve a hero or a next-hours card from. Treat it as
        // stale every time rather than let the one-hour age gate freeze it in — this is what left a once-thin
        // Madrid stuck showing "—" on passive loads and location switches (only a forced pull-to-refresh,
        // which bypasses this gate, could recover it) while other places, fetched when the hourly feed was
        // healthy, stayed fine. Refetching a thin snapshot on every load is what lets it self-heal.
        if existing.hours.isEmpty { return true }
        if !existing.days.isEmpty, existing.days.allSatisfy({ $0.sky == nil }) { return true }
        return false
    }

    /// The observation TTL: an hourly cadence plus a ~30-minute publish-lag margin. Used both as the fint-based
    /// fallback when the RSS marker is unreadable, and as the historical heuristic it replaced.
    public static let observationTTL: TimeInterval = 90 * 60

    /// The fint-based TTL gate (the fallback path). A location's national observation feed is due when there is
    /// no stored anchor (first fetch), on a `force`, or once `now` reaches `anchor + observationTTL`. The anchor
    /// is clamped to `now` so a corrupt future-dated `fint` can suppress a fetch for at most the margin window,
    /// never indefinitely. Pure, so it is unit-tested directly (mirrors aura-android's `observationDue`).
    public static func observationDue(anchor: Date?, now: Date, force: Bool) -> Bool {
        if force { return true }
        guard let anchor else { return true }
        let clamped = min(anchor, now)
        return now >= clamped.addingTimeInterval(observationTTL)
    }

    /// Whether the national observation feed is due, decided by AEMET's own publish marker rather than a timer.
    /// `rssMarker` is the newest publish time read from the keyless observation RSS this cycle (nil when the RSS
    /// was unreachable or unparseable, or when skipped on a `force`/single-location pass); `storedPublished` is
    /// the marker from the last successful keyed fetch. A `force` refresh always fetches. Otherwise, when the
    /// RSS marker is available, fetch only when it has advanced past `storedPublished` (a nil stored marker —
    /// first ever fetch — fetches), so a cycle where AEMET has published nothing new makes zero keyed calls.
    /// When the RSS is unreachable, fall back to the fint-based TTL (`observationDue` on `storedFint`) so the
    /// gate degrades gracefully.
    ///
    /// `storedPublished` and `storedFint` are two different clocks (publish time ~30 min past the hour vs the
    /// observation `fint` at the top of the hour) and are never compared against each other; the marker path
    /// uses only the former, the fallback only the latter. Pure, so it is unit-tested directly (mirrors
    /// aura-android's `observationDueFromMarker`).
    public static func observationDueFromMarker(storedPublished: Date?, rssMarker: Date?,
                                                storedFint: Date?, now: Date, force: Bool) -> Bool {
        if force { return true }
        if let rssMarker {
            guard let storedPublished else { return true }
            return rssMarker > storedPublished
        }
        return observationDue(anchor: storedFint, now: now, force: false)
    }

    /// Refresh and cache a snapshot for every stale location, returning what changed. Prunes the cache to
    /// the current favourites first (even when there is no key, so removed places are cleaned up), then —
    /// unless `force` — skips locations cached within the last hour to stay under AEMET's rate limit.
    /// `onlyINE`, when set, scopes the *fetch* to that one location while still pruning the whole list.
    ///
    /// Does no widget reload, no Watch push and no notification — see the type note. The caller owns those.
    public static func refresh(locations: [Location], force: Bool = false,
                               onlyINE: String? = nil) async -> RefreshOutcome {
        // Drop cached snapshots for locations the user no longer tracks (and any long-stale leftover)
        // so the App Group cache stays bounded. Runs before the early-outs below so removed favourites
        // are cleaned up even when nothing needs fetching.
        SharedCache.prune(keepINEs: Set(locations.map(\.ine)))

        guard let client = makeClient() else { return .noop }
        var firstError: String?
        func note(_ error: Error) { if firstError == nil { firstError = message(for: error) } }

        // Locations that need fetching. A pull-to-refresh on one place (`onlyINE`) fetches just that
        // place — the whole favourites list is still pruned below, but their forecasts aren't refetched on
        // a manual swipe. Otherwise: everything on `force`, else those older than an hour or cached by a
        // build before the daily sky/wind fields existed (their days decode with sky == nil, which is why
        // every day rendered as a generic cloud until the next refresh).
        let stale: [Location]
        if let onlyINE, let one = locations.first(where: { $0.ine == onlyINE }) {
            stale = [one]
        } else {
            stale = force ? locations : locations.filter {
                isStale(SharedCache.snapshot(forINE: $0.ine))
            }
        }
        guard !stale.isEmpty else { return RefreshOutcome(events: [], didUpdate: false, errorMessage: nil) }
        // Bail before the network work if the trigger was already cancelled (app backgrounded, view gone).
        if Task.isCancelled { return .noop }

        // One national observation fetch serves every location; nearest station is resolved locally.
        // That product updates once per hour, and each record carries its own measurement time (`fint`).
        // AEMET publishes each hourly reading 20-40 min after the hour, so we hold the last-known feed
        // until the next reading is genuinely due — the stored `fint` plus one hour plus a 30-minute
        // publish-lag margin — and skip the network call entirely until then. A forced or single-location
        // (`onlyINE`) refresh always fetches; when we skip, each location reuses its last good station
        // reading (carried forward in `WeatherSnapshot.make`) instead of blanking the observed card.
        // Gate the keyed observation download on AEMET's own publish marker, not a fixed timer: a cheap keyless
        // RSS notifier (`observacionRssUpdated`) says when the dataset last refreshed, and the keyed call fires
        // only when that marker has advanced past the one stored from the last fetch. A forced or single-
        // location (`onlyINE`) pull always fetches and skips the RSS probe. When the RSS is unreachable, fall
        // back to the fint-based TTL so the cadence degrades, never breaks. Two distinct markers for two
        // distinct jobs: the RSS publish time drives fetch cadence (compared RSS-to-RSS), the freshest `fint`
        // drives the display gate and the TTL fallback — different clocks, never compared against each other.
        // Mirrors aura-android's `observationDueFromMarker` (unified-freshness spec).
        var observations: [StationObservation] = []
        let alwaysFetch = force || onlyINE != nil
        let now = Date()
        let rssMarker: Date? = alwaysFetch ? nil : (try? await client.observacionRssUpdated())
        if observationDueFromMarker(storedPublished: SharedCache.lastObservationPublished,
                                    rssMarker: rssMarker,
                                    storedFint: SharedCache.lastObservationFint,
                                    now: now, force: alwaysFetch) {
            do {
                observations = try await client.observacionTodas()
                // Persist both markers for the next cycle: the freshest fint (display gate + TTL fallback) and,
                // when we read one, the RSS publish time (fetch cadence). They are different clocks.
                if let newest = observations.compactMap({ $0.timestamp }).max() {
                    SharedCache.lastObservationFint = newest
                }
                if let rssMarker { SharedCache.lastObservationPublished = rssMarker }
            } catch { note(error) }
        }

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

        var events: [RefreshEvent] = []
        var didUpdate = false
        for location in stale {
            // Stop fetching the rest the moment the task is cancelled; whatever was already upserted still
            // stands, so a partial refresh isn't wasted.
            if Task.isCancelled { break }
            // Read the still-cached snapshot once: it seeds the observation carry-forward when this cycle
            // skipped the hourly fetch, and it's the "old" value a notification compares against.
            let previous = SharedCache.snapshot(forINE: location.ine)
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
                                                observed: observed, previousObserved: previous,
                                                alert: alert,
                                                airQuality: airQuality, uvIndex: uvIndex,
                                                uvHourly: uvHourly,
                                                bulletin: bulletin,
                                                timeZone: location.timeZone)
            // Record the before/after so the caller can notify. Only the primary location's event carries
            // `isPrimary`; the app acts only on that one (see `NotificationManager.evaluatePrimary`).
            events.append(RefreshEvent(old: previous, new: snapshot, isPrimary: location.ine == primary?.ine))
            // Don't let a thin snapshot overwrite a good one already cached for this location. The hourly
            // carry-forward in `make` already covers a wholly-absent feed (`hourly` nil); this catches the
            // other thin path — a fetch that *succeeded* but returned an empty/degenerate feed with no
            // resolvable current hour, which carry-forward (gated on `hourly` nil) skips. Matches the guard
            // on the Watch push (`WatchSync.upsertGuarded`); a real location switch or first-ever fetch,
            // where the existing cache is nil or itself thin, still writes.
            if snapshot.hasCurrentHourData || !(previous?.hasCurrentHourData ?? false) {
                SharedCache.upsert(snapshot)
            }
            didUpdate = true
        }

        return RefreshOutcome(events: events, didUpdate: didUpdate, errorMessage: firstError)
    }

    /// Localized message for any error surfaced while talking to AEMET (the AEMET status `desc` is
    /// server-returned data and is interpolated as-is).
    public static func message(for error: Error) -> String {
        switch error {
        case AEMETClient.ClientError.missingAPIKey:
            return auraString("error.missingKey")
        case AEMETClient.ClientError.rateLimited:
            return auraString("error.rateLimited")
        case AEMETClient.ClientError.http(let code):
            return auraString("error.network", code)
        case AEMETClient.ClientError.aemetStatus(let code, let desc):
            return auraString("error.aemetStatus", code, desc)
        case AEMETClient.ClientError.decoding:
            return auraString("error.decoding")
        case let urlError as URLError where urlError.code == .notConnectedToInternet:
            return auraString("error.offline")
        default:
            return auraString("error.generic")
        }
    }
}
