import AuraKit
import SwiftUI
import WidgetKit

// Watch twins of the iOS Lock Screen summary/humidity/aviso glances. Layouts come from AuraKit so the
// watch face and the iPhone Lock Screen render identical code.

/// A one-line weather summary — temp · lluvia · humedad — for the inline complication slot.
struct AuraSummaryComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraSummary", provider: AuraComplicationProvider()) { entry in
            Group {
                if let snapshot = entry.snapshot {
                    AuraSummaryInline(snapshot: snapshot, now: entry.date)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Resumen")
        .description("Temperatura, lluvia y humedad en una línea.")
        .supportedFamilies([.accessoryInline])
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
        .configurationDisplayName("Humedad")
        .description("La humedad relativa actual.")
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

/// A severe-weather aviso mark, circular or inline; the empty state when none is active.
struct AuraAvisoComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraAviso", provider: AuraComplicationProvider()) { entry in
            AuraAvisoComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Aviso")
        .description("El aviso meteorológico activo, si lo hay.")
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

struct AuraAvisoComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline: AuraAvisoInline(snapshot: snapshot, now: entry.date)
            case .accessoryCorner:
                let corner = AuraAvisoCorner(snapshot: snapshot, now: entry.date)
                corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
            default:               AuraAvisoCircular(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}
