# Aura — build plan

Personal Apple-ecosystem weather app for Spain, powered by my AEMET OpenData API key.
It fills the gaps the official AEMET app leaves: **Apple Watch complications, a rich widget
set, and macOS / Lock Screen coverage.** The app itself is a thin "settings + locations"
shell; the product is the widgets and complications.

- Name: **Aura** (Latin/Greek — breeze, air), matching the Mira / Vera family.
- Fetch architecture: **on-device hub** (no backend, no hosting, key stays on my devices).
- Spain only. Personal use, single user.

## Targets

iOS, iPadOS, macOS, watchOS. One shared Swift package holds all logic (same pattern as
`mira-apps` / `vera-apps`), so every widget and complication renders from identical code.

## Core constraint: fetching

AEMET limits force the whole design:

- 50 requests/min, global.
- Two-call model: every reading = request → temporary data URL → fetch it = 2 calls.
- Forecasts refresh only a few times a day; observations ~hourly.
- API key is tied to my email and **valid only 3 months** (renewable).

So the architecture is one fetch feeding many surfaces:

- The **iPhone app is the fetch hub**. It calls AEMET, normalizes to a small model, writes
  to a **shared App Group cache**.
- Widgets (iOS / iPadOS / Mac) read that cache — they never call AEMET directly.
- The **Watch** receives data pushed from the iPhone via WatchConnectivity, with a cached
  fallback for when it's away / off-wrist.
- Refresh runs on AEMET's real cadence (forecast ~4x/day, observation ~hourly), not the
  widget's wake schedule.

Trade-off accepted: when the Watch is away from the phone with no synced update, it shows
last-known data. Fine for personal use; avoids any hosting.

## Data mapping — complications → source

| Complication | Source | Notes |
|---|---|---|
| Weather icon | Forecast `estadoCielo` code | ~40 codes → glyphs, day + night variants |
| Min/max temp | Daily forecast | Per municipality |
| Observed temp + conditions | Station observation | Nearest station, not municipality |
| Humidity | Observation + forecast | |
| Rain | Forecast probability + observed precip. | |
| Wind (observed) | Station observation | Speed + direction |
| Sun position | Computed on-device | Matches OAN / ROA ephemerides; no AEMET |
| Sunrise / sunset | Computed on-device | Offline, exact |

Data quirks: AEMET forecasts are keyed by **INE municipality code** (not GPS); observations
by **station code**. The app bundles a lookup table to turn "my location" → "nearest
municipality + nearest station." Table ships in the app; no runtime cost.

Sun data is deterministic astronomy, computed locally to match the Observatorio Astronómico
Nacional (OAN) / Real Observatorio de la Armada (ROA) published orto/ocaso tables. If I want
to cite an official Spanish source in the UI, reference the OAN tables.

## Locations

GPS current location **plus** a list of fixed favorites I choose. Each location can drive its
own widget / complication instance.

## Phased delivery

- **Phase 0 — Foundations:** repo scaffold, shared Swift package, AEMET client (two-call +
  caching + rate-limit backoff), location → municipality/station lookup, key storage. No UI —
  just "can we reliably get clean data."
- **Phase 1 — iOS app shell:** location management, favorites, a "today" screen. Proves the
  data end-to-end. ✅ *Done:* `Aura.xcodeproj` (iOS target, links the local AuraKit package),
  four Spanish tabs (Hoy / Predicción / Ubicaciones / Ajustes), Keychain key entry, favorites
  seeded from the 50 provincial capitals, GPS→nearest-city, on-device sun times, and the official
  community forecast-text screen with its issue date. All screens verified live (Madrid, A Coruña,
  Galicia). *Text-source decision:* OpenData's text products are stale for many regions (A Coruña
  province frozen at 2022, Galicia CCAA ~2 months old), so the narrative comes from AEMET's
  internal website API (`AEMETBulletinClient`, keyless, fresh for every region); OpenData CCAA
  text kept as a fallback. See the `aemet-text-forecast-source` memory. *Deferred to later
  phases:* the full ~8k-municipality table (Phase 1 bundles capitals only), App Group cache,
  macOS/watchOS targets.
