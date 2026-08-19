import SwiftUI

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
                Text("Versión \(version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer().frame(height: 28)

                Text(
                    "Aura es el compañero de Apple Watch de la app de AEMET. Toma tu ubicación más " +
                    "cercana y muestra el tiempo en complicaciones y widgets a todo color, " +
                    "actualizándose a medida que cambian los datos.\n\n" +
                    "Del latín aura: brisa, aire en movimiento — y también el halo de luz que " +
                    "rodea algo.\n\n" +
                    "Los datos vienen de tu clave de AEMET OpenData. Todo ocurre en el dispositivo: " +
                    "sin cuenta, sin servidores, nada se envía a ningún sitio salvo a AEMET."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 360)

                Spacer().frame(height: 24)

                Text("Elaborado con datos de AEMET")
                    .font(.footnote.weight(.medium))

                Spacer().frame(height: 16)

                HStack(spacing: 16) {
                    if let repo = URL(string: "https://github.com/mabaeyens/aura-apps") {
                        Link("Código", destination: repo)
                    }
                    Text("·").foregroundStyle(.tertiary)
                    if let aemet = URL(string: "https://opendata.aemet.es") {
                        Link("AEMET OpenData", destination: aemet)
                    }
                }
                .font(.footnote)

                Text("Sin cuenta · sin servidores · solo habla con AEMET")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 32)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Acerca de")
        .navigationBarTitleDisplayMode(.inline)
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
                .overlay(Image(systemName: "wind").font(.system(size: 44)).foregroundStyle(.white))
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
