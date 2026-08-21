import XCTest
@testable import AuraKit

final class AirQualityTests: XCTestCase {

    // A slice of the real MITECO ica-ultima-hora.csv shape: header + active/inactive rows, a full-data
    // and a partial (×10) index, a no-data (0) row, and an inactive row.
    private let csv = """
    cod_estacion,nombre,tipo,latitud,longitud,activa,fecha,indice,debido_a
    28079035,PLAZA DEL CARMEN,FONDO,40.41932,-3.70237,true,2026-08-21T08:00:00,20,O3
    28079004,RETIRO,FONDO,40.41467,-3.68258,true,2026-08-21T08:00:00,2,O3
    28079008,ESCUELAS AGUIRRE,TRAFICO,40.42167,-3.68232,true,2026-08-21T08:00:00,0,NO2
    08019004,BARCELONA EIXAMPLE,TRAFICO,41.38539,2.15382,true,2026-08-21T08:00:00,3,PM10
    99999999,APAGADA,FONDO,40.0,-3.0,false,2026-08-21T08:00:00,1,O3
    """

    func testParseKeepsOnlyActiveStationsWithData() {
        let stations = MitecoAirQuality.parse(csv)
        // Drops the inactive station and the índice-0 (no-data) row.
        XCTAssertEqual(stations.count, 3)
        XCTAssertFalse(stations.contains { $0.name == "APAGADA" })
        XCTAssertFalse(stations.contains { $0.name == "ESCUELAS AGUIRRE" })
    }

    func testNearestPicksClosestAndDecodesFullCategory() {
        let stations = MitecoAirQuality.parse(csv)
        // A point right by El Retiro.
        let aq = MitecoAirQuality.nearest(toLatitude: 40.4145, longitude: -3.6830, in: stations)
        XCTAssertEqual(aq?.station, "Retiro")           // title-cased from RETIRO
        XCTAssertEqual(aq?.category, 2)
        XCTAssertEqual(aq?.partial, false)
        XCTAssertEqual(aq?.pollutant, "O3")
        XCTAssertEqual(aq?.categoryName, "Razonablemente buena")
        XCTAssertEqual(aq?.pollutantLabel, "O₃")
        XCTAssertLessThan(aq?.distanceKm ?? .infinity, 1)
    }

    func testPartialIndexIsCategoryTimesTen() {
        let stations = MitecoAirQuality.parse(csv)
        // A point right by Plaza del Carmen (índice 20 = category 2, partial).
        let aq = MitecoAirQuality.nearest(toLatitude: 40.4193, longitude: -3.7024, in: stations)
        XCTAssertEqual(aq?.station, "Plaza Del Carmen")
        XCTAssertEqual(aq?.category, 2)
        XCTAssertEqual(aq?.partial, true)
    }

    func testNearestIsNilWithNoStations() {
        XCTAssertNil(MitecoAirQuality.nearest(toLatitude: 40, longitude: -3, in: []))
    }
}
