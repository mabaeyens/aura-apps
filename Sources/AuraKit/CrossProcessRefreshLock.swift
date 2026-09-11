import Foundation

/// Keeps the app and the widget extension from ever running `AuraRefreshCore.refresh` at the same time.
///
/// `AEMETService`'s `RefreshGate` actor only coalesces calls *within one process* — it can't see the widget
/// extension, which is a separate OS process with its own address space and its own copy of every Swift
/// static. Live device logs caught the gap directly: iOS routinely wakes the widget extension's timeline
/// reloads and the app's `BGAppRefreshTask` in the same second (both are "good time to do background work"
/// decisions made from the same signal), so both independently called `AuraRefreshCore.refresh` at once —
/// for the app, every favourite; for the widget, whichever location it's pinned to. AEMET's rate limiter
/// rejected the pile-up outright (`ClientError.rateLimited`, "Espera, necesito un minuto"), so the very
/// refresh that should have caught up an overnight-stale cache failed instead. Two processes writing
/// `SharedCache`'s snapshot file at once is also a plain read-modify-write race independent of AEMET.
///
/// The fix is a non-blocking advisory lock (`flock`) on a file in the shared App Group container, which
/// (unlike an in-process actor or lock) is visible to both processes. Whoever gets there first refreshes
/// and, on a real change, calls `WidgetCenter.reloadAllTimelines()`; the loser skips its own fetch and
/// shows whatever's cached — which is about to be replaced by the winner's reload anyway.
enum CrossProcessRefreshLock {
    private static let fileName = "refresh.lock"

    /// Runs `body` only while holding the lock, or returns nil immediately if another process already
    /// holds it — this never blocks, since a widget extension can't afford to wait out another process's
    /// refresh inside its own tight execution window. `force` (a manual pull-to-refresh) retries a few
    /// times over well under a second before giving up, so an explicit user gesture only loses to a
    /// same-instant background collision in the rare worst case, rather than silently no-op'ing.
    static func tryRun<T>(force: Bool = false, _ body: () async -> T) async -> T? {
        guard let url = SharedCache.groupContainerURL?.appendingPathComponent(fileName) else {
            // No App Group container reachable (shouldn't happen with the entitlement in place) — fail
            // open rather than silently dropping every refresh in a state that's already broken.
            return await body()
        }
        let attempts = force ? 4 : 1
        for attempt in 1...attempts {
            if let fd = acquire(at: url) {
                defer { flock(fd, LOCK_UN); close(fd) }
                return await body()
            }
            if attempt < attempts { try? await Task.sleep(nanoseconds: 200_000_000) }
        }
        return nil
    }

    /// Opens (creating if needed) and non-blockingly locks the file, returning its descriptor on success
    /// or nil if another process holds it (or the open/lock call itself failed).
    private static func acquire(at url: URL) -> Int32? {
        let fd = open(url.path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return nil }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return nil
        }
        return fd
    }
}
