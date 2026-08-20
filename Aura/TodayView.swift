import AuraKit
import SwiftUI

/// "Hoy" — the numeric daily forecast for the selected location, plus locally computed
/// sunrise/sunset. It renders straight from the shared App Group cache: it asks the one coalesced
/// `AEMETService.refreshAllForWidgets` to fill the cache, then reads the snapshot — it never calls
/// AEMET directly, so it can't duplicate the launch refresh's requests.
struct TodayView: View {
    @EnvironmentObject private var store: LocationStore

    @State private var snapshot: WeatherSnapshot?
    @State private var isLoading = false
    @State private var errorMessage: String?
    /// Which location `snapshot` belongs to, and when it was read — so a tab re-appearance or app
    /// foreground doesn't trigger a refresh when the on-screen data is already recent.
    @State private var loadedINE: String?
    @State private var loadedAt: Date?

    /// AEMET updates municipal forecasts only a few times a day; don't refresh the same location
    /// more often than this except on an explicit pull-to-refresh.
    private static let minInterval: TimeInterval = 15 * 60

    var body: some View {
        NavigationStack {
            Group {
                if let location = store.selected {
                    content(for: location)
                } else {
                    ContentUnavailableView(
                        "Sin ubicaciones",
                        systemImage: "mappin.slash",
                        description: Text("Añade una ubicación en la pestaña Ubicaciones.")
                    )
                }
            }
            .navigationTitle(store.selected?.nombre ?? "Hoy")
            .navigationBarTitleDisplayMode(.large)
        }
        .task(id: store.selectedINE) { await load(force: false) }
    }

    @ViewBuilder
    private func content(for location: Location) -> some View {
        List {
            if !store.apiKeyPresent {
                Section {
                    Label("Añade tu clave de AEMET en Ajustes para ver los datos.",
                          systemImage: "key")
                        .foregroundStyle(.secondary)
                }
            }

            if let snapshot {
                Section {
                    CurrentConditionsHeader(snapshot: snapshot)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                if let alert = snapshot.alert {
                    Section {
                        AlertBanner(alert: alert)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
            }

            Section("Sol") {
                SunTimesRow(location: location)
            }

            if let snapshot, !snapshot.days.isEmpty {
                Section("Predicción diaria") {
                    ForEach(snapshot.days) { day in
                        DayRow(day: day)
                    }
                }
            } else if isLoading {
                Section { HStack { ProgressView(); Text("Cargando…").foregroundStyle(.secondary) } }
            } else if let errorMessage {
                Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.secondary) }
            }

            Section {
                Text("Elaborado con datos de AEMET")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .refreshable { await load(force: true) }
    }

    private func load(force: Bool) async {
        guard let location = store.selected else { return }
        // Throttle: if we already show this location's data and it's recent, don't trigger a refresh
        // just because the view re-appeared. Pull-to-refresh (force) always refreshes.
        if !force, snapshot?.ine == location.ine, loadedINE == location.ine,
           let at = loadedAt, Date().timeIntervalSince(at) < Self.minInterval {
            return
        }
        guard store.apiKeyPresent else {
            errorMessage = nil // handled by the key banner
            return
        }
        isLoading = true
        errorMessage = nil
        // The one coalesced refresh fills the shared cache (fetching every favourite once, plus a
        // single national observations call); read this location's snapshot back out of it.
        let refreshError = await AEMETService.refreshAllForWidgets(store.favorites, force: force)
        if let snap = SharedCache.snapshot(forINE: location.ine) {
            snapshot = snap
            loadedINE = location.ine
            loadedAt = Date()
            // Mirror the on-screen location to the paired Watch's complication.
            WatchSync.shared.send(snap)
            errorMessage = nil
        } else {
            // Nothing cached yet and the refresh couldn't fill it — surface why, if we know.
            errorMessage = refreshError ?? "No se pudieron obtener los datos."
        }
        isLoading = false
    }
}

/// The current conditions at a glance: condition icon, temperature-tinted hero number, sky text,
/// and today's Máx/Mín — over a soft sky-gradient card. Aura's splash of colour on the phone.
private struct CurrentConditionsHeader: View {
    let snapshot: WeatherSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: WeatherIcon.symbol(forSky: snapshot.currentSky))
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 40))
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.heroTemp.map { "\($0)°" } ?? "—")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                if let sky = snapshot.currentSkyText {
                    Text(sky).font(.subheadline).foregroundStyle(.white.opacity(0.85)).lineLimit(1)
                }
            }
            Spacer()
            // Right column: max, min and wind on one type scale, each with a leading symbol so the
            // icons line up. Max/min carry their temperature colour (the day-cycle gradient behind
            // them is dark enough to read against); wind stays white.
            VStack(alignment: .leading, spacing: 6) {
                metric("arrow.up", fmt(snapshot.tempMax), Palette.temperature(snapshot.tempMax))
                metric("arrow.down", fmt(snapshot.tempMin), Palette.temperature(snapshot.tempMin))
                if let wind = snapshot.windSpeed {
                    metric("wind",
                           "\(wind) km/h\(snapshot.windDirection.map { " " + $0.abbreviation } ?? "")",
                           .white)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity)
        // Sky gradient that tracks the time of day, not the current condition — Aura's changing splash
        // of colour on the phone. White text reads on every phase.
        .background(Palette.timeGradient(at: Date()), in: RoundedRectangle(cornerRadius: 18))
        .padding(.vertical, 4)
    }

    /// One right-column row: a fixed-width symbol so every row's icon aligns, then the value, all at
    /// the same size. `tint` colours the whole row.
    private func metric(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).frame(width: 18)
            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
    }

    private func fmt(_ value: Int?) -> String { value.map { "\($0)°" } ?? "—" }
}

