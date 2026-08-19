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
  autonomous community, with its issue date. Read from AEMET's website API, which stays current
  for every region (the OpenData text products are frozen for several); needs no key.
- **Ubicaciones** — favorites: pick the active location, add from the bundled list of provincial
  capitals, use the current GPS location (nearest bundled city), reorder, delete.
- **Ajustes** — enter the AEMET API key (stored in the Keychain) and attribution.

The app is the fetch hub: it calls AEMET and will feed the App Group cache the widgets read
(Phase 2). Open `Aura.xcodeproj`, or build from the command line:

```bash
xcodebuild -project Aura.xcodeproj -scheme Aura -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build
```

## AuraKit

- **`AEMETClient`** — handles AEMET's OpenData two-call model (envelope → temporary `datos` URL →
  payload), the UTF-8 payload encoding, JSON forecasts and plain-text bulletins.
- **`AEMETBulletinClient`** / **`ForecastBulletin`** — the narrative community forecast from AEMET's
  website API (keyless), parsed from its XML with issue/validity dates and significant phenomena.
- **`Location`** / **`Location.seedCities`** — a Spanish municipality (INE code + coordinates) and a
  bundled seed of the 50 provincial capitals plus Ceuta, Melilla, Vigo and Gijón.
- **`Comunidad`** — maps INE province code → autonomous community, with both AEMET's OpenData code
  and the website API's area id.
- **`AuraKeychain`** — Keychain storage for the AEMET API key; never in the binary or the repo.
- **`WindDirection`** — 16-point Spanish compass rose (`N`, `NNE`, … , `NNO`) with names and bearings.
- **`SolarTimes`** — sunrise / sunset via the NOAA solar equations; offline and deterministic,
  matching the Observatorio Astronómico Nacional orto/ocaso tables to the minute.

### Smoke test

```bash
AEMET_API_KEY=your-key swift run aura-smoke 28079        # numeric daily forecast (INE code)
swift run aura-smoke boletin 28                          # community narrative (province code; no key)
AEMET_API_KEY=your-key swift run aura-smoke ccaa mad     # OpenData community text (fallback)
```

The numeric forecast reads the key from the environment (never stored in the repo). The `boletin`
mode hits AEMET's website API and needs no key; the `ccaa`/`texto` modes exercise the OpenData
text products kept as a fallback.

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
