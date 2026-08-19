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

    private let payloadKey = "snapshot"

    private override init() { super.init() }

    /// Activate the session on either device. Safe to call more than once.
    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// iPhone → Watch: publish one snapshot as the latest application context (coalesced by the
    /// system, so only the newest survives — exactly right for a complication).
    public func send(_ snapshot: WeatherSnapshot) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              let data = try? Self.encoder.encode(snapshot) else { return }
        try? session.updateApplicationContext([payloadKey: data])
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
        guard let data = context[payloadKey] as? Data,
              let snapshot = try? Self.decoder.decode(WeatherSnapshot.self, from: data) else { return }
        SharedCache.upsert(snapshot)
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
