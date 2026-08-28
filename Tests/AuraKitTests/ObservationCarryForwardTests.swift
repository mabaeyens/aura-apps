import XCTest
@testable import AuraKit

/// Coverage for the observation carry-forward in `WeatherSnapshot.make`: when a refresh skips the hourly
/// `/observacion/convencional/todas` fetch (the feed isn't due yet, or a transient error left `observed`
/// nil), the rebuilt snapshot must keep the last good station reading from the prior snapshot instead of
/// blanking the observed card. A fresh reading, when present, always wins.
final class ObservationCarryForwardTests: XCTestCase {

    private func dailyFixture() throws -> MunicipioForecast {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "municipio_diaria_28079", withExtension: "json",
                              subdirectory: "Fixtures"),
            "missing fixture municipio_diaria_28079.json")
        return try JSONDecoder().decode([MunicipioForecast].self, from: Data(contentsOf: url))[0]
    }

    private let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                                  latitude: 40.4168, longitude: -3.7038)

    /// A snapshot carrying a real observed reading, to act as the "previous" one a skipped refresh reuses.
    private func snapshotWithObservation(temp: Double, station: String) throws -> WeatherSnapshot {
        let observed = StationObservation(idema: "3195", ubi: station,
                                          lat: 40.4114, lon: -3.6782, ta: temp, hr: 50,
                                          fint: "2026-08-25T11:00:00+0000")
        return WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                    observed: observed)
    }

    func testSkippedFetchCarriesForwardPreviousReading() throws {
        let previous = try snapshotWithObservation(temp: 21.4, station: "MADRID RETIRO")
        XCTAssertEqual(previous.observedTemp, 21)
        XCTAssertNotNil(previous.observedReading)

        // No fresh observation this cycle (fetch skipped), but a prior snapshot exists. `now` is within the
        // carry-forward age gate of the fixture's fint (2026-08-25T11:00Z) so the reading is still carried.
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 14)))  // 12:00Z, 1 h after the reading
        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                           observed: nil, previousObserved: previous, now: now)

        XCTAssertEqual(rebuilt.observedTemp, previous.observedTemp)
        XCTAssertEqual(rebuilt.observedStation, previous.observedStation)
        XCTAssertEqual(rebuilt.observedStationDistanceKm, previous.observedStationDistanceKm)
        XCTAssertEqual(rebuilt.observedMetrics, previous.observedMetrics)
        XCTAssertEqual(rebuilt.observedReading, previous.observedReading)
    }

    func testFreshReadingWinsOverPrevious() throws {
        let previous = try snapshotWithObservation(temp: 21.4, station: "MADRID RETIRO")
        let fresh = StationObservation(idema: "3196", ubi: "GETAFE",
                                       lat: 40.30, lon: -3.72, ta: 25.0, hr: 45,
                                       fint: "2026-08-25T12:00:00+0000")

        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                           observed: fresh, previousObserved: previous)

        // The new station's reading is used wholesale — never a mix of new temp with the old station's name.
        XCTAssertEqual(rebuilt.observedTemp, 25)
        XCTAssertEqual(rebuilt.observedStation, "Getafe")
        XCTAssertNotEqual(rebuilt.observedStation, previous.observedStation)
    }

    func testNoObservationAndNoPreviousLeavesReadingNil() throws {
        let rebuilt = WeatherSnapshot.make(location: madrid, daily: try dailyFixture(), hourly: nil,
                                           observed: nil, previousObserved: nil)
        XCTAssertNil(rebuilt.observedTemp)
        XCTAssertNil(rebuilt.observedStation)
        XCTAssertNil(rebuilt.observedReading)
        XCTAssertEqual(rebuilt.observedMetrics, [])
    }
}
