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

// iPhone-ish accessory sizes (community-measured) and watch complication regions.
dump("rectangular", size: CGSize(width: 170, height: 76)) { AuraAccessoryRectangular(snapshot: snap) }
dump("circular",    size: CGSize(width: 76,  height: 76)) { AuraAccessoryCircular(snapshot: snap) }
dump("wind",        size: CGSize(width: 60,  height: 60)) { AuraWindCircular(snapshot: snap) }
dump("sun",         size: CGSize(width: 60,  height: 60)) { AuraSunCircular(snapshot: snap) }
dump("corner",      size: CGSize(width: 44,  height: 44)) { AuraAccessoryCorner(snapshot: snap) }
dump("hours",       size: CGSize(width: 170, height: 76)) { AuraRectHours(snapshot: snap) }
dump("days",        size: CGSize(width: 170, height: 76)) { AuraRectDays(snapshot: snap) }
