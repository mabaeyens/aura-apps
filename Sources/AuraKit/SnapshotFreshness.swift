import Foundation

/// How current a cached snapshot is, measured only from its `updated` stamp against the render time.
/// The widget is a pure cache reader today, so a snapshot can be hours or a day old with nothing to say
/// so; this is the signal a surface uses to draw an honest staleness badge instead of a silent stale value.
public enum SnapshotFreshness: Equatable {
    /// Within the app's own 1 h stale gate — no badge; treat as current.
    case fresh
    /// Older than an hour but still inside the ~24 h strip horizon, where display-time resolution keeps
    /// the values correct. The badge is informational (dim "actualizado HH:mm"), not an error.
    case recent
    /// Past the ~24 h horizon: the hero can no longer re-anchor to today, so the badge escalates to an
    /// honest "Desactualizado".
    case stale
}

public extension WeatherSnapshot {
    /// Under an hour old counts as fresh — the same gate the app uses before it refetches
    /// (`AEMETService.performRefresh`), so app and widget agree on what "current" means.
    static let recentThreshold: TimeInterval = 3600
    /// The next-hours strip spans roughly a day; past it, display-time resolution can no longer show today.
    static let staleThreshold: TimeInterval = 24 * 3600

    /// The snapshot's freshness at `now`, from its `updated` stamp. A future stamp (device clock skew)
    /// reads as fresh, never stale.
    func freshness(at now: Date = Date()) -> SnapshotFreshness {
        let age = now.timeIntervalSince(updated)
        if age < WeatherSnapshot.recentThreshold { return .fresh }
        if age < WeatherSnapshot.staleThreshold { return .recent }
        return .stale
    }

    /// The short badge string for a widget/complication surface, or nil when fresh enough to need none.
    /// `recent` shows when the data was fetched, in the location's own time; `stale` states the fact.
    func stalenessLabel(at now: Date = Date(),
                        timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current) -> String? {
        switch freshness(at: now) {
        case .fresh:
            return nil
        case .recent:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "es_ES")
            formatter.timeZone = timeZone
            formatter.dateFormat = "HH:mm"
            return "actualizado " + formatter.string(from: updated)
        case .stale:
            return "Desactualizado"
        }
    }
}
