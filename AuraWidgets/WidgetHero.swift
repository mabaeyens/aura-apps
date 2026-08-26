import AuraKit
import SwiftUI
import UIKit

/// Picks the wide per-condition hero for the Home Screen widget at the widget's own resolution, so a
/// screen — or the widget gallery — full of Aura widgets stays inside WidgetKit's ~30 MB per-process
/// memory budget.
///
/// The widget ships a single `_w` tier at 1000 px (see `AuraWidgets/Assets.xcassets`), loaded
/// **directly** by name — no runtime downsampling — because `preparingThumbnail` still transiently
/// decodes the full-resolution source on every render, and the gallery renders all four families at
/// once: four of those decodes at once blow the budget and the losing preview (medium, on iPad, where
/// XL joins the set) falls back to a blank placeholder. Only one hero decodes per preview at any time
/// (the current condition + time), so the per-condition grid costs the same as the old four bases —
/// pre-sized assets never decode more than they show, so the whole set fits. The full-resolution wide
/// art (1400 px) lives only in the app's own catalog for iPad; the extra-large widget shares this `_w`
/// tier too, so the widget never carries a second copy of the app's iPad heroes.
enum WidgetHero {
    /// The wide hero for a snapshot + scene, at the widget's 1000 px `_w` tier. Returns `nil` — "no art,
    /// use AuraSky's procedural sky" — when no hero has shipped for this sky.
    static func base(for snapshot: WeatherSnapshot?, now: Date, scene: HeroBackground.Family) -> Image? {
        // Probe the `_w` tier: it's the only tier the widget bundles, so a hero has "shipped" for a sky
        // exactly when its `_w` asset is present.
        guard let name = HeroBackground.wideName(for: snapshot, now: now, family: scene,
                                                 exists: { UIImage(named: $0 + "_w") != nil }) else {
            return nil
        }
        return UIImage(named: name + "_w") != nil ? Image(name + "_w") : nil
    }
}
