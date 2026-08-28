import XCTest
@testable import AuraKit

/// Hardening guards from the adversarial review of the stale-leading-day fix:
///  - a *present-but-temperature-less* feed (HTTP 200 whose current day has a sky but no `temperatura`)
///    must carry the last good temperature forward, not blank the hero, and must not invent one on a cold
///    start (SEV-1);
///  - `futureDays` must drop past/unparseable days order-independently, so an out-of-order or malformed
///    leading `dia` can never become the "current" anchor (F1 / SEV-3);
///  - the hero search spans the whole upcoming window, so a today made entirely of sky-only hours still
///    reaches tomorrow's first reading (SEV-1 corner: currentHour 0 with a full sky-only today).
final class HeroHardeningTests: XCTestCase {

    private let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                                  latitude: 40.4168, longitude: -3.7038)
    private let tz = TimeZone(identifier: "Europe/Madrid")!
    private let full = Array(0...23)

    private func hv(_ hours: [Int], _ value: (Int) -> String) -> [MunicipioHourly.HourValue] {
        hours.map { MunicipioHourly.HourValue(value: value($0), periodo: String(format: "%02d", $0)) }
    }
    private func sky(_ hours: [Int]) -> [MunicipioHourly.SkyValue] {
        hours.map { MunicipioHourly.SkyValue(value: "11", periodo: String(format: "%02d", $0), descripcion: "Despejado") }
    }
    /// `tempHours` may be empty to model a present-but-temperature-less day.
    private func day(fecha: String, tempHours: [Int], skyHours: [Int]) -> MunicipioHourly.Dia {
        MunicipioHourly.Dia(
            fecha: fecha, orto: nil, ocaso: nil,
            temperatura: hv(tempHours) { "\($0 + 10)" },
            estadoCielo: sky(skyHours),
            humedadRelativa: hv(skyHours) { _ in "50" },
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
          {"fecha":"2026-08-28T00:00:00","temperatura":{"maxima":31,"minima":16},"humedadRelativa":{"maxima":70,"minima":30}}
        ]}}]
        """
        return try JSONDecoder().decode([MunicipioForecast].self, from: Data(json.utf8))[0]
    }
    private func noon() throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 12)))
    }
    private func midnight() throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 8, day: 28, hour: 0, minute: 5)))
    }

    /// SEV-1: a present-but-temperature-less feed with a prior good snapshot must carry the temp forward.
    func testTemperaturelessFeedCarriesPreviousTempForward() throws {
        let good = WeatherSnapshot.make(location: madrid, daily: try daily(),
                                        hourly: hourly([day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full)]),
                                        timeZone: tz, now: try noon())
        XCTAssertEqual(good.currentTemp, 22, "sanity: the good snapshot has 12:00 → 22°")

        let templess = hourly([day(fecha: "2026-08-28T00:00:00", tempHours: [], skyHours: full)])
        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: templess,
                                           observed: nil, previousObserved: good, timeZone: tz, now: try noon())
        XCTAssertEqual(rebuilt.heroTemp, 22, "present-but-temp-less feed must carry the previous temp, not blank")
        XCTAssertEqual(rebuilt.currentSky, "11", "the fresh sky is still used — only the missing temp is carried")
    }

    /// SEV-1 cold start: a present-but-temperature-less feed with no prior snapshot stays honest ("—").
    func testTemperaturelessFeedColdStartStaysBlank() throws {
        let templess = hourly([day(fecha: "2026-08-28T00:00:00", tempHours: [], skyHours: full)])
        let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: templess,
                                     observed: nil, previousObserved: nil, timeZone: tz, now: try noon())
        XCTAssertNil(s.heroTemp, "no fresh temp and nothing to carry — must not invent one")
    }

    /// F1 / SEV-3: days out of chronological order — the past day must be dropped wherever it sits, so the
    /// hero anchors on today regardless of position.
    func testOutOfOrderDaysStillAnchorOnToday() throws {
        let feed = hourly([
            day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full),            // today, first
            day(fecha: "2026-08-27T00:00:00", tempHours: [21, 22, 23], skyHours: [20, 21, 22, 23]), // yesterday, second
        ])
        let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: feed, timeZone: tz, now: try noon())
        XCTAssertEqual(s.heroTemp, 22, "hero must read today's 12:00, never the mis-ordered yesterday")
    }

    /// F1: an unparseable leading `fecha` must be dropped, not survive as the anchor.
    func testUnparseableLeadingDayIsDropped() throws {
        let feed = hourly([
            day(fecha: "garbage-date", tempHours: [21, 22, 23], skyHours: [20, 21, 22, 23]),
            day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full),
        ])
        let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: feed, timeZone: tz, now: try noon())
        XCTAssertEqual(s.heroTemp, 22, "an unparseable leading day must not anchor the hero")
    }

    /// SEV-1 corner: currentHour 0 with a full sky-only today — the hero search spans past the 24-slot
    /// display strip into tomorrow's first reading rather than blanking.
    func testFullSkyOnlyTodayAtMidnightReachesTomorrow() throws {
        let feed = hourly([
            day(fecha: "2026-08-28T00:00:00", tempHours: [], skyHours: full),   // today: 24 sky-only hours
            day(fecha: "2026-08-29T00:00:00", tempHours: full, skyHours: full), // tomorrow: real temps
        ])
        let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: feed,
                                     observed: nil, previousObserved: nil, timeZone: tz, now: try midnight())
        XCTAssertEqual(s.heroTemp, 10, "hero must reach tomorrow's 00:00 (10°) past the 24-slot strip, not blank")
    }

    /// BUG A: a failed hourly fetch (`hourly` nil) must keep the last good next-hours strip, not blank the
    /// next-hours card and widget row. This was the iPad symptom — a rate-limited hourly fetch wiped `hours`.
    func testFailedHourlyFetchKeepsPreviousStrip() throws {
        let good = WeatherSnapshot.make(location: madrid, daily: try daily(),
                                        hourly: hourly([day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full)]),
                                        timeZone: tz, now: try noon())
        XCTAssertFalse(good.hours.isEmpty, "sanity: the good snapshot has a populated strip")

        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: nil,
                                           observed: nil, previousObserved: good, timeZone: tz, now: try noon())
        XCTAssertEqual(rebuilt.hours.count, good.hours.count, "a failed hourly fetch must carry the last good strip forward")
        XCTAssertFalse(rebuilt.hours.isEmpty, "the next-hours strip must not blank on a failed hourly fetch")
    }

    /// Cold start with a failed hourly fetch and nothing cached: the strip is honestly empty (nothing to
    /// carry), which is acceptable — there is no prior data to show.
    func testFailedHourlyColdStartHasEmptyStrip() throws {
        let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: nil,
                                     observed: nil, previousObserved: nil, timeZone: tz, now: try noon())
        XCTAssertTrue(s.hours.isEmpty, "no prior strip and no feed — empty is honest")
    }
}
