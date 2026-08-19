import XCTest
@testable import AuraKit

final class WindDirectionTests: XCTestCase {

    func testAbbreviations() {
        XCTAssertEqual(WindDirection.n.abbreviation, "N")
        XCTAssertEqual(WindDirection.ono.abbreviation, "ONO")
        XCTAssertEqual(WindDirection.sse.abbreviation, "SSE")
        XCTAssertEqual(WindDirection.o.abbreviation, "O")
    }

    func testSpanishNames() {
        XCTAssertEqual(WindDirection.ono.spanishName, "Oesnoroeste")
        XCTAssertEqual(WindDirection.nne.spanishName, "Nornordeste")
    }

    func testFromDegrees() {
        XCTAssertEqual(WindDirection(degrees: 0), .n)
        XCTAssertEqual(WindDirection(degrees: 90), .e)
        XCTAssertEqual(WindDirection(degrees: 180), .s)
        XCTAssertEqual(WindDirection(degrees: 270), .o)
        XCTAssertEqual(WindDirection(degrees: 292.5), .ono)
        XCTAssertEqual(WindDirection(degrees: 360), .n)
        XCTAssertEqual(WindDirection(degrees: -22.5), .nno)
        XCTAssertEqual(WindDirection(degrees: 11), .n)   // rounds down to N sector
        XCTAssertEqual(WindDirection(degrees: 12), .nne)  // rounds up to NNE
    }

    func testAllSixteenPresent() {
        XCTAssertEqual(WindDirection.allCases.count, 16)
        XCTAssertEqual(Set(WindDirection.allCases.map(\.abbreviation)).count, 16)
    }
}
