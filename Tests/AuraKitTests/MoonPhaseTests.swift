import XCTest
import SwiftUI
@testable import AuraKit

final class MoonPhaseTests: XCTestCase {

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
        var c = DateComponents()
        c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testReferenceNewMoonIsDark() {
        let p = MoonPhaseMath.fraction(for: MoonPhaseMath.referenceNewMoon)
        // At the reference instant we are exactly at new: fraction ~0, illumination ~0.
        XCTAssertLessThan(min(p, 1 - p), 0.01, "fraction should sit at the new-moon wrap point")
        XCTAssertLessThan(MoonPhaseMath.illumination(fraction: p), 0.01)
    }

    func testFullMoonRoughlyHalfCycleLater() {
        // Half a synodic month after the reference new moon is full.
        let full = MoonPhaseMath.referenceNewMoon
            .addingTimeInterval(MoonPhaseMath.synodicMonth / 2 * 86_400)
        let p = MoonPhaseMath.fraction(for: full)
        XCTAssertEqual(p, 0.5, accuracy: 0.01)
        XCTAssertGreaterThan(MoonPhaseMath.illumination(fraction: p), 0.99)
    }

    func testAug2026IsWaxingGibbousAround61Percent() {
        // Prototype-validated anchor: 21 Aug 2026 is a waxing moon ~61% lit.
        let p = MoonPhaseMath.fraction(for: date(2026, 8, 21))
        XCTAssertTrue(MoonPhaseMath.waxing(fraction: p), "21 Aug 2026 should be waxing")
        XCTAssertEqual(MoonPhaseMath.illumination(fraction: p), 0.61, accuracy: 0.12)
    }

    func testIlluminationSymmetryAroundFull() {
        // Illumination depends only on distance from full: p and (1 - p) match.
        for p in stride(from: 0.05, through: 0.45, by: 0.05) {
            XCTAssertEqual(MoonPhaseMath.illumination(fraction: p),
                           MoonPhaseMath.illumination(fraction: 1 - p),
                           accuracy: 1e-9)
        }
    }

    func testWaxingSplitsCycleAtFull() {
        XCTAssertTrue(MoonPhaseMath.waxing(fraction: 0.0))
        XCTAssertTrue(MoonPhaseMath.waxing(fraction: 0.49))
        XCTAssertFalse(MoonPhaseMath.waxing(fraction: 0.5))
        XCTAssertFalse(MoonPhaseMath.waxing(fraction: 0.99))
    }

    func testPhaseNamesAtPrincipalFractions() {
        XCTAssertEqual(MoonPhaseMath.phaseName(fraction: 0.0), "Luna nueva")
        XCTAssertEqual(MoonPhaseMath.phaseName(fraction: 0.25), "Cuarto creciente")
        XCTAssertEqual(MoonPhaseMath.phaseName(fraction: 0.5), "Luna llena")
        XCTAssertEqual(MoonPhaseMath.phaseName(fraction: 0.75), "Cuarto menguante")
        // The wrap: just shy of a full cycle rounds back to new.
        XCTAssertEqual(MoonPhaseMath.phaseName(fraction: 0.97), "Luna nueva")
    }

    func testNextNewMoonIsInTheFutureAndNew() {
        let from = date(2026, 8, 21)
        let next = MoonPhaseMath.nextNewMoon(from: from)
        XCTAssertGreaterThan(next, from)
        // Within a synodic month, and lands on new (illumination ~0).
        XCTAssertLessThanOrEqual(next.timeIntervalSince(from),
                                 MoonPhaseMath.synodicMonth * 86_400 + 1)
        let p = MoonPhaseMath.fraction(for: next)
        XCTAssertLessThan(MoonPhaseMath.illumination(fraction: p), 0.02)
    }

    func testNextFullMoonIsInTheFutureAndFull() {
        let from = date(2026, 8, 21)
        let next = MoonPhaseMath.nextFullMoon(from: from)
        XCTAssertGreaterThan(next, from)
        XCTAssertLessThanOrEqual(next.timeIntervalSince(from),
                                 MoonPhaseMath.synodicMonth * 86_400 + 1)
        let p = MoonPhaseMath.fraction(for: next)
        XCTAssertGreaterThan(MoonPhaseMath.illumination(fraction: p), 0.98)
    }

    func testNextFullMoonFromJustBeforeFullIsImminent() {
        // A day before the reference-anchored full moon, "next full" should be within ~2 days.
        let nearFull = MoonPhaseMath.referenceNewMoon
            .addingTimeInterval((MoonPhaseMath.synodicMonth / 2 - 1) * 86_400)
        let next = MoonPhaseMath.nextFullMoon(from: nearFull)
        XCTAssertLessThan(next.timeIntervalSince(nearFull), 2 * 86_400)
    }
}
