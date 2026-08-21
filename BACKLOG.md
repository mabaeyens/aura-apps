# Backlog

## Done
- 2026-08-21 — Radar Phase 1 (`AuraRadarCard` + `AuraRadarInfo` in AuraKit, `RadarService` +
  `RadarSite` in the app): the **nearest regional radar** frame shown as-is (the 240 km circle is
  already local, so no georeferencing). `RadarSite.nearest(…)` picks 1 of the 15 sites by haversine;
  `AEMETClient.radarRegional(code)` fetches `/red/radar/regional/{code}` bytes; `RadarService` decodes
  `UIImage` and caches per code on disk with a **10-min TTL** (falls back to any stale frame offline).
  Kept OUT of `WeatherSnapshot` (image bytes would bloat the App-Group/Watch snapshot) — `TodayView`
  loads it lazily after each snapshot. Card = image + "Radar de {sitio} · hace N min". **iOS only.**
  Chrome verified via render (real imagery needs on-device verification). Phase 2 (GeoTIFF precise
  crop) still optional — see below.
- 2026-08-21 — UV Index card (`AuraUVCard`, `UVIndex` in `Sources/AuraKit/UVIndex.swift`): AEMET's
  forecast clear-sky daily-max UV (`/prediccion/especifica/uvi/0`) as a WHO band-coloured swatch +
  band name ("Muy alto") + protection cue. Payload confirmed live: a single object with
  `CIUDAD:[{id,valor,uv,canarias}]` where `id` is the INE municipio code, so it's selected per location
  by `location.ine` — one AEMET call lists every capital (fetched once per refresh, like the ICA feed).
  Snapshot gains optional `uvIndex` (back-compatible). Placed in the environmental cluster after the ICA
  card. Verified phone + Watch. (Render canvas heightened to fit the taller stack.)
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

### Building now
- **Fire risk** — DECISION: use **EFFIS FWI** (EU/Copernicus GWIS). AEMET's own fire risk is map-only
  (no per-coordinate value), but the JRC GWIS GeoServer exposes a **fully anonymous per-lat/lon** query,
  confirmed live against the server:
  - `GET https://ies-ows.jrc.ec.europa.eu/gwis` — WMS 1.3.0 `GetFeatureInfo`, `LAYERS=ecmwf.query`
    (the `.query` layer is queryable; `ecmwf.fwi` is display-only → `LayerNotDefined`). Required params:
    `STYLES=` (empty but present), `CRS=EPSG:4326`, `INFO_FORMAT=text/html` (only format carrying values),
    `TIME=YYYY-MM-DD`. WMS 1.3.0 axis order is **lat,lon**, so `BBOX=lat−.05,lon−.05,lat+.05,lon+.05`
    with `WIDTH=101&HEIGHT=101&I=50&J=50` samples the centre pixel. ECMWF ~8 km grid, **global** (covers
    peninsula + Canarias), daily, 1–9-day forecast horizon.
  - Response is an HTML table; parse the cell after "Fire Weather Index (FWI)" (a float) and "Danger
    Index" (1–6 integer). **Bucket the FWI float ourselves** (don't trust the integer's meaning blindly):
    classic EFFIS breakpoints → 1 Muy bajo <5.2 · 2 Bajo 5.2 · 3 Moderado 11.2 · 4 Alto 21.3 ·
    5 Muy alto 38.0 · 6 Extremo >50.0. (3/4/5 boundaries confirmed from live data; 1↔2 at 5.2 inferred.)
  - No key, no registration (`<Fees>none</Fees>`). Shared public JRC service → **cache 1 value per
    location per day**. Attribution required: "Fuente: EFFIS / GWIS — Copernicus EMS, © Unión Europea".
  - On-device check before shipping: the sandbox clock (2026-08-21) was outside the server's rolling
    window in research, so confirm a live query for the real current date returns a value.
- **Radar images** — Phase 1 shipped (see Done). Phase 2 (GeoTIFF crop) optional, see plan below.

### Later
- **Ozono card** — `/api/red/especial/ozono` is **total-column ozone in Dobson Units** (stratospheric,
  ~320 DU, *not* surface air quality), daily-mean, not produced on weekends/holidays. Low everyday
  value + JSON keys still unknown. Keep for later — only worth it as an "capa de ozono" angle, not as
  air quality (the ICA card already covers that).
- **Other AEMET cards surveyed**: montaña/nivológica (mountain + freezing level + avalanche), marítima
  (coastal/altamar sea state), playa (beach: sky/waves/water temp + UV max). No pollen in AEMET
  (SEAIC/regional).

_(Contaminación de fondo dropped — the MITECO ICA card already covers local air quality.)_

### Radar plan — "radar for the displayed location"

AEMET OpenData radar (tag `red-radares`), two products, each a **single latest image frame** (GIF,
burnt-in dBZ legend), fetched via the existing two-step client (`AEMETClient.fetchBinary` already
returns raw payload bytes):
- `/api/red/radar/nacional` — Península+Baleares composite, **30-min** cadence, **no published
  geographic bounds** (can't crop cleanly).
- `/api/red/radar/regional/{code}` — one radar, a **240 km-radius circle centred on the radar city**,
  **10-min** cadence. 15 codes: `am` Almería, `sa` Asturias, `pm` Balears, `ba` Barcelona, `cc` Cáceres,
  `co` A Coruña, **`ma` Madrid**, `ml` Málaga, `mu` Murcia, `vd` Palencia, `ca` Las Palmas, `se` Sevilla,
  `va` Valencia, `ss` Vizcaya, `za` Zaragoza.

**Phase 1 (ship first — simple, robust, no georeferencing):** show the **nearest regional radar** image
as-is. The regional frame is *already* local (a circle around a nearby city), so no bounds/cropping math
is needed — this sidesteps the un-georeferenced-image problem entirely.
- Map location → nearest of the 15 radar sites by haversine (hardcode the 15 approx city coords; Madrid
  → `ma`).
- Fetch `/red/radar/regional/{code}` with `fetchBinary`; decode bytes → `UIImage`/`NSImage` (handle GIF
  and PNG). New `AuraRadarCard`: the image + radar name + "hace N min" freshness.
- **Keep the image OUT of `WeatherSnapshot`** (image bytes would bloat the Codable/App-Group/Watch-synced
  snapshot). Instead a small `RadarService` in the app fetches + caches per radar code with a **10-min
  TTL** (disk in the App Group or in-memory). Fetch lazily when the card appears, or once per refresh.
- **iOS only in v1** — don't ship heavy images to the Watch over WatchConnectivity; revisit with a
  downscaled frame later.

**Phase 2 (optional — precise crop/overlay):** AEMET also distributes the radar rasters as **EPSG:4326
GeoTIFF** (self-georeferenced, with an `ESCALA` RGBA→dBZ field, 3 latest frames). If reachable via the
OpenData REST endpoint (confirm with a live `metadatos.formato` check: `image/gif` vs `image/tiff` —
needs the API key), use it to crop to the exact point and/or overlay reflectivity on a MapKit snapshot.
Only pursue if Phase 1 isn't local enough.

Note: AEMET has **no precipitation-nowcast** product — the radar raster is the only observed "raining
near me now" surface (HARMONIE-AROME is forecast, not observation).

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
