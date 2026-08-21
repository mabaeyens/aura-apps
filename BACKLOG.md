# Backlog

## Done
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
New data-card requests — full spec to arrive in a fresh session:
- **UV Index card** — `/api/prediccion/especifica/uvi/{0..4}` (0=today … 4=+4 days); returns an
  array of provinces, pick the displayed province (e.g. Madrid).
- **Ozono card** — `/api/red/especial/ozono`; returns all stations, pick the nearest to the
  displayed location. Value interpretation still unknown (Madrid ≈ 320 — units/meaning TBD).
- **Contaminación de fondo card** — `/api/red/especial/contaminacionfondo/estacion/{nombre}`;
  12 stations, pick the nearest and name it (Madrid → Toledo?). Refs: BOE-A-2023-2026 and the
  miteco air-quality visualisation page.
- **AEMET endpoint research** — survey other useful OpenData endpoints and present options to
  choose from.
- **Air-quality (miteco, not AEMET)** — investigate the `ica.miteco.es` /
  `backend.ica.miteco.es` (`/s/sgca`?) JSON backend for nearest-station air quality; the
  OpenData portal exposes no obvious air-quality feed.

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