- **Phase 2 — Widgets (iOS / iPadOS / Mac):** full set — Lock Screen, Home Screen, StandBy, Mac.
- **Phase 3 — Watch app + complications:** the marquee feature, all complication families.
- **Phase 4 — Polish:** glyphs, sun-arc rendering, dark mode, refresh tuning.

Weekly TestFlight release cadence, matching Mira / Vera.

## Risks

- **3-month key expiry** — need a graceful "renew your key" flow, not silent staleness.
- **Rate limits** — mitigated by the caching-hub design.
- **Watch away from phone** — accepted limitation of the on-device architecture.
- **API key storage** — key lives in Keychain, never in the binary or the repo.

## Refinements (session 2026-08-19)

1. **Location** comes from the widget/complication's own Core Location request (both iOS and
   watchOS support this) → derive municipality + coordinates on-device. Abroad = no data,
   expected. Also keep the fixed-favorites list.
2. **Refresh** on AEMET's cadence (1h/4h). Requires two user-enabled permissions:
   **Background App Refresh** (phone tops up the App Group cache before widgets wake) and
   **widget location access**. Without BG refresh it still works but updates lazily.
3. **Offline** → last cached values display. (Core to design.)
4. **Icons**: clean, legible, colorful — red hot / blue cold, sun yellow, clouds white–grey by
   condition. HARD PLATFORM CONSTRAINT: full color only renders on iOS/iPad **Home Screen**,
   **StandBy**, and **Mac** widgets. **Lock Screen widgets and many Watch complication slots
   are forced monochrome (single tint) by the OS** — no hue. Design rule: every glyph must
   read in one flat color AND in full color; temperature-hue is a bonus only where allowed.
5. **Observed vs forecasted are separate variants** for temperature (now vs day min/max),
   wind (now vs typical/max), and precipitation (observed vs probability).
6. **Wind**: arrow graphic + Spanish 16-point rose — N, NNE, NE, ENE, E, ESE, SE, SSE, S, SSO,
   SO, OSO, O, ONO, NO, NNO.

**Units:** °C, wind km/h (AEMET observed wind is m/s internally → convert), precip mm, humidity %.
**Attribution:** AEMET license requires showing "Elaborado con datos de AEMET" (About/credits).
**Dev setup:** reuse `mabaeyens` team + TestFlight (as Mira/Vera).
**UI language:** **Spanish only.**

**In scope (confirmed):** plus the core set, also
- **Weather warnings (avisos)** — official AEMET alerts by zone (amarillo/naranja/rojo). Extra
  endpoint + zone lookup table. Great as a badge/complication.
- **UV index** — AEMET daily UV forecast. Colorful complication (green→purple scale).

These two land in **Phase 2.5** (after the core widgets, before/with the Watch phase).

**Official AEMET forecast text (in scope):** a first-class in-app screen that shows the
human-written narrative forecast AEMET *issues* for the watched location (municipality /
province / CCAA text prediction), separate from the numeric data. Read-only, formatted nicely.
Lands in Phase 1 (app shell).

**Sun times decision:** the OAN provides no special formula or API — its tables are standard
ephemerides. Compute on-device with the NOAA/Meeus solar algorithm (matches OAN to the minute)
and just show the times. No citation required.

**Widgets & complications:** full spec in `docs/WIDGETS.md`, derived from my two Ultra watch
faces. Style anchors: Apple Weather (clean/colorful) + new AEMET app (simplicity) + Carrot
(customizability). **Hard requirement:** Aura replaces my Carrot family subscription, so every
widget/complication is App-Intent-configurable (location + which metric(s)). Metrics include
temp gauge with min/max range, hourly strip (icon+temp+precip%), wind rose + bearing, UV gauge,
precip-probability gauge, sun/daylight-remaining, and avisos banners.

## Next session (implementation)

Kept separate from this planning session. Start at Phase 0: scaffold `aura-apps` repo, create
the shared package, stand up the AEMET client with a live smoke test against my key.
