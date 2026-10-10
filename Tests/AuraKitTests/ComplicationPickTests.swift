import XCTest
@testable import AuraKit

/// The complication prefers the wrist's forced place, but must not show blanks when that place has lost its
/// current-hour data and the phone's active place still has some.
final class ComplicationPickTests: XCTestCase {
    private func snap(_ ine: String, wind: Int?, updated: Date) -> WeatherSnapshot {
        WeatherSnapshot(ine: ine, localidad: ine, provincia: "P",
                        tempMin: 10, tempMax: 20, humedadMax: 50,
                        currentTemp: nil, currentSky: nil, currentSkyText: nil,
                        currentHumidity: nil, currentPrecipProb: nil,
                        windSpeed: wind, windDirection: nil,
                        sunrise: nil, sunset: nil, hours: [], updated: updated)
    }

    func testForcedPlaceWinsWhenItHasData() {
        let now = Date()
        let all = [snap("A", wind: 10, updated: now), snap("B", wind: 12, updated: now)]
        XCTAssertEqual(SharedCache.complicationPick(from: all, selectedINE: "A", activeINE: "B", now: now)?.ine, "A")
    }

    func testFallsBackToActiveWhenForcedPlaceHasNoCurrentHourData() {
        let now = Date()
        let all = [snap("A", wind: nil, updated: now), snap("B", wind: 12, updated: now)]
        XCTAssertEqual(SharedCache.complicationPick(from: all, selectedINE: "A", activeINE: "B", now: now)?.ine, "B")
    }

    func testKeepsForcedPlaceWhenActiveIsNoBetter() {
        let now = Date()
        let all = [snap("A", wind: nil, updated: now), snap("B", wind: nil, updated: now)]
        XCTAssertEqual(SharedCache.complicationPick(from: all, selectedINE: "A", activeINE: "B", now: now)?.ine, "A")
    }

    func testNoForcedPlaceUsesActiveThenFirst() {
        let now = Date()
        let all = [snap("A", wind: 10, updated: now), snap("B", wind: 12, updated: now)]
        XCTAssertEqual(SharedCache.complicationPick(from: all, selectedINE: nil, activeINE: "B", now: now)?.ine, "B")
        XCTAssertEqual(SharedCache.complicationPick(from: all, selectedINE: "", activeINE: nil, now: now)?.ine, "A")
        XCTAssertNil(SharedCache.complicationPick(from: [], selectedINE: "A", activeINE: "B", now: now))
    }
}
