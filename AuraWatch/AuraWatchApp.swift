import AuraKit
import SwiftUI

/// The Apple Watch app. It exists mainly to host the complication and to receive snapshots pushed
/// from the iPhone over WatchConnectivity; the single screen shows the most recently synced
/// location.
@main
struct AuraWatchApp: App {
    // The delegate owns background refresh: it seeds the first WKApplicationRefreshBackgroundTask at
    // launch and reschedules after each pass, so the complication stays current with no wrist raise.
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var delegate

    init() { WatchSync.shared.activate() }   // receive snapshots from the paired iPhone

    var body: some Scene {
        WindowGroup { WatchRootView() }
    }
}
