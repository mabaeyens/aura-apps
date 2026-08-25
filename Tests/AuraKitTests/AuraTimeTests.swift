import XCTest
@testable import AuraKit

/// M2 coverage for `AuraTime.hourLabel`, the hand-rolled 12/24-hour formatter that feeds every hourly
/// strip across phone, widget and watch. A wraparound bug at midnight or noon would mislabel every hour
/// app-wide, and nothing caught it before.
final class AuraTimeTests: XCTestCase {

    override func tearDown() {
        // Restore the pristine default (unset = 24 h) so no other test sees a stray preference.
        SharedCache.groupDefaults?.removeObject(forKey: AuraTime.use24hKey)
        super.tearDown()
    }

    func testHourLabel24Hour() {
        AuraTime.use24h = true
        XCTAssertEqual(AuraTime.hourLabel(hour: 0), "0h")
        XCTAssertEqual(AuraTime.hourLabel(hour: 9), "9h")
        XCTAssertEqual(AuraTime.hourLabel(hour: 13), "13h")
        XCTAssertEqual(AuraTime.hourLabel(hour: 23), "23h")
    }

    func testHourLabel12Hour() throws {
        AuraTime.use24h = false
        // If the App Group defaults aren't writable in this sandbox the getter pins to the 24 h default;
        // skip rather than fail spuriously on the 12 h branch.
        try XCTSkipUnless(AuraTime.use24h == false, "App Group defaults not writable in this environment")

        XCTAssertEqual(AuraTime.hourLabel(hour: 0), "12 AM")   // midnight wraps to 12, not 0
        XCTAssertEqual(AuraTime.hourLabel(hour: 9), "9 AM")
        XCTAssertEqual(AuraTime.hourLabel(hour: 12), "12 PM")  // noon stays 12 and flips to PM
        XCTAssertEqual(AuraTime.hourLabel(hour: 13), "1 PM")
        XCTAssertEqual(AuraTime.hourLabel(hour: 23), "11 PM")
    }
}
