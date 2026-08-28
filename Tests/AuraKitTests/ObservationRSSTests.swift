import XCTest
@testable import AuraKit

/// Pins `ObservationRSS.latestUpdate`, which reads AEMET's keyless observation RSS notifier for the newest
/// "Última actualización" publish time. These are the same vectors as aura-android's `ObservationRssTest`
/// (unified-freshness spec): the shared vectors are the parity enforcement, so iOS and Android read the marker
/// identically. Each `<item>`'s `<description>` is a small JSON blob carrying the ISO timestamp with a `+0200`
/// offset, and the channel wraps them newest-first.
final class ObservationRSSTests: XCTestCase {

    private func feed(_ descriptions: String...) -> Data {
        let items = descriptions.map { desc in
            "<item><title>Actualización</title><description>\(desc)</description>"
                + "<pubDate>Fri, 28 Aug 2026 11:31:59 +0200</pubDate></item>"
        }.joined()
        let xml = #"<?xml version="1.0" encoding="UTF-8"?>"#
            + "<rss version=\"2.0\"><channel><title>Observación convencional</title>\(items)</channel></rss>"
        return Data(xml.utf8)
    }

    private func update(_ iso: String) -> String { #"{"Última actualización": "\#(iso)"}"# }

    private func utc(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    func testParsesTheIsoOffsetTimestamp() {
        // 11:31:59 +0200 == 09:31:59 UTC.
        XCTAssertEqual(ObservationRSS.latestUpdate(feed(update("2026-08-28T11:31:59+0200"))),
                       utc("2026-08-28T09:31:59Z"))
    }

    func testTakesTheMaxRegardlessOfItemOrder() {
        // Items deliberately out of newest-first order: the max must win, not the first.
        let data = feed(update("2026-08-28T02:32:25+0200"),
                        update("2026-08-28T11:31:59+0200"),
                        update("2026-08-28T10:31:54+0200"))
        XCTAssertEqual(ObservationRSS.latestUpdate(data), utc("2026-08-28T09:31:59Z"))
    }

    func testSkipsUnparseableItemsButKeepsGoodOnes() {
        let data = feed(#"{"Última actualización": "not a date"}"#,
                        update("2026-08-28T10:31:54+0200"))
        XCTAssertEqual(ObservationRSS.latestUpdate(data), utc("2026-08-28T08:31:54Z"))
    }

    func testNullWhenNoItemCarriesATimestamp() {
        XCTAssertNil(ObservationRSS.latestUpdate(feed(update(""))))
        XCTAssertNil(ObservationRSS.latestUpdate(feed("no timestamp here")))
    }

    func testNullOnEmptyOrMalformedXml() {
        XCTAssertNil(ObservationRSS.latestUpdate(Data()))
        XCTAssertNil(ObservationRSS.latestUpdate(Data("<rss><channel>".utf8)))
        XCTAssertNil(ObservationRSS.latestUpdate(Data("not xml at all".utf8)))
    }
}
