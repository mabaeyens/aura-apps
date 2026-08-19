import AuraKit
import Combine
import Foundation

/// Owns the user's favorite locations, the current selection, and knowledge of whether an
/// AEMET key has been entered. Favorites persist to `UserDefaults`; the selected location
/// drives every data screen. (App Group–backed storage arrives with the widgets in Phase 2.)
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
    }

    var selected: Location? {
        favorites.first { $0.ine == selectedINE } ?? favorites.first
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
    }
}
