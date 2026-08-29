import AuraKit
import Foundation

/// Fetches AEMET's national text forecast (hoy / manana / pasadomanana / medioplazo), cached on disk per
/// range with a 6-hour TTL — the cadence AEMET reissues them (~4x/day). Only `today()` is pulled on the
/// refresh path; the sheet pulls the other three lazily on first open. The text stays out of the App-Group
/// snapshot, like radar and surface, and each range is a small fixed-name JSON file, so nothing accumulates.
///
/// The amendment-only `hoy` resolve lives here, not in the client: AEMET's national `hoy` is re-issued only
/// on significant intraday change, so on a quiet day it names a stale date. `today()` accepts `hoy` only
/// when it is valid for today and otherwise falls back to `manana` (which reliably covers today's window),
/// reusing the same cached `manana` the sheet's Mañana tab uses instead of pulling it twice.
enum NationalTextService {
    /// AEMET reissues these ~4x/day; don't re-fetch a range inside this window.
    private static let ttl: TimeInterval = 6 * 60 * 60

    private static let cachePrefix = "national-"

    private static func cacheURL(_ slot: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("\(cachePrefix)\(slot).json")
    }

    private static func slot(for day: NationalDay) -> String {
        switch day {
        case .hoy:          return "hoy"
        case .manana:       return "manana"
        case .pasadoManana: return "pasadomanana"
        }
    }

    // MARK: - Card (today, gated, with the stale-hoy → manana fallback)

    /// Today's national bulletin for the card. `hoy` when it parses valid for today; otherwise `manana`,
    /// since AEMET's `hoy` is amendment-only and may name a stale date. Nil only when neither is available
    /// (no key/network and nothing cached), so the card simply doesn't appear.
    static func today(force: Bool = false) async -> ForecastBulletin? {
        if let hoy = await bulletin(.hoy, force: force), isValidForToday(hoy) {
            return hoy
        }
        return await bulletin(.manana, force: force)
    }

    // MARK: - Sheet ranges (lazy, each independently cached)

    /// A day horizon (hoy / manana / pasadomanana), served from disk inside the 6-h window, else fetched.
    /// Offline or on failure, falls back to the last cached copy of that range whatever its age.
    static func bulletin(_ day: NationalDay, force: Bool = false) async -> ForecastBulletin? {
        let url = cacheURL(slot(for: day))
        if !force, let data = freshCached(at: url), let cached = decode(ForecastBulletin.self, data) {
            return cached
        }
        guard let client = AEMETService.client() else {
            return anyCached(at: url).flatMap { decode(ForecastBulletin.self, $0) }
        }
        do {
            let bulletin = try await client.nacionalBulletin(day)
            try? encode(bulletin)?.write(to: url)
            return bulletin
        } catch {
            return anyCached(at: url).flatMap { decode(ForecastBulletin.self, $0) }
        }
    }

    /// The medium-range forecast (per-day blocks), gated and cached like the day ranges.
    static func medioplazo(force: Bool = false) async -> MedioplazoForecast? {
        let url = cacheURL("medioplazo")
        if !force, let data = freshCached(at: url), let cached = decode(MedioplazoForecast.self, data) {
            return cached
        }
        guard let client = AEMETService.client() else {
            return anyCached(at: url).flatMap { decode(MedioplazoForecast.self, $0) }
        }
        do {
            let forecast = try await client.nacionalMedioplazo()
            try? encode(forecast)?.write(to: url)
            return forecast
        } catch {
            return anyCached(at: url).flatMap { decode(MedioplazoForecast.self, $0) }
        }
    }

    // MARK: - Helpers

    private static let madrid = TimeZone(identifier: "Europe/Madrid") ?? .current

    /// True when the bulletin's validity day is today in Spanish peninsular civil time (the clock AEMET
    /// stamps its bulletins in). A `hoy` product that fails this is a stale amendment, so the card uses
    /// `manana` instead.
    private static func isValidForToday(_ bulletin: ForecastBulletin) -> Bool {
        guard let validez = bulletin.validezInicio else { return false }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = madrid
        return cal.isDate(validez, inSameDayAs: Date())
    }

    /// The cached bytes at `url` when the file is younger than the TTL, else nil (a re-fetch is due).
    private static func freshCached(at url: URL) -> Data? {
        guard let modified = modificationDate(of: url),
              Date().timeIntervalSince(modified) < ttl else { return nil }
        return try? Data(contentsOf: url)
    }

    /// The cached bytes at `url` whatever their age — the offline / fetch-failed fallback.
    private static func anyCached(at url: URL) -> Data? {
        try? Data(contentsOf: url)
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}
