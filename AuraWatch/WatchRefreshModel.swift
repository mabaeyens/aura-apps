import AuraKit
import SwiftUI
import WidgetKit

/// Drives the Watch's own standalone refresh, so the wrist can pull fresh AEMET data with no paired
/// iPhone in the loop (the hike-with-a-cellular-watch scenario). Reuses the shared `AuraRefreshCore`
/// fetch path, the same one the phone and widget use, so there is one AEMET client, not a second.
///
/// Foreground only for now: the manual pull (Digital Crown / `.refreshable`) covers "I open the watch app
/// and it updates". watchOS background auto-refresh (`WKApplicationRefreshBackgroundTask`) is a later,
/// on-device-verified step.
@MainActor
final class WatchRefreshModel: ObservableObject {
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    /// True after a current-location refresh found no location permission, so the UI can prompt.
    @Published var locationDenied = false

    private let location = WatchLocationManager()

    /// App Group flag: the wrist is showing its own GPS-resolved current location, so a refresh re-runs
    /// the fix rather than refetching a phone favourite. Device-local, read by the view and this model.
    static var currentLocationMode: Bool {
        get { SharedCache.groupDefaults?.bool(forKey: currentModeKey) ?? false }
        set { SharedCache.groupDefaults?.set(newValue, forKey: currentModeKey) }
    }
    private static let currentModeKey = "watch.currentLocationMode"

    /// Refresh the shown selection directly from AEMET over the Watch's own network.
    ///
    /// In current-location mode, take a one-shot GPS fix, resolve the nearest municipality and fetch it.
    /// Otherwise refetch the shown favourite. The whole favourites list is passed to `AuraRefreshCore` so
    /// its pruning keeps every place; `onlyINE` scopes the actual fetch to the one location, so a pull
    /// costs at most one place's fetch (plus the shared national feeds).
    func refresh(currentMode: Bool, shownINE: String?) async {
        // No key on the Watch yet: ask the phone for it and leave the add-key state in place. Nothing to
        // fetch with, so bail rather than hit AEMET with an empty key.
        guard AuraKeychain.apiKey()?.isEmpty == false else {
            WatchSync.shared.requestAPIKeyIfMissing()
            return
        }

        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        guard let target = await resolveTarget(currentMode: currentMode, shownINE: shownINE) else { return }

        var locations = SharedLocations.read()
        if !locations.contains(where: { $0.ine == target.ine }) { locations.append(target) }

        let outcome = await AuraRefreshCore.refresh(locations: locations, onlyINE: target.ine)
        errorMessage = outcome.errorMessage

        // Point both the app screen and the complication at the refreshed place. In current-location mode
        // the resolved town is the shown place; a favourite refresh keeps whatever was already shown.
        if currentMode {
            SharedCache.watchSelectedINE = target.ine
            SharedCache.activeINE = target.ine
        }
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: WatchSync.snapshotDidUpdate, object: nil)
    }

    /// Enter current-location mode and refresh immediately (used when the picker selects "current location").
    func switchToCurrentLocation() async {
        Self.currentLocationMode = true
        await refresh(currentMode: true, shownINE: nil)
    }

    private func resolveTarget(currentMode: Bool, shownINE: String?) async -> Location? {
        if currentMode {
            let resolved = await resolveCurrent()
            locationDenied = (resolved == nil && location.authorizationDenied)
            return resolved
        }
        guard let ine = shownINE else { return nil }
        // Prefer the mirrored favourite (full coords/name); fall back to a Location rebuilt from the cached
        // snapshot so a refresh still works before the favourites menu has synced.
        return SharedLocations.read().first { $0.ine == ine }
            ?? SharedCache.snapshot(forINE: ine).map {
                Location(ine: $0.ine, nombre: $0.localidad, provincia: $0.provincia,
                         latitude: $0.latitude ?? 0, longitude: $0.longitude ?? 0)
            }
    }

    private func resolveCurrent() async -> Location? {
        await withCheckedContinuation { continuation in
            location.resolveNearest { continuation.resume(returning: $0) }
        }
    }
}
