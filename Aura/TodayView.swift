import AuraKit
import SwiftUI
import UIKit

/// Reports whether the attached scroll view sits at its very top, driving the "MÁS" hint's fade. Uses
/// `onScrollGeometryChange` (iOS 18+, which the target devices run); on older systems it's a no-op and the
/// hint simply stays put — an acceptable fallback since the reliable scroll-offset API isn't there.
private struct FadeHintAtTop: ViewModifier {
    @Binding var atTop: Bool
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { geo in
                geo.contentOffset.y <= 2
            } action: { _, isTop in
                withAnimation(.easeOut(duration: 0.25)) { atTop = isTop }
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

    /// The card column's max width on iPad/Mac (regular width). The cards and the crisp hero sky are both
    /// capped to this and centred, so the portrait art sits at true proportions right behind the column
    /// instead of being cropped across a full-width window.
    private static let columnMaxWidth: CGFloat = 620

    /// AEMET updates municipal forecasts only a few times a day; don't refresh the same location
    /// more often than this except on an explicit pull-to-refresh.
    private static let minInterval: TimeInterval = 15 * 60

    /// The sunless hero art for the current sky+time, or `nil` to fall back to the procedural `AuraSky`.
    /// Probes only the shipped assets in the app bundle; `AuraSky` still draws the live sun/moon on top.
    private var heroImage: Image? {
        HeroBackground.heroImage(for: snapshot,
                                 family: HeroBackground.Family(storage: heroFamily),
                                 exists: { UIImage(named: $0) != nil })
    }

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
            }
        }
        .task(id: store.selectedINE) { await load(force: false) }
    }

    /// The full-bleed sky behind everything.
    /// - iPhone (compact): the sky bleeds edge to edge as before.
    /// - iPad / Mac (regular): the hero art is portrait, so stretching it across a wide landscape window
    ///   crops most of it away. Instead show a heavily blurred, dimmed copy full-bleed as an ambient
    ///   backdrop, and the crisp sky capped to the card-column width and centred — so the art reads at
    ///   its true portrait proportions right behind the cards, showing far more of what was drawn.
    @ViewBuilder private var skyBackground: some View {
        if hSizeClass == .regular {
            ZStack {
                AuraSky(snapshot: snapshot, heroImage: heroImage)
                    .ignoresSafeArea()
                    .blur(radius: 44)
                    .overlay(Color.black.opacity(0.32).ignoresSafeArea())
                AuraSky(snapshot: snapshot, heroImage: heroImage)
                    .frame(maxWidth: Self.columnMaxWidth)
                    .frame(maxWidth: .infinity)   // centre the capped sky column in the window
                    .ignoresSafeArea(.container, edges: .vertical)
            }
        } else {
            AuraSky(snapshot: snapshot, heroImage: heroImage).ignoresSafeArea()
        }
    }

    /// The sections that used to be tabs, now reachable from the hero menu. Presented as sheets (each
    /// brings its own navigation and title; swipe down to dismiss).
    private enum MenuRoute: Int, Identifiable { case forecast, locations, settings; var id: Int { rawValue } }
    @State private var route: MenuRoute?

    /// A discreet frosted control in the hero's top-trailing corner — opposite the editorial text — that
    /// opens Predicción, Ubicaciones and Ajustes without a persistent bottom bar.
    private var heroMenu: some View {
        Menu {
            Button { route = .forecast }  label: { Label("Predicción", systemImage: "text.alignleft") }
            Button { route = .locations } label: { Label("Ubicaciones", systemImage: "mappin.and.ellipse") }
            Button { route = .settings }  label: { Label("Ajustes", systemImage: "gearshape") }
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
    /// it never rides up with the content. Only present when there's a forecast to reveal.
    @ViewBuilder private var scrollHint: some View {
        if snapshot != nil {
            VStack(spacing: 1) {
                Text("MÁS").font(.system(size: 11, weight: .bold)).tracking(2)
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.85))
            .shadow(color: .black.opacity(0.35), radius: 5, y: 1)
            .padding(.bottom, 8)
            .opacity(atTop ? 1 : 0)
            .allowsHitTesting(false)
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

                    if let snapshot {
                        AuraForecastStack(snapshot: snapshot, size: .phone, now: loadedAt ?? Date(),
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
        let refreshError = await AEMETService.refreshAllForWidgets(store.favorites, force: force)
        if let snap = SharedCache.snapshot(forINE: location.ine) {
            snapshot = snap
            loadedINE = location.ine
            loadedAt = Date()
            // Mirror the on-screen location to the paired Watch's complication.
            WatchSync.shared.send(snap)
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
