import AuraKit
import SwiftUI
import WidgetKit

/// "Ajustes" — enter the AEMET API key (stored in the Keychain) and show attribution.
struct SettingsView: View {
    @EnvironmentObject private var store: LocationStore

    @Environment(\.dismiss) private var dismiss

    @State private var keyInput = ""
    @State private var justSaved = false
    /// Gates the destructive Keychain wipe behind a confirmation — clearing the key silently breaks
    /// every data fetch, so it shouldn't happen on a single stray tap.
    @State private var confirmClearKey = false

    /// Clock format, shared with the widgets and the Watch through the App Group so every surface reads
    /// the same value (see `AuraTime`). True = 24-hour, false = 12-hour AM/PM. Defaults to 24-hour.
    @AppStorage(AuraTime.use24hKey, store: SharedCache.groupDefaults) private var use24h = true

    /// The chosen hero background family, persisted across launches. Read elsewhere via
    /// `HeroBackground.Family(storage:)`; the switch below only appears once cityscape art ships.
    @AppStorage("heroFamily") private var heroFamily = HeroBackground.Family.landscape.rawValue

    /// How much Aura may notify: none, avisos only, or avisos plus new forecasts. Shared with the
    /// background-refresh path and the onboarding step via `NotificationLevel.storageKey`.
    @AppStorage(NotificationLevel.storageKey) private var notifyLevel: NotificationLevel = .off

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
                        Button("Borrar clave", role: .destructive) { confirmClearKey = true }
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
                    Picker("Formato de hora", selection: $use24h) {
                        Text("24 h").tag(true)
                        Text("12 h").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: use24h) { _, _ in
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                } header: {
                    Text("Formato de hora")
                } footer: {
                    Text("Elige entre 24 horas (14:30) y 12 horas con AM/PM (2:30 PM). Se aplica en toda la app, los widgets y el reloj.")
                }

                Section {
                    Picker("Notificaciones", selection: $notifyLevel) {
                        ForEach(NotificationLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .onChange(of: notifyLevel) { _, newValue in
                        if newValue != .off { NotificationManager.requestAuthorization() }
                    }
                } header: {
                    Text("Notificaciones")
                } footer: {
                    Text("Los avisos notifican solo en nivel naranja o rojo de tu ubicación activa. "
                        + "Las predicciones avisan cuando AEMET actualiza el boletín. Necesita permiso "
                        + "de notificaciones y el repaso en segundo plano activado en Ajustes del sistema.")
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .confirmationDialog("¿Borrar la clave de AEMET?", isPresented: $confirmClearKey, titleVisibility: .visible) {
                Button("Borrar clave", role: .destructive) { clear() }
                Button("Cancelar", role: .cancel) { }
            } message: {
                Text("Dejarás de recibir datos hasta que vuelvas a introducir una clave.")
            }
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
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
