import AppKit
import AuraKit
import SwiftUI

// Renders the Apple Watch app's hero screen (location · moment, temperature, headline, forecast prose over
// the live sky) at the real Apple Watch Ultra 2 (49mm) resolution — 410×502 — for the App Store product
// page. This is the CITYSCAPE companion set to the four nature captures in screenshots/watch: the same
// four moments and conditions (dawn/rain, noon/clear, dusk/storm, night/snow), drawn over the cityscape
// hero art instead. Dev tool, not shipped. Run:  swift run aura-watch-shots [outdir]
//
// Faithful to WatchRootView: AuraSky (the condition-baked cityscape hero, pinned to the ground, with the
// live sun/moon disc) under AuraForecastStack(size: .watch, heroFillHeight:), so the cards fall below the
// fold and the first screen is the clean editorial hero — exactly what the sim capture shows. The one
// thing an offline render can't carry is the watchOS system clock the real captures show top-right.

let outDir = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let repoRoot = FileManager.default.currentDirectoryPath

@MainActor
func diskImage(_ rel: String) -> Image? {
    guard let ns = NSImage(contentsOfFile: "\(repoRoot)/\(rel)") else { return nil }
    return Image(nsImage: ns)
}

let cal = Calendar.current
func todayAt(_ h: Int, _ m: Int) -> Date {
    cal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
}

// A fixed day span so the sun-path buckets (and the momentLabel + disc position) land where each scene
// wants them: dawn just after sunrise, noon mid-arc, dusk just before sunset, night after sunset.
let sunrise = todayAt(7, 0), sunset = todayAt(21, 0)

/// One watch scene: which cityscape hero to draw, the moment (drives momentLabel + disc), and a snapshot
/// whose fields make the headline/dataline read for that condition.
struct Scene {
    let name: String            // output filename (without extension)
    let asset: String           // city_<condition>_<time> on disk
    let snapshot: WeatherSnapshot
}

/// Build a Madrid snapshot for one condition. `now` sets the moment; sunrise/sunset are the shared span.
func snap(sky: String, skyText: String, now: Date,
          temp: Int, lo: Int, hi: Int, humidity: Int,
          wind: Int, dir: WindDirection,
          precip: Int? = nil, storm: Int? = nil, snow: Double? = nil) -> WeatherSnapshot {
    WeatherSnapshot(ine: "28079", localidad: "Madrid", provincia: "Madrid",
                    tempMin: lo, tempMax: hi, humedadMax: humidity,
                    currentTemp: temp, currentSky: sky, currentSkyText: skyText,
                    currentHumidity: humidity, currentPrecipProb: precip,
                    currentSnowMm: snow, currentStormProb: storm,
                    windSpeed: wind, windDirection: dir,
                    sunrise: sunrise, sunset: sunset, updated: now)
}

let scenes: [Scene] = [
    Scene(name: "app_city_dawn_rain", asset: "city_rainy_dawn",
          snapshot: snap(sky: "23", skyText: "Lluvia", now: todayAt(7, 30),
                         temp: 13, lo: 11, hi: 18, humidity: 88, wind: 14, dir: .ne, precip: 80)),
    Scene(name: "app_city_noon_clear", asset: "city_clear_noon",
          snapshot: snap(sky: "11", skyText: "Despejado", now: todayAt(14, 0),
                         temp: 34, lo: 22, hi: 38, humidity: 20, wind: 8, dir: .o)),
    Scene(name: "app_city_dusk_storm", asset: "city_stormy_dusk",
          snapshot: snap(sky: "51", skyText: "Tormenta", now: todayAt(20, 15),
                         temp: 24, lo: 19, hi: 30, humidity: 70, wind: 25, dir: .s, precip: 90, storm: 80)),
    Scene(name: "app_city_night_snow", asset: "city_snowy_night",
          snapshot: snap(sky: "33", skyText: "Nieve", now: todayAt(22, 30),
                         temp: -1, lo: -3, hi: 2, humidity: 90, wind: 12, dir: .n, snow: 5)),
]

// The Apple Watch Ultra 2 (49mm) screen is 410×502 px at @2x → 205×251 pt. Rendering at scale 2 lands on
// the exact 410×502 the sim captures use, so these sit beside the nature set at identical pixels.
let watchPt = CGSize(width: 205, height: 251)

@MainActor
func render(_ scene: Scene) {
    let s = scene.snapshot
    let hero = diskImage("Aura/Assets.xcassets/\(scene.asset).imageset/\(scene.asset).png")
    if hero == nil { print("⚠︎ \(scene.name): hero \(scene.asset) not found — procedural sky") }

    let view = ZStack(alignment: .top) {
        AuraSky(snapshot: s, now: s.updated, heroImage: hero,
                heroCarriesCondition: true, heroAnchor: .bottom,
                heroHorizon: HeroBackground.heroHorizon(.cityscape),
                heroAspect: HeroBackground.heroAspect)
        AuraForecastStack(snapshot: s, size: .watch, now: s.updated,
                          hoursScroll: false, heroFillHeight: watchPt.height)
            .padding(.horizontal, 4)
            .padding(.top, 40)   // clear where the system clock and the rounded top corners sit
    }
    .frame(width: watchPt.width, height: watchPt.height, alignment: .top)
    .background(Color.black)     // opaque, rectangular: match the sim framebuffer, no corner clip
    .environment(\.colorScheme, .dark)
    .fontDesign(.rounded)

    let renderer = ImageRenderer(content: view.frame(width: watchPt.width, height: watchPt.height))
    renderer.scale = 2
    guard let cg = renderer.cgImage else { print("✗ \(scene.name): render failed"); return }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    let path = "\(outDir)/\(scene.name).png"
    do { try data.write(to: URL(fileURLWithPath: path)); print("✓ \(path) (\(cg.width)×\(cg.height))") }
    catch { print("✗ \(scene.name): \(error)") }
}

for scene in scenes { render(scene) }
print("done — \(scenes.count) cityscape watch screens written to \(outDir)")
