import AuraKit
import SwiftUI

@main
struct AuraApp: App {
    @StateObject private var store = LocationStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Open the WatchConnectivity session so we can push snapshots to the paired Watch.
        WatchSync.shared.activate()
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
                    // Refresh widget data whenever the app comes to the foreground.
                    if phase == .active {
                        Task { await AEMETService.refreshAllForWidgets(store.favorites) }
                    }
                }
        }
    }
}
