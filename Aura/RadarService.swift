import AuraKit
import Foundation

/// Fetches the nearest regional radar frame for a location, cached on disk with a 10-minute TTL (the
/// cadence AEMET republishes regional radar). Separate from the coalesced forecast refresh — it's lazy,
/// only the "Hoy" screen needs it, and its image bytes stay out of the App-Group snapshot. iOS only.
enum RadarService {
    /// A fetched radar frame: the raw image bytes, the site name for the card, and when it was fetched.
    struct Frame {
        let data: Data
        let siteName: String
        let time: Date
    }

    /// Regional radar republishes every ~10 minutes; don't re-fetch within that window.
    private static let ttl: TimeInterval = 10 * 60

    private static func cacheURL(code: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("radar-\(code).img")
    }

    /// The nearest regional radar frame for `location`, served from a ≤10-min disk cache or fetched
    /// fresh. Returns nil when there's no API key or the fetch fails with no cached frame to fall back
    /// on — the radar card then simply doesn't appear.
    static func frame(for location: Location, force: Bool = false) async -> Frame? {
        let site = RadarSite.nearest(toLatitude: location.latitude, longitude: location.longitude)
        let url = cacheURL(code: site.code)

        if !force, let cached = cachedFrame(at: url, site: site, maxAge: ttl) {
            return cached
        }
        guard let client = AEMETService.client() else {
            return cachedFrame(at: url, site: site, maxAge: .infinity)   // offline: any stale frame beats none
        }
        do {
            let data = try await client.radarRegional(site.code)
            try? data.write(to: url)
            return Frame(data: data, siteName: site.name, time: Date())
        } catch {
            return cachedFrame(at: url, site: site, maxAge: .infinity)
        }
    }

    /// The cached frame at `url` if it exists and is younger than `maxAge`.
    private static func cachedFrame(at url: URL, site: RadarSite, maxAge: TimeInterval) -> Frame? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let modified = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < maxAge,
              let data = try? Data(contentsOf: url) else { return nil }
        return Frame(data: data, siteName: site.name, time: modified)
    }
}
