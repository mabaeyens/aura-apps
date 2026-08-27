import XCTest
@testable import AuraKit

/// Guards the current-hour *description* against a cross-day mix-up. When day 0's hours are all in the past,
/// the resolved current hour rolls into day 1, and its sky text must be read from day 1 too. The old code
/// always tried day 0 first at the same hour number and only fell through to day 1 when day 0 had no entry —
/// so a day 0 entry that happened to exist at that hour won, describing a *different* day than the sky code
/// the glyph and background use. That is the "Nubes altas" text sitting over a clear sky.
final class HourlySkyDayRolloverTests: XCTestCase {

    private let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                                  latitude: 40.4168, longitude: -3.7038)

    private func dailyFixture() throws -> MunicipioForecast {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "municipio_diaria_28079", withExtension: "json",
                              subdirectory: "Fixtures"))
        return try JSONDecoder().decode([MunicipioForecast].self, from: Data(contentsOf: url))[0]
    }

    /// One hour's `{value, periodo}` reading.
    private func hv(_ hour: Int, _ value: String) -> String {
        #"{"value":"\#(value)","periodo":"\#(String(format: "%02d", hour))"}"#
    }

    /// One hour's sky `{value, periodo, descripcion}`.
    private func sky(_ hour: Int, _ code: String, _ desc: String) -> String {
        #"{"value":"\#(code)","periodo":"\#(String(format: "%02d", hour))","descripcion":"\#(desc)"}"#
    }

    /// A two-day hourly feed. Day 0 carries entries only at the given past hours (so, resolved after them,
    /// day 0 is exhausted and the current hour rolls into day 1); day 1 is a normal early strip. Both days
    /// carry an entry at hour 0, deliberately with *different* descriptions, so a cross-day read is visible.
    private func rolloverHourly(day0PastHours: [Int]) throws -> MunicipioHourly {
        let day0Temps = day0PastHours.map { hv($0, "20") }.joined(separator: ",")
        // Day 0's hour-0 sky is the wrong-day trap: a real description at the same hour number as day 1's.
        let day0Skies = ([sky(0, "11", "Despejado dia0")]
            + day0PastHours.map { sky($0, "11", "Despejado dia0") }).joined(separator: ",")
        let day1Temps = (0...5).map { hv($0, "18") }.joined(separator: ",")
        let day1Skies = (0...5).map { sky($0, "17", "Nubes altas") }.joined(separator: ",")
        let json = """
        [{"nombre":"Madrid","provincia":"Madrid","prediccion":{"dia":[
          {"fecha":"2026-08-25T00:00:00","temperatura":[\(day0Temps)],"estadoCielo":[\(day0Skies)],
           "humedadRelativa":[],"probPrecipitacion":[]},
          {"fecha":"2026-08-26T00:00:00","temperatura":[\(day1Temps)],"estadoCielo":[\(day1Skies)],
           "humedadRelativa":[],"probPrecipitacion":[]}
        ]}}]
        """
        return try JSONDecoder().decode([MunicipioHourly].self, from: Data(json.utf8))[0]
    }

    private func madridAt(_ hour: Int) throws -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Madrid"))
        return try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: hour)))
    }

    /// Day 0 exhausted → current hour is day 1's hour 0. Its sky *code* and *text* must both be day 1's, so
    /// they agree; the day 0 hour-0 description must never leak in.
    func testCurrentTextFollowsTheDayTheCurrentHourCameFrom() throws {
        let hourly = try rolloverHourly(day0PastHours: [6, 7])
        let snapshot = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(),
                                            hourly: hourly, now: try madridAt(10))

        XCTAssertEqual(snapshot.currentSky, "17", "sky code is day 1's current hour")
        XCTAssertEqual(snapshot.currentSkyText, "Nubes altas", "text must come from the same day as the code")
        XCTAssertNotEqual(snapshot.currentSkyText, "Despejado dia0", "day 0's same-hour text must not leak in")
    }

    /// Sanity check the other branch: while day 0 still has an upcoming hour, the text stays day 0's.
    func testCurrentTextStaysOnDayZeroWhileItHasUpcomingHours() throws {
        let hourly = try rolloverHourly(day0PastHours: [6, 7, 12, 13])
        let snapshot = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(),
                                            hourly: hourly, now: try madridAt(12))
        XCTAssertEqual(snapshot.currentSky, "11")
        XCTAssertEqual(snapshot.currentSkyText, "Despejado dia0")
    }
}
