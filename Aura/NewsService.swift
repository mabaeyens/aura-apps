import AuraKit
import Foundation

/// Fetches the "Noticias" stream — several public weather RSS feeds (RTVE, AEMET, Meteored, AEMET Blog,
/// see `NewsSource`) — merged into one recency-sorted list and cached on disk with a 30-minute TTL.
/// Separate from the AEMET forecast refresh: these are public RSS feeds on other hosts, so they don't
/// count against AEMET's request budget. iOS only.
enum NewsService {
    /// News turns over far more slowly than weather; a 30-minute cache is plenty and keeps the feeds light.
    private static let ttl: TimeInterval = 30 * 60
    private static let limit = 20

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("news.json")
    }

    /// The merged headline stream, served from a ≤30-min disk cache or fetched fresh. Returns whatever it
    /// has (possibly stale, possibly empty) rather than throwing — a miss simply drops the news card.
    static func latest(force: Bool = false) async -> [NewsItem] {
        if !force, let cached = cached(maxAge: ttl) { return cached }

        let groups = await withTaskGroup(of: [NewsItem].self) { group -> [[NewsItem]] in
            for source in NewsSource.allCases { group.addTask { await fetch(source) } }
            var all: [[NewsItem]] = []
            for await items in group { all.append(items) }
            return all
        }

        let merged = NewsFeed.merge(groups, limit: limit)
        if merged.isEmpty { return cached(maxAge: .infinity) ?? [] }   // network failed: any stale beats none
        if let data = try? JSONEncoder().encode(merged) { try? data.write(to: cacheURL) }
        return merged
    }

    private static func fetch(_ source: NewsSource) async -> [NewsItem] {
        do {
            let (data, response) = try await URLSession.shared.data(from: source.feedURL)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            return NewsFeed.parse(data, source: source)
        } catch {
            return []
        }
    }

    private static func cached(maxAge: TimeInterval) -> [NewsItem]? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: cacheURL.path),
              let modified = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modified) < maxAge,
              let data = try? Data(contentsOf: cacheURL),
              let items = try? JSONDecoder().decode([NewsItem].self, from: data) else { return nil }
        return items
    }
}
