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

/// The current relative humidity as a circular face.
struct AuraHumidityComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraHumidity", provider: AuraComplicationProvider()) { entry in
            Group {
                if let snapshot = entry.snapshot {
                    AuraHumidityCircular(snapshot: snapshot)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Humedad")
        .description("La humedad relativa actual.")
        .supportedFamilies([.accessoryCircular])
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
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

struct AuraAvisoComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline: AuraAvisoInline(snapshot: snapshot, now: entry.date)
            default:               AuraAvisoCircular(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}
