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
    /// Result of the last "Verify Key" tap, and whether a check is in flight.
    @State private var verifying = false
    @State private var verifyResult: AEMETClient.KeyCheck?

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
                    SecureField(auraString("settings.apiKey.placeholder"), text: $keyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button(auraString("settings.saveKey")) { save() }
                        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button(auraString("settings.verifyKey")) { verify() }
                        .disabled(verifying || (!store.apiKeyPresent && keyInput.filter { !$0.isWhitespace }.isEmpty))
                    if verifying {
                        Label(auraString("settings.verify.checking"), systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    } else if let result = verifyResult {
                        Label(verifyMessage(for: result), systemImage: verifyIcon(for: result))
                            .foregroundStyle(result == .valid ? .green : (result == .invalidKey ? .red : .orange))
                    }
                    if store.apiKeyPresent {
                        Button(auraString("settings.deleteKey"), role: .destructive) { confirmClearKey = true }
                    }
                } header: {
                    Text(auraString("settings.apiKey.section"))
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(
                            store.apiKeyPresent ? auraString("settings.keyStored") : auraString("settings.keyNotStored"),
                            systemImage: store.apiKeyPresent ? "checkmark.seal" : "key"
                        )
                        if justSaved {
                            Text(auraString("settings.keyUpdated")).foregroundStyle(.green)
                        }
                        Text(auraString("settings.apiKey.footer"))
                    }
                }

                if hasCityscapeArt {
                    Section {
                        Picker(auraString("settings.background.picker"), selection: $heroFamily) {
                            ForEach(HeroBackground.Family.allCases, id: \.rawValue) { family in
                                Text(family.displayName).tag(family.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text(auraString("settings.background.section"))
                    } footer: {
                        Text(auraString("settings.background.footer"))
                    }
                }

                Section {
                    Picker(auraString("settings.timeFormat.picker"), selection: $use24h) {
                        Text(auraString("settings.timeFormat.24h")).tag(true)
                        Text(auraString("settings.timeFormat.12h")).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: use24h) { _, _ in
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                } header: {
                    Text(auraString("settings.timeFormat.section"))
                } footer: {
                    Text(auraString("settings.timeFormat.footer"))
                }

                Section {
                    Picker(auraString("settings.notifications.picker"), selection: $notifyLevel) {
                        ForEach(NotificationLevel.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .onChange(of: notifyLevel) { _, newValue in
                        if newValue != .off { NotificationManager.requestAuthorization() }
                    }
                } header: {
                    Text(auraString("settings.notifications.section"))
                } footer: {
                    Text(auraString("settings.notifications.footer"))
                }

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label(auraString("settings.aboutRow"), systemImage: "info.circle")
                    }
                    LabeledContent(auraString("settings.versionLabel"), value: appVersion)
                } footer: {
                    Text(auraString("attribution.madeWith", "AEMET") + ".")
                }
            }
            .navigationTitle(auraString("settings.title"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(auraString("common.done")) { dismiss() }
                }
            }
            .confirmationDialog(auraString("settings.deleteKey.confirmTitle"), isPresented: $confirmClearKey, titleVisibility: .visible) {
                Button(auraString("settings.deleteKey"), role: .destructive) { clear() }
                Button(auraString("common.cancel"), role: .cancel) { }
            } message: {
                Text(auraString("settings.deleteKey.confirmBody"))
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

    /// Verify the key the user just typed if there is one, otherwise the stored key, with a single
    /// throwaway envelope request. Whitespace is stripped so a line-wrapped paste checks the same
    /// cleaned string that `save()` would persist.
    private func verify() {
        let typed = keyInput.filter { !$0.isWhitespace }
        let key = typed.isEmpty ? (AuraKeychain.apiKey() ?? "") : typed
        guard !key.isEmpty else { return }
        verifying = true
        verifyResult = nil
        Task {
            let outcome = await AEMETClient(apiKey: key).verifyKey()
            await MainActor.run {
                verifying = false
                verifyResult = outcome
            }
        }
    }

    private func verifyMessage(for result: AEMETClient.KeyCheck) -> String {
        switch result {
        case .valid:         return auraString("settings.verify.ok")
        case .invalidKey:    return auraString("settings.verify.invalid")
        case .rateLimited:   return auraString("settings.verify.rateLimited")
        case .offline:       return auraString("settings.verify.offline")
        case .serverProblem: return auraString("settings.verify.serverProblem")
        }
    }

    private func verifyIcon(for result: AEMETClient.KeyCheck) -> String {
        switch result {
        case .valid:         return "checkmark.seal.fill"
        case .invalidKey:    return "xmark.seal.fill"
        case .rateLimited:   return "clock.badge.exclamationmark"
        case .offline:       return "wifi.slash"
        case .serverProblem: return "exclamationmark.icloud"
        }
    }
}
