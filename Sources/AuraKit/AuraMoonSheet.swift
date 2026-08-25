import SwiftUI

/// The detail behind the Luna card: tapping it on the phone opens this. The night-sky disc stays purely
/// visual on the card face; here is where the numbers live — tonight's phase and true illuminated
/// fraction (from the real Sun–Moon elongation, `LunarPosition`), moonrise and moonset for the location
/// (`LunarTimes`), and the countdown to the next full and new moon (`MoonPhaseMath`). Same chrome as the
/// scale sheets (night gradient, corner close button), but an info panel rather than a legend.
public struct AuraMoonSheet: View {
    let snapshot: WeatherSnapshot
    let now: Date
    /// Render-only escape hatch: the offline `aura-render` tool passes `false` so it lays out without a
    /// `ScrollView` (which `ImageRenderer` can't render). The app always uses the default.
    var scrolls: Bool
    @Environment(\.dismiss) private var dismiss

    public init(snapshot: WeatherSnapshot, now: Date = Date(), scrolls: Bool = true) {
        self.snapshot = snapshot; self.now = now; self.scrolls = scrolls
    }

    private var position: LunarPosition { LunarPosition(date: now) }
    private var times: LunarTimes? {
        guard let lat = snapshot.latitude, let lon = snapshot.longitude else { return nil }
        return LunarTimes(date: now, latitude: lat, longitude: lon)
    }

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.09, green: 0.12, blue: 0.19),
                                    Color(red: 0.03, green: 0.04, blue: 0.08)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            content
                .conditionalMoonScroll(scrolls)
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
        let p = position
        let illumPct = Int((p.illumination * 100).rounded())
        let phase = MoonPhaseMath.phaseName(illumination: p.illumination, waxing: p.waxing)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Luna")
                    .auraFont(25, relativeTo: .title2, weight: .bold, design: .rounded)
                    .foregroundStyle(.white)
                    .padding(.trailing, 34)   // clear of the close button
                Text("\(phase) · \(illumPct) % iluminada")
                    .auraFont(15, relativeTo: .body)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The signature: tonight's real phase, large, over a soft cool glow.
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.66, green: 0.72, blue: 0.92)
                                                    .opacity(0.35 * p.illumination), .clear],
                                         center: .center, startRadius: 6, endRadius: 130))
                    .frame(height: 180)
                PhasedMoonDisc(illumination: p.illumination, waxing: p.waxing, radius: 52,
                               litColor: Color(red: 0.94, green: 0.96, blue: 1.0))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)

            VStack(spacing: 0) {
                factRow(icon: "arrow.up", label: "Salida", value: timeText(times?.moonrise),
                        tint: Palette.tempBlue)
                factRow(icon: "arrow.down", label: "Puesta", value: timeText(times?.moonset),
                        tint: Palette.tempBlue)
                factRow(icon: "moon.fill", label: "Próxima llena",
                        value: eventText(MoonPhaseMath.nextFullMoon(from: now)),
                        tint: Color(white: 0.92))
                factRow(icon: "moon", label: "Próxima nueva",
                        value: eventText(MoonPhaseMath.nextNewMoon(from: now)),
                        tint: Color(white: 0.55), last: true)
            }

            Text("La fase y el porcentaje se calculan a partir de la posición real del Sol y la Luna; salida y puesta, para tu ubicación. Las horas de las próximas fases son aproximadas (unas horas de margen).")
                .auraFont(13, relativeTo: .callout)
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
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

    /// "28 ago · en 5 días" — the date plus a relative-day tail (hoy / mañana / en N días).
    private func eventText(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_ES"); f.dateFormat = "d MMM"
        let cal = Calendar(identifier: .gregorian)
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                      to: cal.startOfDay(for: date)).day ?? 0
        let tail = days <= 0 ? "hoy" : (days == 1 ? "mañana" : "en \(days) días")
        return "\(f.string(from: date)) · \(tail)"
    }
}

private extension View {
    @ViewBuilder func conditionalMoonScroll(_ scrolls: Bool) -> some View {
        if scrolls { ScrollView { self } } else { self }
    }
}
