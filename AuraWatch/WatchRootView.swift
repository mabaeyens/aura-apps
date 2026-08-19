import AuraKit
import SwiftUI

/// The Watch app's screen: the most recently synced location in detail. Data arrives from the iPhone
/// via `WatchSync` and lands in the Watch's own `SharedCache`; before the first sync it invites the
/// user to open Aura on the phone.
struct WatchRootView: View {
    @State private var snapshot: WeatherSnapshot? = SharedCache.read().first

    var body: some View {
        Group {
            if let snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        header(snapshot)
                        if let alert = snapshot.alert { alertBanner(alert) }
                        if !snapshot.hours.isEmpty { hoursSection(snapshot.hours) }
                        if !snapshot.days.isEmpty { daysSection(snapshot.days) }
                        detailsRow(snapshot)
                        if let bulletin = snapshot.bulletin, !bulletin.isEmpty {
                            bulletinSection(phenomenon: snapshot.bulletinPhenomenon, text: bulletin)
                        }
                        Text("Elaborado con datos de AEMET")
                            .font(.system(size: 9)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 2)
                }
            } else {
                ContentUnavailableView("Abre Aura en el iPhone", systemImage: "iphone")
            }
        }
        .onAppear { snapshot = SharedCache.read().first }
        .onReceive(NotificationCenter.default.publisher(for: WatchSync.snapshotDidUpdate)) { _ in
            snapshot = SharedCache.read().first
        }
    }

    // MARK: Header

    private func header(_ s: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(s.localidad).font(.headline).lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: WeatherIcon.symbol(forSky: s.currentSky))
                    .symbolRenderingMode(.multicolor)
                    .font(.title2)
                Text(s.heroTemp.map { "\($0)°" } ?? "—")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.temperature(s.heroTemp))
            }
            if let sky = s.currentSkyText {
                Text(sky).font(.footnote).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(spacing: 10) {
                Text("Máx \(fmt(s.tempMax))").foregroundStyle(Palette.temperature(s.tempMax))
                Text("Mín \(fmt(s.tempMin))").foregroundStyle(Palette.temperature(s.tempMin))
            }
            .font(.caption).fontWeight(.medium)
            if s.heroIsObserved, let station = s.observedStation {
                Text("Observado · \(station)").font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Palette.skyGradient(forCode: s.currentSky).opacity(0.45),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    private func alertBanner(_ alert: WeatherAlert) -> some View {
        Label(alert.phenomenon ?? alert.event, systemImage: "exclamationmark.triangle.fill")
            .font(.caption2).fontWeight(.medium)
            .foregroundStyle(Palette.alert(alert.level))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Palette.alert(alert.level).opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Next hours

    private func hoursSection(_ hours: [HourSlot]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("PRÓXIMAS HORAS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(hours) { h in
                        VStack(spacing: 3) {
                            Text("\(h.hour)h").font(.system(size: 10)).foregroundStyle(.secondary)
                            Image(systemName: WeatherIcon.symbol(forSky: h.sky))
                                .symbolRenderingMode(.multicolor).font(.body)
                            Text(h.temp.map { "\($0)°" } ?? "—")
                                .font(.caption).foregroundStyle(Palette.temperature(h.temp))
                            if let p = h.precipProb, p > 0 {
                                Text("\(p)%").font(.system(size: 9)).foregroundStyle(Palette.tempBlue)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Next days

    private func daysSection(_ days: [DaySnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("PRÓXIMOS DÍAS")
            ForEach(days) { d in
                HStack {
                    Text(Self.weekday(d.date)).frame(width: 40, alignment: .leading)
                    Spacer()
                    Text(fmt(d.min)).foregroundStyle(Palette.temperature(d.min))
                    Text("·").foregroundStyle(.tertiary)
                    Text(fmt(d.max)).fontWeight(.semibold).foregroundStyle(Palette.temperature(d.max))
                }
                .font(.caption)
            }
        }
    }

    // MARK: Wind + sun

    private func detailsRow(_ s: WeatherSnapshot) -> some View {
        HStack(spacing: 14) {
            if let wind = s.windSpeed {
                Label("\(wind) km/h \(s.windDirection?.abbreviation ?? "")", systemImage: "wind")
                    .foregroundStyle(Palette.tempTeal)
            }
            if let event = s.nextSunEvent() {
                switch event {
                case .sunrise(let d):
                    Label(Self.hhmm(d), systemImage: "sunrise.fill").foregroundStyle(Palette.tempOrange)
                case .sunset(let d):
                    Label(Self.hhmm(d), systemImage: "sunset.fill").foregroundStyle(Palette.tempOrange)
                }
            }
        }
        .font(.caption2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Bulletin

    private func bulletinSection(phenomenon: String?, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionTitle("PREDICCIÓN")
            if let phenomenon {
                Label(phenomenon, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(Palette.tempOrange)
            }
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fmt(_ value: Int?) -> String { value.map { "\($0)°" } ?? "—" }

    private static func weekday(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "EEE"
        return f.string(from: date).capitalized
    }

    private static func hhmm(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
