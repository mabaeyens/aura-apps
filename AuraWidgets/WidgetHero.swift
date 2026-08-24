import AuraKit
import SwiftUI
import UIKit

/// Picks the wide per-condition hero for the Home Screen widget at a resolution matched to the widget
/// family, so a screen — or the widget gallery — full of Aura widgets stays inside WidgetKit's ~30 MB
/// per-process memory budget.
///
/// Each hero ships in two tiers (see `AuraWidgets/Assets.xcassets`): the bare name at 1400 px for the
/// extra-large iPad family, and a `_w` variant at 1000 px for small/medium/large. Each is loaded
/// **directly** by name — no runtime downsampling — because `preparingThumbnail` still transiently
/// decodes the full-resolution source on every render, and the gallery renders all four families at
/// once: four of those decodes at once blow the budget and the losing preview (medium, on iPad, where
/// XL joins the set) falls back to a blank placeholder. Only one hero decodes per preview at any time
/// (the current condition + time), so the per-condition grid costs the same as the old four bases —
/// pre-sized assets never decode more than they show, so the whole set fits.
enum WidgetHero {
    /// The wide hero for a snapshot + scene at the given tier (`full` = the extra-large 1400 px asset,
    /// otherwise the 1000 px `_w` variant). Returns `nil` — "no art, use AuraSky's procedural sky" —
    /// when no hero has shipped for this sky.
    static func base(for snapshot: WeatherSnapshot?, now: Date, scene: HeroBackground.Family,
                     full: Bool) -> Image? {
        guard let name = HeroBackground.wideName(for: snapshot, now: now, family: scene,
                                                 exists: { UIImage(named: $0) != nil }) else {
            return nil
        }
        let sized = full ? name : name + "_w"
        // Prefer the tier's asset; fall back to the bare name, then to nothing (→ procedural sky).
        if UIImage(named: sized) != nil { return Image(sized) }
        if UIImage(named: name) != nil { return Image(name) }
        return nil
    }
}
