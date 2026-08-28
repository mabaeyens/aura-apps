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
                .widgetURL(entry.deepLink)
        }
        .configurationDisplayName(auraString("card.sunmoon.title"))
        .description(auraString("widget.sunmoon.desc"))
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
                if let snapshot = entry.snapshot?.resolved(at: entry.date) {
                    AuraSummaryInline(snapshot: snapshot, now: entry.date)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(entry.deepLink)
        }
        .configurationDisplayName(auraString("widget.summary.name"))
        .description(auraString("widget.summary.desc"))
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
                if let snapshot = entry.snapshot?.resolved(at: entry.date) {
                    AuraHumidityCircular(snapshot: snapshot)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(entry.deepLink)
        }
        .configurationDisplayName(auraString("widget.humidity.name"))
        .description(auraString("widget.humidity.desc"))
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
                .widgetURL(entry.deepLink)
        }
        .configurationDisplayName(auraString("aviso.label"))
        .description(auraString("widget.aviso.desc"))
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
            case .accessoryInline: AuraAvisoInline(snapshot: snapshot, now: entry.date)
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
                               intent: SelectHomeIntent.self,
                               provider: AuraHomeProvider()) { entry in
            AuraHomeEntryView(entry: entry)
                .containerBackground(for: .widget) { AuraHomeBackground(entry: entry) }
                .widgetURL(entry.deepLink)
        }
        .configurationDisplayName("Aura")
        .description(auraString("widget.home.desc"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

/// The Home Screen widget's background: the wide per-condition hero behind the live sun/moon, with a
/// gentle top-and-bottom scrim for text contrast. The hero is pre-sized to this family's display size
/// (`WidgetHero`) so a screen full of Aura widgets stays within WidgetKit's memory budget;
/// `heroCarriesCondition: true` because the condition (and time) are baked into the art, so AuraSky
/// draws only the live sun/moon on top. No hero for this sky → AuraSky's procedural sky.
struct AuraHomeBackground: View {
    let entry: AuraEntry

    var body: some View {
        // Re-anchor to the timeline entry's clock so the backdrop's condition (and the per-condition hero
        // art it picks) tracks the *displayed* hour, matching the resolved foreground in `AuraHomeEntryView`
        // rather than the frozen fetch-hour sky. See `WeatherSnapshot.resolved(at:)`.
        let snapshot = entry.snapshot?.resolved(at: entry.date)
        ZStack {
            AuraSky(snapshot: snapshot, now: entry.date,
                    heroImage: WidgetHero.base(for: snapshot, now: entry.date,
                                               scene: entry.scene),
                    heroCarriesCondition: true,
                    // Anchor the wide hero to the ground: on the short, wide Home families a centre crop
                    // shows mostly sky, so pin the bottom to keep the horizon and landscape in frame.
                    heroAnchor: .bottom,
                    // Pin a low dawn/dusk sun just above the art's ridge so it sits *behind* the scenery,
                    // not as a ball in front of the mountains. Mapped through the .bottom crop per family.
                    heroHorizon: HeroBackground.wideBaseHorizon(entry.scene),
                    heroAspect: HeroBackground.wideBaseAspect,
                    compact: true)
            LinearGradient(colors: [.black.opacity(0.22), .clear, .black.opacity(0.38)],
                           startPoint: .top, endPoint: .bottom)
        }
    }
}

/// Picks the Home Screen layout by size, or the empty state before anything is cached.
struct AuraHomeEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot?.resolved(at: entry.date) {
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
