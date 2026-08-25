import AuraKit
import Combine
import Foundation

/// Owns the user's favorite locations, the current selection, and knowledge of whether an
/// AEMET key has been entered. Favorites persist to `UserDefaults` and are mirrored to the App
/// Group (via `SharedLocations`) so the widget's configuration picker can list them; the selected
/// location drives every data screen.
@MainActor
final class LocationStore: ObservableObject {
    @Published var favorites: [Location] {
        didSet { persist() }
    }
    @Published var selectedINE: String? {
        didSet { defaults.set(selectedINE, forKey: Keys.selected) }
    }
    /// Bumped whenever the API key changes, so views re-read Keychain state.
    @Published private(set) var apiKeyPresent: Bool

    private let defaults: UserDefaults
    private enum Keys {
        static let favorites = "aura.favorites"
        static let selected = "aura.selectedINE"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.apiKeyPresent = AuraKeychain.apiKey()?.isEmpty == false

        if let data = defaults.data(forKey: Keys.favorites),
           let saved = try? JSONDecoder().decode([Location].self, from: data),
           !saved.isEmpty {
            favorites = saved
        } else {
            // First launch: seed with two places proven live in Phase 0.
            favorites = Location.seedCities.filter { $0.ine == "28079" || $0.ine == "15030" }
        }
        selectedINE = defaults.string(forKey: Keys.selected) ?? favorites.first?.ine
        // `didSet` doesn't fire during init, so mirror the initial list explicitly.
        SharedLocations.write(favorites)
    }

    var selected: Location? {
        favorites.first { $0.ine == selectedINE } ?? favorites.first
    }

    /// Switch to a saved location by its INE — the entry point for a widget deep link (`aura://location/…`).
    /// Ignores an INE that is no longer a favourite (a widget still pinned to a since-removed place) so the
    /// tap is a no-op rather than a silent jump to whatever `selected` falls back to.
    func select(ine: String) {
        guard favorites.contains(where: { $0.ine == ine }) else { return }
        selectedINE = ine
    }

    func add(_ location: Location) {
        guard !favorites.contains(where: { $0.ine == location.ine }) else {
            selectedINE = location.ine
            return
        }
        favorites.append(location)
        selectedINE = location.ine
    }

    func remove(atOffsets offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        if let sel = selectedINE, !favorites.contains(where: { $0.ine == sel }) {
            selectedINE = favorites.first?.ine
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
    }

    func refreshKeyState() {
        apiKeyPresent = AuraKeychain.apiKey()?.isEmpty == false
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(favorites) {
            defaults.set(data, forKey: Keys.favorites)
        }
        // Keep the widget's location picker in sync with the favourites list.
        SharedLocations.write(favorites)
    }
}
