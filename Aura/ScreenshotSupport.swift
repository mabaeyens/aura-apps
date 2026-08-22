#if DEBUG
import AuraKit
import Foundation

/// Debug-only rendering overrides used to capture App Store screenshots. They're driven entirely by
/// launch-environment variables so a capture script (see `scripts/screenshots.sh`) can render Aura at any
/// hour and under any sky without waiting for the real time or the real weather. None of this compiles
/// into a release build.
///
/// This is *not* faking the UI: the same rendering path runs, only fed a chosen `Date` and sky code, so
/// every frame is exactly what the device would show at that instant and condition.
enum ScreenshotOverride {
    /// `AURA_FAKE_DATE` — an instant to render "now" as. Accepts a zoned ISO-8601 string
    /// (`2026-08-22T19:30:00+02:00`) or a plain local one (`2026-08-22T19:30:00`, read in the current
    /// time zone — what an author means by "7:30 pm"). Drives the sun/moon position, the sky gradient and
    /// every time-derived label.
    static var now: Date? {
        guard let raw = value(for: "AURA_FAKE_DATE") else { return nil }
        return parseDate(raw)
    }

    /// `AURA_FAKE_SKY` — an AEMET sky-state code that replaces the current condition. Handy codes, one per
    /// veil: `11` despejado, `12` poco nuboso, `14` nuboso, `16` cubierto, `23` lluvia, `51` tormenta,
    /// `33` nieve, `81` niebla. (Night vs day comes from `AURA_FAKE_DATE`, not the code.)
    static var skyCode: String? { value(for: "AURA_FAKE_SKY") }

    private static func value(for key: String) -> String? {
        guard let raw = ProcessInfo.processInfo.environment[key]?
                .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return raw
    }

    private static func parseDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm"] {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = .current
            df.dateFormat = format
            if let date = df.date(from: raw) { return date }
        }
        return nil
    }
}

extension WeatherSnapshot {
    /// A copy with the current sky code (and a matching Spanish label) replaced, via a Codable round-trip
    /// so it stays correct as fields are added or removed. DEBUG/screenshot use only — the daily/hourly
    /// arrays keep their real codes, which is fine for the hero-led store shots.
    func overridingSky(_ code: String) -> WeatherSnapshot {
        guard let data = try? JSONEncoder().encode(self),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return self
        }
        dict["currentSky"] = code
        let base = code.hasSuffix("n") ? String(code.dropLast()) : code
        if let label = Self.screenshotSkyLabel[base] { dict["currentSkyText"] = label }
        guard let patched = try? JSONSerialization.data(withJSONObject: dict),
              let copy = try? JSONDecoder().decode(WeatherSnapshot.self, from: patched) else {
            return self
        }
        return copy
    }

    /// Spanish labels (AEMET's own vocabulary) for the sky codes a screenshot run is likely to use, keyed
    /// by the two-digit base and matched to `Palette.sky(forCode:)`'s categories.
    private static let screenshotSkyLabel: [String: String] = [
        "11": "Despejado", "17": "Nubes altas",
        "12": "Poco nuboso", "13": "Intervalos nubosos",
        "14": "Nuboso", "15": "Muy nuboso", "16": "Cubierto",
        "23": "Lluvia", "24": "Lluvia", "25": "Chubascos", "26": "Chubascos",
        "43": "Intervalos nubosos con lluvia", "45": "Lluvia escasa",
        "51": "Tormenta", "52": "Tormenta", "61": "Tormenta",
        "33": "Nieve", "34": "Nieve", "71": "Nieve escasa",
        "81": "Niebla", "82": "Bruma", "83": "Calima",
    ]
}
#endif
