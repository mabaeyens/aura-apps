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

    /// True when the wrist is showing its own GPS-resolved current location (a refresh re-runs the fix),
    /// rather than a phone favourite. Persisted in the App Group so it survives relaunch.
    @AppStorage("watch.currentLocationMode", store: SharedCache.groupDefaults) private var currentMode = false

    @State private var snapshot: WeatherSnapshot?
    @State private var showingPicker = false
    @State private var showingScenePicker = false
    @StateObject private var refresher = WatchRefreshModel()

    /// The instant the wrist renders "now" from — the live clock. The sky's sun/moon position and every
    /// time-derived label (the "· Atardecer" moment word, the hourly strip) all read from this one value,
    /// so they agree, exactly as the phone keeps them matched through its own `displayNow`. Before this the
    /// sky used the live clock while the hero card read the snapshot's build time, so a day-old snapshot
    /// could label a high midday sun "Atardecer".
    private var displayNow: Date { Date() }

    /// The sunless hero art for the current sky+time, or `nil` to fall back to the procedural sky.
    private func heroImage(now: Date) -> Image? {
        // Resolve to `now` so the per-condition hero art tracks the displayed hour's sky, matching the
        // resolved hero card in `AuraForecastStack` rather than the frozen fetch-hour sky. See
        // `WeatherSnapshot.resolved(at:)`.
        HeroBackground.heroImage(for: snapshot?.resolved(at: now), now: now,
                                 family: HeroBackground.Family(storage: heroFamily),
                                 exists: { UIImage(named: $0) != nil })
    }

    /// The place to show: the user's pick if it still has data, else the phone's active location, else the
    /// first cached snapshot. Resolved from the cache on every read so a new sync or a new pick re-points it.
    private func resolvedSnapshot() -> WeatherSnapshot? {
        SharedCache.resolve(preferredINE: selectedINE)
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
        // The outer reader gives the real top safe-area inset (the band the system clock and rounded
        // corners occupy). The hero fill adds it back, so the hero still covers the whole first screen even
        // though the text now sits at a small top inset — otherwise the next card ("Próximas horas") peeks
        // above the fold.
        GeometryReader { proxy in
            let now = displayNow
            ZStack {
                // `.bottom` keeps the landscape in frame on the near-square wrist screen (a centred fill would
                // crop the mountains, tree and river off the bottom of the tall art). `heroHorizon` pins a low
                // dawn/dusk sun above the art's skyline so it rides the sky, not the scenery in front of it.
                AuraSky(snapshot: snapshot?.resolved(at: now), now: now, heroImage: heroImage(now: now), heroAnchor: .bottom,
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
                                AuraForecastStack(snapshot: snapshot, size: .watch, now: now,
                                                  heroFillHeight: geo.size.height + proxy.safeAreaInsets.top + 4)
                                    // The Watch reuses the dense phone cards at their smallest size, so
                                    // its type is capped: it still tracks the reader's Text Size, but only
                                    // up to the point the cards stay legible on a 40-49mm screen.
                                    .dynamicTypeSize(...DynamicTypeSize.xLarge)
                                // The location switcher lives at the foot of the scroll, below the last card
                                // (UVI) — not pinned in the top safe area, where the taps were swallowed next
                                // to the system clock. A frosted pill, shown only with more than one place.
                                // Always shown now, not just with 2+ favourites: this switcher is also how the
                                // wrist enters current-location mode, which is available with any number of
                                // saved places. In current mode the label carries a location glyph.
                                Button { showingPicker = true } label: {
                                    Label(snapshot.localidad,
                                          systemImage: currentMode ? "location.fill" : "mappin.and.ellipse")
                                        .auraFont(14, relativeTo: .callout, weight: .semibold)
                                        .lineLimit(1)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                // The hero-art family switch (Paisaje / Ciudad), just below the location pill —
                                // the same choice the phone offers, here on the wrist so the watch background
                                // isn't stuck on the default. Writes the same `heroFamily` the sky reads above.
                                Button { showingScenePicker = true } label: {
                                    Label(HeroBackground.Family(storage: heroFamily).displayName,
                                          systemImage: "photo")
                                        .auraFont(14, relativeTo: .callout, weight: .semibold)
                                        .lineLimit(1)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 4)
                            // Sit the editorial text a set fraction of the top safe-area inset below the
                            // edge. The inset is the band the system reserves for the clock and rounded
                            // corners and it scales per case (40/41 vs 45/49 vs Ultra); the full inset drops
                            // the text too far under the clock, so 0.7 of it clears the digits with a tight
                            // gap and holds that same proportion on every watch — no hand-tuned constant.
                            .padding(.top, proxy.safeAreaInsets.top * 0.7)
                            .padding(.bottom, 6)
                        }
                        // Digital Crown pull to fetch fresh data standalone: in current-location mode this
                        // re-runs the GPS fix and fetches wherever the wrist now is, straight from AEMET over
                        // the Watch's own network, with the phone left at home.
                        .refreshable {
                            // `snapshot` is shadowed non-optional inside `if let`; reach the @State property
                            // via self to read the shown INE and to write the refreshed value back.
                            await refresher.refresh(currentMode: currentMode, shownINE: self.snapshot?.ine)
                            self.snapshot = resolvedSnapshot()
                        }
                    }
                    .ignoresSafeArea(.container, edges: .top)
                } else {
                    ContentUnavailableView(auraString("watch.openOnPhone"), systemImage: "iphone")
                        .environment(\.colorScheme, .dark)
                }
            }
        }
        .fontDesign(.rounded)   // one typeface across phone and watch (see RootView)
        .onAppear {
            snapshot = resolvedSnapshot()
            // Catch-up for a Watch set up after the key was already entered on the phone: ask for it if we
            // have none. The phone replies over WatchConnectivity and `apiKeyDidUpdate` then kicks a fetch.
            WatchSync.shared.requestAPIKeyIfMissing()
        }
        .onChange(of: selectedINE) {
            snapshot = resolvedSnapshot()
            // The pick lives in the App Group; nudge the complication so it re-resolves to the same place
            // instead of keeping the previously shown location.
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchSync.snapshotDidUpdate)) { _ in
            snapshot = resolvedSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: WatchSync.apiKeyDidUpdate)) { _ in
            // The phone just delivered (or cleared) the key. If we now have one, pull data straight away so
            // a freshly set-up Watch fills itself without another tap.
            guard AuraKeychain.apiKey()?.isEmpty == false else { return }
            Task {
                await refresher.refresh(currentMode: currentMode, shownINE: snapshot?.ine)
                snapshot = resolvedSnapshot()
            }
        }
        .sheet(isPresented: $showingPicker) {
            WatchLocationPicker(choices: locationChoices,
                                currentINE: snapshot?.ine,
                                following: selectedINE.isEmpty && !currentMode,
                                currentMode: currentMode) { pick in
                currentMode = false           // picking a favourite leaves current-location mode
                selectedINE = pick ?? ""      // nil → follow the phone again
                showingPicker = false
            } onPickCurrent: {
                showingPicker = false
                Task {
                    await refresher.switchToCurrentLocation()
                    snapshot = resolvedSnapshot()
                }
            }
        }
        .sheet(isPresented: $showingScenePicker) {
            WatchScenePicker(current: HeroBackground.Family(storage: heroFamily)) { pick in
                heroFamily = pick.rawValue    // the sky re-resolves its hero on the next read
                showingScenePicker = false
            }
        }
    }
}

