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
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

struct AuraConditionsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline: AuraAccessoryInline(snapshot: snapshot)
            case .accessoryCorner:
                // `.widgetCurvesContent()` (watchOS 10+) curves the corner's main content along the
                // screen edge — the documented fix for corner content that otherwise stays horizontal
                // and cramped. The range arcs along the outer bezel via `.widgetLabel`.
                if AuraAccessoryCorner(snapshot: snapshot, now: entry.date).hasRange {
                    AuraAccessoryCorner(snapshot: snapshot, now: entry.date)
                        .widgetCurvesContent()
                        .widgetLabel { AuraAccessoryCorner(snapshot: snapshot, now: entry.date).cornerGauge }
                } else {
                    AuraAccessoryCorner(snapshot: snapshot, now: entry.date)
                        .widgetCurvesContent()
                        .widgetLabel(AuraAccessoryCorner(snapshot: snapshot, now: entry.date).cornerLabel)
                }
            default: AuraAccessoryCircular(snapshot: snapshot, now: entry.date)
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
                AuraSunCorner(snapshot: snapshot, now: entry.date)
                    .widgetLabel(AuraSunCorner(snapshot: snapshot, now: entry.date).cornerLabel)
            default:
                // The circular face shows only the icon + time so it fits; the time-until rides the
                // curved bezel via `.widgetLabel` (was a third stacked line that overflowed).
                if let remaining = AuraSunCircular(snapshot: snapshot, now: entry.date).remainingLabel {
                    AuraSunCircular(snapshot: snapshot, now: entry.date)
                        .widgetLabel(remaining)
                } else {
                    AuraSunCircular(snapshot: snapshot, now: entry.date)
                }
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Wind

/// Wind speed + direction — a two-tone compass needle over a rose.
struct AuraWindNeedleComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraWindNeedle", provider: AuraComplicationProvider()) { entry in
            AuraWindView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Viento")
        .description("Velocidad y dirección del viento, con una aguja.")
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

// MARK: - Rain chance

/// Precipitation probability for the current hour — a ring fill with a raindrop and the percentage.
struct AuraRainComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraRain", provider: AuraComplicationProvider()) { entry in
            Group {
                if let snapshot = entry.snapshot {
                    AuraRainCircular(snapshot: snapshot)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Lluvia")
        .description("La probabilidad de precipitación de la hora actual.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - UV index

/// The day's maximum UV index — a ring fill with a sun and the index number, plus the band on the bezel.
struct AuraUVComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraUV", provider: AuraComplicationProvider()) { entry in
            AuraUVView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("UV máximo")
        .description("El índice UV máximo del día (cielo despejado).")
        .supportedFamilies([.accessoryCircular])
    }
}

struct AuraUVView: View {
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            // The band name ("Muy alto"…) rides the curved bezel, keeping the ring honest that the
            // number is a daily maximum rather than a live value.
            if let band = AuraUVCircular(snapshot: snapshot).bandLabel {
                AuraUVCircular(snapshot: snapshot)
                    .widgetLabel(band)
            } else {
                AuraUVCircular(snapshot: snapshot)
            }
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
