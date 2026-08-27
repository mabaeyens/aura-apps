import XCTest
@testable import AuraKit

/// Coverage for the hourly carry-forward in `WeatherSnapshot.make`: when a refresh's `horaria` fetch
/// fails or returns nothing (`hourly` nil), the rebuilt snapshot must hold the last good current-hour
/// reading from the prior snapshot rather than blanking every `current*` field. Blanking them silently
/// dropped the hero to today's daily *max* and defaulted the sky to a bare sun — the "29 and clear"
/// regression this guards. A fresh feed, when present, always wins over the carried values.
final class HourlyCarryForwardTests: XCTestCase {

    private let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                                  latitude: 40.4168, longitude: -3.7038)

    /// Noon (Madrid) on the fixtures' first day, so the resolved current hour lands inside the feed.
    private func madridNoon() throws -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Madrid"))
        return try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 12)))
    }

    private func dailyFixture() throws -> MunicipioForecast {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "municipio_diaria_28079", withExtension: "json",
                              subdirectory: "Fixtures"))
        return try JSONDecoder().decode([MunicipioForecast].self, from: Data(contentsOf: url))[0]
    }

    private func hourlyFixture() throws -> MunicipioHourly {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "municipio_horaria_28079", withExtension: "json",
                              subdirectory: "Fixtures"))
        return try JSONDecoder().decode([MunicipioHourly].self, from: Data(contentsOf: url))[0]
    }

    /// A missing hourly feed with a prior good snapshot: the current-hour reading is held over, and the
    /// hero is that reading — never today's daily max.
    func testHourlyFailureCarriesForwardCurrentHour() throws {
        let now = try madridNoon()
        let previous = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(),
                                            hourly: try hourlyFixture(), now: now)
        XCTAssertNotNil(previous.currentTemp, "the fixture-built snapshot should have a current-hour temp")
        XCTAssertNotNil(previous.currentSky)

        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                           observed: nil, previousObserved: previous, now: now)

        XCTAssertEqual(rebuilt.currentTemp, previous.currentTemp)
        XCTAssertEqual(rebuilt.currentSky, previous.currentSky)
        XCTAssertEqual(rebuilt.currentSkyText, previous.currentSkyText)
        XCTAssertEqual(rebuilt.currentHumidity, previous.currentHumidity)
        XCTAssertEqual(rebuilt.windSpeed, previous.windSpeed)
        XCTAssertEqual(rebuilt.heroTemp, previous.currentTemp, "hero is the carried current-hour reading")
        XCTAssertTrue(rebuilt.hasCurrentHourData, "carried current-hour data must not read as thin")
    }

    /// A missing hourly feed with no prior snapshot (cold start): the snapshot stays thin and the hero is
    /// nil so the card shows "—". It must not fall back to the daily max.
    func testHourlyFailureWithoutPreviousStaysThin() throws {
        let now = try madridNoon()
        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                           observed: nil, previousObserved: nil, now: now)
        XCTAssertNil(rebuilt.currentTemp)
        XCTAssertNil(rebuilt.currentSky)
        XCTAssertNil(rebuilt.heroTemp, "hero must not fall back to the daily max")
        XCTAssertNotNil(rebuilt.tempMax, "the daily max is still present, just not used as the hero")
        XCTAssertFalse(rebuilt.hasCurrentHourData)
    }

    /// A fresh hourly feed wins over any carried previous — the carry only fills a wholly-absent feed.
    func testFreshHourlyWinsOverCarry() throws {
        let now = try madridNoon()
        let fresh = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(),
                                         hourly: try hourlyFixture(), now: now)
        XCTAssertNotNil(fresh.currentTemp)

        // A prior snapshot with a deliberately divergent current-hour reading, which must be ignored.
        let stale = WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                                    tempMin: 0, tempMax: 0, humedadMax: 0,
                                    currentTemp: 99, currentSky: "99", currentSkyText: "Inventado",
                                    sunrise: nil, sunset: nil, updated: now)
        let withStale = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(),
                                             hourly: try hourlyFixture(),
                                             observed: nil, previousObserved: stale, now: now)

        XCTAssertEqual(withStale.currentTemp, fresh.currentTemp)
        XCTAssertNotEqual(withStale.currentTemp, 99)
        XCTAssertEqual(withStale.currentSky, fresh.currentSky)
    }
}
