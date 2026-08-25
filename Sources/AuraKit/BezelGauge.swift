import SwiftUI

/// The curved bezel gauge shared by every `.accessoryCorner` complication's `cornerGauge`. On a real face
/// the complication wraps this in `.widgetLabel`, which arcs it along the outer bezel — so it carries no
/// `gaugeStyle` and no centre content (the corner's own glyph/text sits inside): just the fill and the two
/// end labels, tinted along a gradient. Every corner differs only in the value, range, end labels and tint,
/// so each `cornerGauge` is now a single `BezelGauge(...)` instead of the same six-line `Gauge` boilerplate.
struct BezelGauge<Bounds: View, Tint: ShapeStyle>: View {
    let value: Double
    let range: ClosedRange<Double>
    let tint: Tint
    // Gauge folds both end labels into one `BoundsLabel` slot, so they share a type — always true here
    // since every corner's two labels are the same shape (both plain numbers, or both a tinted degree).
    @ViewBuilder let minLabel: () -> Bounds
    @ViewBuilder let maxLabel: () -> Bounds

    var body: some View {
        Gauge(value: value, in: range) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        } minimumValueLabel: {
            minLabel()
        } maximumValueLabel: {
            maxLabel()
        }
        .tint(tint)
    }
}
