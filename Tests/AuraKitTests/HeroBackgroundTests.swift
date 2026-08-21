import XCTest
@testable import AuraKit

final class HeroBackgroundTests: XCTestCase {

    // MARK: The 8×6 grid

    func testGridIsFortyEightCanonicalNames() {
        XCTAssertEqual(HeroBackground.allAssetNames.count, 48)
        XCTAssertEqual(Set(HeroBackground.allAssetNames).count, 48, "names must be unique")
        XCTAssertTrue(HeroBackground.allAssetNames.contains("few_clouds_dawn"))
        XCTAssertTrue(HeroBackground.allAssetNames.contains("clear_night"))
        XCTAssertTrue(HeroBackground.allAssetNames.contains("stormy_afternoon"))
    }

    // MARK: Resolver chain

    func testExactMatchWins() {
        let have: Set = ["clear_noon", "clear_dawn"]
        XCTAssertEqual(HeroBackground.resolve(sky: .clear, time: .noon, available: have), "clear_noon")
    }

    func testNearestTimeSameCondition() {
        // noon missing; morning (distance 1) beats night (distance 3).
        let have: Set = ["clear_morning", "clear_night"]
        XCTAssertEqual(HeroBackground.resolve(sky: .clear, time: .noon, available: have), "clear_morning")
    }

    func testNearestWrapsAroundTheDay() {
        // night missing; dawn is a neighbour of night across the cycle.
        let have: Set = ["clear_dawn"]
        XCTAssertEqual(HeroBackground.resolve(sky: .clear, time: .night, available: have), "clear_dawn")
    }

    func testNeverBorrowsAnotherCondition() {
        // Only rainy art exists; a clear sky must not use it — it falls to procedural (nil).
        let have: Set = ["rainy_noon", "rainy_dawn"]
        XCTAssertNil(HeroBackground.resolve(sky: .clear, time: .noon, available: have))
    }

    func testUnknownSkyIsProcedural() {
        let have = Set(HeroBackground.allAssetNames)
        XCTAssertNil(HeroBackground.resolve(sky: .unknown, time: .noon, available: have))
    }

    func testEmptyBundleIsProcedural() {
        XCTAssertNil(HeroBackground.resolve(sky: .clear, time: .noon, available: []))
    }

    func testConditionTokens() {
        XCTAssertEqual(HeroBackground.Condition(.clouds)?.rawValue, "cloudy")
        XCTAssertEqual(HeroBackground.Condition(.fewClouds)?.rawValue, "few_clouds")
        XCTAssertEqual(HeroBackground.Condition(.rain)?.rawValue, "rainy")
        XCTAssertNil(HeroBackground.Condition(.unknown))
    }

    // MARK: Time buckets from the sun path

    private func at(_ h: Int, _ m: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())!
    }

    func testTimeBucketsTrackTheSun() {
        let sunrise = at(7), sunset = at(21)   // a 14-hour day
        XCTAssertEqual(HeroBackground.Time(now: at(7, 20), sunrise: sunrise, sunset: sunset), .dawn)
        XCTAssertEqual(HeroBackground.Time(now: at(10),    sunrise: sunrise, sunset: sunset), .morning)
        XCTAssertEqual(HeroBackground.Time(now: at(14),    sunrise: sunrise, sunset: sunset), .noon)
        XCTAssertEqual(HeroBackground.Time(now: at(18, 30), sunrise: sunrise, sunset: sunset), .afternoon)
        XCTAssertEqual(HeroBackground.Time(now: at(20, 40), sunrise: sunrise, sunset: sunset), .dusk)
        XCTAssertEqual(HeroBackground.Time(now: at(23),    sunrise: sunrise, sunset: sunset), .night)
    }

    func testTimeBucketWithoutSunTimesIsNoon() {
        XCTAssertEqual(HeroBackground.Time(now: at(3), sunrise: nil, sunset: nil), .noon)
    }
}
