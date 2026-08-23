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
// New per-metric complication faces filling out the WIDGETS.md catalog: UV + wind corner content
// (the bezel arc is drawn by WidgetKit on a real face, so these show the corner *content* only), and
// the rectangular sun combo for the Modular centre slot.
dump("uv-corner",   size: CGSize(width: 44,  height: 44)) { AuraUVCorner(snapshot: snap) }
dump("wind-corner", size: CGSize(width: 44,  height: 44)) { AuraWindCorner(snapshot: snap) }
dump("sun-rect",    size: CGSize(width: 170, height: 76)) { AuraRectSun(snapshot: snap) }
dump("hours",       size: CGSize(width: 170, height: 76)) { AuraRectHours(snapshot: snap) }
dump("days",        size: CGSize(width: 170, height: 76)) { AuraRectDays(snapshot: snap) }

// UV and rain circular complications across their bands, so the per-band glyph, the index/percentage
// colour and the ring tint can all be eyeballed (and every SF Symbol name confirmed to resolve — a
// bad name renders blank at runtime, not at compile time). Minimal snapshots: only the field each
// card reads is set, everything else defaults.
func uvSnap(_ v: Int) -> WeatherSnapshot {
    WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                    tempMin: 18, tempMax: 34, humedadMax: 50,
                    uvIndex: UVIndex(value: v),
                    sunrise: nil, sunset: nil, updated: Date())
}
func rainSnap(_ p: Int) -> WeatherSnapshot {
    WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                    tempMin: 18, tempMax: 34, humedadMax: 50,
                    currentPrecipProb: p,
                    sunrise: nil, sunset: nil, updated: Date())
}
for v in [1, 4, 7, 9, 11] {   // one per WHO band: bajo, moderado, alto, muy alto, extremo
    dump("uv-\(v)", size: CGSize(width: 76, height: 76)) { AuraUVCircular(snapshot: uvSnap(v)) }
}
for p in [10, 45, 70, 95] {   // up the probability ramp: pálido → tempBlue → tempDeepBlue → intenso
    dump("rain-\(p)", size: CGSize(width: 76, height: 76)) { AuraRainCircular(snapshot: rainSnap(p)) }
}

// ---- New Lock Screen / complication faces: resumen, humedad, aviso ----
// The preview snapshot already carries humidity (42%), precip (15%) and an active naranja aviso, so each
// renders populated. `dump` writes both the colour (watch face) and desaturated (Lock Screen) versions.
dump("summary-inline", size: CGSize(width: 180, height: 34)) { AuraSummaryInline(snapshot: snap) }
dump("humidity",       size: CGSize(width: 76,  height: 76)) { AuraHumidityCircular(snapshot: snap) }
dump("aviso-circular", size: CGSize(width: 76,  height: 76)) { AuraAvisoCircular(snapshot: snap) }
dump("aviso-inline",   size: CGSize(width: 180, height: 34)) { AuraAvisoInline(snapshot: snap) }
// The iPad rectangular takes the WIDE branch (width > 220): the near-square 2-up read with the
// top-trailing aviso triangle. (The narrow "rectangular" render above now shows the enriched compact —
// aviso-led sky line + rain/humidity figures.)
dump("rectangular-ipad", size: CGSize(width: 330, height: 160)) { AuraAccessoryRectangular(snapshot: snap) }
// The iPad Lock Screen's 2×2 cell is far squarer than the 1×2 strip above — check the wide 2-up read
// doesn't run past the bottom of a near-square slot (the "2×2 text is cut" report).
dump("rectangular-ipad2x2", size: CGSize(width: 250, height: 172)) { AuraAccessoryRectangular(snapshot: snap) }

// NOTE: the Home Screen cards (AuraHomeSmall/Medium/Large/XL) are intentionally NOT rendered here —
// ImageRenderer segfaults on them offline. They build green in the widget extension and are verified in
// the simulator instead; only the Lock Screen / complication faces above are dev-rendered.

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
    .frame(width: size.width, height: size.height, alignment: .top)   // show the top of the scroll, not a centred crop
    .clipShape(RoundedRectangle(cornerRadius: isPhone ? 32 : 40, style: .continuous))
    .environment(\.colorScheme, .dark)
    .fontDesign(.rounded)   // mirror RootView so the preview reflects the app's single typeface
}

