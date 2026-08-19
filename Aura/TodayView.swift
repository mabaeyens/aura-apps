import AuraKit
import SwiftUI
import WidgetKit

/// "Hoy" — the numeric daily forecast for the selected location, plus locally computed
/// sunrise/sunset. This is the screen that proves clean AEMET data reaches the UI.
struct TodayView: View {
    @EnvironmentObject private var store: LocationStore

    @State private var forecast: MunicipioForecast?
    @State private var isLoading = false
    @State private var errorMessage: String?

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
        .task(id: store.selectedINE) { await load() }
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

            Section("Sol") {
                SunTimesRow(location: location)
            }

            if let forecast {
                Section("Predicción diaria") {
                    ForEach(forecast.prediccion.dia.prefix(5), id: \.fecha) { dia in
                        DayRow(dia: dia)
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
        .refreshable { await load() }
    }

    private func load() async {
        guard let location = store.selected else { return }
        guard let client = AEMETService.client() else {
            errorMessage = nil // handled by the key banner
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await client.municipioDiaria(location.ine)
            forecast = fetched
            // Feed the App Group cache the widgets read, then ask them to re-render.
            SharedCache.upsert(WeatherSnapshot.make(location: location, forecast: fetched))
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            errorMessage = AEMETService.message(for: error)
        }
        isLoading = false
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

/// One day of the daily forecast: date, min/max temperature, humidity range.
private struct DayRow: View {
    let dia: MunicipioForecast.Dia

    var body: some View {
        HStack {
            Text(Self.dayLabel(dia.fecha))
                .frame(width: 96, alignment: .leading)
            Spacer()
            if let hum = dia.humedadRelativa, let max = hum.maxima {
                Label("\(max)%", systemImage: "humidity")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                Spacer().frame(width: 12)
            }
            Text(temperatureText)
                .font(.headline.monospacedDigit())
        }
    }

    private var temperatureText: String {
        let min = dia.temperatura?.minima.map { "\($0)°" } ?? "—"
        let max = dia.temperatura?.maxima.map { "\($0)°" } ?? "—"
        return "\(min) / \(max)"
    }

    private static func dayLabel(_ fecha: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "es_ES")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = parser.date(from: fecha) ?? {
            parser.dateFormat = "yyyy-MM-dd"
            return parser.date(from: fecha)
        }() else { return fecha }

        let out = DateFormatter()
        out.locale = Locale(identifier: "es_ES")
        out.dateFormat = "EEE d MMM"
        return out.string(from: date).capitalized
    }
}
