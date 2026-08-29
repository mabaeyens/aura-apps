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

    /// The App Group's shared user defaults, for small cross-process/cross-device state (e.g. which
    /// location the phone considers active, so the Watch can default to it). Nil if the group is missing.
    public static var groupDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    /// Defaults key under which the phone-active INE is stored (written on each Watch sync, read by the
    /// Watch to default its shown location before the user overrides it).
    public static let activeINEKey = "AuraKit.activeINE"

    /// The INE the app currently considers active (the location on screen). A widget the user hasn't
    /// pinned to a specific place falls back to this, so an unconfigured glance follows the app instead
    /// of an arbitrary favourite. Written by the app on each load/location switch; read by the widgets.
    public static var activeINE: String? {
        get { groupDefaults?.string(forKey: activeINEKey) }
        set { groupDefaults?.set(newValue, forKey: activeINEKey) }
    }

    /// The location the **Watch** user forced with the wrist picker (empty/nil = follow the phone's
    /// active one). Kept in the App Group so the Watch's complication resolves the *same* place the Watch
    /// app shows — a plain `@AppStorage` lives in the app's own defaults, which the complication process
    /// can't see, so a forced pick left the complication tracking a different, stale location.
    public static let watchSelectedINEKey = "watch.selectedINE"
    public static var watchSelectedINE: String? {
        get { groupDefaults?.string(forKey: watchSelectedINEKey) }
        set { groupDefaults?.set(newValue, forKey: watchSelectedINEKey) }
    }

    /// The measurement time (`fint`) of the freshest record from the last successful national
    /// observation fetch (`/observacion/convencional/todas`). That product updates once per hour, so
    /// the refresh path uses this to hold the last-known feed until the next hourly reading is due
    /// instead of re-downloading every cycle. Nil until the first successful fetch (then fetch anyway).
    public static let lastObservationFintKey = "AuraKit.lastObservationFint"
    public static var lastObservationFint: Date? {
        get { groupDefaults?.object(forKey: lastObservationFintKey) as? Date }
        set {
            if let newValue { groupDefaults?.set(newValue, forKey: lastObservationFintKey) }
            else { groupDefaults?.removeObject(forKey: lastObservationFintKey) }
        }
    }

    /// The RSS publish time (`Última actualización`, ~30 min past the hour) from the observation RSS notifier at
    /// the last successful keyed observation fetch. Drives fetch cadence: the keyed `/observacion/convencional/
    /// todas` download fires only when the current RSS marker has advanced past this. A DIFFERENT clock from
    /// `lastObservationFint` (the reading's measurement time, top of the hour) and never compared against it —
    /// this one is compared RSS-to-RSS. Nil until the first successful fetch that read a marker.
    public static let lastObservationPublishedKey = "AuraKit.lastObservationPublished"
    public static var lastObservationPublished: Date? {
        get { groupDefaults?.object(forKey: lastObservationPublishedKey) as? Date }
        set {
            if let newValue { groupDefaults?.set(newValue, forKey: lastObservationPublishedKey) }
            else { groupDefaults?.removeObject(forKey: lastObservationPublishedKey) }
        }
    }

    /// When the surface analysis chart was last successfully fetched. The chart is reissued every ~12h
    /// (00/12 UTC), so `SurfaceAnalysisService` re-fetches only when this marker is older than 12h (or the
    /// disk cache is empty), keeping the AEMET request budget flat across repeated app opens. App-process
    /// only — the widget never fetches this heavy image. Nil until the first successful fetch.
    public static let lastSurfaceAnalysisFetchKey = "AuraKit.lastSurfaceAnalysisFetch"
    public static var lastSurfaceAnalysisFetch: Date? {
        get { groupDefaults?.object(forKey: lastSurfaceAnalysisFetchKey) as? Date }
        set {
            if let newValue { groupDefaults?.set(newValue, forKey: lastSurfaceAnalysisFetchKey) }
            else { groupDefaults?.removeObject(forKey: lastSurfaceAnalysisFetchKey) }
        }
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("snapshots.json")
    }

    /// Serializes the cache's file access within this process so the read-modify-write in `upsert`/`prune`
    /// can't interleave with another task's read or write and lose an update. Recursive so the mutating
    /// paths can call `read`/`write` while already holding it. Cross-process safety comes from the atomic
    /// write (a rename, so a reader in another process sees the whole old file or the whole new one); the
    /// app is the only writer, so there are no cross-process read-modify-write races to guard.
    private static let lock = NSRecursiveLock()
    private static func sync<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }
        return body()
    }

    /// All cached snapshots, newest write wins per location. Empty if nothing has been cached yet.
    public static func read() -> [WeatherSnapshot] {
        sync {
            guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
            return (try? decoder.decode([WeatherSnapshot].self, from: data)) ?? []
        }
    }

    /// The cached snapshot for one municipality, if present.
    public static func snapshot(forINE ine: String) -> WeatherSnapshot? {
        read().first { $0.ine == ine }
    }

    /// The snapshot to show for a preferred location, with the app-wide fallback the Watch app and the
    /// widgets both use: the caller's pick if it still has data, else the phone's active location, else the
    /// first cached entry. Reads the cache once. A nil or empty `preferredINE` skips straight to the active
    /// location (an unpinned widget, or the Watch before the user forces a place).
    public static func resolve(preferredINE: String?) -> WeatherSnapshot? {
        let all = read()
        if let ine = preferredINE, !ine.isEmpty, let s = all.first(where: { $0.ine == ine }) { return s }
        if let active = activeINE, let s = all.first(where: { $0.ine == active }) { return s }
        return all.first
    }

    /// Replace all cached snapshots.
    public static func write(_ snapshots: [WeatherSnapshot]) {
        sync {
            guard let url = fileURL, let data = try? encoder.encode(snapshots) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Insert or update the snapshot for its location, leaving the others untouched. Read and write are
    /// held under the same lock so two concurrent upserts can't each read the old file and clobber the other.
    public static func upsert(_ snapshot: WeatherSnapshot) {
        sync {
            var all = read().filter { $0.ine != snapshot.ine }
            all.append(snapshot)
            write(all)
        }
    }

    /// Trim the cache so it can't grow without bound as favourites come and go. Drops any snapshot
    /// older than `maxAge`; when `keepINEs` is given, also drops any location no longer in that set
    /// (a favourite the user removed); then caps the store to the `maxCount` most-recently-updated
    /// entries as a final safety net. Cheap enough to call on every launch/refresh — it only rewrites
    /// the file when it actually removed something.
    public static func prune(keepINEs: Set<String>? = nil,
                             maxAge: TimeInterval = 30 * 24 * 60 * 60,
                             maxCount: Int = 24) {
        sync {
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