// iPad / Mac (Designed for iPad): the card column is capped to a comfortable width and centred over a
// full-bleed sky (mirrors TodayView's `.frame(maxWidth: 620)` on the regular size class), so the cards
// sit inset instead of stretching the full window width.
@MainActor
func appScreenWide(size: CGSize, now: Date) -> some View {
    ZStack(alignment: .top) {
        AuraSky(snapshot: .preview, now: now)
        AuraForecastStack(snapshot: .preview, size: .phone, now: now, hoursScroll: false)
            .padding(.horizontal, 16)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .padding(.top, 16)
    }
    .frame(width: size.width, height: size.height, alignment: .top)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .environment(\.colorScheme, .dark)
    .fontDesign(.rounded)
}
let renderCal = Calendar.current
func todayAt(_ h: Int, _ m: Int) -> Date {
    renderCal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
}
// Mac window aspect from the screenshot (~1010×860 content), tall enough to show the top cards.
write(appScreenWide(size: CGSize(width: 1010, height: 1500), now: todayAt(20, 40)),
      name: "app-ipad-wide", size: CGSize(width: 1010, height: 1500))
for (label, when) in [("1morning", todayAt(8, 0)), ("2noon", todayAt(13, 30)),
                      ("3sunset", todayAt(20, 40)), ("4night", todayAt(23, 30))] {
    let phone = CGSize(width: 300, height: 1880)   // tall enough to show the whole stack (device scrolls)
    let watch = CGSize(width: 184, height: 1320)   // tall enough to show the full stack (device scrolls)
    write(appScreen(size: phone, now: when), name: "app-phone-\(label)", size: phone)
    write(appScreen(size: watch, now: when), name: "app-watch-\(label)", size: watch)
}

// ---- Sun/moon occlusion across conditions ----
// One tall sky tile per condition at the *same* solar position, so the disc going from a crisp point
// of light (clear) to a swollen, dim smudge (rain / storm / fog) is visible side by side. Same at
// night for the moon. Occlusion is driven off the `veil` table (radius shrink + blur growth).
@MainActor
func occlusionTile(code: String, now: Date) -> some View {
    let s = WeatherSnapshot(ine: "0", localidad: "", provincia: "",
                            tempMin: nil, tempMax: nil, humedadMax: nil,
                            currentSky: code, sunrise: todayAt(7, 0), sunset: todayAt(21, 0),
                            updated: Date())
    return AuraSky(snapshot: s, now: now)
        .frame(width: 120, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.colorScheme, .dark)
}
@MainActor
func occlusionMatrix(now: Date) -> some View {
    let conds: [(name: String, code: String)] = [
        ("despejado", "11"), ("poco nub.", "12"), ("nuboso", "14"), ("cubierto", "16"),
        ("niebla", "81"), ("lluvia", "25"), ("tormenta", "52"), ("nieve", "34"),
    ]
    return HStack(spacing: 8) {
        ForEach(conds, id: \.code) { c in
            VStack(spacing: 4) {
                occlusionTile(code: c.code, now: now)
                Text(c.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
            }
        }
    }
    .padding(10)
    .background(Color(white: 0.10))
}
let occSize = CGSize(width: 120 * 8 + 8 * 7 + 20, height: 260)
write(occlusionMatrix(now: todayAt(13, 0)), name: "occlusion-noon", size: occSize)
write(occlusionMatrix(now: todayAt(23, 0)), name: "occlusion-night", size: occSize)

// ---- Moon phase disc, the eight principal phases ----
// The bare PhasedMoonDisc across a full cycle, waxing (lit on the right) then waning (mirrored), so the
// terminator geometry and the ashen earthshine body of a new moon can be judged directly.
@MainActor
func moonDiscSweep() -> some View {
    let phases: [(name: String, illum: Double, waxing: Bool)] = [
        ("Nueva", 0.00, true), ("Creciente", 0.25, true), ("C. creciente", 0.50, true),
        ("G. creciente", 0.85, true), ("Llena", 1.00, true), ("G. menguante", 0.85, false),
        ("C. menguante", 0.50, false), ("Menguante", 0.25, false),
    ]
    return HStack(spacing: 10) {
        ForEach(phases, id: \.name) { p in
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.06))
                    PhasedMoonDisc(illumination: p.illum, waxing: p.waxing, radius: 26,
                                   litColor: Color(red: 0.94, green: 0.96, blue: 1.0))
                }
                .frame(width: 96, height: 96)
                Text(p.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
            }
        }
    }
    .padding(12)
    .background(Color(white: 0.12))
}
let moonSweepSize = CGSize(width: 96 * 8 + 10 * 7 + 24, height: 132)
write(moonDiscSweep(), name: "moon-disc-sweep", size: moonSweepSize)

