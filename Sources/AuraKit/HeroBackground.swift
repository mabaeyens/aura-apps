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

    // MARK: Wide base scenes (iPad / wide canvases)

    /// The wide, **conditionless** base scene for a family and day/night — one image per family per
    /// day/night, four in all (`wide_landscape_day`/`_night`, `wide_city_day`/`_night`). On a wide or
    /// landscape canvas the portrait 8×6 grid can't reflow, so these stand in for it: `AuraSky` draws the
    /// live sun/moon (the hour) and the cloud veil (the weather) on top, so four images cover the matrix.
    public static func wideBaseName(_ family: Family, isNight: Bool) -> String {
        let scene = family == .cityscape ? "city" : "landscape"
        return "wide_\(scene)_\(isNight ? "night" : "day")"
    }

    /// The intrinsic aspect ratio (width ÷ height) of the wide base art — all four ship at 1400×1050.
    /// `AuraSky` needs it to map `wideBaseHorizon` through the `scaledToFill` crop to the live canvas.
    public static let wideBaseAspect: CGFloat = 1400.0 / 1050.0

    /// Where the land meets the sky in each wide base, as a fraction of the art's height — measured from
    /// the shipped 1400×1050 art. The cityscape's rooftops-and-hills sit low (~0.84), so the dawn/dusk sun
    /// already clears them; the landscape's rolling hills rise higher (~0.72), which is why the same low
    /// sun used to land on the grass in front. `AuraSky` uses this to pin a low sun/moon just above the
    /// ridge instead of over the scenery. Day and night share a family's composition, so one value each.
    public static func wideBaseHorizon(_ family: Family) -> CGFloat {
        family == .cityscape ? 0.84 : 0.72
    }

    /// The wide base **name** for a snapshot's day/night state (the string counterpart of
    /// `wideBaseImage`), or `nil` for a missing snapshot. Lets the widget load the asset itself — and
    /// downsample it to the widget's display size — instead of taking a full-resolution `Image`.
    public static func wideBaseName(for snapshot: WeatherSnapshot?, now: Date = Date(),
                                    family: Family = .landscape) -> String? {
        guard let snapshot else { return nil }
        let path = AuraSunPath(now: now, sunrise: snapshot.sunrise, sunset: snapshot.sunset)
        return wideBaseName(family, isNight: path.isNight)
    }

    /// The wide base **image** for a snapshot's day/night state, or `nil` (→ procedural sky) when the asset
    /// hasn't shipped. Pure but for the `exists` probe, mirroring `heroImage(for:)`.
    public static func wideBaseImage(for snapshot: WeatherSnapshot?, now: Date = Date(),
                                     family: Family = .landscape, exists: (String) -> Bool) -> Image? {
        guard let snapshot else { return nil }
        let path = AuraSunPath(now: now, sunrise: snapshot.sunrise, sunset: snapshot.sunset)
        let name = wideBaseName(family, isNight: path.isNight)
        return exists(name) ? Image(name) : nil
    }

    private static func cyclicDistance(_ a: Int, _ b: Int, _ n: Int) -> Int {
        let d = abs(a - b)
        return min(d, n - d)
    }

    /// Resolve the best hero **image** for a snapshot, given a predicate that reports which asset names
    /// actually exist. `AuraKit` stays agnostic about the bundle: the app passes `exists`
    /// (e.g. `{ UIImage(named: $0) != nil }`), and only the chosen family's 48 names are probed. Returns
    /// `nil` — meaning "no art for this sky, use the procedural `AuraSky`" — for a missing snapshot, an
    /// unknown/unmapped sky, or a family whose art for this condition hasn't shipped.
    public static func heroImage(for snapshot: WeatherSnapshot?, now: Date = Date(),
                                 family: Family = .landscape, exists: (String) -> Bool) -> Image? {
        guard let snapshot else { return nil }
        let available = Set(assetNames(for: family).filter(exists))
        guard let name = resolve(for: snapshot, now: now, family: family, available: available) else {
            return nil
        }
        return Image(name)
    }
}
