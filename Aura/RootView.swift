import SwiftUI

/// The app is a single immersive screen — "Hoy", the forecast for the selected location over a
/// full-bleed sky. The other sections (Predicción, Ubicaciones, Ajustes) open from a discreet frosted
/// menu on the hero rather than a bottom tab bar, so nothing chromes the sky. `TodayView` owns that menu
/// and presents the three as sheets.
struct RootView: View {
    var body: some View {
        TodayView()
            // One typeface across the whole app: SF Rounded, the app's signature (already used for the
            // hero temperature and the wind speed). Cascades to every `.system(...)` and semantic text
            // style that doesn't pin its own design, so the cards and the screens read as one family.
            .fontDesign(.rounded)
    }
}
