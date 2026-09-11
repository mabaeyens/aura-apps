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

    /// The deep link the widget carries so a tap opens the app to the location it shows, not the app's
    /// own active one (see `AuraApp.onOpenURL`). Nil before anything is cached, so the tap just launches
    /// the app rather than routing to nowhere.
    var deepLink: URL? { snapshot.flatMap { URL(string: "aura://location/\($0.ine)") } }
}

/// The configured location's cached snapshot, falling back to the first cached location so a freshly
/// added widget shows something before it's configured. Shared by both providers.
private func resolveSnapshot(ine: String?, isPreview: Bool) -> WeatherSnapshot? {
    if isPreview { return .preview }
    // Pinned location if it still has data, else the app's active one, else the first cache entry — so an
    // unconfigured widget tracks whatever the app is showing rather than an arbitrary favourite.
    return SharedCache.resolve(preferredINE: ine)
}

/// The interval WidgetKit is nudged to re-read the cache over. The app is still the main fetch hub; the
/// widget only tops up its own device's cache when the app hasn't run recently (see `refreshIfStale`).
/// Matches `AuraRefreshCore.staleWindow` (the hour AEMET's own data actually turns over): asking for a
/// reload every 3 hours — as this used to — meant that even on a lucky cycle where the system granted the
/// reload, the widget could still be sitting on data up to 3 hours stale by design, on top of whatever the
/// system's own budget already withholds. Asking hourly doesn't cost extra network calls (`refreshIfStale`
/// still gates on the same one-hour staleness check) — it just gives the system a nearer date to grant
/// against. This is now on top of `timelineEntries`' own hour-by-hour coverage below, not the only thing
/// standing between the widget and a frozen night: it's still worth asking for, since only an actual
/// reload can bring genuinely new data (a changed forecast, a new aviso), which no amount of synthesizing
/// from an already-fetched strip can produce.
private func nextRefresh(after date: Date) -> Date {
    Calendar.current.date(byAdding: .hour, value: 1, to: date) ?? date.addingTimeInterval(3600)
}

/// One entry per upcoming hour already in the snapshot's own forecast, instead of a single entry frozen
/// at `now`. A single-entry timeline is fully dependent on the next background wake actually happening —
/// confirmed on-device to sometimes just not, since it's an opaque per-app budget outside this app's
/// control — so between wakes the widget showed exactly the same pixels all night regardless of how much
/// time had actually passed. `WeatherSnapshot.resolved(at:)` already re-derives every displayed field
/// (temp, sky, precip…) for an arbitrary instant from the same hourly strip fetched once, so handing
/// WidgetKit one entry per hour that strip covers lets it step through the correct value on its own
/// clock, with no further process wake needed until the strip runs out. Capped well under WidgetKit's
/// practical per-widget budget; AEMET's hourly product rarely carries more than ~48h anyway. Falls back
/// to a single `now`-stamped entry when there's nothing cached yet, or the strip is exhausted.
private func timelineEntries(snapshot: WeatherSnapshot?, now: Date,
                             scene: HeroBackground.Family = .landscape) -> [AuraEntry] {
    guard let snapshot else { return [AuraEntry(date: now, snapshot: nil, scene: scene)] }
    let dates = snapshot.upcomingHourDates(now: now).prefix(48)
    guard !dates.isEmpty else { return [AuraEntry(date: now, snapshot: snapshot, scene: scene)] }
    return dates.map { AuraEntry(date: $0, snapshot: snapshot, scene: scene) }
}

/// Before rendering a timeline, refresh the shown location if the shared staleness gate says its cache is
/// stale — so a Lock Screen glance stays current even when the app hasn't been opened in hours. Scoped to
/// that one location (`onlyINE`) so a reload costs at most one place's fetch; gated by
/// `AuraRefreshCore.isStale`, the exact rule the app uses, so a fresh cache is reused with no network. The
/// whole favourites list is passed so pruning keeps every place — only the shown one is refetched. The
/// result lands in the App Group cache, so the app and every widget on this device see it (never other
/// devices — the cache is device-local). Skipped in previews; a no-op when there is no stored key.
private func refreshIfStale(preferredINE: String?, isPreview: Bool) async {
    guard !isPreview else { return }
    let favorites = SharedLocations.read()
    guard let targetINE = preferredINE ?? SharedCache.activeINE ?? favorites.first?.ine,
          favorites.contains(where: { $0.ine == targetINE }),
          AuraRefreshCore.isStale(SharedCache.snapshot(forINE: targetINE)) else { return }
    _ = await AuraRefreshCore.refresh(locations: favorites, onlyINE: targetINE)
}

/// Reads the shared cache the app fills, for the location the widget is configured to show, topping it up
/// first when the shared gate says it is stale (`refreshIfStale`). Drives the Lock Screen glances.
struct AuraProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> AuraEntry {
        AuraEntry(date: Date(), snapshot: .preview)
    }

    func snapshot(for configuration: SelectLocationIntent, in context: Context) async -> AuraEntry {
        AuraEntry(date: Date(), snapshot: resolveSnapshot(ine: configuration.location?.id, isPreview: context.isPreview))
    }

    func timeline(for configuration: SelectLocationIntent, in context: Context) async -> Timeline<AuraEntry> {
        await refreshIfStale(preferredINE: configuration.location?.id, isPreview: context.isPreview)
        let now = Date()
        let snapshot = resolveSnapshot(ine: configuration.location?.id, isPreview: false)
        return Timeline(entries: timelineEntries(snapshot: snapshot, now: now),
                        policy: .after(nextRefresh(after: now)))
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
        await refreshIfStale(preferredINE: configuration.location?.id, isPreview: context.isPreview)
        let now = Date()
        let snapshot = resolveSnapshot(ine: configuration.location?.id, isPreview: false)
        return Timeline(entries: timelineEntries(snapshot: snapshot, now: now, scene: configuration.scene.family),
                        policy: .after(nextRefresh(after: now)))
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
                .widgetURL(entry.deepLink)
        }
        .configurationDisplayName(auraString("widget.today.name"))
        .description(auraString("widget.today.desc"))
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
                if let snapshot = entry.snapshot?.resolved(at: entry.date) {
                    AuraRainCircular(snapshot: snapshot)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(entry.deepLink)
        }
        .configurationDisplayName(auraString("widget.rain.name"))
        .description(auraString("widget.rain.desc"))
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
                if let snapshot = entry.snapshot?.resolved(at: entry.date) {
                    AuraUVCircular(snapshot: snapshot, now: entry.date)
                } else {
                    AuraAccessoryEmpty()
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(entry.deepLink)
        }
        .configurationDisplayName(auraString("widget.uv.name"))
        .description(auraString("widget.uv.desc"))
        .supportedFamilies([.accessoryCircular])
    }
}

/// Picks the Lock Screen layout, or an invitation to open the app when nothing is cached yet.
struct AuraTodayEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AuraEntry

    var body: some View {
        if let snapshot = entry.snapshot?.resolved(at: entry.date) {
            switch family {
            case .accessoryCircular: AuraAccessoryCircular(snapshot: snapshot, now: entry.date)
            case .accessoryRectangular: AuraAccessoryRectangular(snapshot: snapshot, now: entry.date)
            default: AuraAccessoryInline(snapshot: snapshot)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}
