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
