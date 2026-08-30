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
    private let clockKey = "use24h"            // the phone's 24/12-hour choice, mirrored onto the Watch

    // Option A key handoff (iPhone Keychain → Watch Keychain). The Watch can't read the phone's
    // Keychain (separate devices), so the key rides a queued `transferUserInfo` and the Watch stores
    // its own device-only copy. Never placed in `updateApplicationContext`, which lingers as re-readable
    // state; `transferUserInfo` is a one-shot queued delivery instead.
    private let apiKeyKey = "aemetKey"          // iPhone → Watch: the AEMET key to store
    private let apiKeyRemovedKey = "aemetKeyGone"  // iPhone → Watch: the key was cleared, drop the copy
    private let apiKeyRequestKey = "wantAEMETKey"  // Watch → iPhone: I have no key, send me the current one

    /// Posted on the main thread after the Watch stores or clears its AEMET key, so an open view can
    /// re-evaluate the add-key state and kick a refresh.
    public static let apiKeyDidUpdate = Notification.Name("AuraKit.WatchSync.apiKeyDidUpdate")

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
        context[clockKey] = AuraTime.use24h
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
        context[clockKey] = AuraTime.use24h
        if let d = try? Self.encoder.encode(active) { context[payloadKey] = d }      // legacy fallback
        if let d = try? Self.encoder.encode(snaps) { context[snapshotsKey] = d }
        if let d = try? Self.encoder.encode(favorites) { context[locationsKey] = d }
        try? session.updateApplicationContext(context)
    }

    // MARK: - Option A key handoff

    /// iPhone → Watch: hand the AEMET key across so the Watch can fetch standalone. An empty key sends a
    /// "removed" marker so the Watch drops its copy and falls back to the add-key state instead of fetching
    /// with a stale or revoked key. Queued (`transferUserInfo`), so it survives the Watch being asleep or
    /// out of range and is delivered when it next reconnects. The key is never logged.
    public func sendAPIKey(_ key: String) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        let cleaned = key.filter { !$0.isWhitespace }
        let payload: [String: Any] = cleaned.isEmpty ? [apiKeyRemovedKey: true] : [apiKeyKey: cleaned]
        session.transferUserInfo(payload)
    }

    /// Watch → iPhone: ask for the current key when the Watch has none of its own (first launch after
    /// pairing, before any key change happened to push one). The phone replies via `sendAPIKey`. Covers the
    /// case the change-on-save trigger can't: a Watch set up after the key was already entered.
    public func requestAPIKeyIfMissing() {
        guard WCSession.isSupported() else { return }
        guard AuraKeychain.apiKey()?.isEmpty != false else { return }   // already have one, nothing to ask
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        session.transferUserInfo([apiKeyRequestKey: true])
    }

    // MARK: WCSessionDelegate

    public func session(_ session: WCSession,
                        didReceiveApplicationContext applicationContext: [String: Any]) {
        cache(applicationContext)
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        #if os(watchOS)
        // Watch side: store or clear the handed-over key in the Watch's own Keychain.
        if let key = userInfo[apiKeyKey] as? String {
            AuraKeychain.setAPIKey(key)
            postKeyUpdate()
        } else if userInfo[apiKeyRemovedKey] != nil {
            AuraKeychain.setAPIKey("")
            postKeyUpdate()
        }
        #endif
        #if os(iOS)
        // Phone side: a Watch with no key asked for it; reply with whatever is currently stored (an empty
        // reply becomes a "removed" marker, telling the Watch there is genuinely no key yet).
        if userInfo[apiKeyRequestKey] != nil {
            sendAPIKey(AuraKeychain.apiKey() ?? "")
        }
        #endif
    }

    private func postKeyUpdate() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.apiKeyDidUpdate, object: nil)
        }
    }

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                        error: Error?) {
        // On the Watch, seed from whatever context arrived before we activated.
        if activationState == .activated {
            cache(session.receivedApplicationContext)
            #if os(watchOS)
            // Now that the session is up, ask the phone for the key if the Watch has none of its own. This
            // is the reliable trigger (activation is async, so requesting straight after `activate()` races).
            requestAPIKeyIfMissing()
            #endif
        }
    }

    private func cache(_ context: [String: Any]) {
        // Remember which location the phone considers active, so the Watch can default to it.
        if let active = context[activeKey] as? String {
            SharedCache.groupDefaults?.set(active, forKey: SharedCache.activeINEKey)
        }

        // Mirror the phone's 24/12-hour clock choice so the Watch and its complication format times the
        // same way. App Group defaults are device-local, so this flag has to ride the sync like the rest.
        if let use24h = context[clockKey] as? Bool {
            SharedCache.groupDefaults?.set(use24h, forKey: AuraTime.use24hKey)
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