// ---- Moon phase in context: AuraSky at night, clear, across the cycle ----
// Each tile forces a `now` an exact phase-fraction past a known new moon, with sun times set so it reads
// as night, so the moonglow scaling (new = dark sky, full = lit) and the phased disc show together.
@MainActor
func moonSkyTile(offset: Double) -> some View {
    let synodic = AuraKit.MoonPhaseMath.synodicMonth * 86_400
    let now = AuraKit.MoonPhaseMath.referenceNewMoon.addingTimeInterval((329 + offset) * synodic)
    let s = WeatherSnapshot(ine: "0", localidad: "", provincia: "",
                            tempMin: nil, tempMax: nil, humedadMax: nil,
                            currentSky: "11",                                   // despejado: most stars
                            sunrise: now.addingTimeInterval(-10 * 3600),        // both before `now` → night,
                            sunset: now.addingTimeInterval(-2 * 3600),          // 2 h after dusk (moon mid-low)
                            updated: now)
    return AuraSky(snapshot: s, now: now)
        .frame(width: 150, height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .environment(\.colorScheme, .dark)
}
@MainActor
func moonSkySweep() -> some View {
    let cols: [(name: String, offset: Double)] = [
        ("Nueva", 0.0), ("Creciente", 0.125), ("C. creciente", 0.25),
        ("Llena", 0.5), ("C. menguante", 0.75), ("Menguante", 0.875),
    ]
    return HStack(spacing: 8) {
        ForEach(cols, id: \.name) { c in
            VStack(spacing: 4) {
                moonSkyTile(offset: c.offset)
                Text(c.name).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
            }
        }
    }
    .padding(10)
    .background(Color(white: 0.10))
}
let moonSkySize = CGSize(width: 150 * 6 + 8 * 5 + 20, height: 300)
write(moonSkySweep(), name: "moon-sky-sweep", size: moonSkySize)

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
    .frame(width: 320, height: 380)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
}
write(radarPreview(), name: "app-radar-card", size: CGSize(width: 320, height: 380))

// The full sun arc card over a noon sky: the live-position arc, orto/ocaso ends, the daylight-remaining
// readout, and the new solar-noon + day-length lines (with the day-over-day delta). Built from a real
// SolarTimes solve for Madrid today + Madrid coords, so the delta ("N min que ayer") is truthful.
@MainActor
func sunCardPreview() -> some View {
    let when = todayAt(13, 0)
    let lat = 40.4168, lon = -3.7038
    let sun = SolarTimes(date: when, latitude: lat, longitude: lon)
    let snap = WeatherSnapshot(
        ine: "28079", localidad: "Madrid", provincia: "Madrid",
        tempMin: 18, tempMax: 34, humedadMax: 55,
        sunrise: sun.sunrise, sunset: sun.sunset,
        latitude: lat, longitude: lon,
        updated: when)
    return ZStack {
        AuraSky(snapshot: .preview, now: when)
        AuraSunArcCard(snapshot: snap, size: .phone, now: when)
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 320, height: 300)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .fontDesign(.rounded)
}
write(sunCardPreview(), name: "app-sun-card", size: CGSize(width: 320, height: 300))

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

