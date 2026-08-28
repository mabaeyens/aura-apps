import AuraKit
import SwiftUI

/// "Predicción" — the official, human-written forecast bulletin AEMET issues for the selected
/// location's autonomous community. Read from AEMET's OpenData normalized-text products
/// (`AEMETClient.comunidadBulletin`), which resolve to the bulletin that covers today. The issue
/// date is always shown so the reader can see how fresh it is. Needs the API key (Ajustes).
struct ForecastTextView: View {
    @EnvironmentObject private var store: LocationStore
    @Environment(\.dismiss) private var dismiss

    @State private var bulletin: ForecastBulletin?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var comunidad: Comunidad? { store.selected?.comunidad }

    var body: some View {
        NavigationStack {
            Group {
                if comunidad == nil {
                    ContentUnavailableView(
                        auraString("today.empty.title"),
                        systemImage: "mappin.slash",
                        description: Text(auraString("forecast.empty.body"))
                    )
                } else {
                    scroll
                }
            }
            .navigationTitle(auraString("card.forecast.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(auraString("common.done")) { dismiss() }
                }
            }
        }
        .task(id: store.selectedINE) { await load() }
    }

    private var scroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let comunidad {
                    Text(comunidad.nombre)
                        .font(.title3.bold())
                }

                if let bulletin {
                    if let elaborado = bulletin.elaborado {
                        Text(auraString("forecast.updatedAt", Self.dateText(elaborado)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let fenomeno = bulletin.fenomenoSignificativo {
                        Label(fenomeno, systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }

                    // AEMET writes the bulletin as one run-on paragraph — sky, then rain, then max
                    // temps, min temps, wind, all in a row, with hard column wraps baked in. One line
                    // per sentence (BulletinText) flows it and makes it scannable: one topic per line.
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(BulletinText.sentences(bulletin.texto).enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else if isLoading {
                    HStack { ProgressView(); Text(auraString("common.loading")).foregroundStyle(.secondary) }
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }

                Text(auraString("attribution.madeWith", "AEMET"))
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .refreshable { await load() }
    }

    private func load() async {
        guard let comunidad else { return }
        guard let client = AEMETService.client() else {
            bulletin = nil
            errorMessage = auraString("error.missingKey")
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            bulletin = try await client.comunidadBulletin(comunidad)
        } catch {
            errorMessage = AEMETService.message(for: error)
        }
        isLoading = false
    }

    private static func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        // The bulletin timestamp follows the device language (Spanish "1 de septiembre de 2026,
        // 14:30"; English "September 1, 2026 at 14:30"), but the clock stays on Madrid time since
        // that is where the forecast is issued.
        f.locale = .current
        f.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        f.setLocalizedDateFormatFromTemplate("d MMMM y HH:mm")
        return f.string(from: date)
    }
}
