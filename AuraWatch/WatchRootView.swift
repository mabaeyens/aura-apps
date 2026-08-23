import AuraKit
import SwiftUI
import UIKit
import WidgetKit

/// The Watch app's screen: a synced location, rendered from the **same** `AuraForecastStack` and
/// `AuraSky` the iPhone uses — identical cards in identical order over the same sun-tracking sky, only
/// resized to the wrist. Data arrives from the iPhone via `WatchSync` and lands in the Watch's own
/// `SharedCache`; before the first sync it invites the user to open Aura on the phone.
///
/// Which place shows: the user's own pick if they've set one (and it still has data), else the location
/// the phone considers active, else whatever is cached. A switcher (top-leading) lets the wrist force any
/// saved location, since the phone syncs the whole favourites menu, not just the active one.
struct WatchRootView: View {
    /// Same persisted hero-art family as the phone (synced per-device via `@AppStorage`); picks which
    /// 48-asset grid the sky probes, falling back to the procedural `AuraSky` when the art isn't present.
    @AppStorage("heroFamily") private var heroFamily = HeroBackground.Family.landscape.rawValue

    /// The user's forced location, or "" to follow the phone's active one. Persisted on the watch in the
    /// **App Group** (not the app's private defaults) so the complication resolves the same place — see
    /// `SharedCache.watchSelectedINE`.
    @AppStorage(SharedCache.watchSelectedINEKey, store: SharedCache.groupDefaults) private var selectedINE = ""

    @State private var snapshot: WeatherSnapshot?
    @State private var showingPicker = false

    /// The sunless hero art for the current sky+time, or `nil` to fall back to the procedural sky.
    private var heroImage: Image? {
        HeroBackground.heroImage(for: snapshot,
                                 family: HeroBackground.Family(storage: heroFamily),
                                 exists: { UIImage(named: $0) != nil })
    }

    /// The place to show: the user's pick if it still has data, else the phone's active location, else the
    /// first cached snapshot. Resolved from the cache on every read so a new sync or a new pick re-points it.
    private func resolvedSnapshot() -> WeatherSnapshot? {
        let all = SharedCache.read()
        if !selectedINE.isEmpty, let s = all.first(where: { $0.ine == selectedINE }) { return s }
        if let active = SharedCache.groupDefaults?.string(forKey: SharedCache.activeINEKey),
           let s = all.first(where: { $0.ine == active }) { return s }
        return all.first
    }

    /// The places the switcher offers: the favourites the phone mirrored, or (before that first sync) the
    /// locations we happen to have cached weather for.
    private var locationChoices: [Location] {
        let menu = SharedLocations.read()
        if !menu.isEmpty { return menu }
        return SharedCache.read().map {
            Location(ine: $0.ine, nombre: $0.localidad, provincia: $0.provincia,
                     latitude: $0.latitude ?? 0, longitude: $0.longitude ?? 0)
        }
    }

    var body: some View {
        ZStack {
            // `.bottom` keeps the landscape in frame on the near-square wrist screen (a centred fill would
            // crop the mountains, tree and river off the bottom of the tall art). `heroHorizon` pins a low
            // dawn/dusk sun above the art's skyline so it rides the sky, not the scenery in front of it.
            AuraSky(snapshot: snapshot, heroImage: heroImage, heroAnchor: .bottom,
                    heroHorizon: HeroBackground.heroHorizon(HeroBackground.Family(storage: heroFamily)),
                    heroAspect: HeroBackground.heroAspect).ignoresSafeArea()
            if let snapshot {
                // Hero fills the wrist screen — clean sky + landscape, system clock in its top-right
                // corner — and the cards sit below the fold, revealed on scroll (`heroFillHeight`). The
                // content reaches into the top safe area so the editorial text sits high, not marooned
                // below a tall blank band; the system time still floats in its corner.
                // `ignoresSafeArea` on the reader (not the ScrollView) so `geo` measures the full reclaimed
                // height — the hero then fills the whole wrist screen and the cards stay below the fold.
                GeometryReader { geo in
                    ScrollView {
                        VStack(spacing: 8) {
                            AuraForecastStack(snapshot: snapshot, size: .watch, now: snapshot.updated,
                                              heroFillHeight: geo.size.height)
                            // The location switcher lives at the foot of the scroll, below the last card
                            // (UVI) — not pinned in the top safe area, where the taps were swallowed next
                            // to the system clock. A frosted pill, shown only with more than one place.
                            if locationChoices.count > 1 {
                                Button { showingPicker = true } label: {
                                    Label(snapshot.localidad, systemImage: "mappin.and.ellipse")
                                        .font(.system(size: 14, weight: .semibold))
                                        .lineLimit(1)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
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
        .onAppear { snapshot = resolvedSnapshot() }
        .onChange(of: selectedINE) {
            snapshot = resolvedSnapshot()
            // The pick lives in the App Group; nudge the complication so it re-resolves to the same place
            // instead of keeping the previously shown location.
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchSync.snapshotDidUpdate)) { _ in
            snapshot = resolvedSnapshot()
        }
        .sheet(isPresented: $showingPicker) {
            WatchLocationPicker(choices: locationChoices,
                                currentINE: snapshot?.ine,
                                following: selectedINE.isEmpty) { pick in
                selectedINE = pick ?? ""      // nil → follow the phone again
                showingPicker = false
            }
        }
    }
}

/// The wrist location switcher: a list of the phone's saved places, plus a "follow the iPhone" option that
/// clears any forced pick. A checkmark marks the one currently shown.
private struct WatchLocationPicker: View {
    let choices: [Location]
    let currentINE: String?
    /// True when no manual pick is set (the wrist is tracking the phone's active location).
    let following: Bool
    /// Called with the chosen INE, or nil to follow the phone.
    let onPick: (String?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Button { onPick(nil) } label: {
                    HStack {
                        Label("Seguir el iPhone", systemImage: "iphone")
                        Spacer()
                        if following { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                ForEach(choices) { loc in
                    Button { onPick(loc.ine) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(loc.nombre).lineLimit(1)
                                if loc.provincia != loc.nombre {
                                    Text(loc.provincia)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer()
                            if !following, loc.ine == currentINE {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Ubicación")
        }
        .fontDesign(.rounded)
    }
}
