import SwiftUI

@main
struct AuraApp: App {
    @StateObject private var store = LocationStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
