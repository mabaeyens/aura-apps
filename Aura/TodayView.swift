import AuraKit
import SwiftUI
import UIKit

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

    @State private var snapshot: WeatherSnapshot?
    @State private var radar: AuraRadarInfo?
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Which location `snapshot` belongs to, and when it was read — so a tab re-appearance or app
    /// foreground doesn't trigger a refresh when the on-screen data is already recent.
    @State private var loadedINE: String?
    @State private var loadedAt: Date?

    /// AEMET updates municipal forecasts only a few times a day; don't refresh the same location
    /// more often than this except on an explicit pull-to-refresh.
    private static let minInterval: TimeInterval = 15 * 60

    var body: some View {
        NavigationStack {
            ZStack {
                AuraSky(snapshot: snapshot).ignoresSafeArea()
                Group {
                    if let location = store.selected {
                        content(for: location)
                    } else {
                        ContentUnavailableView(
                            "Sin ubicaciones",
                            systemImage: "mappin.slash",
                            description: Text("Añade una ubicación en la pestaña Ubicaciones.")
                        )
                    }
                }
                .environment(\.colorScheme, .dark)   // light text + dark frosted cards over the sky
            }
            .toolbar(.hidden, for: .navigationBar)    // immersive: the hero card carries the location name
        }
        .task(id: store.selectedINE) { await load(force: false) }
    }

    @ViewBuilder
    private func content(for location: Location) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                if !store.apiKeyPresent { keyBanner }

                if let snapshot {
                    AuraForecastStack(snapshot: snapshot, size: .phone, now: loadedAt ?? Date(),
                                      radar: radar)
                } else if isLoading {
                    notice { HStack(spacing: 8) { ProgressView().tint(.white); Text("Cargando…") } }
                } else if let errorMessage {
                    notice { Label(errorMessage, systemImage: "exclamationmark.triangle") }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 64)   // let the sky's horizon breathe below the last card
        }
        .scrollContentBackground(.hidden)
        .refreshable { await load(force: true) }
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
