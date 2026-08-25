import XCTest
@testable import AuraKit

/// M2 coverage for `Comunidad.forProvincia`, the province → autonomous-community table that routes the
/// bulletin fetch and the "Predicción" screen. A missing or typo'd entry fails silently (no bulletin,
/// no crash), so the key guard is completeness: every one of Spain's 52 INE provinces must resolve.
final class ComunidadTests: XCTestCase {

    func testAllFiftyTwoProvincesResolve() {
        for n in 1...52 {
            let code = String(format: "%02d", n)
            let comunidad = Comunidad.forProvincia(code)
            XCTAssertNotNil(comunidad, "province \(code) has no community mapping")
            XCTAssertFalse(comunidad?.code.isEmpty ?? true, "province \(code) maps to an empty code")
            XCTAssertFalse(comunidad?.nombre.isEmpty ?? true, "province \(code) maps to an empty name")
        }
    }

    func testKnownMappings() {
        XCTAssertEqual(Comunidad.forProvincia("28")?.code, "mad")   // Madrid
        XCTAssertEqual(Comunidad.forProvincia("08")?.code, "cat")   // Barcelona → Cataluña
        XCTAssertEqual(Comunidad.forProvincia("01")?.code, "pva")   // Álava → País Vasco
        XCTAssertEqual(Comunidad.forProvincia("35")?.code, "coo")   // Las Palmas → Canarias
        XCTAssertEqual(Comunidad.forProvincia("38")?.code, "coo")   // Sta. Cruz de Tenerife → Canarias
        XCTAssertEqual(Comunidad.forProvincia("07")?.code, "bal")   // Illes Balears
        XCTAssertEqual(Comunidad.forProvincia("51")?.code, "ceu")   // Ceuta
        XCTAssertEqual(Comunidad.forProvincia("52")?.code, "mel")   // Melilla
    }

    func testUnknownProvinceReturnsNil() {
        for code in ["00", "53", "99", "1", "", "abc"] {
            XCTAssertNil(Comunidad.forProvincia(code), "unexpected mapping for \(code)")
        }
    }
}
