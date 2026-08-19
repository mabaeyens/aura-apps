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
                // Cache every saved location at launch so widgets have data whichever one is picked.
                .task { await AEMETService.refreshAllForWidgets(store.favorites) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await AEMETService.refreshAllForWidgets(store.favorites) }
                    }
                }
        }
    }
}
