import XCTest
@testable import AuraKit

/// AEMET's hourly `vientoAndRachaMax` interleaves two entry kinds under the same `periodo`: a wind
/// reading (`direccion`+`velocidad`) and a peak-gust reading (a scalar `value`). The gust entries were
/// dropped until now; these lock the discriminator and the per-hour extraction into `HourSlot.windGust`.
final class WindGustTests: XCTestCase {

    private let madrid = TimeZone(identifier: "Europe/Madrid")!

    /// Decode one `Dia` from an AEMET-shaped payload with mixed wind + gust entries at 10h and 11h,
    /// plus an 11h with no gust (to prove absence stays nil, not fabricated as 0).
    private func decodeDia() throws -> MunicipioHourly.Dia {
        let json = """
        {
          "fecha": "2026-08-21T00:00:00",
          "temperatura": [{"value":"22","periodo":"10"},{"value":"24","periodo":"11"}],
          "estadoCielo": [{"value":"11","periodo":"10"},{"value":"11","periodo":"11"}],
          "humedadRelativa": [{"value":"50","periodo":"10"},{"value":"48","periodo":"11"}],
          "probPrecipitacion": [{"value":"0","periodo":"0612"}],
          "vientoAndRachaMax": [
            {"direccion":["NO"],"velocidad":["20"],"periodo":"10"},
            {"value":"45","periodo":"10"},
            {"direccion":["N"],"velocidad":["15"],"periodo":"11"}
          ]
        }
        """
        return try JSONDecoder().decode(MunicipioHourly.Dia.self, from: Data(json.utf8))
    }

    // The scalar `value` entry is a gust; the `velocidad` entry is wind. They must not be confused.
    func testWindAndGustEntriesDecodeDistinctly() throws {
        let dia = try decodeDia()
        let entries = dia.vientoAndRachaMax ?? []
        let wind = entries.first { $0.velocidad != nil }
        let gust = entries.first { $0.value != nil && $0.velocidad == nil }

        XCTAssertEqual(wind?.velocidad?.first, "20")
        XCTAssertEqual(wind?.direccion?.first, "NO")
        XCTAssertNil(wind?.value, "a wind entry carries no scalar value")
        XCTAssertEqual(gust?.value, "45")
        XCTAssertNil(gust?.velocidad, "a gust entry carries no velocidad")
    }

    // `slots` lifts the gust into the matching hour, and leaves hours without a gust reading nil.
    func testSlotsSurfaceGustPerHour() throws {
        let dia = try decodeDia()
        let slots = WeatherSnapshot.slots(for: dia, timeZone: madrid)

        let h10 = slots.first { $0.hour == 10 }
        let h11 = slots.first { $0.hour == 11 }
        XCTAssertEqual(h10?.windSpeed, 20)
        XCTAssertEqual(h10?.windGust, 45, "the 10h gust is surfaced alongside its wind speed")
        XCTAssertEqual(h11?.windSpeed, 15)
        XCTAssertNil(h11?.windGust, "no gust reported at 11h stays nil, not 0")
    }
}
