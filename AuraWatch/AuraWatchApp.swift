import AuraKit
import SwiftUI

/// The Apple Watch app. It exists mainly to host the complication and to receive snapshots pushed
/// from the iPhone over WatchConnectivity; the single screen shows the most recently synced
/// location.
@main
struct AuraWatchApp: App {
    init() { WatchSync.shared.activate() }   // receive snapshots from the paired iPhone

    var body: some Scene {
        WindowGroup { WatchRootView() }
    }
}
