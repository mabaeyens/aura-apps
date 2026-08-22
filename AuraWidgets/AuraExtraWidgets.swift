import AppIntents
import AuraKit
import SwiftUI
import WidgetKit

// Two widgets beyond the original Lock Screen glances, both reading the same `AuraProvider` cache and
// configurable to a saved location:
//   • Sol y Luna — the next sun/moon event, for the Lock Screen date/inline slot and the circular face.
//   • Aura (Home Screen) — the full glance in the three Home Screen sizes, over the live AuraSky.

// MARK: - Sol y Luna

/// The next relevant sun/moon event — amanecer, ocaso, or (after dark) the moon with the coming
/// amanecer — as a time and a glyph. `.accessoryInline` is the piece that sits in the Lock Screen
/// date/top slot; `.accessoryCircular` is the ring face.
struct AuraSunMoonWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraSunMoonWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
            AuraSunMoonEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sol y Luna")
        .description("El próximo amanecer, ocaso o salida de la luna.")
        .supportedFamilies([.accessoryInline, .accessoryCircular])
    }
}

/// Picks the inline or circular layout, or the empty state before anything is cached.
struct AuraSunMoonEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline: AuraSunMoonInline(snapshot: snapshot, now: entry.date)
            default:               AuraSunMoonCircular(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Home Screen

/// Aura's Home Screen widget in small, medium and large — location, current conditions, the hourly
/// strip, a multi-day outlook and sun/UV, over the live sky. Rich enough to replace AEMET's own widget.
struct AuraHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraHomeWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
            AuraHomeEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        AuraSky(snapshot: entry.snapshot, now: entry.date)
                        // A gentle top-and-bottom scrim so the white text keeps its contrast over a pale
                        // noon sky without hiding the scene.
                        LinearGradient(colors: [.black.opacity(0.22), .clear, .black.opacity(0.38)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
        }
        .configurationDisplayName("Aura")
        .description("El tiempo de tu ubicación en la pantalla de inicio.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Picks the Home Screen layout by size, or the empty state before anything is cached.
struct AuraHomeEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall: AuraHomeSmall(snapshot: snapshot, now: entry.date)
            case .systemLarge: AuraHomeLarge(snapshot: snapshot, now: entry.date)
            default:           AuraHomeMedium(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraHomeEmpty()
        }
    }
}
