import AppIntents
import AuraKit
import SwiftUI
import WidgetKit

/// One timeline entry: the moment it represents and the snapshot to draw (nil before the app has
/// cached anything).
struct AuraEntry: TimelineEntry {
    let date: Date
    let snapshot: WeatherSnapshot?
}

/// Reads the shared cache the app fills, for the location the widget is configured to show. The
/// widget never calls AEMET; it just re-renders whatever the app last stored, and asks WidgetKit to
/// refresh a few times a day.
struct AuraProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        AuraEntry(date: Date(), snapshot: .preview)
    }

    func snapshot(for configuration: SelectLocationIntent, in context: Context) async -> AuraEntry {
        AuraEntry(date: Date(), snapshot: resolve(configuration, isPreview: context.isPreview))
    }

    func timeline(for configuration: SelectLocationIntent, in context: Context) async -> Timeline<AuraEntry> {
        let entry = AuraEntry(date: Date(), snapshot: resolve(configuration, isPreview: false))
        // The app is the real fetch hub; nudge WidgetKit to re-read the cache periodically.
        let next = Calendar.current.date(byAdding: .hour, value: 3, to: entry.date) ?? entry.date.addingTimeInterval(3 * 3600)
        return Timeline(entries: [entry], policy: .after(next))
    }

    /// The configured location's cached snapshot, falling back to the first cached location so a
    /// freshly added widget shows something before it's configured.
    private func resolve(_ configuration: SelectLocationIntent, isPreview: Bool) -> WeatherSnapshot? {
        if isPreview { return .preview }
        if let ine = configuration.location?.id, let snapshot = SharedCache.snapshot(forINE: ine) {
            return snapshot
        }
        return SharedCache.read().first
    }
}

/// Aura's all-in-one location card, on the home screen (small / medium / large) and the Lock Screen
/// (circular / rectangular / inline). Each instance is configurable to a specific saved location.
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
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryCircular, .accessoryRectangular, .accessoryInline,
        ])
    }
}

/// Picks the family-appropriate layout, or an invitation to open the app when nothing is cached yet.
struct AuraTodayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemLarge: AuraCardLarge(snapshot: snapshot)
            case .systemMedium: AuraCardMedium(snapshot: snapshot)
            case .accessoryCircular: AuraAccessoryCircular(snapshot: snapshot)
            case .accessoryRectangular: AuraAccessoryRectangular(snapshot: snapshot)
            case .accessoryInline: AuraAccessoryInline(snapshot: snapshot)
            default: AuraCardSmall(snapshot: snapshot)
            }
        } else if isAccessory {
            AuraAccessoryEmpty()
        } else {
            AuraCardEmpty()
        }
    }

    private var isAccessory: Bool {
        switch family {
        case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
        default: return false
        }
    }
}
