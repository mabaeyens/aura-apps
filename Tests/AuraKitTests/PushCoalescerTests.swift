import XCTest
@testable import AuraKit

final class PushCoalescerTests: XCTestCase {
    private let a = Data("context-a".utf8)
    private let b = Data("context-b".utf8)
    private let t0 = Date(timeIntervalSince1970: 1_000)

    func testFirstPushAlwaysSends() {
        var c = PushCoalescer()
        XCTAssertTrue(c.shouldSend(a, now: t0))
    }

    func testIdenticalPushInsideWindowIsDropped() {
        var c = PushCoalescer(window: 3)
        XCTAssertTrue(c.shouldSend(a, now: t0))
        XCTAssertFalse(c.shouldSend(a, now: t0.addingTimeInterval(0.5)))
        XCTAssertFalse(c.shouldSend(a, now: t0.addingTimeInterval(2.9)))
    }

    func testIdenticalPushAfterWindowSendsAgain() {
        var c = PushCoalescer(window: 3)
        XCTAssertTrue(c.shouldSend(a, now: t0))
        XCTAssertTrue(c.shouldSend(a, now: t0.addingTimeInterval(3.1)))
    }

    func testChangedPayloadSendsImmediately() {
        var c = PushCoalescer()
        XCTAssertTrue(c.shouldSend(a, now: t0))
        XCTAssertTrue(c.shouldSend(b, now: t0.addingTimeInterval(0.1)))
    }

    func testForceAlwaysSends() {
        var c = PushCoalescer()
        XCTAssertTrue(c.shouldSend(a, now: t0))
        XCTAssertTrue(c.shouldSend(a, now: t0.addingTimeInterval(0.1), force: true))
    }

    func testResetLetsTheSamePayloadRetry() {
        var c = PushCoalescer()
        XCTAssertTrue(c.shouldSend(a, now: t0))
        c.reset()
        XCTAssertTrue(c.shouldSend(a, now: t0.addingTimeInterval(0.1)))
    }
}
