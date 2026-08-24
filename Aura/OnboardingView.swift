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
             title: "Bienvenido a Aura",
             body: "El tiempo de AEMET sobre un cielo vivo, con el sol y la luna donde de verdad están a "
                 + "cada hora de tu ubicación."),
        Page(icon: "key.fill",
             title: "Tu clave de AEMET",
             body: "AEMET es pública y gratuita, pero necesitas tu propia clave, también gratis. Pídela con "
                 + "el botón y pégala aquí mismo. Podrás cambiarla cuando quieras en Ajustes.",
             showsKeyButton: true),
        Page(icon: "square.grid.2x2.fill",
             title: "En toda la pantalla",
             body: "Widgets para la pantalla de inicio y la de bloqueo, y complicaciones para el Apple "
                 + "Watch: el tiempo de un vistazo, sin abrir la app."),
        Page(icon: "bell.badge.fill",
             title: "¿Te aviso?",
             body: "Puedo notificarte los avisos naranja y rojo de tu ubicación, y si quieres también "
                 + "cuando AEMET actualice la predicción. Cámbialo cuando quieras en Ajustes.",
             showsNotifyChoice: true),
        Page(icon: "hand.thumbsup.fill",
             title: "Todo listo",
             body: "Añade tu ubicación y Aura hará el resto. Puedes volver a leer esto en Ayuda cuando "
                 + "quieras."),
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
                        Button("Pasar", action: onFinish)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .frame(height: 40)
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
                .font(.system(size: 66, weight: .semibold))
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
                        Label("Solicitar mi clave gratis", systemImage: "arrow.up.right.square")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .foregroundStyle(.white)
                    }

                    // Paste-and-save right here: no trip to Ajustes to finish setup.
                    HStack(spacing: 8) {
                        SecureField("Pega aquí tu clave", text: $keyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundStyle(.white)
                            .tint(.white)
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .background(.ultraThinMaterial, in: Capsule())
                            .onChange(of: keyInput) { _, _ in keySaved = false }
                        Button {
                            AuraKeychain.setAPIKey(keyInput.trimmingCharacters(in: .whitespaces))
                            keyInput = ""
                            keySaved = true
                        } label: {
                            Text("Guardar")
                                .font(.callout.weight(.semibold))
                                .padding(.horizontal, 16).padding(.vertical, 11)
                                .background(.white, in: Capsule())
                                .foregroundStyle(.black)
                        }
                        .disabled(keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if keySaved {
                        Label("Clave guardada", systemImage: "checkmark.seal.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .transition(.opacity)
                    }
                }
                .animation(.default, value: keySaved)
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
                    Text("Empezar")
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
