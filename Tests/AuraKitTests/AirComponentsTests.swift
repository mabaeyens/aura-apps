import XCTest
@testable import AuraKit

/// The per-pollutant breakdown comes from MITECO's backend `sql1` query: 24 hourly rows per pollutant,
/// each with a raw `valor_medido` and a `dato_medido` validity flag. These lock the "latest valid hour
/// per pollutant, omit the unmeasured" rule (item 5) and the display formatting, against captured shapes.
final class AirComponentsTests: XCTestCase {

    private func parse(_ json: String) -> [AirComponent] {
        MitecoAirQuality.parseComponents(Data(json.utf8))
    }

    // A traffic station: only NO₂ is measured; every other pollutant is null/unvalidated all day. The
    // breakdown must carry NO₂ alone — never a fabricated zero for O₃/PM/SO₂.
    func testOnlyMeasuredPollutantsSurvive() {
        let json = """
        [{"hora":8,"magnitud":"NO2","valor_medido":22,"dato_medido":true,"valor_media_movil":null,"dato_medido_mm":false},
         {"hora":9,"magnitud":"NO2","valor_medido":27,"dato_medido":true,"valor_media_movil":null,"dato_medido_mm":false},
         {"hora":9,"magnitud":"O3","valor_medido":null,"dato_medido":false,"valor_media_movil":null,"dato_medido_mm":false},
         {"hora":9,"magnitud":"PM10","valor_medido":null,"dato_medido":false,"valor_media_movil":null,"dato_medido_mm":false},
         {"hora":9,"magnitud":"SO2","valor_medido":null,"dato_medido":false,"valor_media_movil":null,"dato_medido_mm":false}]
        """
        let comps = parse(json)
        XCTAssertEqual(comps.map(\.pollutant), ["NO2"], "only the measured pollutant appears")
        XCTAssertEqual(comps.first?.value, 27, "the latest valid hour (9), not an earlier one, is taken")
    }

    // A background station reporting all five. Order must be the canonical NO₂, O₃, PM2.5, PM10, SO₂
    // (applied by AirQuality.init), and each value the latest validated hour.
    func testFullBreakdownLatestHourAndOrder() {
        let json = """
        [{"hora":9,"magnitud":"SO2","valor_medido":4,"dato_medido":true,"valor_media_movil":null,"dato_medido_mm":false},
         {"hora":9,"magnitud":"PM10","valor_medido":3,"dato_medido":true,"valor_media_movil":3.5,"dato_medido_mm":true},
         {"hora":9,"magnitud":"PM2.5","valor_medido":1,"dato_medido":true,"valor_media_movil":null,"dato_medido_mm":false},
         {"hora":9,"magnitud":"O3","valor_medido":60,"dato_medido":true,"valor_media_movil":63,"dato_medido_mm":true},
         {"hora":8,"magnitud":"NO2","valor_medido":9,"dato_medido":true,"valor_media_movil":null,"dato_medido_mm":false},
         {"hora":9,"magnitud":"NO2","valor_medido":3,"dato_medido":true,"valor_media_movil":null,"dato_medido_mm":false}]
        """
        let aq = AirQuality(category: 1, partial: false, pollutant: "O3",
                            station: "Valderejo", distanceKm: 5, measured: Date(),
                            components: parse(json))
        XCTAssertEqual(aq.components.map(\.pollutant), ["NO2", "O3", "PM2.5", "PM10", "SO2"])
        XCTAssertEqual(aq.components.first { $0.pollutant == "NO2" }?.value, 3, "latest hour wins over hour 8")
        XCTAssertEqual(aq.components.first { $0.pollutant == "O3" }?.value, 60,
                       "the raw valor_medido, not the moving average, is used")
    }

    // An invalid latest hour must not shadow an earlier valid one.
    func testInvalidHourDoesNotShadowValid() {
        let json = """
        [{"hora":8,"magnitud":"NO2","valor_medido":22,"dato_medido":true,"valor_media_movil":null,"dato_medido_mm":false},
         {"hora":9,"magnitud":"NO2","valor_medido":99,"dato_medido":false,"valor_media_movil":null,"dato_medido_mm":false}]
        """
        let comps = parse(json)
        XCTAssertEqual(comps.map(\.pollutant), ["NO2"])
        XCTAssertEqual(comps.first?.value, 22, "the hour-9 row is unvalidated (dato_medido false) and skipped")
    }

    func testEmptyAndMalformed() {
        XCTAssertTrue(parse("[]").isEmpty)
        XCTAssertTrue(parse("not json").isEmpty)
        XCTAssertTrue(parse("Consulta incorrecta").isEmpty, "the backend's error string is not JSON")
    }

    // Spanish decimal comma; whole numbers show no decimals.
    func testValueTextFormatting() {
        XCTAssertEqual(AirComponent(pollutant: "PM10", value: 12.5).valueText, "12,5")
        XCTAssertEqual(AirComponent(pollutant: "NO2", value: 27).valueText, "27")
        XCTAssertEqual(AirComponent(pollutant: "O3", value: 60.0).valueText, "60")
    }

    // The request body must keep a literal "sql=" separator and escape the value's '#', space and ':'.
    // Encoding the whole "sql=…" string (the original bug) turns '=' into %3D, and the backend then
    // answers "Consulta incorrecta" — the card silently loses its breakdown.
    func testRequestBodyKeepsLiteralSeparator() {
        let body = MitecoAirQuality.requestBody(code: 1055001, day: "20260821")
        let s = String(decoding: body ?? Data(), as: UTF8.self)
        XCTAssertTrue(s.hasPrefix("sql=sql1"), "the 'sql=' separator stays literal, not %3D-encoded")
        XCTAssertFalse(s.contains("%3D"), "the '=' must never be percent-encoded")
        XCTAssertFalse(s.contains("#"), "the '#' delimiters must be escaped to %23")
        XCTAssertFalse(s.contains(" "), "the space must be escaped to %20")
        XCTAssertTrue(s.contains("%231055001%23"), "station code sits between escaped '#' delimiters")
    }

    func testLabels() {
        XCTAssertEqual(AirComponent(pollutant: "NO2", value: 1).label, "NO₂")
        XCTAssertEqual(AirComponent(pollutant: "O3", value: 1).label, "O₃")
        XCTAssertEqual(AirComponent(pollutant: "PM2.5", value: 1).label, "PM2,5")
        XCTAssertEqual(AirComponent(pollutant: "SO2", value: 1).label, "SO₂")
    }
}
