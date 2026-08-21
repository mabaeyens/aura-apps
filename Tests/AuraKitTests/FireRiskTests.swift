import XCTest
@testable import AuraKit

final class FireRiskTests: XCTestCase {
    private func fwi(_ v: Double) -> FireRisk { FireRisk(fwi: v, measured: Date(timeIntervalSince1970: 0)) }

    func testDangerClassBoundaries() {
        // Classic EFFIS breakpoints: <5.2, <11.2, <21.3, <38.0, <50.0, else.
        XCTAssertEqual(fwi(0).dangerClass, 1)
        XCTAssertEqual(fwi(5.1).dangerClass, 1)
        XCTAssertEqual(fwi(5.2).dangerClass, 2)
        XCTAssertEqual(fwi(11.2).dangerClass, 3)
        XCTAssertEqual(fwi(21.3).dangerClass, 4)
        XCTAssertEqual(fwi(38.0).dangerClass, 5)
        XCTAssertEqual(fwi(50.0).dangerClass, 6)
        XCTAssertEqual(fwi(120).dangerClass, 6)
    }

    func testCategoryNames() {
        XCTAssertEqual(fwi(2).categoryName, "Muy bajo")
        XCTAssertEqual(fwi(8).categoryName, "Bajo")
        XCTAssertEqual(fwi(15).categoryName, "Moderado")
        XCTAssertEqual(fwi(30).categoryName, "Alto")
        XCTAssertEqual(fwi(45).categoryName, "Muy alto")
        XCTAssertEqual(fwi(60).categoryName, "Extremo")
    }

    func testParseFWIFromRealResponse() {
        // The exact table shape GWIS returns (confirmed live for Madrid).
        let html = """
        <H2>Fire Danger</H2>
        <table id="main">
        <tr><td>Fire Weather Index (FWI)</td><td>45.129936</td></tr>
        <tr><td>Danger Index</td><td>5</td></tr>
        </table>
        """
        XCTAssertEqual(EFFISFireRisk.parseFWI(html), 45.129936)
    }

    func testParseFWIMissingRowIsNil() {
        // A no-data pixel / out-of-window date returns HTML without the FWI row.
        XCTAssertNil(EFFISFireRisk.parseFWI("<H2>Fire Danger</H2><table></table>"))
        XCTAssertNil(EFFISFireRisk.parseFWI(""))
    }

    func testRequestURLShape() {
        let url = EFFISFireRisk.requestURL(latitude: 40.4168, longitude: -3.7038,
                                           date: Date(timeIntervalSince1970: 0))
        let s = url!.absoluteString
        XCTAssertTrue(s.contains("REQUEST=GetFeatureInfo"))
        XCTAssertTrue(s.contains("LAYERS=ecmwf.query"))
        XCTAssertTrue(s.contains("INFO_FORMAT=text/html"))
        XCTAssertTrue(s.contains("TIME=1970-01-01"))
        // Centre pixel of a 101×101 image samples the coordinate.
        XCTAssertTrue(s.contains("I=50"))
        XCTAssertTrue(s.contains("J=50"))
    }
}