// The watch wind card: same needle-through-a-clean-dial as the phone (no redundant centre number, since
// the speed is spelled out beside it) but on the plain 32-point rose that stays legible when desaturated.
@MainActor
func windCardWatchPreview() -> some View {
    ZStack {
        AuraSky(snapshot: .preview, now: todayAt(13, 0))
        AuraWindCard(snapshot: .preview, size: .watch)
            .environment(\.colorScheme, .dark)
            .padding(10)
    }
    .frame(width: 198, height: 130)
    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
}
write(windCardWatchPreview(), name: "app-wind-card-watch", size: CGSize(width: 198, height: 130))

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
// station), then a row of colour-coded chips — each of the five ICA pollutants tinted by its own band,
// grey for the ones the station doesn't measure, the driver ringed. Preview station reports all five.
@MainActor
func airQualityCardPreview(_ aq: AirQuality) -> some View {
    ZStack {
        AuraSky(snapshot: .preview, now: todayAt(13, 0))
        AuraAirQualityCard(airQuality: aq, size: .phone)
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 340, height: 230)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .fontDesign(.rounded)
}
write(airQualityCardPreview(WeatherSnapshot.preview.airQuality!),
      name: "app-airquality-card", size: CGSize(width: 340, height: 230))

// A partial breakdown: NO₂ from the nearest urban station, O₃ from a background station farther out;
// PM2,5, PM10 and SO₂ aren't found nearby, so their chips show grey with a dash (MITECO's grey-for-
// unavailable convention). The composite (worst = NO₂) is built by the real `composite` path.
let aqNow = todayAt(13, 0)
let partialAQ = MitecoAirQuality.composite(from: [
    AirComponent(pollutant: "NO2", value: 96, station: "Escuelas Aguirre", distanceKm: 0.8, measured: todayAt(12, 0)),
    AirComponent(pollutant: "O3", value: 58, station: "Casa de Campo", distanceKm: 6.4, measured: todayAt(11, 0)),
])!
write(airQualityCardPreview(partialAQ),
      name: "app-airquality-card-partial", size: CGSize(width: 340, height: 230))

// A full breakdown drawn from several stations: NO₂/particulates from the nearest, O₃ from a background
// station a few km out, SO₂ from an industrial one farther still — each labelled with its own source.
let fullAQ = MitecoAirQuality.composite(from: [
    AirComponent(pollutant: "NO2", value: 96, station: "Escuelas Aguirre", distanceKm: 0.8, measured: todayAt(12, 0)),
    AirComponent(pollutant: "O3", value: 63, station: "Casa de Campo", distanceKm: 6.4, measured: todayAt(12, 0)),
    AirComponent(pollutant: "PM2.5", value: 12, station: "Escuelas Aguirre", distanceKm: 0.8, measured: todayAt(12, 0)),
    AirComponent(pollutant: "PM10", value: 18, station: "Escuelas Aguirre", distanceKm: 0.8, measured: todayAt(12, 0)),
    AirComponent(pollutant: "SO2", value: 5, station: "Villaverde", distanceKm: 9.1, measured: todayAt(11, 0)),
])!

// The tap-through detail sheets: the reference scales that open when a wind / air-quality / UV card is
// tapped, with the current reading ringed and tagged "Ahora". Rendered as their own content (the sheet
// chrome — grabber, detents — is added by the system at runtime), tall enough to show every row.
@MainActor
func sheetPreview<V: View>(_ view: V, size: CGSize) -> some View {
    view.frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .fontDesign(.rounded)
}
write(sheetPreview(AuraBeaufortSheet(snapshot: .preview, scrolls: false),
                   size: CGSize(width: 380, height: 1120)),
      name: "sheet-beaufort", size: CGSize(width: 380, height: 1120))
write(sheetPreview(AuraAirQualitySheet(airQuality: fullAQ, now: aqNow, scrolls: false),
                   size: CGSize(width: 380, height: 1680)),
      name: "sheet-airquality", size: CGSize(width: 380, height: 1680))
