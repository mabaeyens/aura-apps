import XCTest
@testable import AuraKit

/// Coverage for the extended `StationObservation` fields (wind, pressure, precipitation) added so the app
/// can show which metrics the resolving station actually reports, plus the `[Location]` decode contract the
/// bundled `municipios.json` relies on.
final class StationMetricsTests: XCTestCase {

    // MARK: - Extended observation decode

    func testDecodesExtendedObservationFields() throws {
        let json = """
        [{"idema":"3195","ubi":"MADRID RETIRO","lat":40.41,"lon":-3.68,
          "ta":21.4,"hr":55,"vv":3.2,"dv":225,"pres":940.5,"prec":0.2,
          "fint":"2026-08-25T11:00:00+0000"}]
        """.data(using: .utf8)!
        let station = try JSONDecoder().decode([StationObservation].self, from: json)[0]
        XCTAssertEqual(station.vv, 3.2)
        XCTAssertEqual(station.dv, 225)
        XCTAssertEqual(station.pres, 940.5)
        XCTAssertEqual(station.prec, 0.2)
        XCTAssertEqual(station.availableMetrics,
                       [.temperature, .wind, .humidity, .pressure, .precipitation])
    }

    func testAvailableMetricsReflectsPresence() throws {
        // Only temperature and humidity reported — the "partial station" case.
        let json = """
        [{"idema":"9999","ubi":"PARCIAL","lat":40.0,"lon":-3.0,"ta":18.0,"hr":70,
          "fint":"2026-08-25T11:00:00+0000"}]
        """.data(using: .utf8)!
        let station = try JSONDecoder().decode([StationObservation].self, from: json)[0]
        XCTAssertEqual(station.availableMetrics, [.temperature, .humidity])
        XCTAssertFalse(station.availableMetrics.contains(.wind))
        XCTAssertFalse(station.availableMetrics.contains(.pressure))
    }

    func testMissingOptionalFieldsDoNotAbortDecode() throws {
        // One sparse record (only idema) must still decode alongside a full one — every field but idema
        // is optional, so a station that reports nothing this hour can't break the whole array.
        let json = """
        [{"idema":"AAAA"},
         {"idema":"BBBB","ubi":"OTRA","lat":41.0,"lon":-4.0,"ta":15.0,"vv":5.0,
          "fint":"2026-08-25T11:00:00+0000"}]
        """.data(using: .utf8)!
        let stations = try JSONDecoder().decode([StationObservation].self, from: json)
        XCTAssertEqual(stations.count, 2)
        XCTAssertEqual(stations[0].availableMetrics, [])
        XCTAssertEqual(stations[1].availableMetrics, [.temperature, .wind])
    }

    // MARK: - Display reading

    func testReadingConvertsAndRoundsForDisplay() throws {
        let json = """
        [{"idema":"3195","ubi":"MADRID RETIRO","lat":40.41,"lon":-3.68,
          "ta":21.4,"hr":54.6,"vv":3.2,"dv":225,"pres":940.5,"prec":0.2,
          "fint":"2026-08-25T11:00:00+0000"}]
        """.data(using: .utf8)!
        let reading = try JSONDecoder().decode([StationObservation].self, from: json)[0].reading
        XCTAssertEqual(reading.temperature, 21)          // 21.4 → 21
        XCTAssertEqual(reading.humidity, 55)             // 54.6 → 55
        XCTAssertEqual(reading.windKmh, 12)              // 3.2 m/s × 3.6 = 11.52 → 12
        XCTAssertEqual(reading.windDirection, .so)       // 225° → SO
        XCTAssertEqual(reading.pressure, 941)            // 940.5 → 941
        XCTAssertEqual(reading.precipMm, 0.2)            // mm passes through unrounded
    }

    func testReadingLeavesUnreportedMetricsNil() {
        // A station reporting only temperature and humidity: wind/pressure/rain must stay nil so the
        // card shows a dash rather than a fabricated 0.
        let station = StationObservation(idema: "9999", ubi: "PARCIAL", lat: 40.0, lon: -3.0,
                                         ta: 18.0, hr: 70, fint: "2026-08-25T11:00:00+0000")
        let reading = station.reading
        XCTAssertEqual(reading.temperature, 18)
        XCTAssertEqual(reading.humidity, 70)
        XCTAssertNil(reading.windKmh)
        XCTAssertNil(reading.windDirection)
        XCTAssertNil(reading.pressure)
        XCTAssertNil(reading.precipMm)
    }

    func testReadingCodableRoundTripInSnapshot() throws {
        // The reading rides in the App Group cache as part of the snapshot, so it must survive a Codable
        // round trip (older snapshots without it decode as nil — covered by the field being optional).
        let reading = ObservedReading(temperature: 24, humidity: 40, windKmh: 14,
                                      windDirection: .n, pressure: 1013, precipMm: 0)
        let decoded = try JSONDecoder().decode(ObservedReading.self,
                                               from: JSONEncoder().encode(reading))
        XCTAssertEqual(decoded, reading)
    }

    func testObservedMetricsCodableRoundTrip() throws {
        let metrics: ObservedMetrics = [.temperature, .wind, .pressure]
        let data = try JSONEncoder().encode(metrics)
        let decoded = try JSONDecoder().decode(ObservedMetrics.self, from: data)
        XCTAssertEqual(decoded, metrics)
    }

    func testDistanceKmFromLocation() {
        let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                              latitude: 40.4168, longitude: -3.7038)
        let station = StationObservation(idema: "3195", ubi: "MADRID RETIRO",
                                         lat: 40.4114, lon: -3.6782, ta: 22, hr: 50,
                                         fint: "2026-08-25T11:00:00+0000")
        let km = station.distanceKm(from: madrid)
        XCTAssertNotNil(km)
        XCTAssertEqual(km!, 2.2, accuracy: 0.6)   // Retiro sits ~2 km east of the city centroid
    }

    func testDistanceKmNilWithoutCoordinates() {
        let madrid = Location(ine: "28079", nombre: "Madrid", provincia: "Madrid",
                              latitude: 40.4168, longitude: -3.7038)
        let station = StationObservation(idema: "AAAA", ubi: nil, lat: nil, lon: nil,
                                         ta: nil, hr: nil, fint: nil)
        XCTAssertNil(station.distanceKm(from: madrid))
    }

    // MARK: - Municipality decode contract

    func testMunicipiosShapeDecodesIntoLocation() throws {
        // The bundled municipios.json is exactly this shape; the app decodes it straight into [Location].
        let json = """
        [{"ine":"44001","nombre":"Ababuj","provincia":"Teruel","latitude":40.54846,"longitude":-0.8078},
         {"ine":"28079","nombre":"Madrid","provincia":"Madrid","latitude":40.4654,"longitude":-3.6965}]
        """.data(using: .utf8)!
        let places = try JSONDecoder().decode([Location].self, from: json)
        XCTAssertEqual(places.count, 2)
        XCTAssertEqual(places[0].ine, "44001")
        XCTAssertEqual(places[0].nombre, "Ababuj")
        XCTAssertEqual(places[0].provinciaCode, "44")
        XCTAssertEqual(places[1].latitude, 40.4654, accuracy: 0.0001)
    }
}
