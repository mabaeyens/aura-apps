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
    /// The location the complication draws, resolved in the **same order** as `WatchRootView` so the
    /// complication and the Watch app never disagree: the wrist's own forced pick first, then the phone's
    /// active place (mirrored into the Watch's shared defaults by `WatchSync`), then the first cached
    /// snapshot before the first sync. Reading the forced pick straight from the App Group is what fixes
    /// the complication tracking a different, stale location than the app after a wrist location switch.
    private func activeSnapshot() -> WeatherSnapshot? {
        let all = SharedCache.read()
        if let sel = SharedCache.watchSelectedINE, !sel.isEmpty,
           let s = all.first(where: { $0.ine == sel }) { return s }
        if let active = SharedCache.activeINE,
           let s = all.first(where: { $0.ine == active }) { return s }
        return all.first
    }

    func placeholder(in context: Context) -> AuraComplicationEntry {
        AuraComplicationEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (AuraComplicationEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : activeSnapshot()
        completion(AuraComplicationEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AuraComplicationEntry>) -> Void) {
        let snapshot = activeSnapshot()
        let now = Date()
        let cal = Calendar.current
        // Hourly entries for the next 12 hours, all off the same snapshot: each redraws with its own
        // `date` as "now", so the time-sensitive faces — UV-now, the sun countdown — track the hour
        // without waiting on the next iPhone sync. WidgetKit refreshes the whole set after the window.
        let entries = (0..<12).map { h -> AuraComplicationEntry in
            let d = cal.date(byAdding: .hour, value: h, to: now) ?? now.addingTimeInterval(Double(h) * 3600)
            return AuraComplicationEntry(date: d, snapshot: snapshot)
        }
        let next = cal.date(byAdding: .hour, value: 12, to: now) ?? now.addingTimeInterval(12 * 3600)
        completion(Timeline(entries: entries, policy: .after(next)))
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
        .configurationDisplayName(auraString("watch.complication.conditions.name"))
        .description(auraString("watch.complication.conditions.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryInline, .accessoryCorner])
    }
}

struct AuraConditionsView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot?.resolved(at: entry.date) {
            switch family {
            case .accessoryInline: AuraAccessoryInline(snapshot: snapshot)
            case .accessoryCorner:
                // `.widgetCurvesContent()` (watchOS 10+) curves the corner's main content along the
                // screen edge — the documented fix for corner content that otherwise stays horizontal
                // and cramped. The range arcs along the outer bezel via `.widgetLabel`.
                let corner = AuraAccessoryCorner(snapshot: snapshot, now: entry.date)
                if corner.hasRange {
                    corner
                        .widgetCurvesContent()
                        .widgetLabel { corner.cornerGauge }
                } else {
                    corner
                        .widgetCurvesContent()
                        .widgetLabel(corner.cornerLabel)
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
        .configurationDisplayName(auraString("watch.complication.sun.name"))
        .description(auraString("watch.complication.sun.desc"))
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
                let corner = AuraSunCorner(snapshot: snapshot, now: entry.date)
                corner.widgetLabel(corner.cornerLabel)
            default:
                // The circular face shows only the icon + time so it fits; the time-until rides the
                // curved bezel via `.widgetLabel` (was a third stacked line that overflowed).
                let circular = AuraSunCircular(snapshot: snapshot, now: entry.date)
                if let remaining = circular.remainingLabel {
                    circular.widgetLabel(remaining)
                } else {
                    circular
                }
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Wind

/// Wind speed + direction — a two-tone compass needle over a rose (circular), or the speed + direction
/// with a strength gauge curving the bezel (corner).
struct AuraWindNeedleComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraWindNeedle", provider: AuraComplicationProvider()) { entry in
            AuraWindView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("card.wind.title"))
        .description(auraString("watch.complication.wind.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct AuraWindView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot?.resolved(at: entry.date) {
            switch family {
            case .accessoryCorner:
                let corner = AuraWindCorner(snapshot: snapshot)
                if corner.hasValue {
                    corner.widgetCurvesContent().widgetLabel { corner.cornerGauge }
                } else {
                    corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
                }
            default:
                AuraWindCircular(snapshot: snapshot)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Rain chance

/// Precipitation probability for the current hour — a ring fill with a raindrop and the percentage
/// (circular), or the drop + percentage with a 0…100 % gauge curving the bezel (corner).
struct AuraRainComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraRain", provider: AuraComplicationProvider()) { entry in
            AuraRainView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("watch.complication.rain.name"))
        .description(auraString("watch.complication.rain.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct AuraRainView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot?.resolved(at: entry.date) {
            switch family {
            case .accessoryCorner:
                let corner = AuraRainCorner(snapshot: snapshot)
                if corner.hasValue {
                    corner.widgetCurvesContent().widgetLabel { corner.cornerGauge }
                } else {
                    corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
                }
            default:
                AuraRainCircular(snapshot: snapshot)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - UV index

/// The current UV index — a ring fill from 0 to today's peak with a sun, the live index number, and the
/// band name on the bezel. Grades along the WHO colour scale; falls back to the daily max off the hourly.
struct AuraUVComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraUV", provider: AuraComplicationProvider()) { entry in
            AuraUVView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("watch.complication.uv.name"))
        .description(auraString("watch.complication.uv.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct AuraUVView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot?.resolved(at: entry.date) {
            switch family {
            case .accessoryCorner:
                // The index + glyph curve the corner; the 0…peak graded arc rides the outer bezel.
                let corner = AuraUVCorner(snapshot: snapshot, now: entry.date)
                if corner.hasValue {
                    corner.widgetCurvesContent().widgetLabel { corner.cornerGauge }
                } else {
                    corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
                }
            default:
                // The band name ("Muy alto"…) of the current reading rides the curved bezel.
                let circular = AuraUVCircular(snapshot: snapshot, now: entry.date)
                if let band = circular.bandLabel {
                    circular.widgetLabel(band)
                } else {
                    circular
                }
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Máx / Mín del día

/// Today's high and low — each in its own temperature colour (circular), or the high in the corner with
/// the low on the bezel (corner). Temperature is unbounded, so the corner uses plain text, not a gauge.
struct AuraMinMaxComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraMinMax", provider: AuraComplicationProvider()) { entry in
            AuraMinMaxView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("watch.complication.minmax.name"))
        .description(auraString("watch.complication.minmax.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner])
    }
}

struct AuraMinMaxView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCorner:
                let corner = AuraMinMaxCorner(snapshot: snapshot)
                corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
            default:
                AuraMinMaxCircular(snapshot: snapshot)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Calidad del aire (ICA)

/// The MITECO air-quality index (ICA 1…6) — a ring fill in the official ICA colour with the category and
/// the aqi glyph (circular), or the glyph + category with a 1…6 gauge curving the bezel (corner). ICA is a
/// bounded scale, so the corner takes the bezel gauge. Empty when no station is near.
struct AuraAirQualityComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraAirQuality", provider: AuraComplicationProvider()) { entry in
            AuraAirQualityView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("card.aqi.title"))
        .description(auraString("watch.complication.aqi.desc"))
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryInline, .accessoryRectangular])
    }
}

struct AuraAirQualityView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline:      AuraAirQualityInline(snapshot: snapshot)
            case .accessoryRectangular: AuraAirQualityRectangular(snapshot: snapshot)
            case .accessoryCorner:
                let corner = AuraAirQualityCorner(snapshot: snapshot)
                if corner.hasValue {
                    corner.widgetCurvesContent().widgetLabel { corner.cornerGauge }
                } else {
                    corner.widgetCurvesContent().widgetLabel(corner.cornerLabel)
                }
            default:
                AuraAirQualityCircular(snapshot: snapshot)
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
        .configurationDisplayName(auraString("card.hourly.title"))
        .description(auraString("watch.complication.hours.desc"))
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
        .configurationDisplayName(auraString("card.daily.title"))
        .description(auraString("watch.complication.days.desc"))
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Now (rectangular)

/// The current conditions as a wide card — condition + temperature + today's range and rain/humidity —
/// for the Modular centre slot. Reuses the same `AuraAccessoryRectangular` the iPhone Lock Screen uses.
struct AuraNowComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraNow", provider: AuraComplicationProvider()) { entry in
            Group {
                if let snapshot = entry.snapshot?.resolved(at: entry.date) {
                    AuraAccessoryRectangular(snapshot: snapshot, now: entry.date)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("watch.complication.now.name"))
        .description(auraString("watch.complication.now.desc"))
        .supportedFamilies([.accessoryRectangular])
    }
}

// MARK: - Sun (rectangular)

/// The day's sun as a wide card — a daylight-remaining readout, a warm progress bar, and orto/ocaso at
/// the ends — for the Modular centre slot.
struct AuraSunRectComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraSunRect", provider: AuraComplicationProvider()) { entry in
            Group {
                if let snapshot = entry.snapshot {
                    AuraRectSun(snapshot: snapshot, now: entry.date)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(auraString("watch.complication.sunrect.name"))
        .description(auraString("watch.complication.sunrect.desc"))
        .supportedFamilies([.accessoryRectangular])
    }
}
