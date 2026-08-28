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

    /// `AURA_FAKE_CITY` — the city name to show on the hero, so a run can vary the location across shots
    /// without switching the loaded snapshot. Either `"Sevilla"` or `"Sevilla,Sevilla"` (name,provincia);
    /// the province only matters if you also want the province-derived text to match.
    static var city: (name: String, provincia: String?)? {
        guard let raw = value(for: "AURA_FAKE_CITY") else { return nil }
        let parts = raw.split(separator: ",", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let name = parts.first, !name.isEmpty else { return nil }
        return (name, parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil)
    }

    /// `AURA_FAKE_ALERT` — injects a synthetic AEMET aviso card. `"naranja"` or `"naranja:Tormentas"`
    /// (level:phenomenon). Levels: `amarillo`, `naranja`, `rojo` (the card tints by level). The phenomenon
    /// is the text the card shows; it defaults to a generic label when omitted.
    static var alert: (level: String, phenomenon: String)? {
        guard let raw = value(for: "AURA_FAKE_ALERT") else { return nil }
        let parts = raw.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let level = parts.first, !level.isEmpty else { return nil }
        let phenomenon = parts.count > 1 && !parts[1].isEmpty ? parts[1] : "Aviso meteorológico"
        return (level, phenomenon)
    }

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
    /// so it stays correct as fields are added or removed. DEBUG/screenshot use only. Rewrites the hourly
    /// strip's sky codes too, not just the `currentSky` scalar: every surface now derives its shown sky
    /// through `resolved(at:)`, which re-reads the sky from the upcoming hours strip, so an override that
    /// touched only the scalar would be discarded the moment the hero, backdrop or a widget resolved. The
    /// daily array keeps its real codes (the days card is per-day, not a "now" reading).
    func overridingSky(_ code: String) -> WeatherSnapshot {
        guard let data = try? JSONEncoder().encode(self),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return self
        }
        dict["currentSky"] = code
        let base = code.hasSuffix("n") ? String(code.dropLast()) : code
        let label = Self.screenshotSkyLabel[base]
        if let label { dict["currentSkyText"] = label }
        // Stamp the fake sky onto every hour of the strip so `resolved(at:)` picks it up whichever slot is
        // the upcoming one at the screenshot's `now`, keeping the backdrop, hero and widgets on one sky.
        if var hours = dict["hours"] as? [[String: Any]] {
            for i in hours.indices {
                hours[i]["sky"] = code
                if let label { hours[i]["skyText"] = label }
            }
            dict["hours"] = hours
        }
        guard let patched = try? JSONSerialization.data(withJSONObject: dict),
              let copy = try? JSONDecoder().decode(WeatherSnapshot.self, from: patched) else {
            return self
        }
        return copy
    }

    /// A copy with the displayed city name (and optionally province) replaced, via the same Codable
    /// round-trip. DEBUG/screenshot use only. This relabels the hero — it does not reload another city's
    /// data, so the temperatures and forecast stay those of the loaded snapshot.
    func overridingCity(_ name: String, provincia: String?) -> WeatherSnapshot {
        guard let data = try? JSONEncoder().encode(self),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return self
        }
        dict["localidad"] = name
        if let provincia { dict["provincia"] = provincia }
        guard let patched = try? JSONSerialization.data(withJSONObject: dict),
              let copy = try? JSONDecoder().decode(WeatherSnapshot.self, from: patched) else {
            return self
        }
        return copy
    }

    /// A copy carrying a synthetic AEMET aviso, so the warning card renders for a screenshot. The card
    /// shows the phenomenon and tints by level; `onset`/`expires` are left open so it always reads as
    /// active. DEBUG/screenshot use only.
    func overridingAlert(level: String, phenomenon: String) -> WeatherSnapshot {
        let alert = WeatherAlert(level: WeatherAlert.Level(rawValue: level.lowercased()) ?? .naranja,
                                 event: phenomenon, phenomenon: phenomenon,
                                 zona: "000000", areaDesc: nil, onset: nil, expires: nil)
        guard let snapData = try? JSONEncoder().encode(self),
              var dict = (try? JSONSerialization.jsonObject(with: snapData)) as? [String: Any],
              let alertData = try? JSONEncoder().encode(alert),
              let alertObj = try? JSONSerialization.jsonObject(with: alertData) else {
            return self
        }
        dict["alert"] = alertObj
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
