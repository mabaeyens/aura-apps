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
    /// An optional **sunless** hero image that sits behind the live sun/moon. When set, it replaces the
    /// procedural gradient, veil, stars and scenery (the art carries the sky colour and the landscape);
    /// the glow and the sun/moon disc are still drawn on top at the true position. Nil → fully procedural.
    /// The app resolves this via `HeroBackground` and its bundle; `AuraKit` stays agnostic about where the
    /// image comes from.
    private let heroImage: Image?
    /// When false, `heroImage` is a **conditionless base scene** (a plain clear-sky landscape/cityscape):
    /// the cloud veil is still drawn over it so weather reads, while the live sun/moon and its glow sit on
    /// top as usual. True (the default) means the image bakes in its own condition (the 8×6 grid), so the
    /// veil is skipped. Ignored when `heroImage` is nil. This is what lets four wide base images
    /// (family × day/night) stand in for the whole grid on the iPad, with the light and veil doing the rest.
    private let heroCarriesCondition: Bool
    /// Where the hero art anchors when the view's aspect differs from the 9:19.5 art. The phone matches
    /// the art almost exactly, so `.center` shows the whole scene; the near-square Watch would crop the
    /// landscape off the bottom, so it passes `.bottom` to keep the mountains, tree and river in frame.
    private let heroAnchor: Alignment
    /// Tames the sun/moon glow for small, text-over-sky surfaces (the Home Screen widgets). At full size
    /// the halo spans the long edge and blooms bright — right for the full-screen hero, where frosted
    /// cards sit over it — but on a widget it bleaches the whole card white and the sky and scenery read
    /// as a blank panel. When true the glow is pulled in to the short edge and its peak dimmed, so the
    /// light stays a localised sun in a legible sky. The phone and Watch hero keep the default (false).
    private let compact: Bool

    public init(snapshot: WeatherSnapshot?, now: Date = Date(), heroImage: Image? = nil,
                heroCarriesCondition: Bool = true, heroAnchor: Alignment = .center,
                compact: Bool = false) {
        self.snapshot = snapshot
        self.now = now
        self.heroImage = heroImage
        self.heroCarriesCondition = heroCarriesCondition
        self.heroAnchor = heroAnchor
        self.compact = compact
    }

    public var body: some View {
        let path = AuraSunPath(now: now, sunrise: snapshot?.sunrise, sunset: snapshot?.sunset)
        let (category, _) = Palette.sky(forCode: snapshot?.currentSky)
        let veil = Self.veil(category)                     // how much cloud dulls the light, 0…1
        let hidesDisc = Self.hidesDisc(category)           // heavy skies show glow but no defined disc
        let base = Palette.skyBaseColors(at: now)
        let sun = Self.glowColor(isNight: path.isNight, altitude: path.altitude)
        let scene = Self.sceneColors(isNight: path.isNight, altitude: path.altitude, glow: sun)

        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // 1 — the sky itself. Either the sunless hero image (which carries the sky colour and the
                // landscape), or the procedural top-to-bottom gradient that tracks the hour.
                if let heroImage {
                    heroImage.resizable().scaledToFill()
                        .frame(width: size.width, height: size.height, alignment: heroAnchor).clipped()
                } else {
                    LinearGradient(colors: [base.top, base.bottom], startPoint: .top, endPoint: .bottom)
                }

                // 2 — the cloud veil: a soft, slightly cool scrim that greys the sky as it clouds over.
                // A neutral-cool grey (not warm) keeps an overcast noon from reading muddy/brown. Skipped
                // over a condition-baked image (the 8×6 art carries its own weather); drawn over a
                // conditionless base scene so its weather still reads.
                if heroImage == nil || !heroCarriesCondition {
                    (path.isNight ? Color(white: 0.12)
                                  : Color(red: 0.60, green: 0.65, blue: 0.72)).opacity(veil * 0.5)
                }

                // 2.5 — night dim: a subtle darkening so night reads as night, not dusk. Deepest at the
                // middle of the night (when the moon rides highest) and gentle toward dawn and dusk. It
                // sits *under* the moon glow (step 3), so the moonlit pool still lifts back out of it. I
                // keep it light and let it fall on the hero art too — I paid for the art to be seen, so
                // this only takes the daylit edge off; it never crushes the scene to black.
                if path.isNight {
                    let nightDim = 0.10 + path.altitude * 0.12       // ~0.10 at the edges → ~0.22 at midnight
                    Color(red: 0.02, green: 0.03, blue: 0.09).opacity(nightDim)
                }

                // 3 — the light: a warm (or cool, at night) glow centred exactly where the sun/moon is.
                // Day glow eases off as the sun climbs, so the gold doesn't overpower the blue at noon
                // (which read as a green cast); it stays strong low on the horizon at dawn/dusk. On a
                // `compact` surface (a widget) the halo is pulled in to the short edge and its peak dimmed,
                // so it stays a localised sun instead of bleaching the whole small card to white.
                let glowPeak = (path.isNight ? 0.55 : 0.92 - path.altitude * 0.30)
                    * (1 - veil * 0.5) * (compact ? 0.62 : 1.0)
                let glowRadius = compact ? min(size.width, size.height) * 1.1
                                         : max(size.width, size.height) * 0.78
                RadialGradient(colors: [sun.opacity(glowPeak), sun.opacity(0)],
                               center: path.point,
                               startRadius: 0,
                               endRadius: glowRadius)

                // 3.5 — the light source itself: a defined sun (or moon) disc with a soft corona, sitting
                // exactly where the glow is centred. This is "the signature" — the sun you can point at,
                // not just an ambient wash. Static per render (position from `now`). Cloud doesn't just dim
                // it: the same `veil` occludes it — the disc shrinks and its blur swells, so rain/storm/fog
                // read as the sun *hidden* behind weather (a soft, low-contrast smudge) while a clear sky
                // keeps it a pin-sharp point of light. Occlusion is alpha + radius + blur only; the disc
                // never leaves the true solar position.
                let occlusion = veil
                // Cap the disc's radius so the sun/moon reads at the same physical size on a large iPad
                // screen as on a phone. Without the cap `min(width, height) * 0.075` scales with the
                // canvas and the disc balloons on iPad; 32pt matches the largest phone, and the corona
                // and blur below follow from `discR`, so the whole light source stays device-consistent.
                // On a `compact` surface (a widget) the disc is smaller and capped harder, so it reads the
                // same modest size whether the widget is a small iPhone tile or a large iPad one — without
                // it the disc scales with the canvas and balloons on the big iPad families.
                let discR = compact ? min(min(size.width, size.height) * 0.07, 20)
                                    : min(min(size.width, size.height) * 0.075, 32)
                let occludedR = discR * (1 - occlusion * 0.35)          // smaller under cloud, full when clear
                // The moon reads as reflected moonlight, not a second sun: markedly dimmer than the day
                // disc and drawn with a soft base blur even on the clearest night, so its edge stays a
                // gentle pale coin rather than a hard, sun-bright point.
                let discAlpha = (path.isNight ? 0.62 : 1.0) * (1 - occlusion * 0.85)
                let discBlur = discR * ((path.isNight ? 0.14 : 0.05) + occlusion * 0.9)  // sharp when clear, swollen under cloud; softer for the moon
                // Overcast, rain, storm, snow and fog never resolve into a disc you can point at — at any
                // hour, sun or moon. The warm glow (step 3) still bleeds through the deck, but the defined
                // core and its corona are dropped entirely; only clear/few-clouds/cloudy keep a real ball.
                if discAlpha > 0.02 && !hidesDisc {
                    let disc = Self.discColors(isNight: path.isNight, altitude: path.altitude, glow: sun)
                    let centre = CGPoint(x: path.point.x * size.width, y: path.point.y * size.height)
                    // Corona — a wide soft halo around the disc; fades and tightens as the disc is occluded.
                    // At night I let the halo do the work the hard core no longer does: a touch wider and
                    // held up in its own right, so the moon reads as a soft pool of light against the darker
                    // sky rather than a dim dot. Drawn `.normal` at night (screen would over-brighten the
                    // dark), `.screen` by day.
                    let coronaR = discR * (1 - occlusion * 0.2)
                    let coronaAlpha = (path.isNight ? 0.60 : 0.55) * discAlpha
                    let coronaSpread: CGFloat = path.isNight ? 3.4 : 3.2
                    Circle()
                        .fill(RadialGradient(colors: [disc.glow.opacity(coronaAlpha), disc.glow.opacity(0)],
                                             center: .center, startRadius: coronaR * 0.7, endRadius: coronaR * coronaSpread))
                        .frame(width: coronaR * coronaSpread * 2, height: coronaR * coronaSpread * 2)
                        .position(centre)
                        .blendMode(path.isNight ? .normal : .screen)
                    // The disc — bright core to warm rim, lit slightly off-centre for depth.
                    Circle()
                        .fill(RadialGradient(colors: [disc.core.opacity(discAlpha), disc.rim.opacity(discAlpha)],
                                             center: UnitPoint(x: 0.42, y: 0.38),
                                             startRadius: 0, endRadius: occludedR))
                        .frame(width: occludedR * 2, height: occludedR * 2)
                        .position(centre)
                        .blur(radius: discBlur)
                }

                // 4 — stars, night only. Skipped over an image (the art carries its own).
                if heroImage == nil, path.isNight {
                    Canvas { ctx, sz in Self.drawStars(&ctx, size: sz) }
                        .opacity(1 - veil * 0.8)
                }

                // 5 — the flat vector scenery along the horizon: mountain, hills, sun-lit river, a tree
                // whose shadow leans away from the sun. Skipped over an image (the art has its landscape).
                if heroImage == nil {
                    Canvas { ctx, sz in
                        Self.drawScenery(&ctx, size: sz, colors: scene, sunX: path.point.x)
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .ignoresSafeArea()
        // Decorative: the sky, landscape and sun/moon disc are pure atmosphere — every fact they
        // encode (the hour's light, the weather) is also spoken by the frosted cards in front. Hide
        // it from VoiceOver so the swipe order is the cards, not a large unlabelled image.
        .accessibilityHidden(true)
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

    /// Whether this sky is too veiled to ever show a *defined* sun/moon disc. Overcast, fog, rain, storm
    /// and snow read as an even deck — a glow at most, never a ball you can point at — at every hour.
    /// Clear, few-clouds and (dimmed) cloudy keep a real disc; `unknown` falls back to drawing one.
    private static func hidesDisc(_ category: Palette.Sky) -> Bool {
        switch category {
        case .overcast, .fog, .rain, .storm, .snow: return true
        case .clear, .fewClouds, .clouds, .unknown: return false
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
            // A pale, cool silver — the core is deliberately held back off pure white so the moon reads
            // as reflected light, and the rim/glow stay a faint blue.
            return (core: RGB(r: 0.90, g: 0.92, b: 0.99).color,
                    rim:  RGB(r: 0.78, g: 0.82, b: 0.97).color,
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
        let band = h * 0.46                 // a taller scenery band, so the horizon sits higher up the
        let top = h - band                  // screen and shows through/behind the lower cards

        // A soft haze just above the horizon lifts the ridges off the sky and adds depth.
        let hazeTop = top - band * 0.14
        ctx.fill(Path(CGRect(x: 0, y: hazeTop, width: w, height: band * 0.62)),
                 with: .linearGradient(Gradient(colors: [colors.far.opacity(0), colors.far.opacity(0.34)]),
                                       startPoint: CGPoint(x: 0, y: hazeTop),
                                       endPoint: CGPoint(x: 0, y: hazeTop + band * 0.62)))

        // Distant ridge — hazier and higher, sitting behind the main range for a sense of depth.
        var ridge = Path()
        ridge.move(to: CGPoint(x: 0, y: top + band * 0.30))
        ridge.addLine(to: CGPoint(x: w * 0.22, y: top + band * 0.12))
        ridge.addLine(to: CGPoint(x: w * 0.40, y: top + band * 0.26))
        ridge.addLine(to: CGPoint(x: w * 0.58, y: top + band * 0.06))
        ridge.addLine(to: CGPoint(x: w * 0.78, y: top + band * 0.24))
        ridge.addLine(to: CGPoint(x: w, y: top + band * 0.14))
        ridge.addLine(to: CGPoint(x: w, y: h)); ridge.addLine(to: CGPoint(x: 0, y: h)); ridge.closeSubpath()
        ctx.fill(ridge, with: .color(colors.far.opacity(0.55)))

        // Far mountain range.
        var mountain = Path()
        mountain.move(to: CGPoint(x: 0, y: top + band * 0.50))
        mountain.addLine(to: CGPoint(x: w * 0.17, y: top + band * 0.16))
        mountain.addLine(to: CGPoint(x: w * 0.30, y: top + band * 0.46))
        mountain.addLine(to: CGPoint(x: w * 0.48, y: top + band * 0.02))
        mountain.addLine(to: CGPoint(x: w * 0.66, y: top + band * 0.44))
        mountain.addLine(to: CGPoint(x: w * 0.84, y: top + band * 0.18))
        mountain.addLine(to: CGPoint(x: w, y: top + band * 0.46))
        mountain.addLine(to: CGPoint(x: w, y: h)); mountain.addLine(to: CGPoint(x: 0, y: h)); mountain.closeSubpath()
        ctx.fill(mountain, with: .color(colors.far.opacity(0.92)))

        // Near hills.
        var hills = Path()
        hills.move(to: CGPoint(x: 0, y: top + band * 0.66))
        hills.addQuadCurve(to: CGPoint(x: w * 0.5, y: top + band * 0.60),
                           control: CGPoint(x: w * 0.25, y: top + band * 0.46))
        hills.addQuadCurve(to: CGPoint(x: w, y: top + band * 0.58),
                           control: CGPoint(x: w * 0.75, y: top + band * 0.76))
        hills.addLine(to: CGPoint(x: w, y: h)); hills.addLine(to: CGPoint(x: 0, y: h)); hills.closeSubpath()
        ctx.fill(hills, with: .color(colors.near))

        // A river/ribbon that catches the sun's colour.
        var river = Path()
        let ry = top + band * 0.80
        river.move(to: CGPoint(x: 0, y: ry))
        river.addQuadCurve(to: CGPoint(x: w * 0.5, y: ry + band * 0.055),
                           control: CGPoint(x: w * 0.25, y: ry - band * 0.045))
        river.addQuadCurve(to: CGPoint(x: w, y: ry + band * 0.02),
                           control: CGPoint(x: w * 0.75, y: ry + band * 0.11))
        river.addLine(to: CGPoint(x: w, y: ry + band * 0.15))
        river.addQuadCurve(to: CGPoint(x: w * 0.5, y: ry + band * 0.19),
                           control: CGPoint(x: w * 0.75, y: ry + band * 0.24))
        river.addQuadCurve(to: CGPoint(x: 0, y: ry + band * 0.13),
                           control: CGPoint(x: w * 0.25, y: ry + band * 0.09))
        river.closeSubpath()
        ctx.fill(river, with: .color(colors.water))

        // Trees, with ground shadows that lean away from the sun. A larger one on the right and a smaller
        // one on the left add depth without cluttering the lower cards.
        let shadowDir: CGFloat = (0.5 - sunX)            // sun on the left → +, shadow falls right
        func drawTree(tx: CGFloat, groundY: CGFloat, foliageR: CGFloat) {
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
        drawTree(tx: w * 0.80, groundY: top + band * 0.68, foliageR: band * 0.20)
        drawTree(tx: w * 0.19, groundY: top + band * 0.74, foliageR: band * 0.13)
    }
}
