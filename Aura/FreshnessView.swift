import AuraKit
import SwiftUI

/// "Actualización de los datos" — a reference page, pushed from Ayuda, that explains for every reading on
/// screen when it was actually pulled and how often it changes. Aura always leads with the last data it
/// saved and refreshes in the background, so the same screen mixes readings on very different clocks: a
/// station observation published half an hour after its :00 timestamp, a radar frame from the last ten
/// minutes, a bulletin issued once or twice a day. This spells that out so "why hasn't this moved?" has an
/// answer. Every cadence here mirrors a real constant in the app (see `RadarService.ttl`, `NewsService.ttl`,
/// `AuraRefreshCore` observation window, `TodayView.forceInterval`); keep them in step when those change.
///
/// Not its own NavigationStack: it is pushed onto Ayuda's stack, so it inherits the back button and title bar.
struct FreshnessView: View {
    var body: some View {
        Form {
            Section {
                Text(auraString("freshness.intro")).font(.subheadline)
            }

            Section {
                row("thermometer.medium", auraString("freshness.observed.title"), auraString("freshness.observed.body"))
                row("clock",              auraString("freshness.forecast.title"), auraString("freshness.forecast.body"))
                row("text.alignleft",     auraString("freshness.bulletin.title"), auraString("freshness.bulletin.body"))
                row("antenna.radiowaves.left.and.right", auraString("freshness.radar.title"), auraString("freshness.radar.body"))
                row("sun.max.fill",       auraString("freshness.uv.title"),    auraString("freshness.uv.body"))
                row("aqi.medium",         auraString("freshness.air.title"),   auraString("freshness.air.body"))
                row("exclamationmark.triangle.fill", auraString("freshness.aviso.title"), auraString("freshness.aviso.body"))
            } header: {
                Text(auraString("freshness.section.data"))
            }

            Section {
                row("newspaper",       auraString("freshness.news.title"),    auraString("freshness.news.body"))
                row("arrow.clockwise", auraString("freshness.refresh.title"), auraString("freshness.refresh.body"))
            } header: {
                Text(auraString("freshness.section.app"))
            }
        }
        .navigationTitle(auraString("freshness.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// One data source: its icon, what it shows (title), and when it is pulled / how often it changes (body).
    /// The icon slot is fixed-width so every explanation starts on the same column, top-aligned to the title.
    private func row(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .symbolRenderingMode(.multicolor)
                .auraFont(22, relativeTo: .title2)
                .frame(width: 38, height: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.medium))
                Text(body).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