/// A tinted avisos banner matching AEMET's warning level colour.
private struct AlertBanner: View {
    let alert: WeatherAlert

    var body: some View {
        Label(alert.phenomenon ?? alert.event, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Palette.alert(alert.level))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Palette.alert(alert.level).opacity(0.16),
                        in: RoundedRectangle(cornerRadius: 14))
            .padding(.vertical, 4)
    }
}

/// Sunrise/sunset for today, computed on-device and shown in the location's time zone.
private struct SunTimesRow: View {
    let location: Location

    var body: some View {
        let sun = SolarTimes(date: Date(), latitude: location.latitude, longitude: location.longitude)
        HStack {
            sunLabel("Orto", systemImage: "sunrise.fill", date: sun.sunrise, tint: .orange)
            Spacer()
            sunLabel("Ocaso", systemImage: "sunset.fill", date: sun.sunset, tint: .pink)
        }
    }

    private func sunLabel(_ title: String, systemImage: String, date: Date?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
            Text(date.map { Self.timeFormatter(for: location).string(from: $0) } ?? "—")
                .font(.title3.monospacedDigit())
        }
    }

    private static func timeFormatter(for location: Location) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.timeZone = location.timeZone
        f.dateFormat = "HH:mm"
        return f
    }
}

/// One day of the daily forecast: date, min/max temperature, peak humidity. Renders from the cached
/// `DaySnapshot`.
private struct DayRow: View {
    let day: DaySnapshot

    var body: some View {
        HStack {
            Text(Self.dayLabel(day.date))
                .frame(width: 96, alignment: .leading)
            Spacer()
            // The day's actual condition, not peak humidity: the humidity glyph looked like rain and
            // showed every day, which read as "rain daily" and contradicted the complications. This is
            // the same sky code the complications use, so a clear day shows a sun and rain shows only
            // when it actually rains.
            Image(systemName: WeatherIcon.symbol(forSky: day.sky))
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .frame(width: 30)
            Spacer().frame(width: 12)
            minMax
                .font(.headline.monospacedDigit())
        }
    }

    private var minMax: some View {
        HStack(spacing: 4) {
            Text(day.min.map { "\($0)°" } ?? "—").foregroundStyle(Palette.temperature(day.min))
            Text("/").foregroundStyle(.tertiary)
            Text(day.max.map { "\($0)°" } ?? "—").foregroundStyle(Palette.temperature(day.max))
        }
    }

    private static func dayLabel(_ date: Date) -> String {
        let out = DateFormatter()
        out.locale = Locale(identifier: "es_ES")
        out.dateFormat = "EEE d MMM"
        return out.string(from: date).capitalized
    }
}