// A station set that yields only NO₂ and O₃ — so PM2,5, PM10 and SO₂ show the "No medido" grey rail.
write(sheetPreview(AuraAirQualitySheet(airQuality: partialAQ, now: aqNow, scrolls: false),
                   size: CGSize(width: 380, height: 1560)),
      name: "sheet-airquality-partial", size: CGSize(width: 380, height: 1560))
write(sheetPreview(AuraUVSheet(uvIndex: UVIndex(value: 8), scrolls: false),
                   size: CGSize(width: 380, height: 660)),
      name: "sheet-uv", size: CGSize(width: 380, height: 660))
// Moon detail sheet: Madrid coordinates and a fixed waxing-gibbous evening (2026-08-23 22:00 UTC, moon up)
// so phase, true illumination and both moonrise/moonset populate — the .preview snapshot carries no coords.
func utcDate(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    var c = DateComponents(); c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    c.timeZone = TimeZone(identifier: "UTC")
    return Calendar(identifier: .gregorian).date(from: c) ?? Date()
}
let moonSnap = WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                               tempMin: nil, tempMax: nil, humedadMax: nil,
                               currentSky: "11", sunrise: nil, sunset: nil,
                               latitude: 40.4168, longitude: -3.7038, updated: utcDate(2026, 8, 23, 22, 0))
write(sheetPreview(AuraMoonSheet(snapshot: moonSnap, now: utcDate(2026, 8, 23, 22, 0), scrolls: false),
                   size: CGSize(width: 380, height: 720)),
      name: "sheet-moon", size: CGSize(width: 380, height: 720))

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

// PROTOTYPE: phased moon (MoonPreview.swift). The eight principal phases, a crescent traversing the
// arc, and tonight's actual moon — brightness of disc + glow tracks illumination.
write(moonPhaseChart(), name: "moon-phases", size: CGSize(width: 1360, height: 220))
write(moonTraverse(fraction: 0.15,
                   positions: [.init(x: 0.5, y: 0.55), .init(x: 0.5, y: 0.42),
                               .init(x: 0.5, y: 0.30), .init(x: 0.5, y: 0.42),
                               .init(x: 0.5, y: 0.55)]),
      name: "moon-traverse", size: CGSize(width: 820, height: 200))
write(moonTonight(now: Date()), name: "moon-tonight", size: CGSize(width: 340, height: 360))

// Sun-disc parity check: AuraSky at REAL device point sizes (phone portrait vs iPad landscape), same
// clear noon. The disc radius is capped (see AuraSky), so the sun should read at the same physical size
// on both rather than ballooning on the larger iPad canvas.
@MainActor
func discCheck(size: CGSize) -> some View {
    AuraSky(snapshot: .preview, now: todayAt(13, 0))
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, .dark)
}
write(discCheck(size: CGSize(width: 393, height: 852)), name: "disc-phone", size: CGSize(width: 393, height: 852))
write(discCheck(size: CGSize(width: 1194, height: 834)), name: "disc-ipad", size: CGSize(width: 1194, height: 834))

// The app UV card: AEMET's forecast daily-max swatch (band glyph beside the band name, the symbol the
// complication shows) plus the CAMS hourly curve beneath it — today's UV hour by hour, current hour
// outlined and its value called out.
@MainActor
func uvCardPreview() -> some View {
    let when = todayAt(13, 0)
    return ZStack {
        AuraSky(snapshot: .preview, now: when)
        AuraUVCard(uvIndex: UVIndex(value: 8), hourly: WeatherSnapshot.preview.uvHourly ?? [],
                   now: when, size: .phone)
            .environment(\.colorScheme, .dark)
            .padding(16)
    }
    .frame(width: 340, height: 232)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .fontDesign(.rounded)
}
write(uvCardPreview(), name: "app-uv-card", size: CGSize(width: 340, height: 232))

