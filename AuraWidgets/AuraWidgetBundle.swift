import SwiftUI
import WidgetKit

/// The widget extension's entry point. Slice A ships one widget; Slices B–D add the rich card
/// sizes, the Lock Screen families, and App-Intent configuration.
@main
struct AuraWidgetBundle: WidgetBundle {
    var body: some Widget {
        AuraTodayWidget()
        AuraRainWidget()
        AuraUVWidget()
        AuraSunMoonWidget()
        AuraSummaryWidget()
        AuraHumidityWidget()
        AuraAvisoWidget()
        AuraHomeWidget()
    }
}
