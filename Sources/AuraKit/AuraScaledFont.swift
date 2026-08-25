import SwiftUI

// MARK: - Dynamic-Type-aware fonts and metrics
//
// Aura's layout is tuned around the fixed point sizes in `AuraSize`. Rather than replace those tuned
// numbers with Apple's text styles (which would re-baseline the whole poster look), we keep every one
// of them as the *base* and let `@ScaledMetric` grow it in step with a reference text style. At the
// default content-size category the app therefore looks exactly as it always has, and the type only
// grows once the reader turns up Larger Text.
//
// `@ScaledMetric` has to live inside a view, so the scaling lives here in a `ViewModifier` instead of
// in the `AuraSize` enum. `UIFontMetrics` would be the UIKit equivalent, but it doesn't exist on
// watchOS; `@ScaledMetric` is the one primitive that scales identically on both platforms.

private struct AuraScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, relativeTo textStyle: Font.TextStyle, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

public extension View {
    /// Drop-in for `.font(.system(size: pt, weight:, design:))` that scales with Dynamic Type.
    ///
    /// `pt` is a tuned `AuraSize` value (or a literal). `relativeTo` picks which text style's growth
    /// curve the size follows — it does **not** change the base size, only how fast it grows. Match it
    /// to the element's role: `.largeTitle` for the hero temperature, `.title3` for card body values,
    /// `.callout` for secondary text, `.caption` for the small uppercase section labels.
    func auraFont(_ pt: CGFloat,
                  relativeTo textStyle: Font.TextStyle,
                  weight: Font.Weight = .regular,
                  design: Font.Design = .default) -> some View {
        modifier(AuraScaledFont(size: pt, relativeTo: textStyle, weight: weight, design: design))
    }
}

/// A single fixed length (a frame width, a padding) that scales with Dynamic Type, so columns and
/// gaps widen in step with the text they sit next to. Read it as a `CGFloat`.
///
///     @AuraScaledMetric(96, relativeTo: .body) private var weekdayColumn
///     ...
///     .frame(width: weekdayColumn)
@propertyWrapper
public struct AuraScaledLength: DynamicProperty {
    @ScaledMetric private var value: CGFloat
    public init(_ base: CGFloat, relativeTo textStyle: Font.TextStyle = .body) {
        _value = ScaledMetric(wrappedValue: base, relativeTo: textStyle)
    }
    public var wrappedValue: CGFloat { value }
}
