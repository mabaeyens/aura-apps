import AuraKit
import SwiftUI
import UIKit
import WidgetKit

/// Reports whether the attached scroll view sits at its very top, driving the "MÁS" hint's fade. Uses
/// `onScrollGeometryChange` (iOS 18+, which the target devices run); on older systems it's a no-op and the
/// hint simply stays put — an acceptable fallback since the reliable scroll-offset API isn't there.
private struct FadeHintAtTop: ViewModifier {
    @Binding var atTop: Bool
    /// The one place the app animates. Honour Reduce Motion: when it's on, toggle the hint instantly
    /// instead of cross-fading, so the app carries no motion the setting doesn't already suppress.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y <= 2
            } action: { _, isTop in
                if reduceMotion { atTop = isTop }
                else { withAnimation(.easeOut(duration: 0.25)) { atTop = isTop } }
            }
        } else {
            content
        }
    }
}

/// "Hoy" — the forecast for the selected location, rendered as Aura's signature screen: the shared
/// `AuraForecastStack` (hero, hours, days, sun·wind, aviso, predicción) floating as frosted cards over
/// a full-bleed `AuraSky` whose light sits where the sun actually is for the hour. The same cards the
/// Apple Watch shows, resized.
///
/// It renders straight from the shared App Group cache: it asks the one coalesced
/// `AEMETService.refreshAllForWidgets` to fill the cache, then reads the snapshot — it never calls
/// AEMET directly, so it can't duplicate the launch refresh's requests.
struct TodayView: View {
    @EnvironmentObject private var store: LocationStore
    /// Compact on iPhone; regular on iPad and Mac (Designed for iPad). The sky stays full-bleed either
    /// way — only the card column is inset on the wider canvas so the cards don't stretch edge to edge.
    @Environment(\.horizontalSizeClass) private var hSizeClass
    /// Drives an on-screen refresh when the app returns from the background. `.task(id:)` fires only on
    /// appear and when the location changes — not on foreground — so an overnight-suspended app would keep
    /// showing last night's snapshot (and its stale sky) even as the widgets updated. Reloading here
    /// re-reads the cache and advances `loadedAt`, so the sky and every time-derived label catch up.
    @Environment(\.scenePhase) private var scenePhase

    /// The persisted hero-art family (landscape / cityscape). Drives which 48-asset grid the sky probes;
    /// changing it in Settings re-resolves the background on the next render.
    @AppStorage("heroFamily") private var heroFamily = HeroBackground.Family.landscape.rawValue

