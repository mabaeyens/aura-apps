import XCTest
@testable import AuraKit

/// M2 coverage for `BulletinText.sentences`, which reflows AEMET's hard-wrapped run-on "PREDICCIÓN"
/// paragraph into one line per sentence. AEMET writes decimals with commas and uses no mid-sentence
/// abbreviations, so ". " reliably ends a sentence; these lock that heuristic.
final class BulletinTextTests: XCTestCase {

    func testCollapsesHardWrapsAndSplitsSentences() {
        // AEMET bakes column wraps mid-sentence, sometimes with a leading space on the next line.
        let input = "Cielo poco nuboso.\nProbabilidad de\n lluvia por la tarde. Temperaturas en descenso."
        XCTAssertEqual(BulletinText.sentences(input), [
            "Cielo poco nuboso.",
            "Probabilidad de lluvia por la tarde.",
            "Temperaturas en descenso.",
        ])
    }

    func testDecimalCommasDoNotSplit() {
        // Decimals use commas, so a "." only ever ends a sentence, never a number.
        let input = "Máximas de 20,5 grados. Mínimas de 10,0."
        XCTAssertEqual(BulletinText.sentences(input), [
            "Máximas de 20,5 grados.",
            "Mínimas de 10,0.",
        ])
    }

    func testSingleSentenceWithoutTrailingSpace() {
        XCTAssertEqual(BulletinText.sentences("Cielo despejado en toda la comunidad."),
                       ["Cielo despejado en toda la comunidad."])
    }

    func testEmptyAndWhitespaceOnlyYieldNoLines() {
        XCTAssertEqual(BulletinText.sentences(""), [])
        XCTAssertEqual(BulletinText.sentences("   \n\t  \n"), [])
    }

    func testCollapsesTabsAndMultipleSpaces() {
        XCTAssertEqual(BulletinText.sentences("Viento\t\tflojo   variable."), ["Viento flojo variable."])
    }
}
