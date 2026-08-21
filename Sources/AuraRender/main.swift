import AppKit
import AuraKit
import SwiftUI

// Renders the accessory faces to PNGs at their true point sizes, so layout/legibility can be judged
// without a device. Not shipped — a dev tool. Run:  swift run aura-render [outdir]
//
// Caveat: the watch corner's bezel arc is drawn by WidgetKit only on a real watch face, so the corner
// PNG here shows the corner *content* alone (icon + degrees), not the curved range gauge.

let outDir = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath

/// Render `view` at `size`, on a dark card, twice: full colour (watch face) and desaturated (an
/// approximation of the iPhone Lock Screen's vibrant, near-monochrome rendering).
@MainActor
func dump(_ name: String, size: CGSize, @ViewBuilder _ view: () -> some View) {
    let content = view()
    let colour = card(size: size) { content }
    write(colour, name: "\(name)-colour", size: size)

    let mono = card(size: size) { content.grayscale(1).brightness(0.06) }
    write(mono, name: "\(name)-lockscreen", size: size)
}

@MainActor
func card(size: CGSize, @ViewBuilder _ view: () -> some View) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: min(size.width, size.height) * 0.28, style: .continuous)
            .fill(Color(white: 0.10))
        view().padding(4)
    }
    .frame(width: size.width, height: size.height)
    .environment(\.colorScheme, .dark)
}

@MainActor
func write(_ view: some View, name: String, size: CGSize) {
    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 5
    guard let cg = renderer.cgImage else { print("✗ \(name): render failed"); return }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    let path = "\(outDir)/\(name).png"
    do { try data.write(to: URL(fileURLWithPath: path)); print("✓ \(path)") }
    catch { print("✗ \(name): \(error)") }
}

let snap = WeatherSnapshot.preview

// iPhone-ish accessory sizes and watch complication regions. The Lock Screen rectangular is rendered
// at the *narrow* ~160pt it collapses to when two rectangulars share the bottom row — the crowded case
// that truncated the temperature on device — so this render reflects the worst case, not a roomy one.
dump("rectangular", size: CGSize(width: 160, height: 72)) { AuraAccessoryRectangular(snapshot: snap) }
dump("circular",    size: CGSize(width: 76,  height: 76)) { AuraAccessoryCircular(snapshot: snap) }
dump("wind",        size: CGSize(width: 84,  height: 84)) { AuraWindCircular(snapshot: snap) }
dump("sun",         size: CGSize(width: 60,  height: 60)) { AuraSunCircular(snapshot: snap) }
dump("corner",      size: CGSize(width: 44,  height: 44)) { AuraAccessoryCorner(snapshot: snap) }
dump("hours",       size: CGSize(width: 170, height: 76)) { AuraRectHours(snapshot: snap) }
dump("days",        size: CGSize(width: 170, height: 76)) { AuraRectDays(snapshot: snap) }

// Temperature ramp: one swatch per degree from -5 to 45, each labelled, so the smooth AEMET/TVE
// progression can be eyeballed (no hard bands, 20° green→yellow hand-off, red ~30°).
@MainActor
func tempRamp() -> some View {
    HStack(spacing: 0) {
        ForEach(Array(stride(from: -5, through: 45, by: 5)), id: \.self) { t in
            VStack(spacing: 2) {
                Text("\(t)").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                Rectangle().fill(Palette.temperature(t)).frame(width: 26, height: 34)
            }
        }
    }
    .padding(6)
    .background(Color(white: 0.10))
}
write(tempRamp(), name: "temp-ramp", size: CGSize(width: 26 * 11 + 12, height: 58))

// ---- Full app screen (the redesign): the shared stack over the sun-tracking sky ----
// Rendered at four times of day so the sun's travel (east → noon → west → night) is visible on a real
// build. Phone and Watch draw the identical stack from AuraKit, only resized.
@MainActor
func appScreen(size: CGSize, now: Date) -> some View {
    let isPhone = size.width > 220
    return ZStack(alignment: .top) {
        AuraSky(snapshot: .preview, now: now)
        AuraForecastStack(snapshot: .preview, size: isPhone ? .phone : .watch, now: now,
                          hoursScroll: false)   // ImageRenderer can't lay out the horizontal strip
            .padding(.horizontal, isPhone ? 14 : 5)
            .padding(.top, isPhone ? 16 : 8)
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: isPhone ? 32 : 40, style: .continuous))
    .environment(\.colorScheme, .dark)
    .fontDesign(.rounded)   // mirror RootView so the preview reflects the app's single typeface
}

let renderCal = Calendar.current
func todayAt(_ h: Int, _ m: Int) -> Date {
    renderCal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
}
for (label, when) in [("1morning", todayAt(8, 0)), ("2noon", todayAt(13, 30)),
                      ("3sunset", todayAt(20, 40)), ("4night", todayAt(23, 30))] {
    let phone = CGSize(width: 300, height: 1880)   // tall enough to show the whole stack (device scrolls)
    let watch = CGSize(width: 184, height: 1320)   // tall enough to show the full stack (device scrolls)
    write(appScreen(size: phone, now: when), name: "app-phone-\(label)", size: phone)
    write(appScreen(size: watch, now: when), name: "app-watch-\(label)", size: watch)
}

