import AuraKit
import SwiftUI

/// "Ayuda" — the reference sheet opened from the hero menu. Two jobs: explain how to get your own free
/// AEMET key, and give a legend for every icon in the app (even the obvious ones — the water drop is
/// humidity, not rain). Colour *scales* aren't repeated here; each card opens its own scale on a tap, so
/// this points there instead. Presented as a sheet, like Ajustes.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    /// AEMET's self-service page: enter an email, the key arrives by return mail.
    private let apiKeyURL = URL(string: "https://opendata.aemet.es/centrodedescargas/altaUsuario")!

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                freshnessSection
                skySection
                temperatureSection
                rainHumiditySection
                windSection
                sunMoonSection
                uvSection
                airSection
                avisoSection
                appSection
                scalesSection
            }
            .navigationTitle(auraString("help.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(auraString("common.done")) { dismiss() }
                }
            }
        }
    }

    // MARK: Clave de AEMET

    private var apiKeySection: some View {
        Section {
            Text(auraString("help.apiKey.intro"))
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 8) {
                step(1, auraString("help.step1"))
                step(2, auraString("help.step2"))
                step(3, auraString("help.step3"))
                step(4, auraString("help.step4"))
            }
            .padding(.vertical, 2)
            Link(destination: apiKeyURL) {
                Label(auraString("help.requestKey"), systemImage: "arrow.up.right.square")
            }
        } header: {
            Text(auraString("help.yourKey.title"))
        } footer: {
            Text(auraString("help.yourKey.body"))
        }
    }

    // MARK: Freshness

    /// A link to the data-freshness page — what each card shows and when it was actually pulled. Sits right
    /// under the API-key how-to because "why hasn't this number moved?" is the next question after "no data".
    private var freshnessSection: some View {
        Section {
            NavigationLink {
                FreshnessView()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(auraString("freshness.link.title")).font(.subheadline.weight(.medium))
                        Text(auraString("freshness.link.body")).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .symbolRenderingMode(.multicolor)
                        .auraFont(22, relativeTo: .title2)
                }
            }
        }
    }

    // MARK: Icon legends

    private var skySection: some View {
        Section {
            conditionRow("11", night: false, "Despejado")
            conditionRow("11", night: true,  "Despejado de noche")
            conditionRow("12", night: false, "Poco nuboso o con intervalos")
            conditionRow("14", night: false, "Nuboso o cubierto")
            conditionRow("16", night: false, "Niebla o bruma")
            conditionRow("23", night: false, "Lluvia con claros / chubascos")
            conditionRow("24", night: false, "Lluvia")
            conditionRow("25", night: false, "Lluvia fuerte")
            conditionRow("33", night: false, "Nieve")
            conditionRow("71", night: false, "Nieve escasa (aguanieve)")
            conditionRow("51", night: false, "Tormenta")
            conditionRow("53", night: false, "Tormenta con lluvia")
        } header: {
            Text(auraString("help.sky.title"))
        } footer: {
            Text(auraString("help.sky.body"))
        }
    }

    private var temperatureSection: some View {
        Section {
            iconRow("arrow.up",   auraString("help.tempMax.title"), auraString("help.tempMax.body"))
            iconRow("arrow.down", auraString("help.tempMin.title"), auraString("help.tempMin.body"))
        } header: {
            Text(auraString("help.temp.title"))
        } footer: {
            Text(auraString("help.temp.body"))
        }
    }

    private var rainHumiditySection: some View {
        Section {
            iconRow("umbrella.fill", auraString("help.rain.title"), auraString("help.rain.body"))
            iconRow("drop.fill", auraString("help.rainWatch.title"), auraString("help.rainWatch.body"))
            iconRow("humidity.fill", auraString("help.humidity.title"), auraString("help.humidity.body"))
        } header: {
            Text(auraString("help.rainHumidity.title"))
        } footer: {
            Text(auraString("help.rainHumidity.body"))
        }
    }

    private var windSection: some View {
        Section {
            iconRow("wind", auraString("help.wind.speed.title"), auraString("help.wind.speed.body"))
            legendRow(glyph: { WindArrowMark() },
                      title: auraString("help.windrose.title"),
                      meaning: auraString("help.windrose.body"))
        } header: {
            Text(auraString("card.wind.title"))
        } footer: {
            Text(auraString("help.wind.body"))
        }
    }

    private var sunMoonSection: some View {
        Section {
            iconRow("sunrise.fill", auraString("help.sunrise.title"), auraString("help.sunrise.body"))
            iconRow("sunset.fill",  auraString("help.sunset.title"), auraString("help.sunset.body"))
            conditionRow("11", night: true, auraString("help.moonUp.body"))
        } header: {
            Text(auraString("help.sunmoon.title"))
        }
    }

    private var uvSection: some View {
        Section {
            // The UV band names stay in Spanish to match the on-device UV vocabulary the reader sees on
            // the card and scale sheet; only the advice on the right localizes.
            iconRow("sun.max.fill",                          "UV bajo (0–2)", auraString("help.uv.low.advice"))
            iconRow("sunglasses.fill",                       "UV moderado (3–5)", auraString("help.uv.moderate.advice"))
            iconRow("sun.max.trianglebadge.exclamationmark", "UV alto (6–7)", auraString("help.uv.high.advice"))
            iconRow("beach.umbrella.fill",                   "UV muy alto (8–10)", auraString("help.uv.veryHigh.advice"))
            iconRow("thermometer.variable.and.figure",       "UV extremadamente alto (11+)", auraString("help.uv.extreme.advice"))
            iconRow("cloud",                                 "UV atenuado por nubes", auraString("help.uv.clouds.advice"))
        } header: {
            Text(auraString("card.uv.title"))
        } footer: {
            Text(auraString("help.uv.body"))
        }
    }

    private var airSection: some View {
        Section {
            iconRow("aqi.medium", auraString("help.aqi.iconTitle"), auraString("help.aqi.iconBody"))
        } header: {
            Text(auraString("card.aqi.title"))
        } footer: {
            Text(auraString("help.aqi.body"))
        }
    }

    private var avisoSection: some View {
        Section {
            iconRow("exclamationmark.triangle.fill", auraString("help.aviso.iconTitle"), auraString("help.aviso.iconBody"))
        } header: {
            Text(auraString("help.avisos.title"))
        } footer: {
            Text(auraString("help.avisos.body"))
        }
    }

    private var appSection: some View {
        Section {
            iconRow("line.3.horizontal",   auraString("help.icon.menu.title"), auraString("help.icon.menu.body"))
            iconRow("text.alignleft",      auraString("card.forecast.title"), auraString("help.icon.forecast.body"))
            iconRow("mappin.and.ellipse",  auraString("locations.title"), auraString("help.icon.locations.body"))
            iconRow("gearshape",           auraString("settings.title"), auraString("help.icon.settings.body"))
            iconRow("questionmark.circle", auraString("help.title"), auraString("help.icon.help.body"))
            iconRow("waterbottle",         auraString("tip.title"), auraString("help.icon.tip.body"))
            iconRow("info.circle",         auraString("settings.aboutRow"), auraString("help.icon.about.body"))
            iconRow("location.fill",       auraString("help.icon.myLocation.title"), auraString("help.icon.myLocation.body"))
            iconRow("mappin.slash",        auraString("help.icon.noLocation.title"), auraString("help.icon.noLocation.body"))
            iconRow("key",                 auraString("help.icon.missingKey.title"), auraString("help.icon.missingKey.body"))
            iconRow("checkmark.seal",      auraString("onboarding.keySaved"), auraString("help.icon.keySaved.body"))
            iconRow("plus",                auraString("help.icon.add.title"), auraString("help.icon.add.body"))
            iconRow("checkmark",           auraString("help.icon.selected.title"), auraString("help.icon.selected.body"))
            iconRow("chevron.down",        auraString("help.icon.expand.title"), auraString("help.icon.expand.body"))
            iconRow("xmark.circle.fill",   auraString("common.close"), auraString("help.icon.close.body"))
        } header: {
            Text(auraString("help.inApp.title"))
        }
    }

    private var scalesSection: some View {
        Section {
            Text(auraString("help.scales.intro"))
                .font(.subheadline)
        } header: {
            Text(auraString("help.scales.title"))
        } footer: {
            Text(auraString("help.scales.body"))
        }
    }

    // MARK: Rows

    /// A numbered step in the API-key how-to.
    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.accentColor, in: Circle())
            Text(text).font(.subheadline)
        }
    }

    /// One icon legend row: the real SF Symbol (multicolour, as the app draws most of them), a name, and a
    /// plain-language meaning.
    private func iconRow(_ symbol: String, _ title: String, _ meaning: String) -> some View {
        legendRow(glyph: {
            Image(systemName: symbol)
                .symbolRenderingMode(.multicolor)
                .auraFont(22, relativeTo: .title2)
        }, title: title, meaning: meaning)
    }

    /// A legend row whose glyph is a weather condition, drawn by the very same `ConditionGlyph` the cards
    /// use, so the legend can't drift from the app. The condition symbols are made to sit on Aura's sky —
    /// its clouds are near-white and vanish on a light form — so each rides a small sky tile, day or night,
    /// exactly as it appears in the app.
    private func conditionRow(_ code: String, night: Bool, _ title: String) -> some View {
        legendRow(glyph: {
            ConditionGlyph(sky: code, isNight: night)
                .auraFont(19, relativeTo: .title3)
                .frame(width: 38, height: 30)
                .background(skyTile(night: night))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }, title: title, meaning: nil)
    }

    /// A little day or night sky behind a condition glyph, so a white cloud or a blue moon reads the way
    /// it does over the app's own sky.
    private func skyTile(night: Bool) -> some View {
        LinearGradient(
            colors: night ? [Color(red: 0.10, green: 0.14, blue: 0.30), Color(red: 0.22, green: 0.28, blue: 0.46)]
                          : [Color(red: 0.26, green: 0.52, blue: 0.86), Color(red: 0.55, green: 0.75, blue: 0.96)],
            startPoint: .top, endPoint: .bottom)
    }

    /// The shared row shell: a fixed-width glyph slot, then a title over an optional meaning.
    private func legendRow<Glyph: View>(@ViewBuilder glyph: () -> Glyph,
                                        title: String, meaning: String?) -> some View {
        HStack(alignment: meaning == nil ? .center : .top, spacing: 14) {
            glyph()
                .frame(width: 38, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                if let meaning {
                    Text(meaning).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
    }
}

/// A tiny compass-arrow mark for the legend — the wind card's direction indicator is a custom shape, not
/// an SF Symbol, so the legend draws a matching miniature rather than borrowing a symbol that isn't used.
private struct WindArrowMark: View {
    var body: some View {
        Image(systemName: "location.north.fill")
            .symbolRenderingMode(.hierarchical)
            .auraFont(20, relativeTo: .title3)
            .foregroundStyle(.teal)
    }
}
