import AuraKit
import SwiftUI
import WidgetKit

/// One timeline entry: the moment and the snapshot to draw (nil before the first sync).
struct AuraComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: WeatherSnapshot?
}

/// Reads the Watch's own `SharedCache`, which `WatchSync` fills from snapshots the iPhone pushes.
struct AuraComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> AuraComplicationEntry {
        AuraComplicationEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (AuraComplicationEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : SharedCache.read().first
        completion(AuraComplicationEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AuraComplicationEntry>) -> Void) {
        let entry = AuraComplicationEntry(date: Date(), snapshot: SharedCache.read().first)
        let next = Calendar.current.date(byAdding: .hour, value: 2, to: entry.date)
            ?? entry.date.addingTimeInterval(2 * 3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Conditions + Temp

/// The main complication: condition + temperature, in every watch accessory family. All layouts come
/// from AuraKit so they match the iPhone's Lock Screen widgets exactly.
struct AuraConditionsComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraConditions", provider: AuraComplicationProvider()) { entry in
            AuraConditionsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("El tiempo")
        .description("La temperatura y los avisos de tu ubicación.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct AuraConditionsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryRectangular: AuraAccessoryRectangular(snapshot: snapshot)
            case .accessoryInline: AuraAccessoryInline(snapshot: snapshot)
            case .accessoryCorner:
                if AuraAccessoryCorner(snapshot: snapshot).hasRange {
                    AuraAccessoryCorner(snapshot: snapshot)
                        .widgetLabel { AuraAccessoryCorner(snapshot: snapshot).cornerGauge }
                } else {
                    AuraAccessoryCorner(snapshot: snapshot)
                        .widgetLabel(AuraAccessoryCorner(snapshot: snapshot).cornerLabel)
                }
            default: AuraAccessoryCircular(snapshot: snapshot)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Sunrise / Sunset

/// The next sun event (sunrise or sunset, auto-picked from the time of day). Corner + circular.
struct AuraSunComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraSun", provider: AuraComplicationProvider()) { entry in
            AuraSunView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Amanecer/Ocaso")
        .description("La próxima salida o puesta de sol.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct AuraSunView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCorner:
                if AuraSunCorner(snapshot: snapshot, now: entry.date).hasProgress {
                    AuraSunCorner(snapshot: snapshot, now: entry.date)
                        .widgetLabel { AuraSunCorner(snapshot: snapshot, now: entry.date).cornerGauge }
                } else {
                    AuraSunCorner(snapshot: snapshot, now: entry.date)
                        .widgetLabel(AuraSunCorner(snapshot: snapshot, now: entry.date).cornerLabel)
                }
            default: AuraSunCircular(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Wind

/// Wind speed + direction as a circular gauge.
struct AuraWindComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraWind", provider: AuraComplicationProvider()) { entry in
            AuraWindView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Viento")
        .description("Velocidad y dirección del viento.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct AuraWindView: View {
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            AuraWindCircular(snapshot: snapshot)
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Next hours (rectangular)

/// The next few hours as a wide card for the Modular centre slot.
struct AuraHoursComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraHours", provider: AuraComplicationProvider()) { entry in
            Group {
                if let snapshot = entry.snapshot {
                    AuraRectHours(snapshot: snapshot)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Próximas horas")
        .description("La previsión de las próximas horas.")
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Next days (rectangular)

/// The next few days as a wide card for the Modular centre slot.
struct AuraDaysComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraDays", provider: AuraComplicationProvider()) { entry in
            Group {
                if let snapshot = entry.snapshot {
                    AuraRectDays(snapshot: snapshot)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Próximos días")
        .description("La previsión de los próximos días.")
        .supportedFamilies([.accessoryRectangular])
    }
}
