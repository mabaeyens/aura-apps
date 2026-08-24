import AppKit
import AuraKit
import SwiftUI

// Renders ONLY the Home Screen widget faces (S / M / L / XL) as isolated, transparent-corner PNGs, for
// the App Store custom product page — every widget shown on its own, no Home Screen chrome around it.
// Each face is the real card view (AuraHomeSmall/Medium/Large/XL) over the same AuraSky + sunless hero
// the widget draws via its containerBackground, clipped to the widget's rounded rect. Dev tool, not
// shipped. Run:  swift run aura-widget-shots [outdir]
//
// Sizes are the canonical WidgetKit point sizes: iPhone from the 430pt class (15/16 Pro Max), iPad from
// the 12.9" (1024×1366) portrait. The Home cards use fixed-point fonts, so rendering at the true point
// size reproduces the on-device look. Rendered at scale 4 for a crisp marketing asset.

let outDir = CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath
let repoRoot = FileManager.default.currentDirectoryPath

@MainActor
func diskImage(_ rel: String) -> Image? {
    guard let ns = NSImage(contentsOfFile: "\(repoRoot)/\(rel)") else { return nil }
    return Image(nsImage: ns)
}

let renderCal = Calendar.current
func todayAt(_ h: Int, _ m: Int) -> Date {
    renderCal.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
}

let snap = WeatherSnapshot.preview

/// The widget's containerBackground: the live sky over the sunless wide base, plus the same
/// top-and-bottom scrim `AuraHomeBackground` applies for text contrast. `scene` picks nature vs city,
/// `when` sets the light (afternoon sun in frame vs a low atardecer).
@MainActor
func widgetBackground(_ scene: HeroBackground.Family, when: Date) -> some View {
    let base = diskImage("hero_asset_creation/output/wide_\(scene == .cityscape ? "city" : "landscape")_day.png")
    return ZStack {
        AuraSky(snapshot: snap, now: when,
                heroImage: base,
                heroCarriesCondition: false,
                heroAnchor: .bottom,
                heroHorizon: HeroBackground.wideBaseHorizon(scene),
                heroAspect: HeroBackground.wideBaseAspect,
                compact: true)
        LinearGradient(colors: [.black.opacity(0.22), .clear, .black.opacity(0.38)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// Compose one widget face: full-bleed background, the card content inset by the widget's content margin,
/// clipped to the widget's continuous corner radius. Rendered at scale 4 to a transparent-corner PNG.
@MainActor
func widgetShot(_ name: String, size: CGSize, radius: CGFloat, margin: CGFloat,
                scene: HeroBackground.Family, when: Date,
                @ViewBuilder _ content: () -> some View) {
    let view = ZStack {
        widgetBackground(scene, when: when)
        content()
            .padding(margin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(width: size.width, height: size.height)
    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    .environment(\.colorScheme, .dark)
    .fontDesign(.rounded)

    let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
    renderer.scale = 4
    guard let cg = renderer.cgImage else { print("✗ \(name): render failed"); return }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    let path = "\(outDir)/\(name).png"
    do { try data.write(to: URL(fileURLWithPath: path)); print("✓ \(path) (\(cg.width)×\(cg.height))") }
    catch { print("✗ \(name): \(error)") }
}

/// Render the full seven-face set (iPhone S/M/L + iPad S/M/L/XL) under one light + scene. `suffix` tags
/// the filenames so the variants sit side by side (e.g. `widget-iphone-l-sunset.png`).
@MainActor
func renderSet(_ suffix: String, when: Date, scene: HeroBackground.Family) {
    let tag = suffix.isEmpty ? "" : "-\(suffix)"
    // iPhone (430pt class: 15/16 Pro Max) — near-fixed ~24pt corner, ~16pt content margin.
    let phoneRadius: CGFloat = 24, phoneMargin: CGFloat = 16
    widgetShot("widget-iphone-s\(tag)", size: CGSize(width: 170, height: 170), radius: phoneRadius, margin: phoneMargin, scene: scene, when: when) {
        AuraHomeSmall(snapshot: snap, now: when)
    }
    widgetShot("widget-iphone-m\(tag)", size: CGSize(width: 364, height: 170), radius: phoneRadius, margin: phoneMargin, scene: scene, when: when) {
        AuraHomeMedium(snapshot: snap, now: when)
    }
    widgetShot("widget-iphone-l\(tag)", size: CGSize(width: 364, height: 382), radius: phoneRadius, margin: phoneMargin, scene: scene, when: when) {
        AuraHomeLarge(snapshot: snap, now: when)
    }
    // iPad (12.9" portrait) — slightly larger radius (~30pt) and margin (~20pt); XL is iPad-only.
    let padRadius: CGFloat = 30, padMargin: CGFloat = 20
    widgetShot("widget-ipad-s\(tag)", size: CGSize(width: 170, height: 170), radius: padRadius, margin: padMargin, scene: scene, when: when) {
        AuraHomeSmall(snapshot: snap, now: when)
    }
    widgetShot("widget-ipad-m\(tag)", size: CGSize(width: 378, height: 170), radius: padRadius, margin: padMargin, scene: scene, when: when) {
        AuraHomeMedium(snapshot: snap, now: when)
    }
    widgetShot("widget-ipad-l\(tag)", size: CGSize(width: 378, height: 378), radius: padRadius, margin: padMargin, scene: scene, when: when) {
        AuraHomeLarge(snapshot: snap, now: when)
    }
    widgetShot("widget-ipad-xl\(tag)", size: CGSize(width: 795, height: 378), radius: padRadius, margin: padMargin, scene: scene, when: when) {
        AuraHomeXL(snapshot: snap, now: when)
    }
}

// Three variants for the product page:
//   default  — warm mid-afternoon, nature: the sun disc sits in frame behind the scenery.
//   sunset   — a low atardecer over the same landscape, at its most striking golden light.
//   city     — the cityscape hero under the same flattering afternoon light.
renderSet("",       when: todayAt(17, 0), scene: .landscape)
renderSet("sunset", when: todayAt(20, 40), scene: .landscape)
renderSet("city",   when: todayAt(17, 0), scene: .cityscape)

print("done — 21 widget faces (3 variants × 7) written to \(outDir)")
