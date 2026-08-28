import Foundation

/// Reads AEMET's keyless observation RSS (`obsconv_hh_opendata_todos_RSS.xml`) and returns the newest publish
/// time. This feed is a *freshness notifier*, never a data source: it says when AEMET last refreshed the
/// conventional-observation dataset, so the app can decide whether the keyed `/observacion/convencional/todas`
/// download is worth making, without spending a keyed call to find out.
///
/// Each `<item>` carries `<description>{"Última actualización": "2026-08-28T11:31:59+0200"}</description>`.
/// That publish time is stamped ~30 min after the hour (11:31 for the 11:00 readings), so it is a DIFFERENT
/// clock from the observation `fint` (top of the hour). The two must never be compared against each other: the
/// publish time drives fetch cadence (compared RSS-to-RSS), the `fint` drives the display gate and station
/// selection. See the unified-freshness design (shared with aura-android's `ObservationRss`).
///
/// The timestamp is pulled out with a shape-matching regex rather than by decoding the description: the key
/// carries a non-ASCII accent (charset-fragile across the ISO-8859 payloads AEMET serves), while the timestamp
/// itself is pure ASCII, so matching it directly is the robust choice. iOS scans the whole decoded payload for
/// the ISO-instant shape rather than walking the DOM: that shape appears only inside `<description>` (the
/// `<pubDate>` is RFC-822, "Fri, 28 Aug 2026 …", which the pattern cannot match), so a direct scan yields the
/// same result on every real and test feed while avoiding an XML parser on untrusted keyless input.
public enum ObservationRSS {

    // e.g. "2026-08-28T11:31:59+0200" — the offset has no colon, so it needs the `Z` pattern, not ISO8601.
    private static let isoInstant = try! NSRegularExpression(
        pattern: #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4}"#)

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"   // "…+0200"
        return f
    }()

    /// The newest "Última actualización" across all items, or nil when the payload can't be decoded or carries
    /// no usable timestamp. Takes the maximum rather than trusting the feed's newest-first ordering, so a
    /// reordered feed can't return a stale marker.
    public static func latestUpdate(_ data: Data) -> Date? {
        guard !data.isEmpty else { return nil }
        // The ISO timestamps are pure ASCII, so the decode charset can't change the match; UTF-8 with an
        // ISO-8859 fallback for AEMET's legacy payloads.
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        var latest: Date?
        for match in isoInstant.matches(in: text, range: range) {
            guard let matchRange = Range(match.range, in: text),
                  let date = formatter.date(from: String(text[matchRange])) else { continue }
            if latest == nil || date > latest! { latest = date }
        }
        return latest
    }
}
