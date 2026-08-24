import XCTest
@testable import AuraKit

/// `activeAlert(at:)` is the render-time gate that stops a cached snapshot from flashing an aviso whose
/// window has already closed. An aviso is filtered for expiry only when it is *fetched*, but a fresh
/// favourite is not refetched for up to an hour, so its snapshot outlives the aviso. Every surface that
/// shows the warning must go through this rather than trust the raw `alert`. These lock that behaviour.
final class ActiveAlertTests: XCTestCase {

    private func snapshot(alert: WeatherAlert?) -> WeatherSnapshot {
        WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                        tempMin: 10, tempMax: 20, humedadMax: 50,
                        currentTemp: 18, currentHumidity: 40,
                        windSpeed: 12, windDirection: .so,
                        sunrise: nil, sunset: nil,
                        hours: [], alert: alert, updated: Date())
    }

    private func alert(level: WeatherAlert.Level, expires: Date?) -> WeatherAlert {
        WeatherAlert(level: level, event: "Aviso de lluvia", phenomenon: "Lluvia",
                     zona: "612801", areaDesc: "Madrid", onset: nil, expires: expires)
    }

    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    // An amber aviso whose `expires` is still ahead of `now` is surfaced.
    func testActiveAvisoIsSurfaced() {
        let snap = snapshot(alert: alert(level: .amarillo, expires: base.addingTimeInterval(3600)))
        XCTAssertNotNil(snap.activeAlert(at: base))
    }

    // The core fix: an aviso baked into the cache whose window has since closed is hidden, even though
    // the raw `alert` is still present on the snapshot.
    func testExpiredAvisoIsHidden() {
        let expired = alert(level: .naranja, expires: base.addingTimeInterval(-1))
        let snap = snapshot(alert: expired)
        XCTAssertNotNil(snap.alert, "the raw aviso is still cached on the snapshot")
        XCTAssertNil(snap.activeAlert(at: base), "but it must not surface once expired")
    }

    // Exactly at the expiry instant the aviso is still considered active (>= now).
    func testAvisoActiveAtExactExpiryInstant() {
        let snap = snapshot(alert: alert(level: .amarillo, expires: base))
        XCTAssertNotNil(snap.activeAlert(at: base))
    }

    // A green "aviso" (below amber) is not a real warning and never surfaces, expiry aside.
    func testGreenLevelNeverSurfaces() {
        let snap = snapshot(alert: alert(level: .verde, expires: base.addingTimeInterval(3600)))
        XCTAssertNil(snap.activeAlert(at: base))
    }

    // No `expires` means an open-ended warning — active until the app drops it.
    func testNilExpiryStaysActive() {
        let snap = snapshot(alert: alert(level: .rojo, expires: nil))
        XCTAssertNotNil(snap.activeAlert(at: base))
    }

    // No aviso at all → nil, not a crash.
    func testNoAvisoIsNil() {
        XCTAssertNil(snapshot(alert: nil).activeAlert(at: base))
    }
}
