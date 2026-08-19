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

/// Aura's first widget: today's forecast for the first cached location. Configuration (choosing the
/// location and metric) arrives in Slice D.
struct AuraTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AuraTodayWidget", provider: AuraProvider()) { entry in
            AuraTodayEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("El tiempo")
        .description("La predicción de hoy para tu ubicación.")
        .supportedFamilies([.systemSmall])
    }
}

struct AuraTodayEntryView: View {
    let entry: AuraEntry

    var body: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading, spacing: 2) {
                Text(s.localidad)
                    .font(.caption).fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text(Self.temp(s.tempMax))
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.7)
                Text("Mín \(Self.temp(s.tempMin))")
                    .font(.caption).foregroundStyle(.secondary)

                if let sunset = s.sunset {
                    Label("Ocaso \(Self.time(sunset))", systemImage: "sunset.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "cloud.sun")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Abre Aura para cargar la predicción.")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private static func temp(_ value: Int?) -> String {
        value.map { "\($0)°" } ?? "—"
    }

    private static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}

private extension WeatherSnapshot {
    /// Sample data for previews and the placeholder.
    static let preview = WeatherSnapshot(
        ine: "28079", localidad: "Madrid", provincia: "Madrid",
        tempMin: 18, tempMax: 34, humedadMax: 55,
        sunrise: nil, sunset: nil, updated: Date()
    )
}
