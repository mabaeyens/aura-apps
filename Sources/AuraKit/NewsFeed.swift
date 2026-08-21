import Foundation

/// A single-stream "Noticias" feed drawn from a few official Spanish sources (RTVE's weather desk and
/// AEMET). The model, RSS parsing and the round-robin merge live here in AuraKit so they can be unit
/// tested without networking; the app layer (`NewsService`) does the actual fetching and caching.

/// Where a headline came from. Each case carries its public RSS feed and a short display label.
public enum NewsSource: String, Sendable, Codable, CaseIterable {
    case rtve
    case aemet

    /// Short label shown on the headline row, e.g. "RTVE".
    public var displayName: String {
        switch self {
        case .rtve:  return "RTVE"
        case .aemet: return "AEMET"
        }
    }

    /// The source's RSS feed. RTVE serves UTF-8; AEMET serves ISO-8859-15 (XMLParser honours the
    /// prolog's `encoding=`, so both decode without manual re-encoding).
    public var feedURL: URL {
        switch self {
        case .rtve:  return URL(string: "https://www.rtve.es/api/tematicas/821/noticias.rss")!
        case .aemet: return URL(string: "https://www.aemet.es/es/noticias.rss")!
        }
    }
}

/// One headline: title, article link, its source, publication date, and an optional image URL.
public struct NewsItem: Identifiable, Sendable, Hashable, Codable {
    public let title: String
    public let link: URL
    public let source: NewsSource
    public let date: Date
    public let imageURL: URL?

    public var id: URL { link }

    public init(title: String, link: URL, source: NewsSource, date: Date, imageURL: URL? = nil) {
        self.title = title
        self.link = link
        self.source = source
        self.date = date
        self.imageURL = imageURL
    }
}

public enum NewsFeed {
    /// Parse one source's RSS payload into items, dropping any entry missing a title, a valid link or a
    /// parseable date (AEMET's *publicaciones* feed, for instance, has empty titles — excluded upstream,
    /// but this stays defensive).
    public static func parse(_ data: Data, source: NewsSource) -> [NewsItem] {
        RSSParser().parse(data).compactMap { raw in
            let title = raw.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty,
                  let link = URL(string: raw.link.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let date = parseRFC822(raw.pubDate) else { return nil }
            let image = raw.imageURL.flatMap { URL(string: $0) }
            return NewsItem(title: title, link: link, source: source, date: date, imageURL: image)
        }
    }

    /// Merge per-source items into one stream that is recency-sorted yet never single-source dominated.
    /// Selection is round-robin by rank — each source's newest, then each source's second-newest, … —
    /// so a source that floods (e.g. an eclipse news burst) can't crowd the others out; the selected set
    /// is then sorted by date for a clean time-descending stream, and cut to `limit`.
    public static func merge(_ groups: [[NewsItem]], limit: Int = 20) -> [NewsItem] {
        let ranked = groups.map { $0.sorted { $0.date > $1.date } }
        var selected: [NewsItem] = []
        var rank = 0
        outer: while selected.count < limit {
            var addedAny = false
            for group in ranked where rank < group.count {
                selected.append(group[rank])
                addedAny = true
                if selected.count >= limit { break outer }
            }
            if !addedAny { break }
            rank += 1
        }
        return selected.sorted { $0.date > $1.date }
    }

    /// Parse an RFC-822 `pubDate`. RTVE sends English month/day names ("Fri, 21 Aug 2026 03:58:33 GMT");
    /// AEMET sends Spanish ones with no seconds ("lun, 10 ago 2026 06:41 +0000"). Tries the plausible
    /// locale/format combinations and returns the first that parses.
    static func parseRFC822(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, dd MMM yyyy HH:mm Z",
            "EEE, dd MMM yyyy HH:mm zzz",
        ]
        let locales = [Locale(identifier: "en_US_POSIX"), Locale(identifier: "es_ES")]
        let formatter = DateFormatter()
        for locale in locales {
            formatter.locale = locale
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: value) { return date }
            }
        }
        return nil
    }
}

/// Minimal RSS 2.0 item extractor, built on the same `XMLParserDelegate` pattern as `CAPParser`.
/// Captures only inside `<item>` elements, so channel-level `<title>`/`<link>`/`<pubDate>` are ignored;
/// namespaced tags (AEMET's `<atom:link>`) don't match the bare names and are skipped too.
final class RSSParser: NSObject, XMLParserDelegate {
    struct RawItem {
        var title = ""
        var link = ""
        var pubDate = ""
        var imageURL: String?
    }

    private var items: [RawItem] = []
    private var current: RawItem?
    private var text = ""

    func parse(_ data: Data) -> [RawItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        text = ""
        if elementName == "item" { current = RawItem(); return }
        // Prefer an image enclosure for the optional thumbnail (RTVE attaches one per item).
        if elementName == "enclosure", current != nil, let url = attributes["url"],
           (attributes["type"] ?? "").hasPrefix("image") || current?.imageURL == nil {
            current?.imageURL = url
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        // Some feeds wrap fields in CDATA; we only need plain-text fields, so ignore CDATA payloads.
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        defer { text = "" }
        guard current != nil else { return }
        switch elementName {
        case "title":   current?.title += text
        case "link":    current?.link += text
        case "pubDate": current?.pubDate += text
        case "item":    if let item = current { items.append(item) }; current = nil
        default:        break
        }
    }
}
