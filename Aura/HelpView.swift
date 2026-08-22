import AuraKit
import SwiftUI

/// "Ayuda" — the reference sheet opened from the hero menu. Two jobs: explain how to get your own free
/// AEMET key, and give a legend for every icon in the app (even the obvious ones — the water drop is
/// humidity, not rain). Colour *scales* aren't repeated here; each card opens its own scale on a tap, so
/// this points there instead. Presented as a sheet, like Ajustes.
struct HelpView: View {
    /// AEMET's self-service page: enter an email, the key arrives by return mail.
    private let apiKeyURL = URL(string: "https://opendata.aemet.es/centrodedescargas/altaUsuario")!

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
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
            .navigationTitle("Ayuda")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Clave de AEMET

    private var apiKeySection: some View {
        Section {
            Text("Aura muestra la previsión de AEMET, que es pública y gratuita. Para usarla necesitas tu "
                 + "propia clave, también gratis y personal.")
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 8) {
                step(1, "Abre la página de AEMET (botón de abajo).")
                step(2, "Escribe tu correo y acepta las condiciones.")
                step(3, "AEMET te envía la clave por correo (mira también en spam).")
                step(4, "Pégala en Ajustes → Clave API.")
            }
            .padding(.vertical, 2)
            Link(destination: apiKeyURL) {
                Label("Solicitar mi clave en AEMET", systemImage: "arrow.up.right.square")
            }
        } header: {
            Text("Tu clave de AEMET")
        } footer: {
            Text("Si la previsión deja de actualizarse, pide otra clave del mismo modo y vuelve a pegarla.")
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
            Text("Condiciones del cielo")
        } footer: {
            Text("De noche, el sol de estos iconos se convierte en luna.")
        }
    }

    private var temperatureSection: some View {
        Section {
            iconRow("arrow.up",   "Temperatura máxima", "La más alta prevista para el día.")
            iconRow("arrow.down", "Temperatura mínima", "La más baja prevista para el día.")
        } header: {
            Text("Temperatura")
        } footer: {
            Text("Los grados se colorean en una escala continua de azul (frío) a rojo (calor), la misma en "
                 + "las tarjetas, las barras de rango y los widgets.")
        }
    }

    private var rainHumiditySection: some View {
        Section {
            iconRow("umbrella.fill", "Probabilidad de lluvia", "El porcentaje de que llueva. Es la lluvia.")
            iconRow("drop.fill", "Probabilidad de lluvia (reloj)", "La gota lisa del medidor de lluvia en el reloj.")
            iconRow("humidity.fill", "Humedad relativa", "El agua que hay en el aire, en %. No es la lluvia.")
        } header: {
            Text("Lluvia y humedad")
        } footer: {
            Text("La gota con ondas (humedad) y el paraguas o la gota lisa (lluvia) son cosas distintas a "
                 + "propósito.")
        }
    }

    private var windSection: some View {
        Section {
            iconRow("wind", "Velocidad del viento", "En km/h, la unidad que da AEMET.")
            legendRow(glyph: { WindArrowMark() },
                      title: "Rosa de los vientos",
                      meaning: "La flecha señala la dirección del viento y su color, la intensidad.")
        } header: {
            Text("Viento")
        } footer: {
            Text("Toca la tarjeta del viento para ver la escala Beaufort completa.")
        }
    }

    private var sunMoonSection: some View {
        Section {
            iconRow("sunrise.fill", "Amanecer", "La salida del sol (orto).")
            iconRow("sunset.fill",  "Atardecer", "La puesta del sol (ocaso).")
            conditionRow("11", night: true, "La luna está sobre el horizonte: es de noche.")
        } header: {
            Text("Sol y luna")
        }
    }

    private var uvSection: some View {
        Section {
            iconRow("sun.max.fill",                          "UV bajo (0–2)", "Sin protección necesaria.")
            iconRow("sunglasses.fill",                       "UV moderado (3–5)", "Gafas de sol y crema.")
            iconRow("sun.max.trianglebadge.exclamationmark", "UV alto (6–7)", "Protégete del sol.")
            iconRow("beach.umbrella.fill",                   "UV muy alto (8–10)", "Evita el sol del mediodía.")
            iconRow("thermometer.variable.and.figure",       "UV extremadamente alto (11+)", "Evita la exposición al sol.")
        } header: {
            Text("Índice UV")
        } footer: {
            Text("El UV es el máximo previsto del día con el cielo despejado. Toca la tarjeta para ver "
                 + "cada nivel.")
        }
    }

    private var airSection: some View {
        Section {
            iconRow("aqi.medium", "Calidad del aire (ICA)", "El Índice de Calidad del Aire de MITECO.")
        } header: {
            Text("Calidad del aire")
        } footer: {
            Text("Toca la tarjeta para ver la escala completa y cada contaminante por separado.")
        }
    }

    private var avisoSection: some View {
        Section {
            iconRow("exclamationmark.triangle.fill", "Aviso meteorológico", "AEMET tiene un aviso activo para la zona.")
        } header: {
            Text("Avisos")
        } footer: {
            Text("El color del aviso indica el nivel: amarillo, naranja o rojo, de menor a mayor peligro.")
        }
    }

    private var appSection: some View {
        Section {
            iconRow("line.3.horizontal",   "Menú", "Abre las secciones de la app.")
            iconRow("text.alignleft",      "Predicción", "El parte escrito del día.")
            iconRow("mappin.and.ellipse",  "Ubicaciones", "Tus lugares guardados.")
            iconRow("gearshape",           "Ajustes", "Tu clave y las opciones.")
            iconRow("questionmark.circle", "Ayuda", "Esta pantalla.")
            iconRow("cup.and.saucer",      "Propina", "Invítame a un café, si te apetece.")
            iconRow("info.circle",         "Acerca de Aura", "Versión, fuentes y créditos.")
            iconRow("location.fill",       "Tu ubicación", "El lugar que se muestra, o usar el actual.")
            iconRow("mappin.slash",        "Sin ubicación", "Aún no hay ningún lugar elegido.")
            iconRow("key",                 "Falta tu clave", "Añade tu clave de AEMET en Ajustes.")
            iconRow("checkmark.seal",      "Clave guardada", "Tu clave de AEMET está guardada en el Llavero.")
            iconRow("plus",                "Añadir", "Guarda una ubicación nueva.")
            iconRow("checkmark",           "Elegida", "La ubicación que se está mostrando.")
            iconRow("chevron.down",        "Desplegar", "Muestra más detalle.")
            iconRow("xmark.circle.fill",   "Cerrar", "Cierra la ficha o la escala abierta.")
        } header: {
            Text("En la app")
        }
    }

    private var scalesSection: some View {
        Section {
            Text("Muchas tarjetas se pueden tocar para abrir su escala de color, con tu valor actual "
                 + "señalado: Viento (Beaufort), Calidad del aire (ICA) y UV.")
                .font(.subheadline)
        } header: {
            Text("Escalas de color")
        } footer: {
            Text("La temperatura usa la misma escala azul→rojo en toda la app: tarjetas, barras y widgets.")
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
                .font(.system(size: 22))
        }, title: title, meaning: meaning)
    }

    /// A legend row whose glyph is a weather condition, drawn by the very same `ConditionGlyph` the cards
    /// use, so the legend can't drift from the app. The condition symbols are made to sit on Aura's sky —
    /// its clouds are near-white and vanish on a light form — so each rides a small sky tile, day or night,
    /// exactly as it appears in the app.
    private func conditionRow(_ code: String, night: Bool, _ title: String) -> some View {
        legendRow(glyph: {
            ConditionGlyph(sky: code, isNight: night)
                .font(.system(size: 19))
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
            .font(.system(size: 20))
            .foregroundStyle(.teal)
    }
}
