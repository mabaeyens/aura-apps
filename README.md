# Aura

Personal Apple-ecosystem weather app for Spain, powered by the [AEMET OpenData](https://opendata.aemet.es/) API.
It fills the gaps in the official AEMET app: **Apple Watch complications, a rich widget set, and
macOS / Lock Screen coverage.**

Targets iOS, iPadOS, macOS and watchOS from one shared Swift package, so every widget and
complication renders from identical code.

## Status

Early development — **Phase 0 (foundations)**. No app targets yet; this repo currently holds
`AuraKit`, the shared Swift package with the AEMET client and the pure weather logic.

## AuraKit

- **`AEMETClient`** — handles AEMET's two-call model (envelope → temporary `datos` URL → payload)
  and the ISO-8859-1 payload encoding.
- **`WindDirection`** — 16-point Spanish compass rose (`N`, `NNE`, … , `NNO`) with names and bearings.
- **`SolarTimes`** — sunrise / sunset via the NOAA solar equations; offline and deterministic,
  matching the Observatorio Astronómico Nacional orto/ocaso tables to the minute.

### Smoke test

```bash
AEMET_API_KEY=your-key swift run aura-smoke 28079
```

Prints the daily min/max forecast for the given INE municipality code (default: Madrid, `28079`).
The key is read from the environment and never stored in the repo.

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
