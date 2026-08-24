import AuraKit
import SwiftUI
import WidgetKit

// The Watch twin of the iOS "Sol y Luna" widget: the next sun/moon event as a time and a glyph, in the
// inline and circular accessory families. Layouts come from AuraKit so the watch face and the iPhone
// Lock Screen render identical code.

/// The next amanecer, ocaso or (after dark) the moon with the coming amanecer, for the inline and
/// circular complication slots.
struct AuraSunMoonComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraSunMoon", provider: AuraComplicationProvider()) { entry in
            AuraSunMoonComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sol y Luna")
        .description("El próximo amanecer, ocaso o salida de la luna.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryCorner])
    }
}

struct AuraSunMoonComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline: AuraSunMoonInline(snapshot: snapshot, now: entry.date)
            case .accessoryCorner:
                let corner = AuraSunMoonCorner(snapshot: snapshot, now: entry.date)
                corner.widgetLabel(corner.cornerLabel)
            default:               AuraSunMoonCircular(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}
