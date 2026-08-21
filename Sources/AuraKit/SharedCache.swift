import Foundation

/// The App Group cache the iPhone app writes and the widgets read. This is the seam in the
/// on-device-hub architecture: the app calls AEMET, normalizes to `WeatherSnapshot`s, and stores
/// them here; widgets (which can't reliably hit the network on their own schedule) render from
/// whatever this holds, falling back to the last known values when offline.
///
/// The App Group id must match the `com.apple.security.application-groups` entitlement on both the
/// app and the widget extension.
public enum SharedCache {
    /// Shared App Group identifier. Keep in sync with both targets' entitlements.
    public static let appGroupID = "group.com.mab.Aura"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("snapshots.json")
    }

    /// All cached snapshots, newest write wins per location. Empty if nothing has been cached yet.
    public static func read() -> [WeatherSnapshot] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([WeatherSnapshot].self, from: data)) ?? []
    }

    /// The cached snapshot for one municipality, if present.
    public static func snapshot(forINE ine: String) -> WeatherSnapshot? {
        read().first { $0.ine == ine }
    }

    /// Replace all cached snapshots.
    public static func write(_ snapshots: [WeatherSnapshot]) {
        guard let url = fileURL, let data = try? encoder.encode(snapshots) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Insert or update the snapshot for its location, leaving the others untouched.
    public static func upsert(_ snapshot: WeatherSnapshot) {
        var all = read().filter { $0.ine != snapshot.ine }
        all.append(snapshot)
        write(all)
    }

    /// Trim the cache so it can't grow without bound as favourites come and go. Drops any snapshot
    /// older than `maxAge`; when `keepINEs` is given, also drops any location no longer in that set
    /// (a favourite the user removed); then caps the store to the `maxCount` most-recently-updated
    /// entries as a final safety net. Cheap enough to call on every launch/refresh — it only rewrites
    /// the file when it actually removed something.
    public static func prune(keepINEs: Set<String>? = nil,
                             maxAge: TimeInterval = 30 * 24 * 60 * 60,
                             maxCount: Int = 24) {
        let now = Date()
        var all = read()
        let before = all.count

        all = all.filter { snapshot in
            if now.timeIntervalSince(snapshot.updated) >= maxAge { return false }
            if let keep = keepINEs, !keep.contains(snapshot.ine) { return false }
            return true
        }
        if all.count > maxCount {
            all = Array(all.sorted { $0.updated > $1.updated }.prefix(maxCount))
        }
        if all.count != before { write(all) }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