// The hourly card on its own over a morning sky — the strip now distributes edge to edge (no scroll),
// so ImageRenderer lays it out in full.
@MainActor
func hoursPreview() -> some View {
    ZStack {
        AuraSky(snapshot: .preview, now: todayAt(8, 0))
        AuraHourlyCard(hours: WeatherSnapshot.preview.hours, size: .phone, scrolls: false)
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 320, height: 150)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
}
write(hoursPreview(), name: "app-hours-populated", size: CGSize(width: 320, height: 150))

// The same hourly card with a dry day (no precip anywhere): the precip row is dropped and the card
// shrinks to the three remaining rows instead of reserving an empty band.
@MainActor
func dryHoursPreview() -> some View {
    let dry = WeatherSnapshot.preview.hours.map {
        HourSlot(hour: $0.hour, temp: $0.temp, sky: $0.sky, precipProb: 0)
    }
    return ZStack {
        AuraSky(snapshot: .preview, now: todayAt(8, 0))
        AuraHourlyCard(hours: dry, size: .phone, scrolls: false)
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 320, height: 150)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
}
write(dryHoursPreview(), name: "app-hours-dry", size: CGSize(width: 320, height: 150))

// The radar card with a PLACEHOLDER frame — the real radar image needs an API key, so this only checks
// the card chrome (title, image frame, freshness subtitle); the actual imagery is verified on-device.
@MainActor
func radarPreview() -> some View {
    ZStack {
        AuraSky(snapshot: .preview, now: todayAt(13, 0))
        AuraRadarCard(radar: AuraRadarInfo(image: Image(systemName: "cloud.rain.fill"),
                                           siteName: "Madrid", time: todayAt(12, 54)),
                      size: .phone, now: todayAt(13, 0))
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 320, height: 320)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
}
write(radarPreview(), name: "app-radar-card", size: CGSize(width: 320, height: 320))

// The full wind card over a noon sky: the detailed (phone) rose — denser 48-point ring, lightened
// marks — with the speed, direction spelled out + numeric bearing, and the gust line.
@MainActor
func windCardPreview() -> some View {
    ZStack {
        AuraSky(snapshot: .preview, now: todayAt(13, 0))
        AuraWindCard(snapshot: .preview, size: .phone)
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 320, height: 200)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
}
write(windCardPreview(), name: "app-wind-card", size: CGSize(width: 320, height: 200))

// The Noticias card: a round-robin RTVE + AEMET stream, each row a tappable headline with a source
// badge and relative time. Sample items (the renderer has no network).
@MainActor
func newsCardPreview() -> some View {
    let now = todayAt(13, 0)
    let samples = [
        NewsItem(title: "El tiempo el fin de semana: bajada de temperaturas y fuertes tormentas",
                 link: URL(string: "https://rtve.es/1")!, source: .rtve,
                 date: now.addingTimeInterval(-40 * 60)),
        NewsItem(title: "Julio de 2026 fue el más cálido de la serie histórica, empatado con 2022",
                 link: URL(string: "https://aemet.es/1")!, source: .aemet,
                 date: now.addingTimeInterval(-3 * 3600)),
        NewsItem(title: "Calor intenso en el este peninsular, con avisos rojos en Valencia y Alicante",
                 link: URL(string: "https://rtve.es/2")!, source: .rtve,
                 date: now.addingTimeInterval(-26 * 3600)),
        NewsItem(title: "Predicción especial para el eclipse solar del 12 de agosto",
                 link: URL(string: "https://aemet.es/2")!, source: .aemet,
                 date: now.addingTimeInterval(-2 * 24 * 3600)),
    ]
    return ZStack {
        AuraSky(snapshot: .preview, now: now)
        AuraNewsCard(items: samples, size: .phone, now: now)
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 340, height: 420)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .fontDesign(.rounded)
}
write(newsCardPreview(), name: "app-news-card", size: CGSize(width: 340, height: 420))

// The air-quality card with the per-pollutant breakdown: the ICA headline (category swatch + driver +
// station), then a row of the measured pollutants (label over µg/m³ value). Preview station reports all
// five; a real traffic station would show only NO₂ (unmeasured pollutants are omitted, not zeroed).
@MainActor
func airQualityCardPreview() -> some View {
    ZStack {
        AuraSky(snapshot: .preview, now: todayAt(13, 0))
        AuraAirQualityCard(airQuality: WeatherSnapshot.preview.airQuality!, size: .phone)
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 340, height: 190)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .fontDesign(.rounded)
}
write(airQualityCardPreview(), name: "app-airquality-card", size: CGSize(width: 340, height: 190))

// The sky ALONE (no cards) at the four times of day, so the sun/moon disc and its travel east→west can
// be judged without the frosted stack covering it. Phone aspect.
@MainActor
func skyOnly(now: Date) -> some View {
    AuraSky(snapshot: .preview, now: now)
        .frame(width: 300, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .dark)
}
for (label, when) in [("1morning", todayAt(8, 0)), ("2noon", todayAt(13, 30)),
                      ("3sunset", todayAt(20, 40)), ("4night", todayAt(23, 30))] {
    write(skyOnly(now: when), name: "sky-\(label)", size: CGSize(width: 300, height: 640))
}
