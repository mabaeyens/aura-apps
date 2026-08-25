import AppIntents
import AuraKit
import SwiftUI
import WidgetKit

/// One timeline entry: the moment it represents, the snapshot to draw (nil before the app has cached
/// anything), and — for the Home Screen widget — which background scene family to draw.
struct AuraEntry: TimelineEntry {
    let date: Date
    let snapshot: WeatherSnapshot?
    var scene: HeroBackground.Family = .landscape
}

/// The configured location's cached snapshot, falling back to the first cached location so a freshly
/// added widget shows something before it's configured. Shared by both providers.
private func resolveSnapshot(ine: String?, isPreview: Bool) -> WeatherSnapshot? {
    if isPreview { return .preview }
    // Pinned location if it still has data, else the app's active one, else the first cache entry — so an
    // unconfigured widget tracks whatever the app is showing rather than an arbitrary favourite.
    return SharedCache.resolve(preferredINE: ine)
}

/// The interval WidgetKit is nudged to re-read the cache over — the app is the real fetch hub.
private func nextRefresh(after date: Date) -> Date {
    Calendar.current.date(byAdding: .hour, value: 3, to: date) ?? date.addingTimeInterval(3 * 3600)
}

/// Reads the shared cache the app fills, for the location the widget is configured to show. The
/// widget never calls AEMET; it just re-renders whatever the app last stored, and asks WidgetKit to
/// refresh a few times a day. Drives the Lock Screen glances.
struct AuraProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        AuraEntry(date: Date(), snapshot: .preview)
    }

    func snapshot(for configuration: SelectLocationIntent, in context: Context) async -> AuraEntry {
        AuraEntry(date: Date(), snapshot: resolveSnapshot(ine: configuration.location?.id, isPreview: context.isPreview))
    }

    func timeline(for configuration: SelectLocationIntent, in context: Context) async -> Timeline<AuraEntry> {
        let entry = AuraEntry(date: Date(), snapshot: resolveSnapshot(ine: configuration.location?.id, isPreview: false))
        return Timeline(entries: [entry], policy: .after(nextRefresh(after: entry.date)))
    }
}

/// The Home Screen widget's provider: same cache read as `AuraProvider`, plus the chosen background
/// scene carried on the entry so the wide base art matches the user's Naturaleza/Ciudad pick.
struct AuraHomeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        AuraEntry(date: Date(), snapshot: .preview)
    }

    func snapshot(for configuration: SelectHomeIntent, in context: Context) async -> AuraEntry {
        AuraEntry(date: Date(),
                  snapshot: resolveSnapshot(ine: configuration.location?.id, isPreview: context.isPreview),
                  scene: configuration.scene.family)
    }

    func timeline(for configuration: SelectHomeIntent, in context: Context) async -> Timeline<AuraEntry> {
        let entry = AuraEntry(date: Date(),
                              snapshot: resolveSnapshot(ine: configuration.location?.id, isPreview: false),
                              scene: configuration.scene.family)
        return Timeline(entries: [entry], policy: .after(nextRefresh(after: entry.date)))
    }
}

/// Aura's Lock Screen glance — circular, rectangular and inline. Aura is a Lock Screen and
/// complication product: the Home Screen is left to AEMET's own app, whose widgets cover it well.
/// Each instance is configurable to a specific saved location.
struct AuraTodayWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraTodayWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
            AuraTodayEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("El tiempo")
        .description("La predicción de hoy para tu ubicación.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// Aura's Lock Screen rain glance — the current hour's precipitation probability as a ring.
/// Circular only; configurable to a saved location like the main widget.
struct AuraRainWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraRainWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
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

/// Aura's Lock Screen UV glance — the current UV index as a 0…peak ring. Circular only.
struct AuraUVWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraUVWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
            Group {
                if let snapshot = entry.snapshot {
                    AuraUVCircular(snapshot: snapshot, now: entry.date)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("UV ahora")
        .description("El índice UV de la hora, sobre el máximo del día.")
        .supportedFamilies([.accessoryCircular])
    }
}

/// Picks the Lock Screen layout, or an invitation to open the app when nothing is cached yet.
struct AuraTodayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryCircular: AuraAccessoryCircular(snapshot: snapshot)
            case .accessoryRectangular: AuraAccessoryRectangular(snapshot: snapshot)
            default: AuraAccessoryInline(snapshot: snapshot)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}
