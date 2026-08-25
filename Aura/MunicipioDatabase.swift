import AuraKit
import Foundation

/// The full table of Spanish municipalities (INE code, name, province, centroid), bundled as
/// `municipios.json` (~8100 entries). Backs the location search and the GPS "nearest municipality"
/// resolution, so a coordinate anywhere in Spain snaps to the true closest town rather than the
/// nearest of a handful of capitals. Decoded once on first use; falls back to `Location.seedCities`
/// if the bundled file is missing or unreadable.
enum MunicipioDatabase {
    /// Every municipality, in file order.
    static let all: [Location] = load()

    /// Municipalities sorted by name, each paired with a diacritic/case-folded name and province
    /// for accent-insensitive search ("avila" matches "Ávila", "ababuj" matches "Ababuj").
    static let searchable: [Entry] = all
        .map(Entry.init)
        .sorted { $0.location.nombre.localizedCaseInsensitiveCompare($1.location.nombre) == .orderedAscending }

    struct Entry {
        let location: Location
        let foldedNombre: String
        let foldedProvincia: String

        nonisolated init(_ location: Location) {
            self.location = location
            self.foldedNombre = location.nombre.foldedForSearch
            self.foldedProvincia = location.provincia.foldedForSearch
        }

        /// True when the already-folded query is a substring of the name or province.
        func matches(_ foldedQuery: String) -> Bool {
            foldedNombre.contains(foldedQuery) || foldedProvincia.contains(foldedQuery)
        }
    }

    private static func load() -> [Location] {
        guard let url = Bundle.main.url(forResource: "municipios", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Location].self, from: data),
              !list.isEmpty
        else { return Location.seedCities }
        return list
    }
}

extension String {
    /// Lowercased and stripped of diacritics, for accent- and case-insensitive matching.
    nonisolated var foldedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
    }
}
