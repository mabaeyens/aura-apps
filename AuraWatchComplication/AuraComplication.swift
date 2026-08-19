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

/// The complication, in every watch accessory family. All layouts come from AuraKit so they match
/// the iPhone's Lock Screen widgets exactly.
struct AuraComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraComplication", provider: AuraComplicationProvider()) { entry in
            AuraComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("El tiempo")
        .description("La temperatura y los avisos de tu ubicación.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct AuraComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraComplicationEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryRectangular: AuraAccessoryRectangular(snapshot: snapshot)
            case .accessoryInline: AuraAccessoryInline(snapshot: snapshot)
            case .accessoryCorner:
                AuraAccessoryCorner(snapshot: snapshot)
                    .widgetLabel(AuraAccessoryCorner(snapshot: snapshot).cornerLabel)
            default: AuraAccessoryCircular(snapshot: snapshot)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}
