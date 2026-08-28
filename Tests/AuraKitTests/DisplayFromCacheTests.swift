import XCTest
@testable import AuraKit

/// The gate no prior test covered: a snapshot **built and cached on one day, displayed on the next with
/// no fetch**. Every earlier hero test validates fetch-time `make(...)`; none renders a day-old cache at a
/// `now` past midnight. That is the real user scenario — the app opens, the cache is a few hours to a day
/// old, and the current conditions must still show *today*, resolved from the timestamped strip at display
/// time (`WeatherSnapshot.resolved(at:)`), not the scalars frozen when the snapshot was written.
///
/// Case (a) of `specs/hero-current-temp-structural-fix.md`, plus the "generalize now" scope decision: the
/// whole `current*` family (not only temperature) must re-anchor, so the hero can never disagree with the
/// strip on any field. These must fail on the frozen snapshot and pass once resolved at display time.
final class DisplayFromCacheTests: XCTestCase {

    private let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                                  latitude: 40.4168, longitude: -3.7038)
    private let tz = TimeZone(identifier: "Europe/Madrid")!
    private let full = Array(0...23)

    private func hv(_ hours: [Int], _ value: (Int) -> String) -> [MunicipioHourly.HourValue] {
        hours.map { MunicipioHourly.HourValue(value: value($0), periodo: String(format: "%02d", $0)) }
    }
    private func sky(_ hours: [Int], code: String) -> [MunicipioHourly.SkyValue] {
        hours.map { MunicipioHourly.SkyValue(value: code, periodo: String(format: "%02d", $0),
                                             descripcion: code == "11" ? "Despejado" : "Nuboso") }
    }
    /// `humidity` defaults to a flat 50%; pass a per-hour function to make it distinguishable by hour.
    private func day(fecha: String, tempHours: [Int], skyHours: [Int],
                     skyCode: String = "11", humidity: @escaping (Int) -> String = { _ in "50" }) -> MunicipioHourly.Dia {
        MunicipioHourly.Dia(
            fecha: fecha, orto: nil, ocaso: nil,
            temperatura: hv(tempHours) { "\($0 + 10)" },   // hour h → (h + 10)°
            estadoCielo: sky(skyHours, code: skyCode),
            humedadRelativa: hv(skyHours, humidity),
            probPrecipitacion: [MunicipioHourly.HourValue(value: "0", periodo: "0024")],
            sensTermica: nil, precipitacion: nil, nieve: nil,
            probTormenta: nil, probNieve: nil, vientoAndRachaMax: nil)
    }
    private func hourly(_ dias: [MunicipioHourly.Dia]) -> MunicipioHourly {
        MunicipioHourly(nombre: "Madrid", provincia: "Madrid", prediccion: .init(dia: dias))
    }
    private func daily() throws -> MunicipioForecast {
        let json = """
        [{"nombre":"Madrid","provincia":"Madrid","prediccion":{"dia":[
          {"fecha":"2026-08-27T00:00:00","temperatura":{"maxima":31,"minima":16},"humedadRelativa":{"maxima":70,"minima":30}},
          {"fecha":"2026-08-28T00:00:00","temperatura":{"maxima":30,"minima":15},"humedadRelativa":{"maxima":68,"minima":28}}
        ]}}]
        """
        return try JSONDecoder().decode([MunicipioForecast].self, from: Data(json.utf8))[0]
    }
    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int = 0) throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi)))
    }

    /// (a) A snapshot built yesterday at 22:30, displayed today at 09:00 with **no fetch**. The frozen
    /// `currentTemp` is yesterday's 22:00 reading (32°); the strip still carries today's hours. Resolved at
    /// display time the hero must re-anchor to today's 09:00 (19°), not show yesterday's frozen 32°.
    func testDayOldCacheResolvesTodaysHeroAtDisplayTime() throws {
        let builtYesterday = try date(2026, 8, 27, 22, 30)
        let displayToday = try date(2026, 8, 28, 9, 0)

        let cached = WeatherSnapshot.make(
            location: madrid, daily: try daily(),
            hourly: hourly([day(fecha: "2026-08-27T00:00:00", tempHours: full, skyHours: full),
                            day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full)]),
            timeZone: tz, now: builtYesterday)

        XCTAssertEqual(cached.heroTemp, 32, "sanity: frozen currentTemp is yesterday 22:00 (22 + 10)")
        XCTAssertTrue(cached.hours.contains { ($0.date.map { $0 >= displayToday } ?? false) && $0.temp != nil },
                      "sanity: the cached strip carries a dated today-morning slot with a temperature")

        XCTAssertEqual(cached.resolved(at: displayToday, timeZone: tz).heroTemp, 19,
                       "day-old cache must resolve today's current-hour temp at display time, not the frozen 32°")
    }

    /// "Generalize now": the whole `current*` family re-anchors, not only temperature — so a day-old cache
    /// shows today's sky/humidity too and the hero can't disagree with the strip on any field.
    func testDayOldCacheResolvesWholeCurrentFamily() throws {
        let builtYesterday = try date(2026, 8, 27, 22, 30)
        let displayToday = try date(2026, 8, 28, 9, 0)

        let cached = WeatherSnapshot.make(
            location: madrid, daily: try daily(),
            hourly: hourly([
                day(fecha: "2026-08-27T00:00:00", tempHours: full, skyHours: full,
                    skyCode: "11", humidity: { _ in "80" }),                        // yesterday: clear, 80%
                day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full,
                    skyCode: "12", humidity: { "\($0 + 30)" }),                      // today: cloudy, hour+30%
            ]),
            timeZone: tz, now: builtYesterday)

        // Frozen: yesterday 22:00 — clear sky, 80% humidity.
        XCTAssertEqual(cached.currentSky, "11", "sanity: frozen sky is yesterday's clear")
        XCTAssertEqual(cached.currentHumidity, 80, "sanity: frozen humidity is yesterday's 80%")

        let shown = cached.resolved(at: displayToday, timeZone: tz)
        XCTAssertEqual(shown.currentSky, "12", "sky must re-anchor to today's cloudy")
        XCTAssertEqual(shown.currentSkyText, "Nuboso", "sky text must re-anchor with the code")
        XCTAssertEqual(shown.currentHumidity, 39, "humidity must re-anchor to today 09:00 (9 + 30)")
        XCTAssertEqual(shown.heroTemp, 19, "temp must re-anchor to today 09:00 (9 + 10)")
    }

    /// A fresh snapshot (now == build time) is unchanged by resolving — re-anchoring is a no-op when the
    /// current hour is already the strip's first slot, so nothing regresses on the normal path.
    func testFreshSnapshotIsUnchangedByResolving() throws {
        let now = try date(2026, 8, 28, 12, 0)
        let s = WeatherSnapshot.make(
            location: madrid, daily: try daily(),
            hourly: hourly([day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full)]),
            timeZone: tz, now: now)
        let r = s.resolved(at: now, timeZone: tz)
        XCTAssertEqual(r.heroTemp, s.heroTemp)
        XCTAssertEqual(r.currentSky, s.currentSky)
        XCTAssertEqual(r.currentHumidity, s.currentHumidity)
    }

    /// The strip runs into the afternoon: displayed later the same day, the hero rolls forward to the next
    /// slot that carries a temperature rather than showing a stale one.
    func testDisplayLaterSameDayRollsForward() throws {
        let builtYesterday = try date(2026, 8, 27, 22, 30)
        let cached = WeatherSnapshot.make(
            location: madrid, daily: try daily(),
            hourly: hourly([day(fecha: "2026-08-27T00:00:00", tempHours: full, skyHours: full),
                            day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full)]),
            timeZone: tz, now: builtYesterday)
        // 24-slot strip built at 22:30 spans yesterday 22:00 → today 21:00. Display at today 11:00 → 21°.
        XCTAssertEqual(cached.resolved(at: try date(2026, 8, 28, 11, 0), timeZone: tz).heroTemp, 21,
                       "hero must re-anchor to today 11:00 (11 + 10)")
    }

    /// Cold start, empty snapshot: nothing in the strip, no frozen reading — the hero stays honestly blank,
    /// never invented, and resolving returns the snapshot unchanged.
    func testEmptyCacheStaysBlank() throws {
        let empty = WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                                    tempMin: nil, tempMax: nil, humedadMax: nil,
                                    sunrise: nil, sunset: nil, updated: try date(2026, 8, 27, 22, 30))
        XCTAssertNil(empty.resolved(at: try date(2026, 8, 28, 9, 0), timeZone: tz).heroTemp,
                     "no strip and no frozen reading — must not invent a hero temp")
    }
}
