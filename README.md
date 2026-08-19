# Aura

Personal Apple-ecosystem weather app for Spain, powered by the [AEMET OpenData](https://opendata.aemet.es/) API.
It fills the gaps in the official AEMET app: **Apple Watch complications, a rich widget set, and
macOS / Lock Screen coverage.**

Targets iOS, iPadOS, macOS and watchOS from one shared Swift package, so every widget and
complication renders from identical code.

## Status

Early development — **Phase 1 (iOS app shell)**. The `Aura` iOS app now builds on top of
`AuraKit`: location management with favorites, the numeric "today" forecast, and the official
AEMET narrative forecast text. Widgets, macOS and the Watch follow in later phases.

## Aura (iOS app)

A thin shell over `AuraKit`, Spanish-only, four tabs:

- **Hoy** — the numeric daily forecast (min/max temperature, humidity) for the selected
  municipality, plus on-device sunrise/sunset.
- **Predicción** — the official, human-written forecast bulletin AEMET issues for the
  autonomous community, with its issue date. Read from AEMET's OpenData normalized-text products,
  resolved to the bulletin that covers today (AEMET's `hoy` product is amendment-only, so this
  falls back to the daily `manana` archive — see `AEMETClient.comunidadBulletin`).
- **Ubicaciones** — favorites: pick the active location, add from the bundled list of provincial
  capitals, use the current GPS location (nearest bundled city), reorder, delete.
- **Ajustes** — enter the AEMET API key (stored in the Keychain) and attribution.

The app is the fetch hub: it caches every saved location's `WeatherSnapshot` to the App Group and
mirrors the favourites list so the **widgets** can render any of them. Home-screen (small / medium /
large) and Lock Screen (circular / rectangular / inline) families are supported, and each widget
instance is **configurable to a specific location** via App Intents. An Apple Watch app and
complication share the same layouts — targets `AuraWatch` and `AuraWatchComplication`, built from the
same `AuraKit`; see [`docs/WATCHOS.md`](docs/WATCHOS.md) for running to a watch and placing the
complication. Open `Aura.xcodeproj`, or build from the command line:

```bash
xcodebuild -project Aura.xcodeproj -scheme Aura \
  -destination 'generic/platform=iOS Simulator' build
```

Building the `Aura` scheme also builds and embeds the Watch app + complication (each target keeps its
own SDK — don't pass `-sdk`, which would force one SDK onto every target). Run the `AuraWatch` scheme
to install straight to a paired watch.

## AuraKit

- **`AEMETClient`** — handles AEMET's OpenData two-call model (envelope → temporary `datos` URL →
  payload), the UTF-8 payload encoding, JSON forecasts and plain-text bulletins. Its
  `comunidadBulletin` resolves the community narrative that covers today (`hoy` amendment if AEMET
  issued one, else yesterday's `manana` from the archive).
- **`ForecastBulletin`** / **`AEMETBulletinParser`** — the parsed community narrative from AEMET's
  OpenData text product, with issue/validity dates and significant phenomena, hard wraps unfolded.
- **`Location`** / **`Location.seedCities`** — a Spanish municipality (INE code + coordinates) and a
  bundled seed of the 50 provincial capitals plus Ceuta, Melilla, Vigo and Gijón.
- **`Comunidad`** — maps INE province code → autonomous community, carrying AEMET's OpenData code.
- **`AuraKeychain`** — Keychain storage for the AEMET API key; never in the binary or the repo.
- **`WindDirection`** — 16-point Spanish compass rose (`N`, `NNE`, … , `NNO`) with names and bearings.
- **`SolarTimes`** — sunrise / sunset via the NOAA solar equations; offline and deterministic,
  matching the Observatorio Astronómico Nacional orto/ocaso tables to the minute.
- **`WeatherSnapshot`** — the compact, `Codable` view model the widgets render from: current-hour
  temperature and condition, today's range and humidity, the next hours (`HourSlot`) and the
  multi-day outlook (`DaySnapshot`). Built by `make(location:daily:hourly:)` from AEMET's daily +
  hourly municipal forecasts.
- **`SharedCache`** — the App Group seam (`group.com.mab.Aura`): the app upserts snapshots, the
  widget extension reads them. No backend — the device is the hub.
- **`SharedLocations`** — the favourites list mirrored to the same App Group, so the widget's
  configuration picker lists exactly the user's saved locations.
- **`WatchSync`** — the iPhone↔Apple Watch bridge (WatchConnectivity): the phone pushes the current
  snapshot, the Watch caches it for its complication. Guarded so the package still builds on macOS.
- **`AuraAccessoryCircular/Rectangular/Inline/Corner`** — the Lock Screen and Watch complication
  layouts, shared so every small surface renders identical code.
- **`WeatherIcon`** — maps AEMET `estadoCielo` codes to SF Symbols, honouring the `n` night suffix.
- **`StationObservation`** — decodes `/observacion/convencional/todas` and resolves the nearest
  recent station to a location (haversine, within 3h and 35km) for a real observed temperature.
- **`WeatherAlert`** / **`AvisoArea`** / **`CAPParser`** — the avisos pipeline: fetch a community's
  CAP-XML `.tar`, parse it, and match warnings to a location by province (the warning-zone code
  carries the province INE). `TarReader` unpacks the plain tar on-device.
- **`AuraCard*`** — the shared SwiftUI cards (small / medium / large + empty state), so the app and
  the widget extension render from identical code.

### Smoke test

```bash
AEMET_API_KEY=your-key swift run aura-smoke 28079           # numeric daily forecast (INE code)
AEMET_API_KEY=your-key swift run aura-smoke boletin 28      # community narrative (province code)
AEMET_API_KEY=your-key swift run aura-smoke snapshot 28079  # widget snapshot (obs + hourly + aviso)
AEMET_API_KEY=your-key swift run aura-smoke avisos 04       # active warnings for a province
AEMET_API_KEY=your-key swift run aura-smoke raw /prediccion/ccaa/manana/gal  # any text endpoint
```

Every mode reads the key from the environment (never stored in the repo). `boletin` resolves the
narrative that covers today; `snapshot` builds the widget view model and prints what a card would
show; `raw` fetches any normalized-text endpoint verbatim, handy for inspecting freshness across the
`hoy`/`manana`/`pasadomanana`/`medioplazo` horizons.

### Build & test

```bash
swift build
swift test
```

The tests cover the pure logic (wind rose, solar times) and need no network or API key.

## Data & attribution

Weather data: **Elaborado con datos de AEMET.** An AEMET OpenData API key is required (free,
tied to an email, renewed every three months). Sun times are computed on-device.

## Built with

[Claude Code](https://claude.com/claude-code) (Anthropic).

## License

MIT — see [LICENSE](LICENSE).
