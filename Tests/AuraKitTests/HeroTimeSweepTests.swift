import XCTest
@testable import AuraKit

/// Empirical proof for the stale-leading-day fix: run `WeatherSnapshot.make` at EVERY hour of the day
/// against a feed shaped exactly like the one that blanked the hero (AEMET leading with a stale past day),
/// and assert the hero never resolves to nil and always reads the correct current-hour temperature. This
/// is the scenario that only reproduces at a real day boundary, so it is pinned down here in code.
final class HeroTimeSweepTests: XCTestCase {

    private let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                                  latitude: 40.4168, longitude: -3.7038)
    private let tz = TimeZone(identifier: "Europe/Madrid")!

    // MARK: - Fixture builders (constructed via the models, so any hour set is expressible)

    /// Temperature is deterministic: hour h → (h + 10)°, unique per hour, so a resolved hero can be checked
    /// against the exact hour it should have come from.
    private func hv(_ hours: [Int], _ value: (Int) -> String) -> [MunicipioHourly.HourValue] {
        hours.map { MunicipioHourly.HourValue(value: value($0), periodo: String(format: "%02d", $0)) }
    }
    private func sky(_ hours: [Int]) -> [MunicipioHourly.SkyValue] {
        hours.map { MunicipioHourly.SkyValue(value: "11", periodo: String(format: "%02d", $0), descripcion: "Despejado") }
    }

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

    private func instant(y: Int, m: Int, d: Int, h: Int) throws -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: 30)))
    }

    private let full = Array(0...23)

    // MARK: - The sweep

    /// AEMET leads with YESTERDAY (27th) as a sky-only tail; today (28th) is full; tomorrow (29th) is full.
    /// At every hour of the 28th, the hero must read today's current-hour temp (h + 10), never nil.
    func testStaleLeadingDaySweepEveryHour() throws {
        let feed = hourly([
            day(fecha: "2026-08-27T00:00:00", tempHours: [21, 22, 23], skyHours: [20, 21, 22, 23]),
            day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full),
            day(fecha: "2026-08-29T00:00:00", tempHours: full, skyHours: full),
        ])
        for h in 0...23 {
            let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: feed,
                                         timeZone: tz, now: try instant(y: 2026, m: 8, d: 28, h: h))
            XCTAssertEqual(s.heroTemp, h + 10, "hour \(h): hero must read today's current hour, not blank or the stale 27th")
            XCTAssertEqual(s.currentHumidity, 50, "hour \(h): humidity must resolve today too")
        }
    }

    /// Normal day (no stale lead): today is dia[0]. Behaviour must be identical — hero = h + 10 at every hour.
    func testNormalDaySweepEveryHour() throws {
        let feed = hourly([
            day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full),
            day(fecha: "2026-08-29T00:00:00", tempHours: full, skyHours: full),
        ])
        for h in 0...23 {
            let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: feed,
                                         timeZone: tz, now: try instant(y: 2026, m: 8, d: 28, h: h))
            XCTAssertEqual(s.heroTemp, h + 10, "normal day hour \(h): hero must read the current hour")
        }
    }

    /// Today's hourly data runs out after 14:00 (an afternoon cut). From 15:00 on, the hero must roll to
    /// tomorrow's first hour (10°), never blank.
    func testTodayRunsOutRollsToTomorrow() throws {
        let feed = hourly([
            day(fecha: "2026-08-28T00:00:00", tempHours: Array(0...14), skyHours: Array(0...14)),
            day(fecha: "2026-08-29T00:00:00", tempHours: full, skyHours: full),
        ])
        for h in 15...23 {
            let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: feed,
                                         timeZone: tz, now: try instant(y: 2026, m: 8, d: 28, h: h))
            XCTAssertEqual(s.heroTemp, 10, "hour \(h): with today exhausted, hero must roll to tomorrow's 00:00 (10°)")
        }
    }

    /// The exact live shape on the morning of the outage: now is early on the 28th, feed still leads with
    /// the 27th. Explicitly cover the midnight-boundary hours 0 and 1.
    func testDayBoundaryMidnightHours() throws {
        let feed = hourly([
            day(fecha: "2026-08-27T00:00:00", tempHours: [21, 22, 23], skyHours: [20, 21, 22, 23]),
            day(fecha: "2026-08-28T00:00:00", tempHours: full, skyHours: full),
        ])
        for h in [0, 1, 2] {
            let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: feed,
                                         timeZone: tz, now: try instant(y: 2026, m: 8, d: 28, h: h))
            XCTAssertEqual(s.heroTemp, h + 10, "midnight hour \(h): hero must read today, not the 27th tail")
        }
    }

    /// Today itself leads sky-only (no temps until 12:00). The hero must fall through to the first hour that
    /// carries a temperature rather than blank.
    func testTodaySkyOnlyLeadFallsThrough() throws {
        let feed = hourly([
            day(fecha: "2026-08-28T00:00:00", tempHours: Array(12...23), skyHours: full),
            day(fecha: "2026-08-29T00:00:00", tempHours: full, skyHours: full),
        ])
        for h in 0...12 {
            let s = WeatherSnapshot.make(location: madrid, daily: try daily(), hourly: feed,
                                         timeZone: tz, now: try instant(y: 2026, m: 8, d: 28, h: h))
            let expected = max(h, 12) + 10   // first hour >= h that has a temp
            XCTAssertEqual(s.heroTemp, expected, "hour \(h): hero must skip sky-only hours to the first with a temp")
        }
    }

    /// Fall-back DST day in Madrid (2026-10-25, clocks 03:00 → 02:00, a 25-hour day). The hour filter and
    /// slot dates must not misalign the hero.
    func testDSTFallBackDay() throws {
        let daily = try daily()  // daily fecha is the 28th, irrelevant to the hero; hourly drives it
        let feed = hourly([
            day(fecha: "2026-10-24T00:00:00", tempHours: [22, 23], skyHours: [22, 23]),
            day(fecha: "2026-10-25T00:00:00", tempHours: full, skyHours: full),
            day(fecha: "2026-10-26T00:00:00", tempHours: full, skyHours: full),
        ])
        for h in 0...23 {
            let s = WeatherSnapshot.make(location: madrid, daily: daily, hourly: feed,
                                         timeZone: tz, now: try instant(y: 2026, m: 10, d: 25, h: h))
            XCTAssertNotNil(s.heroTemp, "DST hour \(h): hero must not blank across the 25-hour day")
        }
    }
}