    @State private var snapshot: WeatherSnapshot?
    @State private var radar: AuraRadarInfo?
    @State private var news: [NewsItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Which location `snapshot` belongs to, and when it was read — so a tab re-appearance or app
    /// foreground doesn't trigger a refresh when the on-screen data is already recent.
    @State private var loadedINE: String?
    @State private var loadedAt: Date?
    /// True while the Hoy scroll sits at the very top; drives the "MÁS" hint (shown only at the top,
    /// faded out the moment the user scrolls). Updated via `onScrollGeometryChange` on iOS 18+.
    @State private var atTop = true

    /// The card column's max width on iPad/Mac (regular width). The cards are capped to this and centred
    /// so they don't stretch across a wide window; the sky behind them is the full-bleed procedural
    /// `AuraSky` (see `skyBackground`).
    private static let columnMaxWidth: CGFloat = 620

    /// AEMET updates municipal forecasts only a few times a day; don't refresh the same location
    /// more often than this except on an explicit pull-to-refresh.
    private static let minInterval: TimeInterval = 15 * 60

    /// The sunless hero art for the current sky+time, or `nil` to fall back to the procedural `AuraSky`.
    /// Probes only the shipped assets in the app bundle; `AuraSky` still draws the live sun/moon on top.
    /// Uses `displayNow`/`displaySnapshot` so a DEBUG screenshot run's fake time and sky pick the matching
    /// art, not the wall-clock's.
    private var heroImage: Image? {
        HeroBackground.heroImage(for: displaySnapshot, now: displayNow,
                                 family: HeroBackground.Family(storage: heroFamily),
                                 exists: { UIImage(named: $0) != nil })
    }

    /// Whether any `city_*` art is actually in the bundle. Until it is, there's nothing to switch to, so
    /// the family selector stays hidden (same gate as Settings).
    private var hasCityscapeArt: Bool {
        HeroBackground.assetNames(for: .cityscape).contains { UIImage(named: $0) != nil }
    }

    /// The wide per-condition hero for the current family, used on the regular-width (iPad / Mac) canvas
    /// where the portrait phone rasters can't reflow. It's the 4:3 twin of the portrait 8×6 grid, so the
    /// condition and time of day are baked into the art and `AuraSky` draws only the live sun/moon on top.
    /// Nil for an unknown sky (or before the art ships) → the procedural sky fills in.
    private var wideHeroImage: Image? {
        HeroBackground.wideImage(for: displaySnapshot, now: displayNow,
                                 family: HeroBackground.Family(storage: heroFamily),
                                 exists: { UIImage(named: $0) != nil })
    }

    /// The instant Aura renders "now" from. Normally the load time, so the sky and every time-derived
    /// label match the data on screen. In DEBUG a screenshot run can pin it to any moment via
    /// `AURA_FAKE_DATE`, so the sun/moon position renders exactly as it would on-device at that instant.
    private var displayNow: Date {
        #if DEBUG
        if let overridden = ScreenshotOverride.now { return overridden }
        #endif
        return loadedAt ?? Date()
    }

    /// The snapshot to render. In DEBUG a screenshot run can swap the current sky condition via
    /// `AURA_FAKE_SKY` (an AEMET code), rename the displayed city via `AURA_FAKE_CITY`, and inject a
    /// synthetic aviso card via `AURA_FAKE_ALERT` — so a single clear day can produce every veil, city and
    /// warning for the store shots. Overrides compose; any subset can be set.
    private var displaySnapshot: WeatherSnapshot? {
        #if DEBUG
        if var base = snapshot {
            if let sky = ScreenshotOverride.skyCode { base = base.overridingSky(sky) }
            if let city = ScreenshotOverride.city { base = base.overridingCity(city.name, provincia: city.provincia) }
            if let alert = ScreenshotOverride.alert { base = base.overridingAlert(level: alert.level, phenomenon: alert.phenomenon) }
            return base
        }
        #endif
        return snapshot
    }

    /// The active aviso to surface at the top of the screen, if any. Reads from `displaySnapshot` so a
    /// DEBUG screenshot run's overridden snapshot is honoured. When non-nil it lights the hero aviso badge
    /// and tints the "MÁS" scroll hint, so an active warning is visible before the user reaches its card.
    private var activeAlert: WeatherAlert? { displaySnapshot?.activeAlert(at: Date()) }

    var body: some View {
        NavigationStack {
            ZStack {
                skyBackground
                Group {
                    if let location = store.selected {
                        content(for: location)
                    } else {
                        ContentUnavailableView(
                            "Sin ubicaciones",
                            systemImage: "mappin.slash",
                            description: Text("Abre el menú (arriba a la derecha) y añade una ubicación.")
                        )
                    }
                }
                .environment(\.colorScheme, .dark)   // light text + dark frosted cards over the sky
            }
            // No bottom tab bar (it chromed the sky): the other sections open from a discreet frosted
            // menu on the hero, so the clean sky, landscape and editorial text own the screen.
            .overlay(alignment: .topTrailing) { heroMenu }
            // The "MÁS" hint is a fixed overlay pinned to the bottom of the screen (not part of the scroll
            // content): it shows only while the scroll sits at the very top and fades fully the instant the
            // user scrolls (see `atTop` / `FadeHintAtTop`), so it never drifts up with the cards.
            .overlay(alignment: .bottom) { scrollHint }
            .toolbar(.hidden, for: .navigationBar)    // immersive: the hero card carries the location name
        }
        .sheet(item: $route) { route in
            switch route {
            case .forecast:  ForecastTextView()
            case .locations: LocationsView()
            case .settings:  SettingsView()
            case .help:      HelpView()
            case .tip:       TipJarView()
            }
        }
        .task(id: store.selectedINE) { await load(force: false) }
        // Returning from the background re-reads the cache (the throttle in `load` still skips a fetch
        // when the on-screen data is recent), so the app catches up with the widgets instead of freezing
        // on the state it was suspended in.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await load(force: false) } }
        }
    }

