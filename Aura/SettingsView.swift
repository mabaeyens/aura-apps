import AuraKit
import SwiftUI

/// "Ajustes" — enter the AEMET API key (stored in the Keychain) and show attribution.
struct SettingsView: View {
    @EnvironmentObject private var store: LocationStore

    @State private var keyInput = ""
    @State private var justSaved = false

    /// The chosen hero background family, persisted across launches. Read elsewhere via
    /// `HeroBackground.Family(storage:)`; the switch below only appears once cityscape art ships.
    @AppStorage("heroFamily") private var heroFamily = HeroBackground.Family.landscape.rawValue

    /// Whether any `city_*` art is actually in the bundle. Until it is, there's nothing to switch to, so
    /// the picker stays hidden and the app is landscape-only (procedural sky underneath either way).
    private var hasCityscapeArt: Bool {
        HeroBackground.assetNames(for: .cityscape).contains { UIImage(named: $0) != nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Clave de AEMET", text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Guardar clave") { save() }
                        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    if store.apiKeyPresent {
                        Button("Borrar clave", role: .destructive) { clear() }
                    }
                } header: {
                    Text("Clave API")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            store.apiKeyPresent ? "Clave guardada en el Llavero." : "No hay clave guardada.",
                            systemImage: store.apiKeyPresent ? "checkmark.seal" : "key"
                        )
                        if justSaved {
                            Text("Clave actualizada.").foregroundStyle(.green)
                        }
                        Text("Si la predicción deja de actualizarse, pide otra clave gratis en opendata.aemet.es y pégala aquí.")
                    }
                }

                if hasCityscapeArt {
                    Section {
                        Picker("Fondo", selection: $heroFamily) {
                            ForEach(HeroBackground.Family.allCases, id: \.rawValue) { family in
                                Text(family.displayName).tag(family.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Fondo del cielo")
                    } footer: {
                        Text("Elige el paisaje que acompaña al cielo. El sol y la luna se dibujan siempre en su posición real, sea cual sea el fondo.")
                    }
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("Acerca de Aura", systemImage: "info.circle")
                    }
                    LabeledContent("Versión", value: appVersion)
                } footer: {
                    Text("Elaborado con datos de AEMET.")
                }
            }
            .navigationTitle("Ajustes")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    private func save() {
        AuraKeychain.setAPIKey(keyInput)
        keyInput = ""
        store.refreshKeyState()
        justSaved = true
    }

    private func clear() {
        AuraKeychain.setAPIKey("")
        store.refreshKeyState()
        justSaved = false
    }
}
