import SwiftUI

/// Aura's signature background: a full-bleed sky whose light sits where the sun (or moon) actually is
/// for the location and the hour. The sun **rises on the left (east)**, climbs to the top at solar
/// noon, and **sets on the right (west)**; after dark a dimmer moon glow arcs across a star-scattered
/// night. The sky condition never moves the light — it only draws a veil over it, so a cloudy morning
/// and a cloudy evening are lit from opposite sides.
///
/// Shared in `AuraKit` so the iPhone and the Apple Watch render the *same* sky from one source, only
/// resized. Position is computed once from the `now` passed in (no timer): the apps recompute it on
/// each appearance and on each sync, which is plenty — nobody stares at the screen for a full minute.

// MARK: - Sun / moon position

/// Where the light source sits on screen, and whether it's night. Pure and testable.
public struct AuraSunPath: Sendable {
    /// The light's position, in the view's unit space: x 0 = leading/east, 1 = trailing/west.
    public let point: UnitPoint
    /// True between sunset and the next sunrise.
    public let isNight: Bool
    /// The sun's height above the horizon, 0 (at the horizon) → 1 (at solar noon). At night this is
    /// the moon's arc height instead.
    public let altitude: Double

    public init(now: Date, sunrise: Date?, sunset: Date?) {
        guard let sr = sunrise, let ss = sunset, ss > sr else {
            // No sun times (polar edge case / missing data): a neutral high-noon sky.
            point = UnitPoint(x: 0.5, y: 0.16); isNight = false; altitude = 1; return
        }
        if now >= sr && now <= ss {
            let f = now.timeIntervalSince(sr) / ss.timeIntervalSince(sr)   // 0 at sunrise → 1 at sunset
            let alt = sin(f * .pi)                                          // 0 → 1 → 0 across the day
            point = UnitPoint(x: f, y: 0.80 - alt * 0.66)                  // low at the horizon, high at noon
            isNight = false; altitude = alt
        } else {
            // Night: fraction from this sunset to the next sunrise. Before dawn we're past *yesterday's*
            // sunset (sun times barely move day to day, so today's stand in).
            let dayLength = ss.timeIntervalSince(sr)
            let nightLength = max(86_400 - dayLength, 1)
            let since = now >= ss ? now.timeIntervalSince(ss)
                                  : now.timeIntervalSince(ss.addingTimeInterval(-86_400))
            let g = min(max(since / nightLength, 0), 1)
            let alt = sin(g * .pi)
            point = UnitPoint(x: g, y: 0.60 - alt * 0.40)                  // a gentler, higher moon arc
            isNight = true; altitude = alt
        }
    }
}

// MARK: - The sky view

public struct AuraSky: View {
    private let snapshot: WeatherSnapshot?
    private let now: Date

    public init(snapshot: WeatherSnapshot?, now: Date = Date()) {
        self.snapshot = snapshot
        self.now = now
    }

