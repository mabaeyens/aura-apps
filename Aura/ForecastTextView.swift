import AuraKit
import SwiftUI

/// "Predicción" — the official, human-written forecast bulletin AEMET issues for the selected
/// location's autonomous community. Read from AEMET's OpenData normalized-text products
/// (`AEMETClient.comunidadBulletin`), which resolve to the bulletin that covers today. The issue
/// date is always shown so the reader can see how fresh it is. Needs the API key (Ajustes).
struct ForecastTextView: View {
    @EnvironmentObject private var store: LocationStore

    @State private var bulletin: ForecastBulletin?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var comunidad: Comunidad? { store.selected?.comunidad }

    var body: some View {
        NavigationStack {
            Group {
                if comunidad == nil {
                    ContentUnavailableView(
                        "Sin ubicaciones",
                        systemImage: "mappin.slash",
                        description: Text("Añade una ubicación en la pestaña Ubicaciones.")
                    )
                } else {
                    scroll
                }
            }
            .navigationTitle("Predicción")
            .navigationBarTitleDisplayMode(.inline)
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
                        Text("Actualizado \(Self.dateText(elaborado))")
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
                    HStack { ProgressView(); Text("Cargando…").foregroundStyle(.secondary) }
                } else if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }

                Text("Elaborado con datos de AEMET")
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
            errorMessage = "Falta la clave de AEMET. Añádela en Ajustes."
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
        f.locale = Locale(identifier: "es_ES")
        f.timeZone = TimeZone(identifier: "Europe/Madrid") ?? .current
        f.dateFormat = "d 'de' MMMM 'de' y, HH:mm"
        return f.string(from: date)
    }
}
