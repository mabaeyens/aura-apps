# Hourly UV index — data sources & findings

**Question (item 4):** can Aura show the UV index *per hour* (like AEMET's observation page),
instead of only the clear-sky daily maximum it shows today?

**Answer: yes — and the best source isn't AEMET.** There are three paths. The practical one for a
live hourly curve is **CAMS via Open-Meteo** (modeled forecast, any coordinate, free JSON) — the
same source the dedicated site uvi.today uses. AEMET's own site does expose hourly *observed*
(measured) UV as a real table, but it's historical and station-sparse. Summary and trade-offs
below; decisions flagged at the end.

## Source A — CAMS via Open-Meteo (recommended for a live hourly curve)

`GET https://air-quality-api.open-meteo.com/v1/air-quality` with
`hourly=uv_index,uv_index_clear_sky&timezone=auto`.

- **What it gives.** Hourly `uv_index` (includes forecast cloud effect) **and**
  `uv_index_clear_sky`, for **today + tomorrow** (up to 7 forecast days; `past_days` up to 92 for
  history), at **any lat/lon** — not stations. Fractional precision. Verified live 2026-08-23 for
  Madrid (40.4165, −3.7026, elev 651 m): peak `8.15` at 14:00 today, full 48-hour series returned.
- **Source & cadence.** Copernicus **CAMS** — 11 km CAMS-Europe + 45 km global, hourly, updated
  daily; Open-Meteo caches ≤30 min. This is a **modeled forecast** (ozone + aerosols + forecast
  cloud), not a ground measurement — but it's exactly what uvi.today shows as its hourly UV, and
  it's live, unlike AEMET's observed table.
- **Access.** Free tier needs **no API key**, JSON, `timezone=auto` → local time. Two knobs only
  (lat/lon); response shape is trivial to decode into a `[hour: uv]` series.
- **Caveats that need a call:**
  - **Licence.** The Open-Meteo *free* endpoint is **non-commercial**, ≤10,000 calls/day. The
    underlying CAMS *data* is CC BY 4.0 (commercial OK **with attribution**), so commercial use
    means either the paid customer endpoint (`customer-api.open-meteo.com` + `apikey`) or
    **self-hosting** the open-source Open-Meteo server against CC-BY CAMS. Whether a free,
    non-monetised App Store app counts as "commercial" is the open question. Volume is a non-issue
    for a personal app (Aura caches per location, refreshes on foreground — far under 10k/day), but
    a widely-installed app could approach the cap.
  - **Provenance / identity.** This is **not AEMET data**. Aura's pitch is "official AEMET open
    data" — though it already mixes in MITECO (air quality) and news feeds, so a clearly-attributed
    CAMS/Copernicus UV source isn't unprecedented. Needs a product call.
  - **Attribution required:** credit the CAMS ENSEMBLE data provider **and** reference Open-Meteo
    (both CC BY 4.0). Would join the existing "AEMET y MITECO" credit line.

## Source B — AEMET observed table (the only ground-*measured* hourly UV, but historical)

`…/observacion/radiacion/ultravioleta?datos=tabla` (no `?l=` selector) renders a real HTML table:

- One **row per station** (26 radiometric stations), columns **07 … 22** (hourly local) + **MAX**,
  integers on the WHO 0–11+ scale, one `Fecha:` per table. Example (2026-08-21): Barcelona
  `0 0 0 1 3 5 6 7 7 5 3 2 1 0 0 0`, MAX 7; Sta. Cruz de Tenerife peaked at 11.
  (My first pass wrongly said "only a PNG" — that's the per-station `?l=<token>` view, which does
  render the chart image. The bare `?datos=tabla` view is the numeric grid.)
- **Historical, not live.** The page states *"Los valores se actualizan diariamente"* and
  *"controles automáticos de calidad en tiempo real… no puede garantizarse la ausencia de errores."*
  Fetched Sun 2026-08-23 it still showed Fri 2026-08-21 (weekend QC gap). Freshest = the previous
  complete day, ≥1 day behind. **Cannot power a "UV ahora" figure.**
- **Website scrape, not OpenData.** AEMET OpenData still has **no** observed-radiation product; the
  only UV product there is the forecast clear-sky daily-max (`prediccion/especifica/uvi`, which Aura
  already uses). Consuming this means a defensive HTML parser (anchor on the `?l=` links + 16 hourly
  cells). Reuse authorised with attribution ("© AEMET. Autorizado el uso… citando a AEMET").
- **Coverage:** 26 nearest-match stations. Tokens (`?l=<token>`): `a-coruna, almeria, badajoz,
  barcelona, caceres, cadiz, ciudad-real, cordoba, granada, izana, leon, madrid, malaga, maspalomas,
  arenosillo, murcia, palma, navacerrada, salamanca, igueldo, santander, s-c-tenerife, roquetes,
  valencia, valladolid, zaragoza`.

## Source C — AEMET forecast daily-max (current behaviour)

`prediccion/especifica/uvi` — one integer per provincial capital per day, clear-sky daily maximum on
the WHO scale. Official AEMET, forward-looking, but **daily** granularity only. This is what the app
shows today, labelled "UV máximo".

## Recommendation

- **If the goal is a live hourly UV curve in the app** (the practical read of item 4): use
  **Source A (CAMS via Open-Meteo)** — hourly `uv_index` + `uv_index_clear_sky` for today/tomorrow,
  per exact coordinate, trivial JSON, no key. It's what a dedicated UV service (uvi.today) uses.
  Two decisions gate it: the **commercial-licence** question (free tier is non-commercial → pay for
  the customer endpoint, self-host, or confirm the app is non-commercial) and the **non-AEMET
  provenance** (attribute CAMS + Open-Meteo clearly). If both clear, this is the clean answer and
  could even replace the daily-max as the primary UV figure (keeping AEMET's as a cross-check).
- **If the goal is specifically ground-*observed* (measured) hourly UV:** only **Source B** gives
  it, and only as a lagged, 26-station, HTML-scraped historical curve — worth it only as a
  "what the UV actually did yesterday near you" context card, not a live figure.
- **Otherwise:** keep **Source C** (forecast daily-max) as-is — the one official-AEMET,
  forward-looking "is it high today" number.

Not implemented in this batch — needs the licence + provenance call before building.
