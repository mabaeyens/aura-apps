#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The cross-device seam. `SharedCache` is device-local, so the iPhone can't write straight into the
/// Watch's cache: instead the phone pushes the current `WeatherSnapshot` over WatchConnectivity, and
/// the Watch writes it into its own App Group cache where the complication reads it.
///
/// The same object serves both sides — the iPhone calls `send(_:)`, the Watch just `activate()`s and
/// receives. Guarded by `canImport(WatchConnectivity)` so the shared package still builds on macOS.
public final class WatchSync: NSObject, WCSessionDelegate, @unchecked Sendable {
    public static let shared = WatchSync()

    /// Posted on the main thread after a freshly received snapshot is written to the Watch's cache,
    /// so an open SwiftUI view can re-read it live instead of only on the next `onAppear`.
    public static let snapshotDidUpdate = Notification.Name("AuraKit.WatchSync.snapshotDidUpdate")

    private let payloadKey = "snapshot"       // legacy: the single active snapshot
    private let snapshotsKey = "snapshots"    // all favourites' snapshots, so the Watch can switch instantly
    private let locationsKey = "locations"    // the favourites menu (names/coords) for the Watch's picker
    private let activeKey = "activeINE"        // which favourite the phone considers active

    private override init() { super.init() }

    /// Activate the session on either device. Safe to call more than once.
    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// iPhone → Watch: publish one snapshot as the latest application context (coalesced by the
    /// system, so only the newest survives — exactly right for a complication). Legacy single-location
    /// path; prefer `send(active:favorites:)` so the Watch can switch locations.
    public func send(_ snapshot: WeatherSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              let data = try? Self.encoder.encode(snapshot) else { return }
        var context: [String: Any] = [payloadKey: data]
        context[activeKey] = snapshot.ine
        try? session.updateApplicationContext(context)
    }

    /// iPhone → Watch: publish the **active** location plus the whole favourites menu and every
    /// favourite's cached snapshot, so the Watch shows the right place by default *and* can switch to any
    /// favourite that has data without waiting for the phone. Coalesced by the system like the single send.
    public func send(active: WeatherSnapshot, favorites: [Location]) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        // Collect a snapshot per favourite (the freshest `active` wins for its own INE), de-duplicated, and
        // guarantee the active one is present even if it isn't in the favourites list.
        var snaps: [WeatherSnapshot] = []
        var seen = Set<String>()
        for loc in favorites {
            let snap = loc.ine == active.ine ? active : SharedCache.snapshot(forINE: loc.ine)
            if let snap, seen.insert(snap.ine).inserted { snaps.append(snap) }
        }
        if seen.insert(active.ine).inserted { snaps.append(active) }

        var context: [String: Any] = [activeKey: active.ine]
        if let d = try? Self.encoder.encode(active) { context[payloadKey] = d }      // legacy fallback
        if let d = try? Self.encoder.encode(snaps) { context[snapshotsKey] = d }
        if let d = try? Self.encoder.encode(favorites) { context[locationsKey] = d }
        try? session.updateApplicationContext(context)
    }

    // MARK: WCSessionDelegate

    public func session(_ session: WCSession,
                        didReceiveApplicationContext applicationContext: [String: Any]) {
        cache(applicationContext)
    }

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                        error: Error?) {
        // On the Watch, seed from whatever context arrived before we activated.
        if activationState == .activated { cache(session.receivedApplicationContext) }
    }

    private func cache(_ context: [String: Any]) {
        // Remember which location the phone considers active, so the Watch can default to it.
        if let active = context[activeKey] as? String {
            SharedCache.groupDefaults?.set(active, forKey: SharedCache.activeINEKey)
        }

        // New protocol: a batch of every favourite's snapshot plus the favourites menu. Write them all so
        // the Watch can switch locations, and mirror the menu so its picker can list places the phone knows.
        if let data = context[snapshotsKey] as? Data,
           let snaps = try? Self.decoder.decode([WeatherSnapshot].self, from: data), !snaps.isEmpty {
            for snap in snaps { upsertGuarded(snap) }
            if let locData = context[locationsKey] as? Data,
               let locs = try? Self.decoder.decode([Location].self, from: locData) {
                SharedLocations.write(locs)
            }
            finishCache()
            return
        }

        // Legacy: a single active snapshot.
        guard let data = context[payloadKey] as? Data,
              let snapshot = try? Self.decoder.decode(WeatherSnapshot.self, from: data) else { return }
        upsertGuarded(snapshot)
        finishCache()
    }

    /// Upsert one snapshot, but don't let a "thin" one overwrite a good one already cached for the same
    /// location. When the phone's hourly fetch comes back empty the snapshot still carries the daily
    /// outlook, air quality and UV, but its current-hour fields (hero temp/humidity/precip, wind) are all
    /// nil — so the hero and wind rose would blank out while the rest looked fine. Keep the last good
    /// current-hour data instead; the next refresh (within the hour) restores a full snapshot. Guarded
    /// per-INE so a real location switch, or a first-ever sync, is never blocked.
    private func upsertGuarded(_ snapshot: WeatherSnapshot) {
        if !snapshot.hasCurrentHourData,
           let existing = SharedCache.snapshot(forINE: snapshot.ine),
           existing.hasCurrentHourData {
            return
        }
        SharedCache.upsert(snapshot)
    }

    private func finishCache() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        // Nudge any open view to re-read the cache. Delivered on main so SwiftUI state updates safely.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.snapshotDidUpdate, object: nil)
        }
    }

    #if os(iOS)
    // Required on iOS so the session can hand off between paired watches.
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
#endif
