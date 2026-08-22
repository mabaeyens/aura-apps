# Aura — widgets & complications spec

> **Aspirational design spec (2026-08-19), partly shipped.** What shipped is narrower than this document, but it now includes Home Screen widgets. As of 2026-08-22 the surfaces are: **Home Screen widgets** (`.systemSmall / .systemMedium / .systemLarge`, plus `.systemExtraLarge` on iPad) drawn over the live `AuraSky` with the sunless hero art behind — configurable by **location and a Naturaleza / Ciudad scene**; **Lock Screen accessory widgets** (`.accessoryCircular / .accessoryRectangular / .accessoryInline`) and a **Watch complication** (those three plus `.accessoryCorner`), configurable by **location only**. There is still **no per-metric configuration**, and no StandBy or Mac widget (the Mac would need the Designed-for-iPad flag flipped on the extension). The rich per-metric UI described here landed instead as the app's **"Hoy" card stack** (see the README and `AuraAppCards.swift`). The metric/colour-scale tables below are still a useful design reference; read the rest as intent, not as a description of the code.
>
> **Widget memory note:** the gallery renders every supported family at once, so on iPad (four families including the extra-large) the hero art is loaded from **pre-sized tiers** by name (`WidgetHero` + the `AuraWidgets/Assets` catalog: an extra-large tier and a lighter `_w` tier) rather than decoding the full-resolution source per render — otherwise the transient decodes blow WidgetKit's ~30 MB per-process budget and the losing previews drop to blank placeholders.

Derived from the two watch faces I use today (Modular Ultra + California/analog Ultra) and three style anchors: **Apple Weather** (clean, colorful), the **new AEMET app** (simplicity), and **Carrot Weather** (deep customizability). Aura is meant to replace my Carrot family subscription, so **per-surface configurability is a hard requirement**, not a nice-to-have.

## Guiding principles

1. **One adaptive design per metric.** Each metric renders itself into whatever slot it lands in — full detail on big widgets, condensed on Lock Screen / Ultra faces, tightest form in a circular slot. Same data, responsive layout.
2. **Configurable everywhere.** Every widget and complication is an App Intent config: pick the **location** (GPS or a saved favorite) and, for combo/single surfaces, pick **which metric(s)** to show. This is the Carrot-replacement lever.
3. **Colorful where allowed, legible in mono.** Full color on Home Screen / StandBy / Mac and color-capable watch faces; every glyph still reads in a single tint on Lock Screen and tinted faces (shape carries meaning, hue is a bonus).
4. **Apple Weather-clean typography, AEMET-simple density.** No clutter.

## Metrics (data types)

| Metric | Source | Notes |
|---|---|---|
| Current temp + condition icon | Observation (nearest station) | The hero value |
| Today min / max | Daily forecast | Feeds the temp gauge range |
| Hourly (icon + temp + precip%) | Hourly forecast | Powers the hourly strip |
| Wind (speed + direction) | Observation | Compass rose + arrow; bearing° variant |
| Precipitation probability | Hourly/daily forecast | Blue gauge, umbrella |
| Precipitation observed | Observation | mm |
| Humidity | Observation + forecast | % |
| UV index | AEMET UV forecast | Green→purple WHO scale gauge |
| Sunrise / sunset / daylight left | Computed on-device | e.g. "Ocaso 21:11", "7h 8m" |
| Weather warnings (avisos) | AEMET avisos by zone | Amarillo/naranja/rojo banner |

## Color scales

- **Temperature gauge:** blue (cold) → cyan → green → yellow → orange → red (hot), by absolute °C.
- **UV gauge:** green (0–2) → yellow (3–5) → orange (6–7) → red (8–10) → purple (11+). Matches the `9` gauge on my California face.
- **Precipitation probability:** blue, intensity by %.
- **Condition icons:** day/night variants (the purple moon+stars in the hourly strip = clear night).
- **Avisos:** the official AEMET amarillo / naranja / rojo.

## Complication catalog (watchOS) — mapped to my faces

### Circular (accessoryCircular)
- **Temp gauge** — current temp inside a min→max colored arc + condition icon. *(Face 1 top-right)*
- **Icon + temp** — small condition icon with current temp. *(default tiny slot)*
- **Wind (rose)** — compass ring, arrow, `18 KM/H`. *(Face 1 bottom-left)*
- **Wind (bearing)** — `146° SE` with arrow. *(Face 1 top-center)*
- **UV gauge** — value + green→red arc. *(Face 2 right sub-dial)*
- **Precip prob gauge** — `%` + blue arc + umbrella. *(Face 2 bottom sub-dial)*
- **Humidity** — `%`.
- **Sun** — next event time + glyph.

### Corner (accessoryCorner)
- **Temp + range gauge** (curved) + icon. *(Face 2 top-right corner)*
- **UV** curved gauge.
- **Wind** curved gauge.

### Rectangular (accessoryRectangular)
- **Hourly strip** — 3–5 hours × (icon, temp, precip%). *(Face 1 middle band — the flagship combo)*
- **Now combo** — big icon + current temp + min/max + wind line.
- **Sun combo** — sunrise/sunset + daylight-remaining bar. *(Face 2 "21:06, 7HRS 8MIN")*
- **Aviso banner** — colored alert with zone + phenomenon, shown only when active.

### Inline (accessoryInline)
- One configurable line, e.g. `18° · Soleado · ONO 12 km/h` or `Ocaso 21:11 · quedan 7h 8m`.

## Widgets (iOS / iPadOS / macOS / StandBy)

### Rich all-in-one location card (systemSmall / Medium / Large)
- **Small:** location, big current temp + icon, today min/max.
- **Medium:** adds hourly strip + a wind / precip / UV row.
- **Large:** adds a multi-day forecast, sun times, and an avisos banner when active.
- Full color, Apple-Weather styling.

### Lock Screen (iOS)
- Condensed circular / rectangular / inline versions of the above, monochrome (tint-only).

### StandBy
- The small/medium rich card at desk distance; night mode dims to the OS red tint.

## Configuration surface (the Carrot-replacement)

Every widget/complication exposes, via App Intents:
- **Location:** current (GPS) or a specific saved favorite.
- **Metric(s):** which value(s) this instance shows (for single + combo surfaces).
- **Units** inherited from app settings (°C, km/h, mm, %).

## Data dependencies this adds

- **Hourly forecast** endpoint (`prediccion/especifica/municipio/horaria/{ine}`) for the strip.
- **UV forecast** endpoint.
- **Avisos** endpoint + zone lookup table.

These extend the Phase 0 `AEMETClient` in Phase 2 / 2.5.
