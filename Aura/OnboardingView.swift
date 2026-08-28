import AuraKit
import SwiftUI

/// First-run introduction, shown once (gated by `@AppStorage("hasOnboardedV1")` in `RootView`). A few
/// swipeable pages over the live sky that say what Aura is, that it needs a free AEMET key, and where its
/// widgets live — with a **Pasar** (skip) button so anyone who just wants the weather can jump straight in.
struct OnboardingView: View {
    /// Called when the user finishes the last page or taps Pasar; `RootView` flips its stored flag and
    /// dismisses this cover.
    let onFinish: () -> Void

    @State private var page = 0
    /// The key the user pastes on the AEMET page — saved to the Keychain inline, so onboarding never has to
    /// send them off to Ajustes to finish. Cleared to empty after a save; `keySaved` lights the confirmation.
    @State private var keyInput = ""
    @State private var keySaved = false
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The notification preference picked on the notifications page. Editable later in Ajustes; shared
    /// with the background-refresh path via `NotificationLevel.storageKey`.
    @AppStorage(NotificationLevel.storageKey) private var notifyLevel: NotificationLevel = .off

    /// AEMET's self-service page — the same one Ajustes and Ayuda point at.
    private let apiKeyURL = URL(string: "https://opendata.aemet.es/centrodedescargas/altaUsuario")!

    private struct Page: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
        var showsKeyButton = false
        var showsNotifyChoice = false
    }

    private let pages: [Page] = [
        Page(icon: "sun.max.fill",
             title: auraString("onboarding.welcome.title"),
             body: auraString("onboarding.welcome.body")),
        Page(icon: "key.fill",
             title: auraString("onboarding.key.title"),
             body: auraString("onboarding.key.body"),
             showsKeyButton: true),
        Page(icon: "square.grid.2x2.fill",
             title: auraString("onboarding.everywhere.title"),
             body: auraString("onboarding.everywhere.body")),
        Page(icon: "bell.badge.fill",
             title: auraString("onboarding.notify.title"),
             body: auraString("onboarding.notify.body"),
             showsNotifyChoice: true),
        Page(icon: "hand.thumbsup.fill",
             title: auraString("onboarding.done.title"),
             body: auraString("onboarding.done.body")),
    ]

    var body: some View {
        ZStack {
            AuraSky(snapshot: .preview).ignoresSafeArea()
            // A soft top-to-bottom dim so the white copy stays legible over any part of the sky.
            LinearGradient(colors: [.black.opacity(0.34), .black.opacity(0.12), .black.opacity(0.48)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // The skip affordance, reserved as a fixed-height row so the page dots never shift when it
                // hides on the final page.
                HStack {
                    Spacer()
                    if page < pages.count - 1 {
                        Button(auraString("onboarding.skip"), action: onFinish)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18).padding(.vertical, 11)
                            .background(.ultraThinMaterial, in: Capsule())
                            .contentShape(Capsule())   // full capsule is the tap target, ~44pt tall
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        card(item, isLast: index == pages.count - 1).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            }
        }
        .preferredColorScheme(.dark)
        .fontDesign(.rounded)
    }

    private func card(_ item: Page, isLast: Bool) -> some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: item.icon)
                .symbolRenderingMode(.hierarchical)
                .auraFont(66, relativeTo: .largeTitle, weight: .semibold)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
            VStack(spacing: 12) {
                Text(item.title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)

            if item.showsKeyButton {
                VStack(spacing: 14) {
                    Button {
                        openURL(apiKeyURL)
                    } label: {
                        Label(auraString("onboarding.requestKey"), systemImage: "arrow.up.right.square")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    // Paste-and-save right here: no trip to Ajustes to finish setup.
                    HStack(spacing: 8) {
                        SecureField(auraString("onboarding.keyPlaceholder"), text: $keyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .tint(.white)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(.ultraThinMaterial, in: Capsule())
                            // Only a fresh edit clears the confirmation. Saving blanks the field itself,
                            // which fires this too — guarding on a non-empty value keeps that from wiping
                            // the "Clave guardada" check the moment it appears.
                            .onChange(of: keyInput) { _, newValue in
                                if !newValue.isEmpty { keySaved = false }
                            }
                        Button {
                            AuraKeychain.setAPIKey(keyInput.trimmingCharacters(in: .whitespaces))
                            keyInput = ""
                            keySaved = true
                        } label: {
                            Text(auraString("common.save"))
                                .font(.callout.weight(.semibold))
                                .padding(.horizontal, 16).padding(.vertical, 11)
                                .background(.white, in: Capsule())
                                .foregroundStyle(.black)
                        }
                        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if keySaved {
                        Label(auraString("onboarding.keySaved"), systemImage: "checkmark.seal.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .transition(.opacity)
                    }
                }
                .animation(reduceMotion ? nil : .default, value: keySaved)
            }

            if item.showsNotifyChoice {
                VStack(spacing: 10) {
                    ForEach(NotificationLevel.allCases) { level in
                        Button {
                            notifyLevel = level
                            if level != .off { NotificationManager.requestAuthorization() }
                        } label: {
                            HStack {
                                Text(level.label)
                                Spacer()
                                if notifyLevel == level {
                                    Image(systemName: "checkmark").font(.callout.weight(.bold))
                                }
                            }
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 18).padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            Spacer()

            if isLast {
                Button(action: onFinish) {
                    Text(auraString("onboarding.start"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.black)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 44)   // clear the page dots
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }
}