// ---- UV complication "ahora": current-hour reading on a 0…today's-peak ring ----
// The preview snapshot carries a realistic CAMS bell (peak index 8 around 14h). Rendered at three hours
// so the ring's partial fill and its WHO-graded colour track the live index — 3 (morning, moderate) →
// 8 (peak, muy alto) → 4 (afternoon) — instead of a flat daily-max ring.
for (label, h) in [("morning", 9), ("peak", 13), ("afternoon", 17)] {
    let when = todayAt(h, 0)
    dump("uvnow-\(label)", size: CGSize(width: 76, height: 76)) {
        AuraUVCircular(snapshot: .preview, now: when)
    }
    dump("uvnow-corner-\(label)", size: CGSize(width: 44, height: 44)) {
        AuraUVCorner(snapshot: .preview, now: when)
    }
}

// ---- Sun sitting BEHIND the scenery (heroHorizon), across the hero surfaces ----
// Loads the real shipped art off disk (the SwiftPM bundle doesn't carry the app's asset catalog) and
// draws the live AuraSky sun over it at a low dusk sun, so the pin above each art's skyline can be judged
// the way it renders on device. Wide bases (iPad/widget) are conditionless; portrait heroes are the
// condition-baked dusk art.
let repoRoot = FileManager.default.currentDirectoryPath
@MainActor
func diskImage(_ rel: String) -> Image? {
    guard let ns = NSImage(contentsOfFile: "\(repoRoot)/\(rel)") else { return nil }
    return Image(nsImage: ns)
}
// A clear-sky snapshot whose sun is low (render time 20:40, sunset 21:11) so the horizon clamp bites.
let lowSunSnap = WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                                 tempMin: 18, tempMax: 30, humedadMax: 50, currentSky: "11",
                                 sunrise: todayAt(7, 12), sunset: todayAt(21, 11), updated: Date())
let duskNow = todayAt(20, 40)
@MainActor
func heroTile(_ image: Image?, horizon: CGFloat, aspect: CGFloat, carriesCondition: Bool,
              size: CGSize) -> some View {
    ZStack {
        AuraSky(snapshot: lowSunSnap, now: duskNow, heroImage: image,
                heroCarriesCondition: carriesCondition, heroAnchor: .bottom,
                heroHorizon: horizon, heroAspect: aspect)
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .environment(\.colorScheme, .dark)
}
// Wide bases — the widget/iPad canvas (2:1-ish). Landscape now pins above the mountain PEAK (0.50), the
// city keeps its low skyline (0.84).
write(heroTile(diskImage("hero_asset_creation/output/wide_landscape_day.png"),
               horizon: HeroBackground.wideBaseHorizon(.landscape), aspect: HeroBackground.wideBaseAspect,
               carriesCondition: false, size: CGSize(width: 380, height: 190)),
      name: "hero-wide-landscape", size: CGSize(width: 380, height: 190))
write(heroTile(diskImage("hero_asset_creation/output/wide_city_day.png"),
               horizon: HeroBackground.wideBaseHorizon(.cityscape), aspect: HeroBackground.wideBaseAspect,
               carriesCondition: false, size: CGSize(width: 380, height: 190)),
      name: "hero-wide-city", size: CGSize(width: 380, height: 190))
// Portrait heroes — the phone screen and the wrist. Landscape pins above the peak (0.52), city above the
// tallest tower (0.60). Rendered at both a phone aspect and the near-square wrist (the worst crop).
for (fam, rel, horizon) in [("landscape", "Aura/Assets.xcassets/clear_dusk.imageset/clear_dusk.png",
                             HeroBackground.heroHorizon(.landscape)),
                            ("city", "Aura/Assets.xcassets/city_clear_dusk.imageset/city_clear_dusk.png",
                             HeroBackground.heroHorizon(.cityscape))] {
    write(heroTile(diskImage(rel), horizon: horizon, aspect: HeroBackground.heroAspect,
                   carriesCondition: true, size: CGSize(width: 230, height: 470)),
          name: "hero-phone-\(fam)", size: CGSize(width: 230, height: 470))
    write(heroTile(diskImage(rel), horizon: horizon, aspect: HeroBackground.heroAspect,
                   carriesCondition: true, size: CGSize(width: 200, height: 232)),
          name: "hero-watch-\(fam)", size: CGSize(width: 200, height: 232))
}
