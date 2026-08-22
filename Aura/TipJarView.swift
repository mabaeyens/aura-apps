import AuraKit
import StoreKit
import SwiftUI

/// "Propina" — a warm thank-you sheet with three consumable "tónica" tips. Nothing here unlocks
/// anything; it's a way to say thanks. Matches the app's look: frosted cards floating over a
/// time-of-day sky gradient (`Palette.timeGradient`), white text, dark colour scheme — the same
/// language as the Hoy screen. StoreKit's localized `displayPrice` is always shown, never a
/// hardcoded "€0,99".
struct TipJarView: View {
    @StateObject private var tipJar = TipJar()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.timeGradient().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 22) {
                        header

                        switch tipJar.loadState {
                        case .loading:
                            loadingCard
                        case .failed:
                            failedCard
                        case .loaded:
                            tipButtons
                        }

                        footnote
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .frame(maxWidth: 460)
                    .frame(maxWidth: .infinity)   // centre the column on iPad/Mac
                }
                .scrollBounceBehavior(.basedOnSize)

                ZStack {
                    if tipJar.purchaseState == .success {
                        successOverlay
                    } else if tipJar.purchaseState == .pending {
                        pendingOverlay
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: tipJar.purchaseState)
            }
            .environment(\.colorScheme, .dark)     // light text over the sky, matching Hoy
            .navigationTitle("Propina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .task { await tipJar.loadProducts() }
        // Surface a purchase failure as an alert; dismissing returns the store to `ready`.
        .alert("Vaya", isPresented: failureBinding) {
            Button("Vale", role: .cancel) { tipJar.resetPurchaseState() }
        } message: {
            Text(failureMessage)
        }
    }

    // MARK: - Header & blurb

    private var header: some View {
        VStack(spacing: 14) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 6, y: 1)
                .accessibilityHidden(true)

            Text("Invítame a una tónica")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(
                "Aura es gratis, sin anuncios y sin cuentas. Si te acompaña cada mañana y te " +
                "apetece darme las gracias, puedes invitarme a una tónica. No desbloquea nada: " +
                "es solo un gesto, y me alegra el día."
            )
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
        }
        .foregroundStyle(.white)
        .padding(.top, 8)
    }

    // MARK: - Tip buttons

    private var tipButtons: some View {
        VStack(spacing: 12) {
            ForEach(tipJar.products, id: \.id) { product in
                tipButton(for: product)
            }
        }
    }

    private func tipButton(for product: Product) -> some View {
        Button {
            Task { await tipJar.purchase(product) }
        } label: {
            HStack(spacing: 14) {
                Text(product.displayName)
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer(minLength: 8)

                if tipJar.isPurchasing(product) {
                    ProgressView()
                        .tint(.white)
                        .frame(minWidth: 64)
                } else {
                    Text(product.displayPrice)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.18), in: Capsule())
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnyPurchaseInFlight)
        // One clear spoken label per tip: the gesture plus the price.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Invitar a \(product.displayName), \(product.displayPrice)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Propina para el desarrollador"))
    }

    // MARK: - Load states

    private var loadingCard: some View {
        card {
            HStack(spacing: 10) {
                ProgressView().tint(.white)
                Text("Cargando…").foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var failedCard: some View {
        card {
            VStack(spacing: 12) {
                Label("No se pudieron cargar las propinas.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Button("Reintentar") {
                    Task { await tipJar.loadProducts() }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(.white.opacity(0.18), in: Capsule())
            }
        }
    }

    // MARK: - Confirmations

    private var successOverlay: some View {
        confirmation(
            icon: "checkmark.circle.fill",
            title: "¡Gracias!",
            message: "Va por tu tónica. Que la disfrutes tú también."
        ) {
            tipJar.resetPurchaseState()
        }
    }

    private var pendingOverlay: some View {
        confirmation(
            icon: "hourglass.circle.fill",
            title: "Pendiente de aprobar",
            message: "La compra está a la espera de aprobación. Gracias de todos modos."
        ) {
            tipJar.resetPurchaseState()
        }
    }

    private func confirmation(icon: String, title: String, message: String,
                              onDismiss: @escaping () -> Void) -> some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Button("Cerrar", action: onDismiss)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2), in: Capsule())
                    .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
            .padding(32)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isModal)
        }
        .transition(.opacity)
    }

    // MARK: - Bits

    private var footnote: some View {
        Text("Las propinas se pueden repetir y no desbloquean funciones.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.top, 4)
    }

    /// A frosted container matching the app's card style, used for the loading and error states.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
    }

    /// True while any tip is being purchased, so the other buttons disable rather than stacking taps.
    private var isAnyPurchaseInFlight: Bool {
        if case .purchasing = tipJar.purchaseState { return true }
        return false
    }

    /// Drives the failure alert; reading it never mutates state, dismissing resets via the button.
    private var failureBinding: Binding<Bool> {
        Binding(
            get: { if case .failed = tipJar.purchaseState { return true } else { return false } },
            set: { if !$0 { tipJar.resetPurchaseState() } }
        )
    }

    private var failureMessage: String {
        if case let .failed(message) = tipJar.purchaseState { return message }
        return ""
    }
}
