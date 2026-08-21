import SwiftUI

/// Picks the hero background *image* for the current sky and time of day, with a fallback chain that
/// keeps the screen sensible while the 8×6 art grid is still being filled in, and ultimately falls back
/// to the procedural `AuraSky`.
///
/// The art is generated **without any sun or moon** (see `docs/HERO_BACKGROUNDS.md`): Aura draws the
/// live sun/moon disc on top at the true solar position, so the only light that moves is the real one and
/// the image never carries a second, frozen sun.
///
/// The resolver is pure and testable — it's handed the *set of asset names that actually exist* and
/// returns the best one, or `nil` to mean "no art, use the procedural sky". The app builds that set once
/// by probing its bundle for `HeroBackground.allAssetNames`.
public enum HeroBackground {

    // MARK: Axes

    /// The six times of day the grid is cut into, derived from the **real sun path** so they track true
    /// sunrise/sunset for the location rather than clock hours alone.
    public enum Time: String, CaseIterable, Sendable {
        case dawn, morning, noon, afternoon, dusk, night

        public init(now: Date, sunrise: Date?, sunset: Date?) {
            let path = AuraSunPath(now: now, sunrise: sunrise, sunset: sunset)
            if path.isNight { self = .night; return }
            // point.x runs 0 (sunrise / east) → 1 (sunset / west) across the daylight span.
            switch path.point.x {
            case ..<0.12: self = .dawn
            case ..<0.40: self = .morning
            case ..<0.60: self = .noon
            case ..<0.88: self = .afternoon
            default:      self = .dusk
            }
        }
    }

    /// The eight sky conditions with their own art — the `Palette.Sky` categories except `.unknown`
    /// (which has none and falls through to the procedural sky). The raw value is the filename token.
    public enum Condition: String, CaseIterable, Sendable {
        case clear
        case fewClouds = "few_clouds"
        case cloudy
        case overcast
        case rainy
        case stormy
        case snowy
        case foggy

        public init?(_ sky: Palette.Sky) {
            switch sky {
            case .clear:     self = .clear
            case .fewClouds: self = .fewClouds
            case .clouds:    self = .cloudy
            case .overcast:  self = .overcast
            case .rain:      self = .rainy
            case .storm:     self = .stormy
            case .snow:      self = .snowy
            case .fog:       self = .foggy
            case .unknown:   return nil
            }
        }
    }

    /// The art *family* — a whole alternate set of 48 (same 8×6 grid) with different scenery. The user
    /// picks one and it persists (`@AppStorage("heroFamily")`). Landscape keeps the **bare** name so its
    /// 48 assets never need renaming; cityscape carries a `city_` prefix on the same flat name.
    public enum Family: String, CaseIterable, Sendable {
        case landscape, cityscape

        /// Prepended to the `condition_time` token so both families coexist in one flat asset catalog.
        var assetPrefix: String { self == .cityscape ? "city_" : "" }

        /// Spanish label for the settings switch.
        public var displayName: String { self == .cityscape ? "Ciudad" : "Paisaje" }

        /// Decode the persisted `@AppStorage` string; any unknown value falls back to `.landscape`.
        public init(storage: String?) { self = Family(rawValue: storage ?? "") ?? .landscape }
    }

    // MARK: Resolver

    /// Canonical asset name, e.g. `"few_clouds_dawn"` (landscape) or `"city_clear_night"` (cityscape).
    public static func assetName(_ family: Family, _ condition: Condition, _ time: Time) -> String {
        "\(family.assetPrefix)\(condition.rawValue)_\(time.rawValue)"
    }

    /// Every name one family's full 8×6 grid would contain (48).
    public static func assetNames(for family: Family) -> [String] {
        Condition.allCases.flatMap { c in Time.allCases.map { assetName(family, c, $0) } }
    }

    /// Every name across all families (96). The app probes these against its bundle to learn which art
    /// actually shipped, then passes the surviving set to `resolve`.
    public static let allAssetNames: [String] = Family.allCases.flatMap { assetNames(for: $0) }

    /// Resolve the best background for a sky + time **within the chosen family**, given which assets exist.
    ///
    /// Chain: exact `(family, condition, time)` → nearest existing time for the **same** condition in the
    /// **same** family → `nil` (procedural). It never borrows another condition's art, and never the other
    /// family's — a family with no art for this sky falls to the procedural sky, not to the other family.
    public static func resolve(sky: Palette.Sky, time: Time, family: Family = .landscape,
                               available: Set<String>) -> String? {
        guard let condition = Condition(sky) else { return nil }
        let exact = assetName(family, condition, time)
        if available.contains(exact) { return exact }

        // Nearest existing time bucket for the same condition, over the daily cycle (so `dawn` is a
        // neighbour of `night`). Ties resolve to the earlier bucket in the day.
        let order = Time.allCases
        guard let want = order.firstIndex(of: time) else { return nil }
        let best = order.indices
            .filter { available.contains(assetName(family, condition, order[$0])) }
            .min { cyclicDistance($0, want, order.count) < cyclicDistance($1, want, order.count) }
        return best.map { assetName(family, condition, order[$0]) }
    }

    /// Convenience straight from a snapshot.
    public static func resolve(for snapshot: WeatherSnapshot, now: Date = Date(),
                               family: Family = .landscape, available: Set<String>) -> String? {
        let (category, _) = Palette.sky(forCode: snapshot.currentSky)
        let time = Time(now: now, sunrise: snapshot.sunrise, sunset: snapshot.sunset)
        return resolve(sky: category, time: time, family: family, available: available)
    }

    private static func cyclicDistance(_ a: Int, _ b: Int, _ n: Int) -> Int {
        let d = abs(a - b)
        return min(d, n - d)
    }
}
