import XCTest
@testable import AuraKit

/// The hourly strip is filtered to the current hour at *build* time, but a snapshot is often served
/// from cache hours (or a day) later. `upcomingHours(now:)` re-anchors it to the real current hour at
/// display time, so a snapshot built at 20:00 never shows 20h when it's opened at 09:55 the next day.
final class UpcomingHoursTests: XCTestCase {

    private let madrid = TimeZone(identifier: "Europe/Madrid")!

    /// An absolute instant at hour `h` on `day` (Madrid civil time).
    private func at(_ day: DateComponents, _ h: Int) -> Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = madrid
        var c = day; c.hour = h; c.minute = 0
        return cal.date(from: c)!
    }

    /// A snapshot whose stored strip begins at `firstHour` on `firstDay` and runs forward, each slot
    /// carrying its absolute date — the shape `make` produces from a build at that hour.
    private func snapshot(firstDay: DateComponents, firstHour: Int, count: Int) -> WeatherSnapshot {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = madrid
        let start = at(firstDay, firstHour)
        let hours = (0..<count).map { i -> HourSlot in
            let date = cal.date(byAdding: .hour, value: i, to: start)!
            return HourSlot(hour: cal.component(.hour, from: date), temp: 20, sky: "11",
                            precipProb: 0, date: date)
        }
        return WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                               tempMin: 10, tempMax: 20, humedadMax: 50,
                               sunrise: nil, sunset: nil, hours: hours, updated: start)
    }

    // Built at 20:00 yesterday, opened at 09:55 today: the strip must start at 09h, not 20h.
    func testReanchorsStaleOvernightSnapshot() {
        let yesterday = DateComponents(year: 2026, month: 8, day: 20)
        let today = DateComponents(year: 2026, month: 8, day: 21)
        let snap = snapshot(firstDay: yesterday, firstHour: 20, count: 28)   // 20h → next-day 23h

        let strip = snap.upcomingHours(now: at(today, 9) .addingTimeInterval(55 * 60), timeZone: madrid)

        XCTAssertEqual(strip.first?.hour, 9, "the current hour leads the strip")
        XCTAssertFalse(strip.contains { $0.date! < at(today, 9) }, "no hour before the current hour survives")
    }

    // The current hour itself is kept as the first column, not dropped in favour of the next hour.
    func testKeepsCurrentHourFirst() {
        let today = DateComponents(year: 2026, month: 8, day: 21)
        let snap = snapshot(firstDay: today, firstHour: 6, count: 18)
        let strip = snap.upcomingHours(now: at(today, 10).addingTimeInterval(30 * 60), timeZone: madrid)
        XCTAssertEqual(strip.first?.hour, 10)
    }

    // Snapshots cached before slots carried a date decode as nil dates — keep the stored order untouched.
    func testNilDatesFallBackToStoredOrder() {
        let hours = [HourSlot(hour: 20, temp: 20, sky: "11", precipProb: 0),
                     HourSlot(hour: 21, temp: 19, sky: "11", precipProb: 0)]
        let snap = WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                                   tempMin: 10, tempMax: 20, humedadMax: 50,
                                   sunrise: nil, sunset: nil, hours: hours, updated: Date())
        let strip = snap.upcomingHours(now: Date(), timeZone: madrid)
        XCTAssertEqual(strip.map(\.hour), [20, 21])
    }
}
