import CoreLocation
import Foundation

/// The full table of Spanish municipalities (INE code, name, province, centroid), bundled as
/// `municipios.json` (~8100 entries). Backs the location search and the GPS "nearest municipality"
/// resolution, so a coordinate anywhere in Spain snaps to the true closest town rather than the
/// nearest of a handful of capitals. Decoded once on first use; falls back to `Location.seedCities`
/// if the bundled file is missing or unreadable.
///
/// Lives in AuraKit (not the phone app target) so the Watch can resolve its own current location
/// standalone, off the paired iPhone. Loaded from `Bundle.module`, so every target that links AuraKit
/// gets the same table without duplicating the JSON.
public enum MunicipioDatabase {
    /// Every municipality, in file order.
    public static let all: [Location] = load()

    /// Municipalities sorted by name, each paired with a diacritic/case-folded name and province
    /// for accent-insensitive search ("avila" matches "Ávila", "ababuj" matches "Ababuj").
    public static let searchable: [Entry] = all
        .map(Entry.init)
        .sorted { $0.location.nombre.localizedCaseInsensitiveCompare($1.location.nombre) == .orderedAscending }

    public struct Entry: Sendable {
        public let location: Location
        public let foldedNombre: String
        public let foldedProvincia: String

        public nonisolated init(_ location: Location) {
            self.location = location
            self.foldedNombre = location.nombre.foldedForSearch
            self.foldedProvincia = location.provincia.foldedForSearch
        }

        /// True when the already-folded query is a substring of the name or province.
        public func matches(_ foldedQuery: String) -> Bool {
            foldedNombre.contains(foldedQuery) || foldedProvincia.contains(foldedQuery)
        }
    }

    /// Ranked search: exact name, then name prefix, then name substring, then province-only matches, each
    /// tier alphabetical (`searchable` is pre-sorted). Without ranking, a province query or a short name
    /// fills the capped list with alphabetically-early towns and the city itself never appears.
    /// "name, province" or "name province" narrows same-named municipalities to that province.
    public static func search(_ query: String, limit: Int = 50) -> [Location] {
        let folded = query.foldedForSearch.trimmingCharacters(in: .whitespaces)
        guard !folded.isEmpty else { return [] }

        var namePart = folded
        var provincePart: String?
        if let comma = folded.firstIndex(of: ",") {
            namePart = String(folded[..<comma]).trimmingCharacters(in: .whitespaces)
            let rest = String(folded[folded.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
            provincePart = rest.isEmpty ? nil : rest
        }

        var tiers: [[Location]] = Array(repeating: [], count: 4)
        for entry in searchable {
            if let provincePart {
                guard entry.foldedProvincia.contains(provincePart) else { continue }
                if entry.foldedNombre == namePart { tiers[0].append(entry.location) }
                else if entry.foldedNombre.hasPrefix(namePart) { tiers[1].append(entry.location) }
                else if entry.foldedNombre.contains(namePart) { tiers[2].append(entry.location) }
                continue
            }
            if entry.foldedNombre == namePart { tiers[0].append(entry.location) }
            else if entry.foldedNombre.hasPrefix(namePart) { tiers[1].append(entry.location) }
            else if entry.foldedNombre.contains(namePart) { tiers[2].append(entry.location) }
            else if entry.foldedProvincia.contains(namePart) { tiers[3].append(entry.location) }
        }
        return Array(tiers.joined().prefix(limit))
    }

    /// The nearest municipality to a coordinate by great-circle distance over the full table, or nil if the
    /// table is empty. Shared by the phone's `LocationManager` and the Watch's `WatchLocationManager` so a
    /// GPS fix snaps to the same town on both, and unit-testable here without either device layer.
    public static func nearest(latitude: Double, longitude: Double) -> Location? {
        let here = CLLocation(latitude: latitude, longitude: longitude)
        return all.min {
            here.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))
                < here.distance(from: CLLocation(latitude: $1.latitude, longitude: $1.longitude))
        }
    }

    private static func load() -> [Location] {
        guard let url = Bundle.module.url(forResource: "municipios", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Location].self, from: data),
              !list.isEmpty
        else { return Location.seedCities }
        return list
    }
}

public extension String {
    /// Lowercased and stripped of diacritics, for accent- and case-insensitive matching.
    nonisolated var foldedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es_ES"))
    }
}