    public var body: some View {
        let path = AuraSunPath(now: now, sunrise: snapshot?.sunrise, sunset: snapshot?.sunset)
        let (category, _) = Palette.sky(forCode: snapshot?.currentSky)
        let veil = Self.veil(category)                     // how much cloud dulls the light, 0…1
        let base = Palette.skyBaseColors(at: now)
        let sun = Self.glowColor(isNight: path.isNight, altitude: path.altitude)
        let scene = Self.sceneColors(isNight: path.isNight, altitude: path.altitude, glow: sun)

        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // 1 — the sky itself: a top-to-bottom gradient that tracks the hour.
                LinearGradient(colors: [base.top, base.bottom], startPoint: .top, endPoint: .bottom)

                // 2 — the cloud veil: a soft, slightly cool scrim that greys the sky as it clouds over.
                // A neutral-cool grey (not warm) keeps an overcast noon from reading muddy/brown.
                (path.isNight ? Color(white: 0.12)
                              : Color(red: 0.60, green: 0.65, blue: 0.72)).opacity(veil * 0.5)

                // 3 — the light: a warm (or cool, at night) glow centred exactly where the sun/moon is.
                // Day glow eases off as the sun climbs, so the gold doesn't overpower the blue at noon
                // (which read as a green cast); it stays strong low on the horizon at dawn/dusk.
                RadialGradient(colors: [sun.opacity((path.isNight ? 0.55 : 0.92 - path.altitude * 0.30)
                                                        * (1 - veil * 0.5)),
                                        sun.opacity(0)],
                               center: path.point,
                               startRadius: 0,
                               endRadius: max(size.width, size.height) * 0.78)

                // 3.5 — the light source itself: a defined sun (or moon) disc with a soft corona, sitting
                // exactly where the glow is centred. This is "the signature" — the sun you can point at,
                // not just an ambient wash. Static per render (position from `now`), and it dims as cloud
                // veils it, so a storm hides it and a clear dawn shows it low and warm at the screen edge.
                let discR = min(size.width, size.height) * 0.075
                let discAlpha = (path.isNight ? 0.90 : 1.0) * (1 - veil * 0.85)
                if discAlpha > 0.02 {
                    let disc = Self.discColors(isNight: path.isNight, altitude: path.altitude, glow: sun)
                    let centre = CGPoint(x: path.point.x * size.width, y: path.point.y * size.height)
                    // Corona — a wide soft halo around the disc.
                    Circle()
                        .fill(RadialGradient(colors: [disc.glow.opacity(0.55 * discAlpha), disc.glow.opacity(0)],
                                             center: .center, startRadius: discR * 0.7, endRadius: discR * 3.2))
                        .frame(width: discR * 6.4, height: discR * 6.4)
                        .position(centre)
                        .blendMode(path.isNight ? .normal : .screen)
                    // The disc — bright core to warm rim, lit slightly off-centre for depth.
                    Circle()
                        .fill(RadialGradient(colors: [disc.core.opacity(discAlpha), disc.rim.opacity(discAlpha)],
                                             center: UnitPoint(x: 0.42, y: 0.38),
                                             startRadius: 0, endRadius: discR))
                        .frame(width: discR * 2, height: discR * 2)
                        .position(centre)
                        .blur(radius: discR * 0.05)
                }

                // 4 — stars, night only.
                if path.isNight {
                    Canvas { ctx, sz in Self.drawStars(&ctx, size: sz) }
                        .opacity(1 - veil * 0.8)
                }

                // 5 — the flat vector scenery along the horizon: mountain, hills, sun-lit river, a tree
                // whose shadow leans away from the sun.
                Canvas { ctx, sz in
                    Self.drawScenery(&ctx, size: sz, colors: scene, sunX: path.point.x)
                }
                .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Condition → how much the light is veiled

    private static func veil(_ category: Palette.Sky) -> Double {
        switch category {
        case .clear:            return 0.00
        case .fewClouds:        return 0.18
        case .clouds:           return 0.45
        case .overcast:         return 0.62
        case .fog:              return 0.68
        case .rain:             return 0.66
        case .storm:            return 0.72
        case .snow:             return 0.50
        case .unknown:          return 0.10
        }
    }

    // MARK: Colours

    private struct RGB {
        var r, g, b: Double
        var color: Color { Color(red: r, green: g, blue: b) }
        static func lerp(_ a: RGB, _ b: RGB, _ k: Double) -> RGB {
            RGB(r: a.r + (b.r - a.r) * k, g: a.g + (b.g - a.g) * k, b: a.b + (b.b - a.b) * k)
        }
    }

    /// The glow colour: pale moonlight at night; warm gold high in the day, deepening to orange as the
    /// sun nears the horizon at dawn and dusk.
    private static func glowColor(isNight: Bool, altitude: Double) -> Color {
        if isNight { return Color(red: 0.76, green: 0.80, blue: 0.96) }
        let horizon = RGB(r: 1.00, g: 0.60, b: 0.34)   // low sun — warm orange
        let noon    = RGB(r: 1.00, g: 0.93, b: 0.72)   // high sun — bright gold
        return RGB.lerp(horizon, noon, altitude).color
    }

    /// The sun/moon disc's own colours: a bright core, a warm (or cool, at night) rim, and the corona
    /// tint. The daytime core stays near-white so the disc reads as a light source, deepening its rim to
    /// orange as the sun nears the horizon; the moon is a pale silver.
    private static func discColors(isNight: Bool, altitude: Double, glow: Color)
        -> (core: Color, rim: Color, glow: Color) {
        if isNight {
            return (core: RGB(r: 0.96, g: 0.97, b: 1.00).color,
                    rim:  RGB(r: 0.80, g: 0.84, b: 0.98).color,
                    glow: RGB(r: 0.76, g: 0.80, b: 0.96).color)
        }
        let rimHorizon = RGB(r: 1.00, g: 0.55, b: 0.28)   // low sun — orange rim
        let rimNoon    = RGB(r: 1.00, g: 0.88, b: 0.60)   // high sun — soft gold rim
        return (core: RGB(r: 1.00, g: 0.99, b: 0.94).color,
                rim:  RGB.lerp(rimHorizon, rimNoon, altitude).color,
                glow: glow)
    }

    /// Scenery tints. Daytime scenery warms toward dusk as the sun drops; night goes near-silhouette.
    private static func sceneColors(isNight: Bool, altitude: Double, glow: Color)
        -> (far: Color, near: Color, water: Color, tree: Color, trunk: Color) {
        if isNight {
            return (far: RGB(r: 0.11, g: 0.14, b: 0.28).color,
                    near: RGB(r: 0.07, g: 0.09, b: 0.20).color,
                    water: glow.opacity(0.26),
                    tree: RGB(r: 0.08, g: 0.12, b: 0.22).color,
                    trunk: RGB(r: 0.05, g: 0.08, b: 0.17).color)
        }
        // Blend a dusk palette (altitude 0) into a daytime palette (altitude 1).
        let farDusk = RGB(r: 0.34, g: 0.30, b: 0.52),  farDay = RGB(r: 0.34, g: 0.50, b: 0.78)
        let nearDusk = RGB(r: 0.16, g: 0.16, b: 0.34), nearDay = RGB(r: 0.17, g: 0.34, b: 0.62)
        let treeDusk = RGB(r: 0.16, g: 0.22, b: 0.34), treeDay = RGB(r: 0.17, g: 0.46, b: 0.37)
        let trunkDusk = RGB(r: 0.16, g: 0.17, b: 0.26), trunkDay = RGB(r: 0.26, g: 0.31, b: 0.35)
        let k = altitude
        return (far: RGB.lerp(farDusk, farDay, k).color,
                near: RGB.lerp(nearDusk, nearDay, k).color,
                water: glow.opacity(0.5),
                tree: RGB.lerp(treeDusk, treeDay, k).color,
                trunk: RGB.lerp(trunkDusk, trunkDay, k).color)
    }

    // MARK: Drawing

    private static let stars: [(x: CGFloat, y: CGFloat, r: CGFloat)] = [
        (0.08, 0.10, 0.9), (0.17, 0.22, 0.7), (0.24, 0.08, 1.0), (0.33, 0.18, 0.7),
        (0.41, 0.28, 0.8), (0.48, 0.12, 0.9), (0.55, 0.24, 0.7), (0.62, 0.09, 1.0),
        (0.68, 0.20, 0.7), (0.74, 0.30, 0.8), (0.80, 0.11, 0.9), (0.87, 0.23, 0.7),
        (0.93, 0.14, 0.9), (0.12, 0.33, 0.6), (0.36, 0.36, 0.6), (0.58, 0.34, 0.6),
        (0.71, 0.38, 0.6), (0.90, 0.34, 0.6),
    ]

    private static func drawStars(_ ctx: inout GraphicsContext, size: CGSize) {
        for s in stars {
            let rect = CGRect(x: s.x * size.width - s.r, y: s.y * size.height - s.r,
                              width: s.r * 2, height: s.r * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.85)))
        }
    }

    private static func drawScenery(_ ctx: inout GraphicsContext, size: CGSize,
                                    colors: (far: Color, near: Color, water: Color, tree: Color, trunk: Color),
                                    sunX: CGFloat) {
        let w = size.width, h = size.height
        let band = h * 0.44                 // a taller scenery band, so the horizon sits higher up the
        let top = h - band                  // screen and shows through/behind the lower cards

        // Far mountain ridge.
        var mountain = Path()
        mountain.move(to: CGPoint(x: 0, y: top + band * 0.46))
        mountain.addLine(to: CGPoint(x: w * 0.17, y: top + band * 0.10))
        mountain.addLine(to: CGPoint(x: w * 0.30, y: top + band * 0.42))
        mountain.addLine(to: CGPoint(x: w * 0.48, y: top - band * 0.04))
        mountain.addLine(to: CGPoint(x: w * 0.66, y: top + band * 0.40))
        mountain.addLine(to: CGPoint(x: w * 0.84, y: top + band * 0.14))
        mountain.addLine(to: CGPoint(x: w, y: top + band * 0.42))
        mountain.addLine(to: CGPoint(x: w, y: h)); mountain.addLine(to: CGPoint(x: 0, y: h)); mountain.closeSubpath()
        ctx.fill(mountain, with: .color(colors.far.opacity(0.9)))

        // Near hills.
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: top + band * 0.62))
        hills.addQuadCurve(to: CGPoint(x: w * 0.5, y: top + band * 0.56),
                           control: CGPoint(x: w * 0.25, y: top + band * 0.40))
        hills.addQuadCurve(to: CGPoint(x: w, y: top + band * 0.54),
                           control: CGPoint(x: w * 0.75, y: top + band * 0.72))
        hills.addLine(to: CGPoint(x: w, y: h)); hills.addLine(to: CGPoint(x: 0, y: h)); hills.closeSubpath()
        ctx.fill(hills, with: .color(colors.near))

        // A river/ribbon that catches the sun's colour.
        var river = Path()
        let ry = top + band * 0.78
        river.move(to: CGPoint(x: 0, y: ry))
        river.addQuadCurve(to: CGPoint(x: w * 0.5, y: ry + band * 0.06),
                           control: CGPoint(x: w * 0.25, y: ry - band * 0.05))
        river.addQuadCurve(to: CGPoint(x: w, y: ry + band * 0.02),
                           control: CGPoint(x: w * 0.75, y: ry + band * 0.12))
        river.addLine(to: CGPoint(x: w, y: ry + band * 0.16))
        river.addQuadCurve(to: CGPoint(x: w * 0.5, y: ry + band * 0.20),
                           control: CGPoint(x: w * 0.75, y: ry + band * 0.26))
        river.addQuadCurve(to: CGPoint(x: 0, y: ry + band * 0.14),
                           control: CGPoint(x: w * 0.25, y: ry + band * 0.10))
        river.closeSubpath()
        ctx.fill(river, with: .color(colors.water))

        // A tree, with a ground shadow that leans away from the sun.
        let tx = w * 0.80, groundY = top + band * 0.66
        let foliageR = band * 0.20
        let shadowDir: CGFloat = (0.5 - sunX)            // sun on the left → +, shadow falls right
        let shadowLen = min(max(abs(shadowDir) * 2.4, 0.35), 1.4)
        let shadowRect = CGRect(x: tx - foliageR * 1.3 + shadowDir * foliageR * 3.0,
                                y: groundY + foliageR * 0.7,
                                width: foliageR * 2.6 * shadowLen, height: foliageR * 0.7)
        ctx.fill(Path(ellipseIn: shadowRect), with: .color(.black.opacity(0.16)))

        let trunk = CGRect(x: tx - foliageR * 0.14, y: groundY - foliageR * 0.2,
                           width: foliageR * 0.28, height: foliageR * 1.1)
        ctx.fill(Path(roundedRect: trunk, cornerRadius: foliageR * 0.1), with: .color(colors.trunk))
        for c in [(dx: 0.0, dy: -0.9, r: 1.0), (dx: -0.7, dy: -0.35, r: 0.7), (dx: 0.7, dy: -0.35, r: 0.7)] {
            let rect = CGRect(x: tx + CGFloat(c.dx) * foliageR - foliageR * CGFloat(c.r),
                              y: groundY + CGFloat(c.dy) * foliageR - foliageR * CGFloat(c.r),
                              width: foliageR * 2 * CGFloat(c.r), height: foliageR * 2 * CGFloat(c.r))
            ctx.fill(Path(ellipseIn: rect), with: .color(colors.tree))
        }
    }
}
