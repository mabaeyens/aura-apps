import SwiftUI

/// Tabbed shell. "Hoy" and "Predicción" are the two data screens that prove the AEMET
/// pipeline end to end; "Ubicaciones" and "Ajustes" manage what they show.
struct RootView: View {
    @EnvironmentObject private var store: LocationStore
    // Initial tab is overridable for validation via `--args -auraTab <0-3>`; defaults to Hoy.
    @State private var tab = UserDefaults.standard.integer(forKey: "auraTab")

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Hoy", systemImage: "sun.max") }
                .tag(0)

            ForecastTextView()
                .tabItem { Label("Predicción", systemImage: "text.alignleft") }
                .tag(1)

            LocationsView()
                .tabItem { Label("Ubicaciones", systemImage: "mappin.and.ellipse") }
                .tag(2)

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape") }
                .tag(3)
        }
        // One typeface across the whole app: SF Rounded, the app's signature (already used for the hero
        // temperature and the wind speed). Cascades to every `.system(...)` and semantic text style that
        // doesn't pin its own design, so the cards and the screens read as one family.
        .fontDesign(.rounded)
    }
}
