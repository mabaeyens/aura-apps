import SwiftUI

// The "Sol y Luna" glance: the next relevant sun-or-moon event as a time with a glyph that tracks the
// moment — at dawn the coming amanecer, by day the ocaso, after dark a moon riding the night with the
// coming amanecer as its close. It fills the iOS Lock Screen date/inline slot (and the circular face),
// and the matching Watch complication. Like every other accessory it lives in AuraKit so the phone and
// the watch render identical code; the widget applies the container background.
//
// Aura carries no lunar ephemeris — the "moon" is the night span (ocaso → next orto) the Luna card
// already models from the location's own sun times — so after sunset this shows a moon glyph with the
// orto that closes the night, the honest "next event" the snapshot can name.

/// Which moment of the sun/moon cycle `now` falls in, resolved from the snapshot's sun times. The
/// associated `Date` is the event to display: the coming amanecer at dawn, the coming ocaso by day, and
/// the orto that closes the night after dark (today's orto stands in for tomorrow's — sun times barely
/// move day to day, exactly as `AuraMoonArcCard` and `SunFormat.remaining` already assume).
public enum SunMoonMoment: Sendable, Hashable {
    case dawn(Date)   // before sunrise: amanecer still to come
    case day(Date)    // daylight: ocaso still to come
    case night(Date)  // after sunset: the moon is up; the amanecer closes the night

    /// Resolve from `snapshot` at `now`, or nil when the sun times are unknown and no event can be named.
    public static func resolve(_ snapshot: WeatherSnapshot, now: Date = Date()) -> SunMoonMoment? {
        // With both boundaries the moment is unambiguous; pre-dawn and post-sunset both read as "night"
        // to `isNight`, so split them here on the actual sunrise/sunset instants instead.
        if let sr = snapshot.sunrise, let ss = snapshot.sunset {
            if now < sr { return .dawn(sr) }
            if now < ss { return .day(ss) }
            return .night(sr)
        }
        // A thin snapshot with only one boundary: fall back to whichever event is next.
        switch snapshot.nextSunEvent(now: now) {
        case .sunrise(let d): return snapshot.isNight(at: now) ? .night(d) : .dawn(d)
        case .sunset(let d):  return .day(d)
        case nil:             return nil
        }
    }

    /// The instant to show.
    public var date: Date {
        switch self {
        case .dawn(let d), .day(let d), .night(let d): return d
        }
    }

    /// The event glyph: a rising sun at dawn, a setting sun by day, a moon after dark.
    public var systemImage: String {
        switch self {
        case .dawn:  return "sunrise.fill"
        case .day:   return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    /// The Spanish label for the event — the noun the time belongs to.
    public var label: String {
        switch self {
        case .dawn, .night: return "Amanecer"
        case .day:          return "Ocaso"
        }
    }
}

private enum SunMoonFormat {
    /// Shared cached formatter (see `AuraTime`), which also honours the 24 h / 12 h preference — this
    /// path previously hardcoded 24 h and so ignored a user on the 12 h setting.
    static func hhmm(_ date: Date) -> String { AuraTime.hhmm(date) }
}

// MARK: - Inline (the Lock Screen date/top slot)

/// `.accessoryInline`: one line beside the clock — the event glyph and "Amanecer 7:12" / "Ocaso 21:11".
/// The system tints inline complications, so this stays plain; the glyph disambiguates sun from moon.
public struct AuraSunMoonInline: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let moment = SunMoonMoment.resolve(snapshot, now: now) {
            Label {
                Text("\(moment.label) \(SunMoonFormat.hhmm(moment.date))")
            } icon: {
                Image(systemName: moment.systemImage)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }
}

// MARK: - Circular

/// `.accessoryCircular`: the event glyph over its precise time. Palette-tinted (a yellow sun, a blue
/// moon) so it stays vibrant on full-colour watch faces; the Lock Screen desaturates it. Semantic fonts
/// plus `minimumScaleFactor` keep the two lines fitting the tiny circular safe area instead of clipping.
public struct AuraSunMoonCircular: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let moment = SunMoonMoment.resolve(snapshot, now: now) {
            VStack(spacing: 0) {
                glyph(moment).font(.title3)
                Text(SunMoonFormat.hhmm(moment.date))
                    .font(.caption).fontWeight(.semibold)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        } else {
            AuraAccessoryEmpty()
        }
    }

    /// The moon is a blue disc with white stars (as elsewhere in Aura, a `.multicolor` moon renders a
    /// flat pale sun); the sun events keep the yellow-over-orange rise/set palette.
    @ViewBuilder private func glyph(_ moment: SunMoonMoment) -> some View {
        switch moment {
        case .night:
            Image(systemName: moment.systemImage)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Palette.nightMoon, .white)
        case .dawn, .day:
            Image(systemName: moment.systemImage)
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .orange)
        }
    }
}

// MARK: - Corner

/// `.accessoryCorner` (Apple Watch): the event glyph filling the corner — a rising sun at dawn, a setting
/// sun by day, a moon after dark — with "Amanecer 7:12" / "Ocaso 21:11" on the curved bezel. A sun/moon
/// event is a moment, not a bounded value, so this is a plain glyph and bezel text, never a gauge. Palette
/// tint keeps it vibrant on full-colour faces; the Lock Screen desaturates it.
public struct AuraSunMoonCorner: View {
    let snapshot: WeatherSnapshot
    let now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if let moment = SunMoonMoment.resolve(snapshot, now: now) {
            glyph(moment)
        } else {
            Image(systemName: "sun.max")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
        }
    }

    /// The curved bezel label: the event noun and its precise time, e.g. "Ocaso 21:11".
    public var cornerLabel: String {
        guard let moment = SunMoonMoment.resolve(snapshot, now: now) else { return "—" }
        return "\(moment.label) \(SunMoonFormat.hhmm(moment.date))"
    }

    /// Same palette as the circular face — a blue-and-white moon at night, a yellow-over-orange sun by day —
    /// resized to fill the corner so it doesn't render at a small fixed intrinsic size.
    @ViewBuilder private func glyph(_ moment: SunMoonMoment) -> some View {
        switch moment {
        case .night:
            Image(systemName: moment.systemImage)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.palette)
                .foregroundStyle(Palette.nightMoon, .white)
        case .dawn, .day:
            Image(systemName: moment.systemImage)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.palette)
                .foregroundStyle(.yellow, .orange)
        }
    }
}
