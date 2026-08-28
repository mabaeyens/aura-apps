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
    /// A client built from the Keychain key, or nil if no key has been entered yet. The construction
    /// lives in `AuraRefreshCore` so the app and the widget build the client the same way.
    static func client() -> AEMETClient? { AuraRefreshCore.makeClient() }

    private static let refreshGate = RefreshGate()

    /// Refresh and cache a snapshot for every saved location, then reload widgets and push the primary
    /// to the Watch. Coalesced (see the type note) and, unless `force`, skips locations cached within
    /// the last hour to stay well under AEMET's rate limit. Returns a Spanish error message if the
    /// refresh hit a problem worth showing (e.g. rate-limited, offline), else nil.
    /// `onlyINE`, when set, scopes the *fetch* to that one location (its forecast, hourly, avisos and, if
    /// it's the primary, its bulletin) while still pruning and watch-syncing the whole favourites list.
    /// Used by the app's pull-to-refresh so a manual swipe refreshes only the place on screen, not every
    /// favourite — the shared national feeds (observations, UV, air quality) are fetched once regardless.
    @discardableResult
    static func refreshAllForWidgets(_ locations: [Location], force: Bool = false,
                                     onlyINE: String? = nil) async -> String? {
        await refreshGate.run { await performRefresh(locations, force: force, onlyINE: onlyINE) }
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

    private static func performRefresh(_ locations: [Location], force: Bool,
                                       onlyINE: String? = nil) async -> String? {
        // The fetch → normalize → cache work lives in AuraRefreshCore so the widget can reuse this exact
        // path. The core does the pruning and the stale-gating and returns what changed; the app owns the
        // side effects the core can't (notifications, widget reload, Watch push).
        let outcome = await AuraRefreshCore.refresh(locations: locations, force: force, onlyINE: onlyINE)

        // Only the active location notifies. The core captured old-vs-new before each upsert, so a
        // genuinely new aviso or an updated forecast fires exactly once.
        for event in outcome.events where event.isPrimary {
            NotificationManager.evaluatePrimary(old: event.old, new: event.new)
        }

        if outcome.didUpdate {
            WidgetCenter.shared.reloadAllTimelines()
            // Keep the Watch fed even if the user never opens "Hoy": push the primary location as active,
            // plus the whole favourites menu and their snapshots so the Watch can switch places on its own.
            if let primary = locations.first, let snapshot = SharedCache.snapshot(forINE: primary.ine) {
                WatchSync.shared.send(active: snapshot, favorites: locations)
            }
        }
        return outcome.errorMessage
    }

    /// Spanish message for any error surfaced while talking to AEMET. Forwards to `AuraRefreshCore` so
    /// the app and the widget map errors identically.
    static func message(for error: Error) -> String { AuraRefreshCore.message(for: error) }
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
