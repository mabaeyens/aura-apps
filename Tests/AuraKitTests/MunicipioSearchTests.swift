import XCTest
@testable import AuraKit

/// Ranked location search: the city itself must surface ahead of the rest of its province.
final class MunicipioSearchTests: XCTestCase {

    func testExactCityComesFirstNotTheWholeProvince() {
        let results = MunicipioDatabase.search("Zaragoza")
        XCTAssertEqual(results.first?.nombre, "Zaragoza")
        XCTAssertEqual(results.first?.provincia, "Zaragoza")
    }

    func testProvinceOnlyMatchesComeAfterNameMatches() {
        let results = MunicipioDatabase.search("Zaragoza", limit: 200)
        let firstProvinceOnly = results.firstIndex { !$0.nombre.foldedForSearch.contains("zaragoza") }
        let lastNameMatch = results.lastIndex { $0.nombre.foldedForSearch.contains("zaragoza") }
        if let firstProvinceOnly, let lastNameMatch {
            XCTAssertLessThan(lastNameMatch, firstProvinceOnly)
        }
    }

    func testAccentAndCaseInsensitive() {
        XCTAssertEqual(MunicipioDatabase.search("avila").first?.nombre, "Ávila")
        XCTAssertEqual(MunicipioDatabase.search("ÁVILA").first?.nombre, "Ávila")
    }

    func testCommaNarrowsToProvince() {
        let results = MunicipioDatabase.search("Zaragoza, Zaragoza")
        XCTAssertEqual(results.first?.nombre, "Zaragoza")
        XCTAssertTrue(results.allSatisfy { $0.provincia.foldedForSearch.contains("zaragoza") })
    }

    func testCommaWithDifferentProvinceExcludesOthers() {
        let results = MunicipioDatabase.search("Zaragoza, Huesca")
        XCTAssertFalse(results.contains { $0.nombre == "Zaragoza" && $0.provincia == "Zaragoza" })
    }

    func testLimitAndEmptyQuery() {
        XCTAssertLessThanOrEqual(MunicipioDatabase.search("a", limit: 10).count, 10)
        XCTAssertTrue(MunicipioDatabase.search("   ").isEmpty)
    }
}
