import AppIntents
import AuraKit
import SwiftUI
import WidgetKit

// Widgets beyond the original Lock Screen glances, all reading the same `AuraProvider` cache and
// configurable to a saved location:
//   • Sol y Luna — the next sun/moon event, for the Lock Screen date/inline slot and the circular face.
//   • Resumen — a one-line weather summary (temp · lluvia · humedad) for the Lock Screen inline slot.
//   • Humedad — the current humidity as a circular Lock Screen face.
//   • Aviso — a severe-weather warning mark, circular and inline, shown only when one is active.
//   • Aura (Home Screen) — the full glance in small/medium/large plus the iPad extra-large, over the
//     live AuraSky with the sunless hero art behind it.

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

// MARK: - Lock Screen summary / humidity / aviso

/// Aura's Lock Screen weather summary — one line of `temp · lluvia · humedad` for the inline
/// date/top slot, an alternative to Sol y Luna for that same slot.
struct AuraSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraSummaryWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
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

/// Aura's Lock Screen humidity glance — the current relative humidity as a circular face.
struct AuraHumidityWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraHumidityWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
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

/// Aura's Lock Screen warning mark — a severe-weather aviso as a circular face or an inline label.
/// Shows the empty state when no warning is active for the location.
struct AuraAvisoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraAvisoWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
            AuraAvisoEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Aviso")
        .description("El aviso meteorológico activo, si lo hay.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

/// Picks the circular or inline aviso mark, or the empty state before anything is cached.
struct AuraAvisoEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .accessoryInline: AuraAvisoInline(snapshot: snapshot)
            default:               AuraAvisoCircular(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Home Screen

/// Aura's Home Screen widget in small, medium, large and the iPad extra-large — location, current
/// conditions, the hourly strip, a multi-day outlook and sun/UV, over the live sky with the sunless
/// hero art behind it. Rich enough to replace AEMET's own widget.
struct AuraHomeWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AuraHomeWidget",
                               intent: SelectLocationIntent.self,
                               provider: AuraProvider()) { entry in
            AuraHomeEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        // The sunless hero art (village silhouette etc.) if the matching asset ships,
                        // with AuraSky drawing the live sun/moon and cloud veil over it; the procedural
                        // sky fills in when there's no art for this sky+time.
                        AuraSky(snapshot: entry.snapshot, now: entry.date,
                                heroImage: HeroBackground.heroImage(for: entry.snapshot, now: entry.date,
                                                                    exists: { UIImage(named: $0) != nil }))
                        // A gentle top-and-bottom scrim so the white text keeps its contrast over a pale
                        // noon sky without hiding the scene.
                        LinearGradient(colors: [.black.opacity(0.22), .clear, .black.opacity(0.38)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
        }
        .configurationDisplayName("Aura")
        .description("El tiempo de tu ubicación en la pantalla de inicio.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

/// Picks the Home Screen layout by size, or the empty state before anything is cached.
struct AuraHomeEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemSmall:      AuraHomeSmall(snapshot: snapshot, now: entry.date)
            case .systemLarge:      AuraHomeLarge(snapshot: snapshot, now: entry.date)
            case .systemExtraLarge: AuraHomeXL(snapshot: snapshot, now: entry.date)
            default:                AuraHomeMedium(snapshot: snapshot, now: entry.date)
            }
        } else {
            AuraHomeEmpty()
        }
    }
}
