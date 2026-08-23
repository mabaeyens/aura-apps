import SwiftUI

/// The detail behind the Sol card: tapping it on the phone opens this — the daytime twin of
/// `AuraMoonSheet`. The drawn day arc stays purely visual on the card face; here are the numbers: civil
/// twilight (first and last light), orto and ocaso, solar noon, and today's daylight length with the
/// day-over-day delta. Orto/ocaso come from the snapshot (what the rest of the app uses); the twilight
/// times, solar noon and length are recomputed from the snapshot's coordinates (`SolarTimes`), no new
/// data. Same chrome as `AuraMoonSheet` (gradient, corner close button, fact rows).
public struct AuraSolarSheet: View {
    let snapshot: WeatherSnapshot
    let now: Date
    /// Render-only escape hatch: the offline `aura-render` tool passes `false` so it lays out without a
    /// `ScrollView` (which `ImageRenderer` can't render). The app always uses the default.
    var scrolls: Bool
    @Environment(\.dismiss) private var dismiss

    public init(snapshot: WeatherSnapshot, now: Date = Date(), scrolls: Bool = true) {
        self.snapshot = snapshot; self.now = now; self.scrolls = scrolls
    }

    private var sunrise: Date? { snapshot.sunrise }
    private var sunset: Date? { snapshot.sunset }
    private var solar: SolarTimes? {
        guard let lat = snapshot.latitude, let lon = snapshot.longitude else { return nil }
        return SolarTimes(date: now, latitude: lat, longitude: lon)
    }
    /// Solar noon: the midpoint between orto and ocaso, the arc's apex.
    private var solarNoon: Date? {
        guard let sr = sunrise, let ss = sunset, ss > sr else { return nil }
        return sr.addingTimeInterval(ss.timeIntervalSince(sr) / 2)
    }
    /// Today's daylight length, orto → ocaso.
    private var dayLength: TimeInterval? {
        guard let sr = sunrise, let ss = sunset, ss > sr else { return nil }
        return ss.timeIntervalSince(sr)
    }
    /// Change in daylight length vs yesterday, whole minutes (+ lengthening, − shortening). nil without
    /// coordinates or at a polar day/night.
    private var dayLengthDeltaMinutes: Int? {
        guard let today = dayLength, let lat = snapshot.latitude, let lon = snapshot.longitude,
              let yday = Calendar.current.date(byAdding: .day, value: -1, to: now) else { return nil }
        let y = SolarTimes(date: yday, latitude: lat, longitude: lon)
        guard let ysr = y.sunrise, let yss = y.sunset, yss > ysr else { return nil }
        return Int(((today - yss.timeIntervalSince(ysr)) / 60).rounded())
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.13, green: 0.15, blue: 0.24),
                                    Color(red: 0.04, green: 0.05, blue: 0.09)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            content
                .conditionalSolarScroll(scrolls)
        }
        .environment(\.colorScheme, .dark)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 27))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sol")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.trailing, 34)   // clear of the close button
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The signature: a warm sun over a soft glow — the daytime echo of the moon disc.
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.82, blue: 0.4).opacity(0.4), .clear],
                                         center: .center, startRadius: 6, endRadius: 130))
                    .frame(height: 180)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 76))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 1.0, green: 0.95, blue: 0.85),
                                     Color(red: 1.0, green: 0.78, blue: 0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)

            VStack(spacing: 0) {
                factRow(icon: "sunrise", label: "Primera luz", value: timeText(solar?.civilDawn),
                        tint: Color(red: 0.98, green: 0.75, blue: 0.5))
                factRow(icon: "sunrise.fill", label: "Orto", value: timeText(sunrise),
                        tint: Color(red: 1.0, green: 0.82, blue: 0.4))
                factRow(icon: "sun.max.fill", label: "Mediodía solar", value: timeText(solarNoon),
                        tint: Color(red: 1.0, green: 0.9, blue: 0.5))
                factRow(icon: "sunset.fill", label: "Ocaso", value: timeText(sunset),
                        tint: Color(red: 1.0, green: 0.6, blue: 0.35))
                factRow(icon: "sunset", label: "Última luz", value: timeText(solar?.civilDusk),
                        tint: Color(red: 0.62, green: 0.55, blue: 0.75))
                factRow(icon: "hourglass", label: "Luz del día", value: dayLengthText,
                        tint: Color(white: 0.85), last: true)
            }

            Text("Orto y ocaso vienen del parte de AEMET para tu municipio; la primera y la última luz (crepúsculo civil), el mediodía solar y la duración del día se calculan para tus coordenadas.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    /// The headline fact: today's daylight length plus the day-over-day delta.
    private var subtitle: String {
        guard let len = dayLength else { return "Horario solar no disponible" }
        var s = "\(durationText(len)) de luz"
        if let dm = dayLengthDeltaMinutes {
            if dm > 0 { s += " · +\(dm) min que ayer" }
            else if dm < 0 { s += " · \(dm) min que ayer" }
            else { s += " · igual que ayer" }
        }
        return s
    }

    private var dayLengthText: String {
        guard let len = dayLength else { return "—" }
        return durationText(len)
    }

    private func factRow(icon: String, label: String, value: String, tint: Color,
                         last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(tint)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 11)
            if !last { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        }
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "—" }
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// Compact "13 h 24 min" / "43 min", matching the Sol card's own daylight-length line.
    private func durationText(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        let hours = seconds / 3600, minutes = (seconds % 3600) / 60
        return hours > 0 ? "\(hours) h \(String(format: "%02d", minutes)) min" : "\(minutes) min"
    }
}

private extension View {
    @ViewBuilder func conditionalSolarScroll(_ scrolls: Bool) -> some View {
        if scrolls { ScrollView { self } } else { self }
    }
}
