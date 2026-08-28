import SwiftUI

/// A dim, low-contrast staleness note for the roomy widget surfaces (the iPad rectangular slot, the Home
/// Screen tiles). It renders nothing while the snapshot is fresh, "actualizado HH:mm" while recent, and
/// "Desactualizado" past the ~24 h horizon — so a current widget stays unmarked and only an old one draws
/// the eye. Lock Screen desaturation is respected: the hierarchy is weight and opacity, never tint.
public struct AuraStalenessNote: View {
    let snapshot: WeatherSnapshot
    var now: Date
    var timeZone: TimeZone

    public init(snapshot: WeatherSnapshot, now: Date = Date(),
                timeZone: TimeZone = TimeZone(identifier: "Europe/Madrid") ?? .current) {
        self.snapshot = snapshot
        self.now = now
        self.timeZone = timeZone
    }

    public var body: some View {
        if let label = snapshot.stalenessLabel(at: now, timeZone: timeZone) {
            let hard = snapshot.freshness(at: now) == .stale
            Label(label, systemImage: hard ? "wifi.slash" : "clock.arrow.circlepath")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(hard ? 0.9 : 0.6)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

/// The space-free staleness signal for the tight faces (the iPhone rectangular slot, circular glances,
/// complications), where there is no room for a timestamp. It shows a small trailing glyph **only** when
/// the snapshot is hard-stale (past ~24 h), the point where display-time resolution can no longer keep the
/// shown values on today. A recent snapshot stays unmarked here — its values are still correct — and
/// nothing renders while fresh.
public struct AuraStalenessGlyph: View {
    let snapshot: WeatherSnapshot
    var now: Date

    public init(snapshot: WeatherSnapshot, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        if snapshot.freshness(at: now) == .stale {
            Image(systemName: "wifi.slash")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
