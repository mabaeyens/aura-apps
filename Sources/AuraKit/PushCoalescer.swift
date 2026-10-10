import Foundation

/// Drops a Watch push that repeats the previous one inside a short window. One refresh pass can reach
/// `WatchSync.send` two or three times (scene-active evaluation plus the foreground pass) with the same
/// ~18 KB context; the system keeps only the newest anyway, so the extra sends are pure traffic.
/// Not thread-safe by itself: `WatchSync` serialises access.
struct PushCoalescer {
    private var lastFingerprint: Int?
    private var lastSent: Date?
    let window: TimeInterval

    init(window: TimeInterval = 3) { self.window = window }

    /// True when `payload` should go out. A changed payload, an expired window or `force` always sends.
    mutating func shouldSend(_ payload: Data, now: Date = Date(), force: Bool = false) -> Bool {
        let fingerprint = payload.hashValue
        if !force, fingerprint == lastFingerprint, let lastSent, now.timeIntervalSince(lastSent) < window {
            return false
        }
        lastFingerprint = fingerprint
        lastSent = now
        return true
    }

    /// Forget the last push, so the next one always goes out (e.g. after the system rejected an update).
    mutating func reset() {
        lastFingerprint = nil
        lastSent = nil
    }
}
