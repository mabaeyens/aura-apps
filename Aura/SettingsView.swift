import AuraKit
import SwiftUI

/// "Ajustes" — enter the AEMET API key (stored in the Keychain) and show attribution.
struct SettingsView: View {
    @EnvironmentObject private var store: LocationStore

    @State private var keyInput = ""
    @State private var justSaved = false

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
                        Text("La clave de AEMET caduca a los 3 meses. Si la predicción deja de actualizarse, renuévala en opendata.aemet.es y pégala aquí.")
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
