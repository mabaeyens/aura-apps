import SwiftUI

/// The condition icon, rendered consistently across every complication: full multicolour by day (a
/// yellow sun, grey clouds), but a clear blue moon at night — because `.multicolor` renders
/// `moon.stars.fill` as a flat pale white that reads as a daytime sun on a black watch face.
///
/// Callers set the size with `.font(...)` on the result, as with any `Image`.
public struct ConditionGlyph: View {
    let sky: String?
    let isNight: Bool
    /// When set, the glyph is drawn at this point size inside a fixed-width slot (≈1.5×), so every
    /// condition keeps the same horizontal footprint: a wide rain cloud no longer looks bigger than a
    /// sun, nor steals width from the temperature beside it — which was truncating it on the Lock Screen
    /// and the Watch corner. Heights stay font-consistent (SF Symbols share a cap height at one size).
    /// When nil the caller sizes it with `.font(...)`, exactly as before.
    var slot: CGFloat?

    public init(sky: String?, isNight: Bool, slot: CGFloat? = nil) {
        self.sky = sky
        self.isNight = isNight
        self.slot = slot
    }

    public var body: some View {
        glyph
            .modifier(GlyphSlot(slot: slot))
    }

    @ViewBuilder private var glyph: some View {
        let name = WeatherIcon.symbol(forSky: sky, isNight: isNight)
        if isNight, name == "moon.stars.fill" {
            // A blue moon with white stars — unambiguously night, and visible on any background.
            Image(systemName: name)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Palette.nightMoon, .white)
        } else if name == "snowflake" {
            // The snowflake glyph is a single-layer symbol, so `.multicolor` renders it in the flat
            // label colour — black on a light surface, where it vanishes into the card. Snow reads as
            // white, so force it: white is legible over the overcast sky these conditions bring and over
            // the light cards, where the label-coloured version was invisible.
            Image(systemName: name)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white)
        } else {
            Image(systemName: name).symbolRenderingMode(.multicolor)
        }
    }
}

/// Sizes a condition glyph to a fixed point size inside a fixed **square** slot, so a wide cloud, a narrow
/// sun and a tall cloud-sun all occupy the same footprint — width *and* height. Fixing the height matters
/// in the vertical hour columns: a taller multi-part symbol (`cloud.sun.fill`) would otherwise push its
/// temperature down a few points, knocking the strip's temperature row out of line. A no-op when `slot` is
/// nil (the caller sizes it with `.font`).
private struct GlyphSlot: ViewModifier {
    let slot: CGFloat?
    func body(content: Content) -> some View {
        if let slot {
            content
                .font(.system(size: slot))
                .frame(width: slot * 1.5, height: slot * 1.5)
        } else {
            content
        }
    }
}
