import AuraKit
import Foundation
import WatchKit
import WidgetKit

/// watchOS background auto-refresh, so the complication and app stay current without the wrist ever
/// being raised and with no paired iPhone in the loop (the standalone cellular-watch case). Companion to
/// the foreground pull in `WatchRefreshModel`: the pull covers "I open the app and it updates", this
/// covers "the complication is fresh when I glance at it".
///
/// Mechanism: a `WKApplicationRefreshBackgroundTask` scheduled ~30 min out (matching the phone's
/// BGAppRefreshTask cadence), refetching through the shared `AuraRefreshCore` path. The task type is
/// generic app refresh, which needs no `WKBackgroundModes` key: that key is only for the special modes
/// (location, workout, remote-notification), none of which apply here.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchBackgroundRefresher.scheduleNext()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                // Arm the next pass before doing any work, so one failed refresh never breaks the chain.
                WatchBackgroundRefresher.scheduleNext()
                Task {
                    await WatchBackgroundRefresher.performRefresh()
                    refreshTask.setTaskCompletedWithSnapshot(false)
                }
            default:
                // Snapshot, connectivity, URLSession and any other task type: complete promptly so watchOS
                // does not treat us as hung.
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}

enum WatchBackgroundRefresher {
    /// Preferred spacing between background passes. watchOS throttles this itself (a floor, not a promise),
    /// and matches the phone's ~30 min top-up so the two devices drift together rather than fighting.
    static let interval: TimeInterval = 30 * 60

    /// Ask watchOS for the next background refresh. Called at launch and again after every handled task,
    /// so there is always exactly one pass armed ahead.
    static func scheduleNext() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: interval),
            userInfo: nil
        ) { error in
            if let error {
                NSLog("Aura watch: background refresh schedule failed: \(error.localizedDescription)")
            }
        }
    }

    /// Refetch the shown place directly from AEMET over the Watch's own network.
    ///
    /// No GPS here, unlike the foreground pull: a background task runs without the foreground When-In-Use
    /// grant, so re-resolving current location is unreliable. Instead it refreshes the last shown INE, which
    /// is what the complication renders. The 1h stale gate means a wake never burns an AEMET call on data
    /// that is still fresh, and no key on the Watch means nothing to fetch with, so it bails quietly.
    static func performRefresh() async {
        guard AuraKeychain.apiKey()?.isEmpty == false else { return }
        guard let ine = SharedCache.watchSelectedINE ?? SharedCache.activeINE else { return }
        guard AuraRefreshCore.isStale(SharedCache.snapshot(forINE: ine)) else { return }

        var locations = SharedLocations.read()
        if !locations.contains(where: { $0.ine == ine }), let cached = SharedCache.snapshot(forINE: ine) {
            locations.append(Location(ine: cached.ine, nombre: cached.localidad, provincia: cached.provincia,
                                      latitude: cached.latitude ?? 0, longitude: cached.longitude ?? 0))
        }
        guard locations.contains(where: { $0.ine == ine }) else { return }

        _ = await AuraRefreshCore.refresh(locations: locations, onlyINE: ine)
        await MainActor.run {
            WidgetCenter.shared.reloadAllTimelines()
            NotificationCenter.default.post(name: WatchSync.snapshotDidUpdate, object: nil)
        }
    }
}
