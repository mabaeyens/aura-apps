import SwiftUI

// MARK: - Uniformly-sized metric values
//
// A row of metric chips (the station card, the air-quality card) sits in equal-width columns. A value
// that runs a glyph or two longer than its neighbours (pressure "1013", humidity "96%", a negative
// temperature) would, left to a per-chip `minimumScaleFactor`, shrink on its own and read smaller than
// the rest, which is exactly the uneven look this fixes.
//
// The row measures the width of one column and the width of its widest value, works out the one font
// size at which that widest value still fits, and hands that single size to every value through the
// environment. Because all five are then drawn at the *same* size literal, they cannot diverge: even if
// the measurement were off, the values stay equal to each other (only uniformly larger or smaller). The
// measurement is taken at the base font, so the size the row settles on never depends on the size it
// feeds back, and the width it reads does not depend on that size either, so it converges in one pass.

private struct ColumnWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = .greatestFiniteMagnitude
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

private struct WidestValueKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MetricValueSizeKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil   // nil until the row has measured; render at base until then
}

extension EnvironmentValues {
    /// The one font size every `AuraMetricValue` in a `.uniformValueScale()` row draws at. `nil` before
    /// the first measurement, so a value falls back to its own base size for that initial pass.
    fileprivate var uniformMetricValueSize: CGFloat? {
        get { self[MetricValueSizeKey.self] }
        set { self[MetricValueSizeKey.self] = newValue }
    }
}

/// One numeric metric value that shares a single font size with the other values in its row. Drop it in
/// place of a `Text` inside a chip, and put `.uniformValueScale()` on the chips' container. Style
/// (`foregroundStyle`, opacity) is applied by the caller, as with a plain `Text`.
struct AuraMetricValue: View {
    private let text: String
    private let base: CGFloat
    private let textStyle: Font.TextStyle
    private let weight: Font.Weight
    @Environment(\.uniformMetricValueSize) private var shared

    init(_ text: String, size: CGFloat, relativeTo textStyle: Font.TextStyle,
         weight: Font.Weight = .regular) {
        self.text = text
        self.base = size
        self.textStyle = textStyle
        self.weight = weight
    }

    var body: some View {
        // Draw at the row's shared size once known, otherwise at this value's own base size.
        Text(text)
            .auraFont(shared ?? base, relativeTo: textStyle, weight: weight, design: .rounded)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .background(measurer)
    }

    /// Reports this value's column width and its intrinsic width at the base font, both measured
    /// independently of the shared size the row hands back (so the loop settles in one pass).
    private var measurer: some View {
        GeometryReader { column in
            Text(text)
                .auraFont(base, relativeTo: textStyle, weight: weight, design: .rounded)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
                .background(GeometryReader { intrinsic in
                    Color.clear
                        .preference(key: ColumnWidthKey.self, value: column.size.width)
                        .preference(key: WidestValueKey.self, value: intrinsic.size.width)
                })
                .hidden()
        }
        // The base size travels with the widest-value width, so the row can turn the two into a size.
        .preference(key: MetricValueBaseKey.self, value: base)
    }
}

/// Carries the base size up alongside the measured widths, so the row scales from the right starting point.
private struct MetricValueBaseKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Collects the narrowest column and the widest value in this subtree and hands every
    /// `AuraMetricValue` in it one shared font size, so a row of values renders at a single size that
    /// still fits. Apply to the chips' container (the `HStack`).
    func uniformValueScale() -> some View {
        modifier(UniformValueScale())
    }
}

private struct UniformValueScale: ViewModifier {
    @State private var column: CGFloat = .greatestFiniteMagnitude
    @State private var widest: CGFloat = 0
    @State private var base: CGFloat = 0

    /// The largest size at which the widest value still fits its column, never above the base size. A tiny
    /// inset keeps the glyph off the column edge.
    private var sharedSize: CGFloat? {
        guard base > 0, widest > 0, column.isFinite, column > 0 else { return nil }
        let fit = base * (column - 2) / widest
        return min(base, max(1, fit))
    }

    func body(content: Content) -> some View {
        content
            .environment(\.uniformMetricValueSize, sharedSize)
            .onPreferenceChange(ColumnWidthKey.self) { column = $0 }
            .onPreferenceChange(WidestValueKey.self) { widest = $0 }
            .onPreferenceChange(MetricValueBaseKey.self) { base = $0 }
    }
}
