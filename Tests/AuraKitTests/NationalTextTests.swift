import XCTest
@testable import AuraKit

/// The national text products (spec: aura-apps/specs/national-text-forecast.md). The day products
/// (hoy/manana/pasadomanana) share the community bulletin's A.-/B.- skeleton, so `AEMETBulletinParser.parse`
/// reuses unchanged. The medium range is a different document with no A.-/B.- sections: one free-narrative
/// block per day under a `DÍA NN (WEEKDAY)` header, split by `parseMedioplazo`. The header format was locked
/// from live AEMET samples on 2026-08-29.
final class NationalTextTests: XCTestCase {

    /// A national day bulletin parses through the shared community parser: phenomena section A and the
    /// narrative section B, exactly as the CCAA bulletin does.
    func testNationalDayBulletinReusesCommunityParser() throws {
        let raw = """
        AGENCIA ESTATAL DE METEOROLOGÍA
        PREDICCIÓN GENERAL PARA ESPAÑA
        DÍA 30 DE AGOSTO DE 2026 A LAS 09:00 HORA OFICIAL
        PREDICCIÓN VÁLIDA PARA EL DOMINGO 30

        A.- FENÓMENOS SIGNIFICATIVOS
        Tormentas fuertes en el nordeste peninsular.

        B.- PREDICCIÓN
        Una vaguada atlántica cruza la Península.
        Cielos nubosos con chubascos en el tercio norte.
        """
        let bulletin = try XCTUnwrap(AEMETBulletinParser.parse(raw))
        XCTAssertEqual(bulletin.fenomenoSignificativo, "Tormentas fuertes en el nordeste peninsular.")
        XCTAssertTrue(bulletin.texto.contains("vaguada atlántica"))
        XCTAssertNotNil(bulletin.elaborado)
        XCTAssertNotNil(bulletin.validezInicio)
    }

    /// "No se esperan." in section A resolves to a nil phenomenon, so the banner hides — same as CCAA.
    func testNationalNoPhenomenaIsNil() throws {
        let raw = """
        AGENCIA ESTATAL DE METEOROLOGÍA
        PREDICCIÓN GENERAL PARA ESPAÑA
        DÍA 30 DE AGOSTO DE 2026 A LAS 09:00 HORA OFICIAL
        PREDICCIÓN VÁLIDA PARA EL DOMINGO 30

        A.- FENÓMENOS SIGNIFICATIVOS
        No se esperan.

        B.- PREDICCIÓN
        Estabilidad generalizada.
        """
        let bulletin = try XCTUnwrap(AEMETBulletinParser.parse(raw))
        XCTAssertNil(bulletin.fenomenoSignificativo)
    }

    /// The medium range splits into one dated block per day on the locked `DÍA NN (WEEKDAY)` header, the
    /// weekday capitalised for display and each block's narrative kept with its day.
    func testMedioplazoSplitsPerDay() throws {
        let raw = """
        AGENCIA ESTATAL DE METEOROLOGÍA
        PREDICCIÓN GENERAL DE MEDIO PLAZO PARA ESPAÑA
        DÍA 30 DE AGOSTO DE 2026 A LAS 12:00 HORA OFICIAL
        PREDICCIÓN VÁLIDA PARA LOS DÍAS 1 Y 2 DE SEPTIEMBRE DE 2026

        DÍA 01 (MARTES)
         Predominio de cielos poco nubosos. Temperaturas en ascenso.

        DÍA 02 (MIÉRCOLES)
         Aumento de la nubosidad en el norte, con posibles lluvias.
        """
        let forecast = try XCTUnwrap(AEMETBulletinParser.parseMedioplazo(raw))
        XCTAssertEqual(forecast.days.count, 2)
        XCTAssertEqual(forecast.days[0].day, 1)
        XCTAssertEqual(forecast.days[0].weekday, "Martes")
        XCTAssertTrue(forecast.days[0].texto.contains("Predominio de cielos poco nubosos"))
        XCTAssertEqual(forecast.days[1].day, 2)
        XCTAssertEqual(forecast.days[1].weekday, "Miércoles")
        XCTAssertTrue(forecast.days[1].texto.contains("Aumento de la nubosidad"))
        XCTAssertNotNil(forecast.elaborado)
        XCTAssertNotNil(forecast.validez)
    }

    /// A document with no `DÍA NN` block (an unexpected layout) yields nil, so the caller drops the segment.
    func testMedioplazoWithoutDayBlocksIsNil() {
        let raw = """
        AGENCIA ESTATAL DE METEOROLOGÍA
        PREDICCIÓN GENERAL DE MEDIO PLAZO PARA ESPAÑA
        DÍA 30 DE AGOSTO DE 2026 A LAS 12:00 HORA OFICIAL
        """
        XCTAssertNil(AEMETBulletinParser.parseMedioplazo(raw))
    }

    /// `ForecastBulletin` and `MedioplazoForecast` round-trip through Codable, since the service caches the
    /// parsed structs to disk as JSON.
    func testModelsRoundTripThroughCodable() throws {
        let bulletin = ForecastBulletin(elaborado: Date(timeIntervalSince1970: 1_756_540_800),
                                        validezInicio: Date(timeIntervalSince1970: 1_756_540_800),
                                        validezFin: nil, fenomenoSignificativo: "Tormentas.",
                                        texto: "Cielos nubosos.")
        let decoded = try JSONDecoder().decode(ForecastBulletin.self,
                                               from: try JSONEncoder().encode(bulletin))
        XCTAssertEqual(decoded.texto, bulletin.texto)
        XCTAssertEqual(decoded.fenomenoSignificativo, bulletin.fenomenoSignificativo)

        let medio = MedioplazoForecast(elaborado: Date(timeIntervalSince1970: 1_756_540_800),
                                       validez: "PREDICCIÓN VÁLIDA PARA LOS DÍAS 1 Y 2",
                                       days: [.init(day: 1, weekday: "Martes", texto: "Sol.")])
        let decodedMedio = try JSONDecoder().decode(MedioplazoForecast.self,
                                                    from: try JSONEncoder().encode(medio))
        XCTAssertEqual(decodedMedio.days.first?.weekday, "Martes")
        XCTAssertEqual(decodedMedio.validez, medio.validez)
    }
}