    /// The full-bleed sky behind everything.
    /// - iPhone (compact): the sunless 8×6 hero art (condition-baked) bleeds edge to edge behind the sun.
    /// - iPad / Mac (regular): the portrait phone rasters can't reflow to a wide/landscape canvas without
    ///   being cropped to ribbons, so use the wide per-condition hero (the 4:3 twin of the 8×6 grid) with
    ///   the condition and time baked in and only the live sun/moon drawn on top. For an unknown sky (or
    ///   before the art ships) `wideHeroImage` is nil and the fully procedural `AuraSky` fills the canvas.
    @ViewBuilder private var skyBackground: some View {
        if hSizeClass == .regular {
            AuraSky(snapshot: displaySnapshot, now: displayNow,
                    heroImage: wideHeroImage, heroCarriesCondition: true,
                    heroHorizon: HeroBackground.wideBaseHorizon(HeroBackground.Family(storage: heroFamily)),
                    heroAspect: HeroBackground.wideBaseAspect)
                .ignoresSafeArea()
        } else {
            // `.bottom` anchor + `heroHorizon` pin a low dawn/dusk sun just above the portrait art's
            // skyline (mountain peak / tallest rooftop) so it sits in the calm sky, not on the scenery —
            // the same fix the Watch and the wide iPad canvas already get.
            AuraSky(snapshot: displaySnapshot, now: displayNow, heroImage: heroImage,
                    heroAnchor: .bottom,
                    heroHorizon: HeroBackground.heroHorizon(HeroBackground.Family(storage: heroFamily)),
                    heroAspect: HeroBackground.heroAspect)
                .ignoresSafeArea()
        }
    }

    /// The sections that used to be tabs, now reachable from the hero menu. Presented as sheets (each
    /// brings its own navigation and title; swipe down to dismiss).
    private enum MenuRoute: Int, Identifiable { case forecast, locations, settings, help, tip; var id: Int { rawValue } }
    @State private var route: MenuRoute?

