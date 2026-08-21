import AuraKit
import SwiftUI
import UIKit

/// The Watch app's screen: the most recently synced location, rendered from the **same**
/// `AuraForecastStack` and `AuraSky` the iPhone uses — identical cards in identical order over the same
/// sun-tracking sky, only resized to the wrist. Data arrives from the iPhone via `WatchSync` and lands
/// in the Watch's own `SharedCache`; before the first sync it invites the user to open Aura on the phone.
struct WatchRootView: View {
    /// Same persisted hero-art family as the phone (synced per-device via `@AppStorage`); picks which
    /// 48-asset grid the sky probes, falling back to the procedural `AuraSky` when the art isn't present.
    @AppStorage("heroFamily") private var heroFamily = HeroBackground.Family.landscape.rawValue

    @State private var snapshot: WeatherSnapshot? = SharedCache.read().first

    /// The sunless hero art for the current sky+time, or `nil` to fall back to the procedural sky.
    private var heroImage: Image? {
        HeroBackground.heroImage(for: snapshot,
                                 family: HeroBackground.Family(storage: heroFamily),
                                 exists: { UIImage(named: $0) != nil })
    }

    var body: some View {
        ZStack {
            // `.bottom` keeps the landscape in frame on the near-square wrist screen (a centred fill would
            // crop the mountains, tree and river off the bottom of the tall art).
            AuraSky(snapshot: snapshot, heroImage: heroImage, heroAnchor: .bottom).ignoresSafeArea()
            if let snapshot {
                // Hero fills the wrist screen — clean sky + landscape, system clock in its top-right
                // corner — and the cards sit below the fold, revealed on scroll (`heroFillHeight`). The
                // content reaches into the top safe area so the editorial text sits high, not marooned
                // below a tall blank band; the system time still floats in its corner.
                // `ignoresSafeArea` on the reader (not the ScrollView) so `geo` measures the full reclaimed
                // height — the hero then fills the whole wrist screen and the cards stay below the fold.
                GeometryReader { geo in
                    ScrollView {
                        AuraForecastStack(snapshot: snapshot, size: .watch, now: snapshot.updated,
                                          heroFillHeight: geo.size.height)
                            .padding(.horizontal, 4)
                            .padding(.top, 40)   // clear the system clock and the rounded top corners
                            .padding(.bottom, 6)
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
            } else {
                ContentUnavailableView("Abre Aura en el iPhone", systemImage: "iphone")
                    .environment(\.colorScheme, .dark)
            }
        }
        .fontDesign(.rounded)   // one typeface across phone and watch (see RootView)
        .onAppear { snapshot = SharedCache.read().first }
        .onReceive(NotificationCenter.default.publisher(for: WatchSync.snapshotDidUpdate)) { _ in
            snapshot = SharedCache.read().first
        }
    }
}
