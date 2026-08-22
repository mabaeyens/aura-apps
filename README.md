# Aura

Personal Apple-ecosystem weather app for Spain, powered by the [AEMET OpenData](https://opendata.aemet.es/) API. It fills the gaps in the official AEMET app: **a rich "Hoy" screen, Apple Watch complications, and Home & Lock Screen widgets** — all over a live, sun-tracking SwiftUI sky.

Targets iOS, iPadOS, macOS and watchOS from one shared Swift package, so every widget and complication renders from identical code.

## Status

Active development. The **iPhone app, the Home & Lock Screen widgets, and the Apple Watch app + complication** are working and verified on device, all rendering from the shared `AuraKit`:

- **iOS app** — location management with favorites and a full **"Hoy" card stack**: an editorial hero, current conditions, the hourly strip, the multi-day outlook, a sunrise→sunset arc, wind, air quality, UV index, radar, the official AEMET narrative bulletin, and a news stream — over a live sun-tracking sky. A brief **first-run intro** (skippable) explains the free AEMET key and where the widgets live, and an **"Ayuda"** sheet explains how to get an AEMET key and gives a legend for every icon in the app.
- **Widgets** — **Home Screen** (small / medium / large, plus the iPad extra-large) over the live sky with the sunless hero art behind it, and **Lock Screen** (circular / rectangular / inline) families. Each is configurable via App Intents — location for all, plus a Naturaleza / Ciudad scene for the Home Screen widget.
- **Apple Watch** — the watch app (the same card stack, resized to the wrist) and a face complication (corner / circular / rectangular / inline), fed live from the phone over WatchConnectivity; both update in place as the phone syncs.
- **Real observed temperature** from the nearest AEMET station, and **avisos** (CAP warnings) matched to each location by province.

Still to come: a dedicated **macOS** app (the shared code already builds for it).

## Aura (iOS app)

A thin shell over `AuraKit`, Spanish-only: one immersive **"Hoy"** screen, with the other sections opening from a discreet frosted menu on the hero (no tab bar):

- **Hoy** — the full card stack for the selected municipality over a live sun-tracking sky. It opens on an **editorial hero**: the temperature and two lines of natural-language Spanish prose (generated on-device by `ForecastPhrase`) sitting straight on the sky, with the place named `LOCALIDAD · Momento` (Amanecer / Mañana / Mediodía / Tarde / Atardecer / Noche). Below it: current conditions (with the nearest station's observed temperature), the hourly strip, the multi-day outlook, a sunrise→sunset arc, a wind compass, air quality (MITECO ICA), the UV index, the nearest regional radar, the AEMET narrative bulletin, and a "Noticias" stream. Each card renders from the shared `AuraKit`, so the Watch shows the same cards resized. The wind, air-quality and UV cards open a tap-through reference-scale sheet (Beaufort, ICA levels, WHO UV bands).
- **Predicción** — the official, human-written forecast bulletin AEMET issues for the autonomous community, with its issue date. Read from AEMET's OpenData normalized-text products, resolved to the bulletin that covers today (AEMET's `hoy` product is amendment-only, so this falls back to the daily `manana` archive — see `AEMETClient.comunidadBulletin`). The same bulletin also appears as a card in the Hoy stack.
- **Ubicaciones** — favorites: pick the active location, add from the bundled list of provincial capitals, use the current GPS location (nearest bundled city), reorder, delete.
- **Ajustes** — enter the AEMET API key (stored in the Keychain), pick the sky-background family (Paisaje / Ciudad), and reach the About screen (attribution and a dedication to my parents).
- **Ayuda** — how to request your own free AEMET key (with a link to the sign-up page) and a legend for every icon in the app, even the obvious ones (the drop-with-waves is humidity, not rain). Colour scales aren't repeated — each card opens its own on a tap.
- **First-run intro** (`OnboardingView`) — a few swipeable pages over the live sky shown once on first launch (gated by `@AppStorage("hasOnboardedV1")` in `RootView`): what Aura is, that it needs a free AEMET key (with a request button), where the widgets live, and a done page — with a **Pasar** (skip) for anyone who just wants the weather.

The app is the fetch hub: it caches every saved location's `WeatherSnapshot` to the App Group and mirrors the favourites list so the **widgets** can render any of them. Both the **Home Screen** families (small / medium / large + iPad extra-large, over the live sky with the sunless hero art behind it) and the **Lock Screen** families (circular / rectangular / inline) are supported; each instance is **configurable to a specific location** via App Intents, and the Home Screen widget also picks a Naturaleza / Ciudad scene. An Apple Watch app and complication share the same layouts — targets `AuraWatch` and `AuraWatchComplication`, built from the same `AuraKit`; see [`docs/WATCHOS.md`](docs/WATCHOS.md) for running to a watch and placing the complication. Open `Aura.xcodeproj`, or build from the command line:

```bash
xcodebuild -project Aura.xcodeproj -scheme Aura \
  -destination 'generic/platform=iOS Simulator' build
```

Building the `Aura` scheme also builds and embeds the Watch app + complication (each target keeps its own SDK — don't pass `-sdk`, which would force one SDK onto every target). Run the `AuraWatch` scheme to install straight to a paired watch.

## AuraKit

- **`AEMETClient`** — handles AEMET's OpenData two-call model (envelope → temporary `datos` URL → payload), the UTF-8 payload encoding, JSON forecasts and plain-text bulletins. Its `comunidadBulletin` resolves the community narrative that covers today (`hoy` amendment if AEMET issued one, else yesterday's `manana` from the archive).
- **`ForecastBulletin`** / **`AEMETBulletinParser`** — the parsed community narrative from AEMET's OpenData text product, with issue/validity dates and significant phenomena, hard wraps unfolded.
- **`ForecastPhrase`** — on-device Spanish natural-language generation for the editorial hero: a `headline` and a `dataline` composed from the snapshot by template/grammar rules (no LLM), seeded per location + day so the wording is deterministic but varies town to town and day to day. The dataline weaves in only the numbers it has — range, humidity, wind, rain probability, and, when the hourly feed carries them, rain amount in mm, a snow note on snowy days, feels-like when it diverges from the shown temperature, and storm risk — each conditional so ordinary days stay short. Spanish decimal comma throughout (`0,4 mm`; whole numbers plain, `2 mm`).
- **`HeroBackground`** — the contract for the optional hero-art layer that sits behind the live sky (see [`docs/HERO_BACKGROUNDS.md`](docs/HERO_BACKGROUNDS.md)): the canonical `condition_time` asset names (8 conditions × 6 times), a landscape/cityscape `Family` axis, and `resolve(...)` with its fallback chain (exact match → nearest time for the same condition → procedural `AuraSky`). The art is generated sunless; Aura keeps drawing the live disc and text on top.
- **`Location`** / **`Location.seedCities`** — a Spanish municipality (INE code + coordinates) and a bundled seed of the 50 provincial capitals plus Ceuta, Melilla, Vigo and Gijón.
- **`Comunidad`** — maps INE province code → autonomous community, carrying AEMET's OpenData code.
- **`AuraKeychain`** — Keychain storage for the AEMET API key; never in the binary or the repo.
- **`WindDirection`** — 16-point Spanish compass rose (`N`, `NNE`, … , `NNO`) with names and bearings.
- **`SolarTimes`** — sunrise / sunset via the NOAA solar equations; offline and deterministic, matching the Observatorio Astronómico Nacional orto/ocaso tables to the minute.
- **`WeatherSnapshot`** — the compact, `Codable` view model every surface renders from: current-hour temperature and condition, today's range and humidity, the nearest station's observed temperature, wind (speed / direction / gust), air quality (`airQuality`), the UV index (`uvIndex`), sunrise / sunset, an active aviso, the community bulletin, the next hours (`HourSlot`) and the multi-day outlook (`DaySnapshot`). From the hourly feed it also resolves the current hour's rain amount (`currentPrecipMm`), snow amount (`currentSnowMm`), feels-like (`currentFeelsLike`) and storm probability (`currentStormProb`). Built by `make(...)` from AEMET's daily + hourly municipal forecasts. (Radar frames and news are intentionally *not* snapshot fields — image bytes / app-side data are fetched separately and passed into the card stack.)
- **`SharedCache`** — the App Group seam (`group.com.mab.Aura`): the app upserts snapshots, the widget extension reads them. No backend — the device is the hub.
- **`SharedLocations`** — the favourites list mirrored to the same App Group, so the widget's configuration picker lists exactly the user's saved locations.
- **`WatchSync`** — the iPhone↔Apple Watch bridge (WatchConnectivity): the phone pushes the current snapshot, the Watch caches it for its complication. It refuses to overwrite a good cached snapshot with a "thin" one whose current-hour fields are all nil (`WeatherSnapshot.hasCurrentHourData`, guarded per-INE). Guarded so the package still builds on macOS.
- **`AuraAccessoryCircular/Rectangular/Inline/Corner`** — the Lock Screen and Watch complication layouts, shared so every small surface renders identical code.
- **`AuraHomeSmall/Medium/Large/XL`** — the Home Screen widget layouts (the extra-large is iPad-only), drawn over `AuraSky` with the sunless hero art behind. The extension loads that art from **pre-sized tiers** (`WidgetHero`, an extra-large tier plus a lighter `_w` tier) rather than decoding the full-resolution source, so a screen full of Aura widgets stays inside WidgetKit's per-process memory budget.
- **`WeatherIcon`** — maps AEMET `estadoCielo` codes to SF Symbols, honouring the `n` night suffix.
- **`StationObservation`** — decodes `/observacion/convencional/todas` and resolves the nearest recent station to a location (haversine, within 3h and 35km) for a real observed temperature.
- **`WeatherAlert`** / **`AvisoArea`** / **`CAPParser`** — the avisos pipeline: fetch a community's CAP-XML `.tar`, parse it, and match warnings to a location by province (the warning-zone code carries the province INE). `TarReader` unpacks the plain tar on-device.
- **`AirQuality`** / **`AirComponent`** / **`MitecoAirQuality`** — the air-quality pipeline off MITECO's national ICA feed (CC-BY 4.0, a separate host): the composite 1–6 índice, per-pollutant readings, and `breakdown(...)` / `composite(...)`, which pull each pollutant from the nearest station that measures it and set the índice from the worst pollutant's band (MITECO's own method).
- **`UVIndex`** / **`UVIForecast`** — AEMET's forecast clear-sky daily-max UV index, resolved per location by INE and shown in its WHO band colour.
- **`RadarSite`** — the 15 AEMET regional radars and nearest-site lookup; the app's `RadarService` fetches the frame and `AuraRadarCard` shows it (kept out of the snapshot — image bytes).
- **`NewsFeed`** / **`NewsSource`** / **`NewsItem`** — the "Noticias" pipeline: several public weather RSS feeds (RTVE, AEMET, Meteored, AEMET Blog) parsed and round-robin-merged by recency; the app's `NewsService` fetches and caches them.
- **`AuraForecastStack`** and the **`Aura*Card`** suite (hero, hourly, daily, sun-arc, wind, air quality, UV, radar, news, alert, bulletin) over **`AuraSky`** (the live sun-tracking SwiftUI sky, whose sun/moon disc dims and blurs under cloud/rain via its `veil`) — the shared card stack the iOS app and the Watch app both render, resized by `AuraSize`.
- **`AuraScaleSheets`** — the tap-through reference-scale detail sheets (Beaufort, ICA levels, WHO UV bands) the wind / air-quality / UV cards open on the phone.

### Smoke test

```bash
AEMET_API_KEY=your-key swift run aura-smoke 28079           # numeric daily forecast (INE code)
AEMET_API_KEY=your-key swift run aura-smoke boletin 28      # community narrative (province code)
AEMET_API_KEY=your-key swift run aura-smoke snapshot 28079  # widget snapshot (obs + hourly + aviso)
AEMET_API_KEY=your-key swift run aura-smoke avisos 04       # active warnings for a province
AEMET_API_KEY=your-key swift run aura-smoke raw /prediccion/ccaa/manana/gal  # any text endpoint
```

Every mode reads the key from the environment (never stored in the repo). `boletin` resolves the narrative that covers today; `snapshot` builds the widget view model and prints what a card would show; `raw` fetches any normalized-text endpoint verbatim, handy for inspecting freshness across the `hoy`/`manana`/`pasadomanana`/`medioplazo` horizons.

### Build & test

```bash
swift build
swift test
```

The tests cover the pure logic (wind rose, solar times, the hero phrasing, the hero-art asset contract) and need no network or API key.

## Data & attribution

Weather data: **Elaborado con datos de AEMET.** An AEMET OpenData API key is required (free, tied to an email; if it ever stops working, request another the same way). Sun times are computed on-device.

Air quality: the national **ICA feed from MITECO** (Ministerio para la Transición Ecológica), licensed **CC-BY 4.0** — so the in-app credit reads "Elaborado con datos de AEMET y MITECO" whenever the air-quality card is shown. The "Noticias" stream links out to public RSS feeds (RTVE, AEMET, Meteored, AEMET Blog); each headline is credited to its source.

## Built with

[Claude Code](https://claude.com/claude-code) (Anthropic).

## License

MIT — see [LICENSE](LICENSE).
