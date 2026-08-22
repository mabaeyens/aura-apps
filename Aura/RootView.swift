import SwiftUI

/// The app is a single immersive screen — "Hoy", the forecast for the selected location over a
/// full-bleed sky. The other sections (Predicción, Ubicaciones, Ajustes) open from a discreet frosted
/// menu on the hero rather than a bottom tab bar, so nothing chromes the sky. `TodayView` owns that menu
/// and presents the three as sheets.
struct RootView: View {
    /// Set once the first-run intro is finished or skipped. Versioned so a future redesigned onboarding
    /// can show again without colliding with an older flag.
    @AppStorage("hasOnboardedV1") private var hasOnboarded = false

    var body: some View {
        TodayView()
            // One typeface across the whole app: SF Rounded, the app's signature (already used for the
            // hero temperature and the wind speed). Cascades to every `.system(...)` and semantic text
            // style that doesn't pin its own design, so the cards and the screens read as one family.
            .fontDesign(.rounded)
            // First launch: the intro over the sky, with a Pasar (skip). Dismisses the moment the flag
            // flips true (onFinish), so it never shows again.
            .fullScreenCover(isPresented: Binding(get: { !hasOnboarded }, set: { _ in })) {
                OnboardingView(onFinish: { hasOnboarded = true })
            }
    }
}
