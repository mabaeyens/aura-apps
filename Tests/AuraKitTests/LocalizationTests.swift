import XCTest
@testable import AuraKit

/// Proves the chrome localization mechanism end to end: AuraKit's `.strings` tables are bundled into the
/// package resources and both the Spanish base and the English override resolve. Loads each `.lproj`
/// bundle directly, so the assertions do not depend on the process language.
final class LocalizationTests: XCTestCase {
    private func bundle(_ lang: String) throws -> Bundle {
        let path = try XCTUnwrap(auraKitBundle.path(forResource: lang, ofType: "lproj"),
                                 "\(lang).lproj not bundled — check Package.swift resources for AuraKit")
        return try XCTUnwrap(Bundle(path: path), "could not open \(lang).lproj")
    }

    private func string(_ key: String, _ lang: String) throws -> String {
        try bundle(lang).localizedString(forKey: key, value: "∅MISSING∅", table: "Localizable")
    }

    /// A representative spread across the slice: section title, tile label, completeness frame,
    /// the list conjunction, and the measured-at prefix. Both languages, exact values.
    func testChromeResolvesInBothLanguages() throws {
        let cases: [(key: String, es: String, en: String)] = [
            ("card.station.title",                 "Estación de observación",             "Observation station"),
            ("card.hourly.title",                  "Próximas horas",                      "Next hours"),
            ("card.station.metric.humidity.label", "Humed.",                              "Humid."),
            ("card.station.complete",              "Mide todos los datos de superficie.", "Measures all surface data."),
            ("list.and",                           "y",                                   "and"),
            ("card.station.distance",              "a %@ km",                             "%@ km away"),
            ("card.station.measuredAt",            "a las %@",                            "at %@"),
        ]
        for c in cases {
            XCTAssertEqual(try string(c.key, "es"), c.es, "es/\(c.key)")
            XCTAssertEqual(try string(c.key, "en"), c.en, "en/\(c.key)")
        }
    }

    /// The "No mide: %@." / "Does not measure: %@." frame fills its argument in each language.
    func testMissingLineFormats() throws {
        XCTAssertEqual(String(format: try string("card.station.missing", "es"), "presión"),
                       "No mide: presión.")
        XCTAssertEqual(String(format: try string("card.station.missing", "en"), "pressure"),
                       "Does not measure: pressure.")
    }