/// The wrist background switcher: the hero-art families (Paisaje, Ciudad), with a checkmark on the one
/// in use. Mirrors the phone's setting so the watch can pick its own scenery without the phone.
private struct WatchScenePicker: View {
    let current: HeroBackground.Family
    let onPick: (HeroBackground.Family) -> Void

    /// A representative glyph per family for the row.
    private func icon(_ family: HeroBackground.Family) -> String {
        family == .cityscape ? "building.2.fill" : "mountain.2.fill"
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(HeroBackground.Family.allCases, id: \.self) { family in
                    Button { onPick(family) } label: {
                        HStack {
                            Label(family.displayName, systemImage: icon(family))
                            Spacer()
                            if family == current {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle(auraString("watch.background.title"))
        }
        .fontDesign(.rounded)
    }
}

/// The wrist location switcher: a list of the phone's saved places, plus a "follow the iPhone" option that
/// clears any forced pick. A checkmark marks the one currently shown.
private struct WatchLocationPicker: View {
    let choices: [Location]
    let currentINE: String?
    /// True when no manual pick is set (the wrist is tracking the phone's active location).
    let following: Bool
    /// True when the wrist is showing its own GPS-resolved current location.
    let currentMode: Bool
    /// Called with the chosen INE, or nil to follow the phone.
    let onPick: (String?) -> Void
    /// Called when the user picks "current location": resolve GPS and fetch standalone.
    let onPickCurrent: () -> Void

    var body: some View {
        NavigationStack {
            List {
                // Current location, at the top: the standalone GPS-resolved place, for when the wrist is away
                // from the phone (a hike, a drive). A checkmark marks it when it is the shown place.
                Button { onPickCurrent() } label: {
                    HStack {
                        Label(auraString("watch.currentLocation"), systemImage: "location.fill")
                        Spacer()
                        if currentMode { Image(systemName: "checkmark").foregroundStyle(.tint) }
                    }
                }
                Button { onPick(nil) } label: {
                    HStack {
                        Label(auraString("watch.followPhone"), systemImage: "iphone")
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
                            if !following, !currentMode, loc.ine == currentINE {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            .navigationTitle(auraString("watch.location.title"))
        }
        .fontDesign(.rounded)
    }
}
