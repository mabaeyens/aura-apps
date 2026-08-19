import Foundation

/// The user's saved locations, mirrored to the App Group so the widget's configuration picker can
/// list them — even before any weather has been cached for them. The app writes this whenever the
/// favourites change; the widget's `EntityQuery` reads it to populate the location chooser.
///
/// This is deliberately separate from `SharedCache`: the cache holds *weather* (and only for
/// locations that have been fetched), while this holds the *menu* of choices the widget offers.
public enum SharedLocations {
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedCache.appGroupID)?
            .appendingPathComponent("locations.json")
    }

    /// The saved locations, in the user's order. Empty if none have been mirrored yet.
    public static func read() -> [Location] {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Location].self, from: data)) ?? []
    }

    /// Replace the mirrored list. Called by the app when favourites are added, removed or reordered.
    public static func write(_ locations: [Location]) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(locations) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