    /// No section-title or station key is left untranslated in either language (would fall through to
    /// the sentinel), which would render a raw key or a Spanish literal on an English device.
    func testNoKeyFallsThrough() throws {
        let keys = [
            "card.hourly.title", "card.daily.title", "card.wind.title", "card.station.title",
            "card.aqi.title", "card.uv.title", "card.radar.title", "card.news.title",
            "card.forecast.title", "card.sunmoon.title",
            "card.station.metric.temp.label", "card.station.metric.wind.label",
            "card.station.metric.humidity.label", "card.station.metric.pressure.label",
            "card.station.metric.rain.label", "card.station.complete", "card.station.missing",
            "card.station.distance", "card.station.measuredAt", "list.and",
            "metric.temperature.full", "metric.wind.full", "metric.humidity.full",
            "metric.pressure.full", "metric.precipitation.full",
            "a11y.metric.temperature", "a11y.metric.wind", "a11y.metric.humidity",
            "a11y.metric.pressure", "a11y.metric.precipitation",
            "a11y.unit.degrees", "a11y.unit.kmh", "a11y.unit.percent", "a11y.unit.hpa", "a11y.unit.mm",
            "a11y.value.unavailable", "a11y.value.reading",
            // Errors, moon/sun sheets, relative-day tails
            "error.missingKey", "error.rateLimited", "error.network", "error.aemetStatus",
            "error.decoding", "error.offline", "error.generic",
            "moon.title", "moon.illuminated", "moon.rise", "moon.set", "moon.nextFull",
            "moon.nextNew", "moon.explain", "moon.unavailable", "moon.risesSets",
            "moon.setsIn", "moon.risesIn",
            "rel.today", "rel.tomorrow", "rel.now", "rel.minsAgo", "rel.hoursAgo", "rel.daysAgo",
            "sun.title", "sun.firstLight", "sun.sunrise", "sun.solarNoon", "sun.sunset",
            "sun.lastLight", "sun.daylight", "sun.explain", "sun.unavailable", "sun.daylightLength",
            "sun.deltaMore", "sun.deltaLess", "sun.deltaSame", "sun.solarNoonAt", "sun.sunriseAt",
            "sun.sunsetAt", "sun.daylightLeft", "sun.sunriseIn",
            "a11y.sun.firstLightAt", "a11y.sun.lastLightAt", "a11y.sun.solarNoonAt",
            // Avisos, events, home, time-of-day, attribution
            "aviso.label", "aviso.none", "aviso.level",
            "aviso.window.between", "aviso.window.until", "aviso.window.from",
            "event.sunrise", "event.sunset", "home.openAura", "home.seeWeatherHere",
            "tod.dawn", "tod.morning", "tod.noon", "tod.afternoon", "tod.dusk", "tod.night",
            "attribution.madeWith",
            // Daily spoken row, wind, UV card, radar, air-quality empty
            "a11y.day.minMax", "a11y.day.max", "a11y.day.min", "a11y.day.rain",
            "wind.gusts", "wind.calm", "wind.direction", "wind.spoken",
            "uv.maxToday", "uv.now", "uv.peak", "uv.protectWindow",
            "radar.subtitle", "radar.rangeLine", "radar.weak", "radar.moderate", "radar.strong",
            "radar.torrential", "radar.intensityScale", "radar.intensityValue",
            "aqi.noData",
            // Scale sheets
            "scale.now", "scale.level",
            "aqi.dominant", "aqi.notMeasuredHere", "aqi.sheetTitle", "aqi.footnote",
            "aqi.byPollutant", "aqi.byPollutantNote", "aqi.bySuffix", "aqi.subtitle",
            "ica.advice.1", "ica.advice.2", "ica.advice.3", "ica.advice.4", "ica.advice.5", "ica.advice.6",
            "beaufort.title", "beaufort.footnote", "beaufort.noWind", "beaufort.dirSuffix",
            "beaufort.subtitle", "beaufort.range.calm", "beaufort.range.between", "beaufort.range.above",
            "beaufort.effect.0", "beaufort.effect.1", "beaufort.effect.2", "beaufort.effect.3",
            "beaufort.effect.4", "beaufort.effect.5", "beaufort.effect.6", "beaufort.effect.7",
            "beaufort.effect.8", "beaufort.effect.9", "beaufort.effect.10", "beaufort.effect.11",
            "beaufort.effect.12",
            "uv.sheetTitle", "uv.subtitle", "uv.footnote", "uv.cloudyNote",
            "uv.advice.0", "uv.advice.3", "uv.advice.6", "uv.advice.8", "uv.advice.11",
            // Data-freshness reference page
            "freshness.title", "freshness.link.title", "freshness.link.body", "freshness.intro",
            "freshness.section.data", "freshness.section.app",
            "freshness.observed.title", "freshness.observed.body",
            "freshness.forecast.title", "freshness.forecast.body",
            "freshness.bulletin.title", "freshness.bulletin.body",
            "freshness.radar.title", "freshness.radar.body",
            "freshness.uv.title", "freshness.uv.body",
            "freshness.air.title", "freshness.air.body",
            "freshness.aviso.title", "freshness.aviso.body",
            "freshness.news.title", "freshness.news.body",
            "freshness.refresh.title", "freshness.refresh.body",
        ]
        for key in keys {
            XCTAssertNotEqual(try string(key, "es"), "∅MISSING∅", "missing es/\(key)")
            XCTAssertNotEqual(try string(key, "en"), "∅MISSING∅", "missing en/\(key)")
        }
    }

    /// The one grammatical plural (moon "en N días" / "in N days") resolves through the `.stringsdict`
    /// in each language: singular for 1, plural otherwise. This is the path `auraString(key, args)` takes.
    func testPluralResolvesInBothLanguages() throws {
        func plural(_ n: Int, _ lang: String) throws -> String {
            let raw = try bundle(lang).localizedString(forKey: "rel.inDays", value: "∅MISSING∅", table: "Localizable")
            XCTAssertNotEqual(raw, "∅MISSING∅", "\(lang)/rel.inDays not in stringsdict")
            return String(format: raw, n)
        }
        XCTAssertEqual(try plural(1, "es"), "en 1 día")
        XCTAssertEqual(try plural(3, "es"), "en 3 días")
        XCTAssertEqual(try plural(1, "en"), "in 1 day")
        XCTAssertEqual(try plural(3, "en"), "in 3 days")
    }
}
