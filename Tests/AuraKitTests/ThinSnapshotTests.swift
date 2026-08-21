import XCTest
@testable import AuraKit

/// `hasCurrentHourData` is the signal `WatchSync` uses to refuse overwriting a good cached snapshot
/// with a "thin" one — the shape the phone produces when the hourly fetch comes back empty (daily,
/// air quality and UV still populate, but the hero and wind rose have nothing to draw). These lock the
/// exact fields that count as current-hour data, so the guard can't silently start accepting a blank.
final class ThinSnapshotTests: XCTestCase {

    // A full snapshot — the current-hour fields are populated — carries current-hour data.
    func testFullSnapshotHasCurrentHourData() {
        XCTAssertTrue(WeatherSnapshot.preview.hasCurrentHourData)
    }

    // A snapshot built with an empty hourly feed: every current-hour field is nil, so it's "thin".
    // The daily outlook still being present must NOT make it look like it has current-hour data.
    func testThinSnapshotHasNoCurrentHourData() {
        let thin = WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                                   tempMin: 10, tempMax: 20, humedadMax: 50,
                                   currentTemp: nil, currentSky: nil, currentSkyText: nil,
                                   currentHumidity: nil, currentPrecipProb: nil,
                                   windSpeed: nil, windDirection: nil,
                                   sunrise: nil, sunset: nil,
                                   days: [DaySnapshot(date: Date(), min: 10, max: 20)],
                                   hours: [], updated: Date())
        XCTAssertFalse(thin.hasCurrentHourData, "all current-hour fields nil → thin")
        XCTAssertFalse(thin.days.isEmpty, "the daily outlook is still present in a thin snapshot")
    }

    // Any single current-hour field being present is enough to count as real data — a snapshot that
    // has, say, only wind must not be treated as thin and skipped.
    func testAnySingleCurrentHourFieldCounts() {
        func snap(windSpeed: Int? = nil, currentHumidity: Int? = nil,
                  currentTemp: Int? = nil, windDirection: WindDirection? = nil) -> WeatherSnapshot {
            WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                            tempMin: 10, tempMax: 20, humedadMax: 50,
                            currentTemp: currentTemp, currentHumidity: currentHumidity,
                            windSpeed: windSpeed, windDirection: windDirection,
                            sunrise: nil, sunset: nil, hours: [], updated: Date())
        }
        XCTAssertTrue(snap(windSpeed: 12).hasCurrentHourData)
        XCTAssertTrue(snap(currentHumidity: 40).hasCurrentHourData)
        XCTAssertTrue(snap(currentTemp: 22).hasCurrentHourData)
        XCTAssertTrue(snap(windDirection: .so).hasCurrentHourData)
    }
}
