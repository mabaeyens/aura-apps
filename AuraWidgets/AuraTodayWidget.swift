import AuraKit
import SwiftUI
import WidgetKit

/// One timeline entry: the moment it represents and the snapshot to draw (nil before the app has
/// cached anything).
struct AuraEntry: TimelineEntry {
    let date: Date
    let snapshot: WeatherSnapshot?
}

/// Reads the shared cache the app fills. The widget never calls AEMET; it just re-renders whatever
/// the app last stored, and asks WidgetKit to refresh a few times a day.
struct AuraProvider: TimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        AuraEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (AuraEntry) -> Void) {
        let snapshot = context.isPreview ? .preview : SharedCache.read().first
        completion(AuraEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AuraEntry>) -> Void) {
        let entry = AuraEntry(date: Date(), snapshot: SharedCache.read().first)
        // The app is the real fetch hub; nudge WidgetKit to re-read the cache periodically.
        let next = Calendar.current.date(byAdding: .hour, value: 3, to: entry.date) ?? entry.date.addingTimeInterval(3 * 3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

/// Aura's all-in-one location card, in the three home-screen sizes. Configuration (choosing the
/// location and metric) arrives in Slice D; the live observed temperature and hourly strip land in
/// the following slice.
struct AuraTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraTodayWidget", provider: AuraProvider()) { entry in
            AuraTodayEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("El tiempo")
        .description("La predicción de hoy para tu ubicación.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Picks the size-appropriate layout, or an invitation to open the app when nothing is cached yet.
struct AuraTodayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemLarge: AuraCardLarge(snapshot: snapshot)
            case .systemMedium: AuraCardMedium(snapshot: snapshot)
            default: AuraCardSmall(snapshot: snapshot)
            }
        } else {
            AuraCardEmpty()
        }
    }
}
