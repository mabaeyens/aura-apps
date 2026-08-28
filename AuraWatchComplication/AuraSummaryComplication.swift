import AuraKit
import SwiftUI
import WidgetKit

// Watch twins of the iOS Lock Screen summary/humidity/aviso glances. Layouts come from AuraKit so the
// watch face and the iPhone Lock Screen render identical code.

/// A weather summary glance in every accessory family: the condition glyph + temperature (circular),
/// the glyph with the temperature on the bezel (corner), and the `temp · lluvia · humedad` line inline
/// and rectangular. All four so it can fill any watch-face slot, including the Wayfinder sundial.
struct AuraSummaryComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraSummary", provider: AuraComplicationProvider()) { entry in
            AuraSummaryComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("watch.complication.summary.name"))
        .description(auraString("watch.complication.summary.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryCorner, .accessoryRectangular])
    }
}

struct AuraSummaryComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline:      AuraSummaryInline(snapshot: snapshot, now: entry.date)
            case .accessoryRectangular: AuraSummaryRectangular(snapshot: snapshot, now: entry.date)
            case .accessoryCorner:
                let corner = AuraSummaryCorner(snapshot: snapshot, now: entry.date)
                corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
            default:                    AuraSummaryCircular(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// The current relative humidity as a ring (circular), or the drop + percentage with a 0…100 % gauge
/// curving the bezel (corner).
struct AuraHumidityComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraHumidity", provider: AuraComplicationProvider()) { entry in
            AuraHumidityView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("watch.complication.humidity.name"))
        .description(auraString("watch.complication.humidity.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct AuraHumidityView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCorner:
                let corner = AuraHumidityCorner(snapshot: snapshot)
                if corner.hasValue {
                    corner.widgetCurvesContent().widgetLabel { corner.cornerGauge }
                } else {
                    corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
                }
            default:
                AuraHumidityCircular(snapshot: snapshot)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

/// A severe-weather aviso mark in every accessory family; the empty state when none is active.
struct AuraAvisoComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraAviso", provider: AuraComplicationProvider()) { entry in
            AuraAvisoComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("aviso.label"))
        .description(auraString("watch.complication.aviso.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryCorner, .accessoryRectangular])
    }
}

struct AuraAvisoComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline:      AuraAvisoInline(snapshot: snapshot, now: entry.date)
            case .accessoryRectangular: AuraAvisoRectangular(snapshot: snapshot, now: entry.date)
            case .accessoryCorner:
                let corner = AuraAvisoCorner(snapshot: snapshot, now: entry.date)
                corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
            default:                    AuraAvisoCircular(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}
