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
                    .auraFont(27, relativeTo: .title2)
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
                Text(auraString("sun.title"))
                    .auraFont(25, relativeTo: .title2, weight: .bold, design: .rounded)
                    .foregroundStyle(.white)
                    .padding(.trailing, 34)   // clear of the close button
                Text(subtitle)
                    .auraFont(15, relativeTo: .body)
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
                    .auraFont(76, relativeTo: .largeTitle)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(red: 1.0, green: 0.95, blue: 0.85),
                                     Color(red: 1.0, green: 0.78, blue: 0.35))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)

            VStack(spacing: 0) {
                factRow(icon: "sunrise", label: auraString("sun.firstLight"), value: timeText(solar?.civilDawn),
                        tint: Color(red: 0.98, green: 0.75, blue: 0.5))
                factRow(icon: "sunrise.fill", label: auraString("sun.sunrise"), value: timeText(sunrise),
                        tint: Color(red: 1.0, green: 0.82, blue: 0.4))
                factRow(icon: "sun.max.fill", label: auraString("sun.solarNoon"), value: timeText(solarNoon),
                        tint: Color(red: 1.0, green: 0.9, blue: 0.5))
                factRow(icon: "sunset.fill", label: auraString("sun.sunset"), value: timeText(sunset),
                        tint: Color(red: 1.0, green: 0.6, blue: 0.35))
                factRow(icon: "sunset", label: auraString("sun.lastLight"), value: timeText(solar?.civilDusk),
                        tint: Color(red: 0.62, green: 0.55, blue: 0.75))
                factRow(icon: "hourglass", label: auraString("sun.daylight"), value: dayLengthText,
                        tint: Color(white: 0.85), last: true)
            }

            Text(auraString("sun.explain"))
                .auraFont(13, relativeTo: .callout)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }

    /// The headline fact: today's daylight length plus the day-over-day delta.
    private var subtitle: String {
        guard let len = dayLength else { return auraString("sun.unavailable") }
        var s = auraString("sun.daylightLength", durationText(len))
        if let dm = dayLengthDeltaMinutes {
            if dm > 0 { s += " · " + auraString("sun.deltaMore", dm) }
            else if dm < 0 { s += " · " + auraString("sun.deltaLess", -dm) }
            else { s += " · " + auraString("sun.deltaSame") }
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
                    .auraFont(17, relativeTo: .body)
                    .foregroundStyle(tint)
                    .frame(width: 24)
                Text(label)
                    .auraFont(16, relativeTo: .body)
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(value)
                    .auraFont(16, relativeTo: .body, weight: .semibold)
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 11)
            if !last { Rectangle().fill(.white.opacity(0.08)).frame(height: 1) }
        }
    }

    private func timeText(_ date: Date?) -> String {
        guard let date else { return "—" }
        return AuraTime.hhmm(date)
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
