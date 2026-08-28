import SwiftUI
import AuraKit

/// "Acerca de Aura" — the info screen, pushed from Ajustes. iPhone only. Mirrors the Mira/Vera
/// about screens: app icon, version, what Aura is, and the AEMET attribution. Spanish, like the
/// rest of the UI.
struct AboutView: View {
    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                appIcon
                    .padding(.top, 12)
                    .padding(.bottom, 20)

                Text("Aura")
                    .font(.title2.weight(.semibold))
                Text(auraString("about.versionLabel", version))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer().frame(height: 28)

                Text(auraString("about.body"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 360)

                Spacer().frame(height: 28)

                dedication

                Spacer().frame(height: 28)

                Text(auraString("about.credits.title"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)

                VStack(spacing: 12) {
                    creditRow("AEMET", auraString("about.credit.aemet"),
                              "https://opendata.aemet.es")
                    creditRow("MITECO", auraString("about.credit.miteco"),
                              "https://www.miteco.gob.es/es/calidad-y-evaluacion-ambiental/temas/atmosfera-y-calidad-del-aire/visualizacion-datos-calidad-del-aire/ica.html")
                    creditRow("Copernicus (CAMS)", auraString("about.credit.copernicus"),
                              "https://atmosphere.copernicus.eu")
                    creditRow("RTVE", auraString("about.credit.rtve"),
                              "https://www.rtve.es")
                    creditRow("Meteored", auraString("about.credit.meteored"),
                              "https://www.tiempo.com")
                    creditRow("AEMET Blog", auraString("about.credit.aemetblog"),
                              "https://aemetblog.es")
                }
                .frame(maxWidth: 360)

                Spacer().frame(height: 20)

                if let repo = URL(string: "https://github.com/mabaeyens/aura-apps") {
                    Link(auraString("about.githubLink"), destination: repo)
                        .font(.footnote)
                }

                Text(auraString("about.tagline"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 8)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(auraString("about.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A quiet personal dedication, set apart from the functional "Créditos" list below it — a
    /// dedication is not an attribution. First person, warm and plain. The lines live in one array so
    /// I can add my brothers and sisters by name later without touching the layout.
    private let dedicationLines = [
        auraString("about.dedication.line1"),
        auraString("about.dedication.line2"),
    ]

    @ViewBuilder
    private var dedication: some View {
        Text(auraString("about.dedication.title"))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 10)

        VStack(spacing: 8) {
            ForEach(dedicationLines, id: \.self) { line in
                Text(line)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: 360)
    }

    /// One credit line: the source name (tappable when it has a link) over a one-line note of what it
    /// provides. Keeps the Créditos list uniform as sources are added.
    @ViewBuilder
    private func creditRow(_ name: String, _ provides: String, _ url: String) -> some View {
        VStack(spacing: 1) {
            if let link = URL(string: url) {
                Link(name, destination: link)
                    .font(.footnote.weight(.semibold))
            } else {
                Text(name).font(.footnote.weight(.semibold))
            }
            Text(provides)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = Self.loadAppIcon() {
            Image(uiImage: image)
                .resizable()
                .frame(width: 100, height: 100)
                .clipShape(.rect(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.07, green: 0.22, blue: 0.37))
                .frame(width: 100, height: 100)
                .overlay(Image(systemName: "wind").auraFont(44, relativeTo: .largeTitle).foregroundStyle(.white))
        }
    }

    private static func loadAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last,
           let image = UIImage(named: name) {
            return image
        }
        return UIImage(named: "AppIcon")
    }
}
