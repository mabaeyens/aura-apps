import SwiftUI
import WidgetKit

/// The Watch complication extension's entry point. Each `Widget` is a separate entry in the
/// watch-face complication gallery.
@main
struct AuraComplicationBundle: WidgetBundle {
    var body: some Widget {
        AuraConditionsComplication()
        AuraSunComplication()
        AuraSunMoonComplication()
        AuraRainComplication()
        AuraUVComplication()
        AuraWindNeedleComplication()
        AuraHoursComplication()
        AuraDaysComplication()
    }
}
