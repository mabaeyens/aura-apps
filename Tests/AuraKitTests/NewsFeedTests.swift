import XCTest
@testable import AuraKit

/// The Noticias stream draws from two feeds with different quirks: RTVE is UTF-8 with English RFC-822
/// dates and per-item image enclosures; AEMET is ISO-8859-15 with Spanish day/month names and no
/// seconds. These lock the parser, the locale-aware date handling, and the round-robin merge.
final class NewsFeedTests: XCTestCase {

    private func t(_ s: Double) -> Date { Date(timeIntervalSince1970: s) }

    // A trimmed RTVE payload: UTF-8, English date, an image enclosure, and channel-level fields that
    // must NOT be mistaken for an item.
    private let rtveXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0"><channel>
      <title>El tiempo</title>
      <link>https://api.rtve.es/api/programas/821</link>
      <pubDate>Fri, 21 Aug 2026 03:58:33 GMT</pubDate>
      <item>
        <enclosure url="https://img.rtve.es/a.jpg" length="1" type="image/jpeg"/>
        <title>Bajada de temperaturas y tormentas</title>
        <link>https://www.rtve.es/noticias/1.shtml</link>
        <pubDate>Fri, 21 Aug 2026 03:58:33 GMT</pubDate>
      </item>
      <item>
        <title>Calor intenso en el este</title>
        <link>https://www.rtve.es/noticias/2.shtml</link>
        <pubDate>Wed, 19 Aug 2026 06:00:00 GMT</pubDate>
      </item>
    </channel></rss>
    """

    func testParsesRTVEItemsAndSkipsChannel() {
        let items = NewsFeed.parse(Data(rtveXML.utf8), source: .rtve)
        XCTAssertEqual(items.count, 2, "two <item>s parsed; the channel title/link/pubDate are ignored")
        XCTAssertEqual(items.first?.title, "Bajada de temperaturas y tormentas")
        XCTAssertEqual(items.first?.link.absoluteString, "https://www.rtve.es/noticias/1.shtml")
        XCTAssertEqual(items.first?.imageURL?.absoluteString, "https://img.rtve.es/a.jpg")
        XCTAssertEqual(items.first?.source, .rtve)
        XCTAssertNil(items.last?.imageURL, "the second item has no enclosure")
    }

    // AEMET: ISO-8859-15 bytes with an accented character, a Spanish date and no seconds.
    func testAEMETEncodingAndSpanishDate() {
        let xml = """
        <?xml version="1.0" encoding="ISO-8859-15"?>
        <rss><channel><item>
          <title>Predicción para la Península</title>
          <link>https://www.aemet.es/es/noticias/x</link>
          <pubDate>lun, 10 ago 2026 06:41 +0000</pubDate>
        </item></channel></rss>
        """
        // Encode as Latin-1 so "ó" becomes the single byte 0xF3, matching the declared 8-bit encoding.
        let data = xml.data(using: .isoLatin1)!
        let items = NewsFeed.parse(data, source: .aemet)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.title, "Predicción para la Península",
                       "XMLParser honours the ISO-8859-15 prolog; accents survive")
        XCTAssertNotNil(items.first?.date, "the Spanish RFC-822 date (no seconds) parses")
    }

    // Meteored (tiempo.com) and the AEMET blog are WordPress: the <title> — and here the <link> — arrive
    // wrapped in CDATA. The parser must unwrap CDATA or every item lands title-less and is dropped, which
    // is exactly what left the feed showing only RTVE + AEMET before the fix.
    func testParsesCDATAWrappedTitles() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel>
          <title>Meteored España</title>
          <item>
            <title><![CDATA[España afectada: 10 días de batalla entre masas de aire]]></title>
            <link><![CDATA[https://www.tiempo.com/noticias/uno.html]]></link>
            <pubDate>Fri, 21 Aug 2026 11:51:35 +0000</pubDate>
          </item>
          <item>
            <title><![CDATA[El calor vuelve la semana que viene]]></title>
            <link>https://www.tiempo.com/noticias/dos.html</link>
            <pubDate>Thu, 20 Aug 2026 09:00:00 +0000</pubDate>
          </item>
        </channel></rss>
        """
        let items = NewsFeed.parse(Data(xml.utf8), source: .meteored)
        XCTAssertEqual(items.count, 2, "both CDATA-titled items survive")
        XCTAssertEqual(items.first?.title, "España afectada: 10 días de batalla entre masas de aire")
        XCTAssertEqual(items.first?.link.absoluteString, "https://www.tiempo.com/noticias/uno.html",
                       "a CDATA-wrapped <link> is unwrapped too")
        XCTAssertEqual(items.first?.source, .meteored)
    }

    // RTVE publishes ~one bulletin a day but its feed carries ~20; the source is capped to its 3 most
    // recent so it can't flood the merged stream with backlog. The uncapped sources keep everything.
    func testRTVECappedToThreeMostRecent() {
        // Eight daily bulletins, newest (21 Aug) first, one day apart going back.
        let days = ["Fri, 21", "Thu, 20", "Wed, 19", "Tue, 18",
                    "Mon, 17", "Sun, 16", "Sat, 15", "Fri, 14"]
        let itemsXML = days.enumerated().map { i, day in
            let date = "\(day) Aug 2026 06:00:00 GMT"
            return "<item><title>bulletin \(i)</title>"
                + "<link>https://www.rtve.es/\(i).shtml</link>"
                + "<pubDate>\(date)</pubDate></item>"
        }.joined()
        let xml = "<rss><channel>" + itemsXML + "</channel></rss>"
        let items = NewsFeed.parse(Data(xml.utf8), source: .rtve)
        XCTAssertEqual(items.count, 3, "RTVE trimmed to its 3 newest items")
        XCTAssertEqual(items.map(\.title), ["bulletin 0", "bulletin 1", "bulletin 2"],
                       "the three kept are the most recent, newest first")
    }

    func testRFC822BothLocales() {
        XCTAssertNotNil(NewsFeed.parseRFC822("Fri, 21 Aug 2026 03:58:33 GMT"))
        XCTAssertNotNil(NewsFeed.parseRFC822("lun, 10 ago 2026 06:41 +0000"))
        XCTAssertNil(NewsFeed.parseRFC822("not a date"))
        XCTAssertNil(NewsFeed.parseRFC822(""))
    }

    // A flood from one source must not crowd out the other: the merge takes each source's newest, then
    // each source's second-newest, and so on, so both are represented even when counts are lopsided.
    func testMergeRoundRobinAvoidsSingleSourceDomination() {
        let flood = (0..<15).map {
            NewsItem(title: "aemet\($0)", link: URL(string: "https://a/\($0)")!,
                     source: .aemet, date: t(2_000 + Double($0)))   // newest = highest index
        }
        let rtve = (0..<3).map {
            NewsItem(title: "rtve\($0)", link: URL(string: "https://r/\($0)")!,
                     source: .rtve, date: t(1_000 + Double($0)))
        }
        let merged = NewsFeed.merge([flood, rtve], limit: 20)

        XCTAssertEqual(merged.count, 18, "15 + 3 available, under the 20 cap")
        XCTAssertEqual(Set(merged.filter { $0.source == .rtve }).count, 3,
                       "all three RTVE items survive despite the AEMET flood")
        // Stream is time-descending.
        XCTAssertEqual(merged, merged.sorted { $0.date > $1.date })
    }

    func testMergeCutsToLimit() {
        let a = (0..<30).map {
            NewsItem(title: "a\($0)", link: URL(string: "https://a/\($0)")!,
                     source: .aemet, date: t(Double($0)))
        }
        let b = (0..<30).map {
            NewsItem(title: "b\($0)", link: URL(string: "https://b/\($0)")!,
                     source: .rtve, date: t(100 + Double($0)))
        }
        let merged = NewsFeed.merge([a, b], limit: 20)
        XCTAssertEqual(merged.count, 20)
        XCTAssertTrue(merged.contains { $0.source == .aemet } && merged.contains { $0.source == .rtve },
                      "both sources present even at the cap")
    }
}
