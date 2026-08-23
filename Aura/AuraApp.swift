import AuraKit
import SwiftUI

@main
struct AuraApp: App {
    @StateObject private var store = LocationStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Open the WatchConnectivity session so we can push snapshots to the paired Watch.
        WatchSync.shared.activate()
        // Wire the notification delegate and re-request authorization for a returning opted-in user.
        NotificationManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                // Cache every saved location at launch so widgets have data whichever one is picked,
                // and sweep any stale radar frames left in the Caches directory.
                .task {
                    RadarService.pruneCache()
                    await AEMETService.refreshAllForWidgets(store.favorites)
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        // Refresh widget data whenever the app comes to the foreground.
                        Task { await AEMETService.refreshAllForWidgets(store.favorites) }
                    case .background:
                        // Arm the next background top-up whenever we leave the foreground.
                        AEMETService.scheduleBackgroundRefresh()
                    default:
                        break
                    }
                }
        }
        // Opt-in background top-up (~30 min, subject to the system Background App Refresh setting). It
        // reschedules itself, refreshes the App Group cache (which reloads widgets and evaluates
        // notifications), and shows new data only when there is any.
        .backgroundTask(.appRefresh(AEMETService.backgroundRefreshIdentifier)) {
            AEMETService.scheduleBackgroundRefresh()
            _ = await AEMETService.refreshFromSharedLocations()
        }
    }
}
