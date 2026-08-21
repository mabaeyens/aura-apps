import XCTest
@testable import AuraKit

final class HeroBackgroundTests: XCTestCase {

    // MARK: The 8×6 grid, across families

    func testGridIsCanonicalNames() {
        // Two families × 8 conditions × 6 times = 96, all unique; 48 per family.
        XCTAssertEqual(HeroBackground.allAssetNames.count, 96)
        XCTAssertEqual(Set(HeroBackground.allAssetNames).count, 96, "names must be unique")
        XCTAssertEqual(HeroBackground.assetNames(for: .landscape).count, 48)
        XCTAssertEqual(HeroBackground.assetNames(for: .cityscape).count, 48)
        // Landscape names stay bare (no prefix — existing assets never rename); cityscape is prefixed.
        XCTAssertTrue(HeroBackground.allAssetNames.contains("few_clouds_dawn"))
        XCTAssertTrue(HeroBackground.allAssetNames.contains("clear_night"))
        XCTAssertTrue(HeroBackground.allAssetNames.contains("city_stormy_afternoon"))
        XCTAssertFalse(HeroBackground.assetNames(for: .landscape).contains { $0.hasPrefix("city_") })
        XCTAssertTrue(HeroBackground.assetNames(for: .cityscape).allSatisfy { $0.hasPrefix("city_") })
    }

    // MARK: Family axis

    func testCityscapeResolvesWithinItsFamily() {
        let have: Set = ["city_clear_noon", "clear_noon"]
        XCTAssertEqual(HeroBackground.resolve(sky: .clear, time: .noon, family: .cityscape, available: have),
                       "city_clear_noon")
        XCTAssertEqual(HeroBackground.resolve(sky: .clear, time: .noon, family: .landscape, available: have),
                       "clear_noon")
    }

    func testFamilyNeverLeaksAcross() {
        // Only landscape art exists; selecting cityscape must fall to procedural, not borrow landscape.
        let have = Set(HeroBackground.assetNames(for: .landscape))
        XCTAssertNil(HeroBackground.resolve(sky: .clear, time: .noon, family: .cityscape, available: have))
    }

    func testCityscapeNearestTimeStaysInFamily() {
        // city noon missing; nearest city time wins, never the landscape noon that does exist.
        let have: Set = ["city_clear_morning", "clear_noon"]
        XCTAssertEqual(HeroBackground.resolve(sky: .clear, time: .noon, family: .cityscape, available: have),
                       "city_clear_morning")
    }

    func testFamilyStorageDecodeFallsBackToLandscape() {
        XCTAssertEqual(HeroBackground.Family(storage: "cityscape"), .cityscape)
        XCTAssertEqual(HeroBackground.Family(storage: "landscape"), .landscape)
        XCTAssertEqual(HeroBackground.Family(storage: nil), .landscape)
        XCTAssertEqual(HeroBackground.Family(storage: "bogus"), .landscape)
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
