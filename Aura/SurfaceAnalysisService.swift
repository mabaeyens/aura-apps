import AuraKit
import Foundation
import UIKit

/// Fetches AEMET's surface analysis chart (isobars, pressure centres, fronts), cached on disk with a
/// 12-hour TTL — the cadence AEMET reissues it (nominally 00 and 12 UTC). Like the radar service it's
/// lazy, app-process only, and its image bytes stay out of the App-Group snapshot. The heavy single-frame
/// GIF is stored rotated 90° counter-clockwise by AEMET, so it's decoded and turned once here into a plain
/// wide landscape image. Cache files are named by issue slot, so keeping a short history later is trivial.
enum SurfaceAnalysisService {
    /// A decoded surface analysis map: the already-upright landscape image and its nominal issue time.
    struct Frame {
        let image: UIImage
        let issue: Date
    }

    /// The chart is reissued every ~12 h; don't re-fetch inside that window.
    private static let ttl: TimeInterval = 12 * 60 * 60

    private static let cachePrefix = "surface-"

    private static func cacheURL(slot: String) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("\(cachePrefix)\(slot).img")
    }

    /// The latest surface analysis map, served from disk when the fetch marker is inside the 12-h window,
    /// otherwise fetched fresh. Returns nil only when there's no key/network AND nothing cached to fall
    /// back on — the card then simply doesn't appear. `force` bypasses the freshness gate (pull-to-refresh).
    static func frame(force: Bool = false) async -> Frame? {
        let issue = nominalIssue()
        let url = cacheURL(slot: slotString(issue))

        // Inside the 12-h window with the current slot on disk: serve it, zero AEMET calls.
        if !force,
           let last = SharedCache.lastSurfaceAnalysisFetch,
           Date().timeIntervalSince(last) < ttl,
           let cached = loadFrame(at: url, issue: issue) {
            return cached
        }
        guard let client = AEMETService.client() else {
            return newestCachedFrame()   // offline: any stale map beats none
        }
        do {
            let data = try await client.surfaceAnalysis()
            guard let image = decodeRotated(data) else { return newestCachedFrame() }
            try? data.write(to: url)                       // cache the RAW bytes, keyed by issue slot
            SharedCache.lastSurfaceAnalysisFetch = Date()
            return Frame(image: image, issue: issue)
        } catch {
            return newestCachedFrame()
        }
    }

    /// Delete surface maps left in the Caches directory that are older than `maxAge` (default 3 days).
    /// The live TTL is 12 h and only the latest is shown, so older slots are dead weight; the OS purges
    /// Caches under pressure anyway. Safe to call on launch; silently ignores a missing directory.
    static func pruneCache(olderThan maxAge: TimeInterval = 3 * 24 * 60 * 60) {
        let fm = FileManager.default
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        guard let files = try? fm.contentsOfDirectory(at: dir,
                                                      includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        for file in files where file.lastPathComponent.hasPrefix(cachePrefix) {
            guard let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  modified < cutoff else { continue }
            try? fm.removeItem(at: file)
        }
    }

    // MARK: - Cache reads

    /// Decode and rotate the raw bytes cached at `url`, tagged with `issue`. Nil if absent or undecodable.
    private static func loadFrame(at url: URL, issue: Date) -> Frame? {
        guard let data = try? Data(contentsOf: url), let image = decodeRotated(data) else { return nil }
        return Frame(image: image, issue: issue)
    }

    /// The newest surface map still on disk, whatever its age — the offline / fetch-failed fallback. Its
    /// issue time is recovered from the filename slot, falling back to the file's modification date.
    private static func newestCachedFrame() -> Frame? {
        let fm = FileManager.default
        let dir = fm.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        guard let files = try? fm.contentsOfDirectory(at: dir,
                                                      includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        let maps = files.filter { $0.lastPathComponent.hasPrefix(cachePrefix) }
        let newest = maps.max { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return da < db
        }
        guard let url = newest, let data = try? Data(contentsOf: url), let image = decodeRotated(data) else { return nil }
        let issue = issue(fromSlotFile: url) ?? modificationDate(of: url) ?? Date()
        return Frame(image: image, issue: issue)
    }

    // MARK: - Decode + rotate

    /// `UIImage(data:)` decodes the single-frame GIF fine; rotate it 90° clockwise once so everything
    /// downstream is a plain wide, upright landscape image (AEMET ships it rotated onto its side).
    private static func decodeRotated(_ data: Data) -> UIImage? {
        guard let raw = UIImage(data: data) else { return nil }
        return rotatedClockwise(raw)
    }

    /// Redraw `image` rotated 90° clockwise into a new bitmap with width and height swapped. Rendered at
    /// scale 1 to keep the source's pixel dimensions (no Retina upscale of a ~2000×1400 chart). In
    /// UIGraphicsImageRenderer's flipped (y-down) space a positive angle rotates clockwise; if a device
    /// check ever shows the map mirrored or upside down, flip the sign of the angle.
    private static func rotatedClockwise(_ image: UIImage) -> UIImage {
        let size = image.size
        let rotatedSize = CGSize(width: size.height, height: size.width)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: rotatedSize, format: format)
        return renderer.image { context in
            let cg = context.cgContext
            cg.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
            cg.rotate(by: .pi / 2)
            image.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2,
                                  width: size.width, height: size.height))
        }
    }

    // MARK: - Issue slot helpers

    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }()

    private static let slotFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = utcCalendar
        f.timeZone = utcCalendar.timeZone
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMddHH"
        return f
    }()

    /// The most recent nominal issue boundary (00 or 12 UTC) at or before `date`. The API envelope
    /// doesn't cleanly expose the real issue time, so the freshness line is anchored to this slot.
    private static func nominalIssue(at date: Date = Date()) -> Date {
        let comps = utcCalendar.dateComponents([.year, .month, .day, .hour], from: date)
        var slot = DateComponents()
        slot.year = comps.year; slot.month = comps.month; slot.day = comps.day
        slot.hour = (comps.hour ?? 0) >= 12 ? 12 : 0
        slot.minute = 0; slot.second = 0
        return utcCalendar.date(from: slot) ?? date
    }

    private static func slotString(_ date: Date) -> String { slotFormatter.string(from: date) }

    /// Recover the issue date encoded in a `surface-YYYYMMDDHH.img` filename.
    private static func issue(fromSlotFile url: URL) -> Date? {
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix(cachePrefix) else { return nil }
        return slotFormatter.date(from: String(name.dropFirst(cachePrefix.count)))
    }

    private static func modificationDate(of url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }
}
