# Backlog

## Done
- 2026-08-21 — Air-quality card (`AuraAirQualityCard`) from MITECO's national ICA feed (`AirQuality` +
  `MitecoAirQuality` in `Sources/AuraKit/AirQuality.swift`): one ~50 KB `ica-ultima-hora.csv` download
  per refresh (in `AEMETService`, alongside `observacionTodas`), nearest active station resolved locally
  by haversine, shown as the official 1–6 ICA colour swatch + category name + "por O₃ · estación · a
  X km". Índice encoding confirmed from the MITECO data dictionary: 1–6 category, ×10 = same category
  from partial pollutants (flagged "parcial"), 0 = no data (card hidden). Snapshot gains an optional
  `airQuality` (back-compatible decode); credit reads "AEMET y MITECO" when present (CC-BY 4.0). Tests
  in `AirQualityTests`. Verified phone + Watch. Note: uses a non-AEMET host with a slightly incomplete
  cert chain (curl accepted it) — **confirm URLSession accepts it on-device**.
- 2026-08-21 — Sun arc card (`AuraSunArcCard`) + full-width wind card (`AuraWindCard`): replaced the
  two-up next-event/wind row with a full-width orto→ocaso arc — the sun glyph rides its live position
  (recomputed from `sunrise/sunset` + `now` at display, so it re-anchors like the hourly strip), warm
  travelled arc, orto/ocaso times at the ends, and a centre readout ("Quedan Xh de luz" by day,
  "Amanece en Xh" after dark, arc dims + sun rests at the horizon). Wind moved to its own full-width
  card reusing the `AuraWindCircular` compass rose. Verified at four times of day, phone + Watch.
- 2026-08-21 — Robust hourly re-anchor + UI polish (`af462de`): `upcomingHours(now:)`
  reconstructs each nil-date slot's instant from `updated`, so an already-cached overnight
  snapshot re-anchors to the current hour without waiting for a refresh; predicción and hero
  fonts larger; uniform `Próximos días` row height (precip line always reserved); lighter card
  frost (`ultraThinMaterial` @ 0.7) so the sky reads through.
- 2026-08-21 — App-screen type + layout pass (`c1eeacf`): whole `AuraSize` type scale bumped
  (phone + Watch); phone hero right column fills its height; `HourSlot` gains an absolute
  `date`; hourly strip re-anchored at display; dry-day hourly drops the empty precip row;
  sun/wind cards centred; sky low-sun arc lifted so its light reaches the visible sky; bigger
  "Elaborado con datos de AEMET" credit.

## Pending
- **UV Index card** — `/api/prediccion/especifica/uvi/{0..4}` (0=today … 4). BLOCKED on the exact
  JSON key names: the product is one **daily-max clear-sky UV integer per provincial capital**,
  selected by capital NAME (no INE/station code); scale 0–2 low … ≥11 extreme. **To unblock**, run one
  live `datos` fetch with the AEMET key (I'm sandboxed out of the Keychain) — e.g. paste the first array
  element of `.../uvi/0` — then it's a small card. High value; do next.
- **Ozono card** — `/api/red/especial/ozono` is **total-column ozone in Dobson Units** (Madrid ≈ 320 DU
  is stratospheric column, *not* surface air quality), daily-mean, and **not produced on weekends/
  holidays**. Low everyday value + JSON keys still unknown. Recommend deprioritising vs. the ICA card
  (already shipped) unless a "capa de ozono / índice UV" angle is wanted.
- **Contaminación de fondo** — `/api/red/especial/contaminacionfondo/estacion/{codigo}` (numeric codes,
  e.g. Madrid → `01` San Pablo de los Montes, ~90 km). Payload is **plain-text FINN**, not JSON (needs a
  custom line parser); pollutants O3/NO2/SO2/PM10 in µg/m³. Superseded for local relevance by the MITECO
  ICA card; build only if actual background concentrations are wanted.
- **Other AEMET cards worth considering** (surveyed): montaña/nivológica (mountain + freezing level +
  avalanche), marítima (coastal/altamar sea state), playa (beach: sky/waves/water temp + UV max),
  radar nacional, riesgo de incendios. No pollen in AEMET (SEAIC/regional). Pick from these next.

## Notes
- Data plumbing: endpoint calls in `Sources/AuraKit/AEMETClient.swift`, assembly in
  `WeatherSnapshot.make(...)`. Shared cards in `Sources/AuraKit/AuraAppCards.swift` are composed
  once and reused by both iOS (`Aura/TodayView.swift`) and watchOS
  (`AuraWatch/WatchRootView.swift`) — new cards should follow that shared pattern.
- `aura-render` (`Sources/AuraRender/main.swift`) renders the full stack at four times of day
  for offline visual review; use it before committing any card visuals.
- Hourly-strip staleness is handled at display time by `WeatherSnapshot.upcomingHours(now:)` —
  any new time-sensitive card should re-anchor similarly rather than baking "now" into the
  stored snapshot.