    /// A discreet frosted control in the hero's top-trailing corner — opposite the editorial text — that
    /// opens Predicción, Ubicaciones and Ajustes without a persistent bottom bar.
    private var heroMenu: some View {
        Menu {
            // Switch the hero-art family right from the menu (mirrors the Settings control), so the theme is
            // one tap from the hero itself. Only offered once cityscape art ships (`hasCityscapeArt`).
            if hasCityscapeArt {
                Picker("Fondo del cielo", selection: $heroFamily) {
                    ForEach(HeroBackground.Family.allCases, id: \.rawValue) { family in
                        Text(family.displayName).tag(family.rawValue)
                    }
                }
                Divider()
            }
            Button { route = .forecast }  label: { Label("Predicción", systemImage: "text.alignleft") }
            Button { route = .locations } label: { Label("Ubicaciones", systemImage: "mappin.and.ellipse") }
            Button { route = .settings }  label: { Label("Ajustes", systemImage: "gearshape") }
            Button { route = .help }      label: { Label("Ayuda", systemImage: "questionmark.circle") }
            Divider()
            Button { route = .tip }       label: { Label("Propina", systemImage: "cup.and.saucer") }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.28), radius: 6, y: 1)
        }
        .padding(.trailing, 16)
        .padding(.top, 4)
        .environment(\.colorScheme, .dark)
    }

    /// A gentle "MÁS ⌄" affordance pinned to the bottom of the screen, inviting a scroll to the cards.
    /// Shown only while the scroll is at the very top (`atTop`) and faded fully once the user scrolls, so
    /// it never rides up with the content. Only present when there's a forecast to reveal. When the
    /// location has an active aviso, a level-tinted warning triangle sits beside the hint (not above the
    /// summary), so the same glance that says "scroll for more" also says "there's a warning down here".
    @ViewBuilder private var scrollHint: some View {
        if snapshot != nil {
            VStack(spacing: 2) {
                // The aviso sign sits to the left of "MÁS" on the same line (icon only here; the word is
                // up in the hero). The chevron is centred under both. No aviso: just "MÁS" and the chevron.
                HStack(spacing: 8) {
                    if let alert = activeAlert {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Palette.alert(alert.level))
                    }
                    Text("MÁS")
                        .font(.system(size: 11, weight: .bold)).tracking(2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .shadow(color: .black.opacity(0.35), radius: 5, y: 1)
            .padding(.bottom, 8)
            .opacity(atTop ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(activeAlert.map { "Desliza para ver más, incluido un aviso de \($0.phenomenon ?? $0.event)" } ?? "Desliza para ver más")
            .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder
    private func content(for location: Location) -> some View {
        // The hero fills the first screen (see `heroFillHeight`), so `geo` gives it the scroll viewport
        // height and the cards start just below the fold — the clean sky + landscape read on their own.
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 14) {
                    if !store.apiKeyPresent { keyBanner }

                    if let snap = displaySnapshot {
                        AuraForecastStack(snapshot: snap, size: .phone, now: displayNow,
                                          radar: radar, news: news, heroFillHeight: geo.size.height)
                    } else if isLoading {
                        notice { HStack(spacing: 8) { ProgressView().tint(.white); Text("Cargando…") } }
                    } else if let errorMessage {
                        notice { Label(errorMessage, systemImage: "exclamationmark.triangle") }
                    }
                }
                .padding(.horizontal, 16)
                // On iPad and Mac the window is far wider than a phone; cap the card column to a comfortable
                // reading width and centre it, so the cards sit inset over a full-bleed sky instead of
                // stretching the full window width. iPhone (compact) keeps the full width.
                .frame(maxWidth: hSizeClass == .regular ? Self.columnMaxWidth : .infinity)
                .frame(maxWidth: .infinity)   // centre the capped column in the scroll view's full width
                .padding(.top, 40)      // start the editorial text a touch lower, off the status bar
                .padding(.bottom, 64)   // let the sky's horizon breathe below the last card
            }
            .scrollContentBackground(.hidden)
            .modifier(FadeHintAtTop(atTop: $atTop))   // fade the "MÁS" hint out the moment we leave the top
            .refreshable { await load(force: true) }
        }
    }

    /// A translucent banner used for the API-key prompt, loading and error states, so they sit on the
    /// sky like the cards do.
    private func notice<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var keyBanner: some View {
        notice { Label("Añade tu clave de AEMET en Ajustes para ver los datos.", systemImage: "key") }
    }

    private func load(force: Bool) async {
        guard let location = store.selected else { return }
        // Throttle: if we already show this location's data and it's recent, don't trigger a refresh
        // just because the view re-appeared. Pull-to-refresh (force) always refreshes.
        if !force, snapshot?.ine == location.ine, loadedINE == location.ine,
           let at = loadedAt, Date().timeIntervalSince(at) < Self.minInterval {
            return
        }
        guard store.apiKeyPresent else {
            errorMessage = nil // handled by the key banner
            return
        }
        isLoading = true
        errorMessage = nil
        // The one coalesced refresh fills the shared cache (fetching every favourite once, plus a
        // single national observations call); read this location's snapshot back out of it.
        var refreshError = await AEMETService.refreshAllForWidgets(store.favorites, force: force)
        // A location just added (or switched to) can miss an already-running refresh that was in flight
        // before it existed: the gate coalesces this call onto that run, which never fetched it. If its
        // snapshot still isn't cached, run one more pass now that the earlier run has finished and the
        // gate is clear, so it fetches the new location without waiting for a manual pull-to-refresh.
        if SharedCache.snapshot(forINE: location.ine) == nil {
            refreshError = await AEMETService.refreshAllForWidgets(store.favorites, force: force)
        }
        if let snap = SharedCache.snapshot(forINE: location.ine) {
            snapshot = snap
            loadedINE = location.ine
            loadedAt = Date()
            // Mirror the on-screen location to the paired Watch (as its active), plus the whole favourites
            // menu and their snapshots, so the Watch can switch to any saved place on its own.
            WatchSync.shared.send(active: snap, favorites: store.favorites)
            // Record the active location and nudge the widgets so an unpinned glance follows the app to
            // this place (even when its data was already cached and the refresh reported no change).
            SharedCache.activeINE = location.ine
            WidgetCenter.shared.reloadAllTimelines()
            errorMessage = nil
            await loadRadar(for: location, force: force)
            news = await NewsService.latest(force: force)
        } else {
            // Nothing cached yet and the refresh couldn't fill it — surface why, if we know.
            errorMessage = refreshError ?? "No se pudieron obtener los datos."
        }
        isLoading = false
    }

    /// Fetch (or reuse the ≤10-min cache of) the nearest regional radar frame and decode it for the
    /// card. A miss just leaves `radar` nil, so the card is dropped rather than showing an empty box.
    private func loadRadar(for location: Location, force: Bool) async {
        guard let frame = await RadarService.frame(for: location, force: force),
              let image = UIImage(data: frame.data) else { radar = nil; return }
        radar = AuraRadarInfo(image: Image(uiImage: image), siteName: frame.siteName, time: frame.time)
    }
}
