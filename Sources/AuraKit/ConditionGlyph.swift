import SwiftUI

/// The condition icon, rendered consistently across every complication: full multicolour by day (a
/// yellow sun, grey clouds), but a clear blue moon at night — because `.multicolor` renders
/// `moon.stars.fill` as a flat pale white that reads as a daytime sun on a black watch face.
///
/// Callers set the size with `.font(...)` on the result, as with any `Image`.
public struct ConditionGlyph: View {
    let sky: String?
    let isNight: Bool

    public init(sky: String?, isNight: Bool) {
        self.sky = sky
        self.isNight = isNight
    }

    public var body: some View {
        let name = WeatherIcon.symbol(forSky: sky, isNight: isNight)
        if isNight, name == "moon.stars.fill" {
            // A blue moon with white stars — unambiguously night, and visible on any background.
            Image(systemName: name)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Palette.nightMoon, .white)
        } else {
            Image(systemName: name).symbolRenderingMode(.multicolor)
        }
    }
}
