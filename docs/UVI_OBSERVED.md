# Hourly observed UVI — findings

**Question:** can Aura show the UV index *observed per hour* (like AEMET's page
`https://www.aemet.es/es/eltiempo/observacion/radiacion/ultravioleta`), instead of only the
clear-sky daily maximum it shows today?

**Short answer: yes, as numeric data — but it's yesterday's, not "now".** The observation
website's **table** view does expose a real, parseable HTML grid of hourly observed UVI per
station. What it does *not* give is a live/current value: it updates once a day and shows the
most recent complete day. And it's an HTML scrape of the public site, not an OpenData product.

## What's actually there (rechecked 2026-08-23)

- **The table view is real numeric data.** `…/ultravioleta?datos=tabla` (no `?l=` station
  selector) renders a proper HTML `<table>`:
  - One **row per station** (26 of them), each linking to `?l=<token>`.
  - Columns **07 … 22** (16 hourly local-time slots) plus a **MAX** column.
  - Each cell is the hourly observed UVI as an integer on the WHO 0–11+ scale (the page shows
    the 1…11+ colour legend).
  - A single **`Fecha:`** heading names the day the whole table covers.
  - Example row (2026-08-21): Madrid, Ciudad Universitaria → `0 0 0 1 3 5 6 8 …`, Barcelona →
    `0 0 0 1 3 5 6 7 7 5 3 2 1 0 0 0`, MAX 7.
  - My earlier note here (that "Tabla" was just the same PNG) was **wrong** — that's the
    per-station `?l=<token>` view, which *does* render the chart image. The bare
    `?datos=tabla` view is the numeric grid.
- **It's historical, updated daily — not live.** The page states *"Los valores se actualizan
  diariamente"* and *"Los datos… han sido únicamente sometidos a controles automáticos de
  calidad en tiempo real, por lo que no puede garantizarse la ausencia de errores."* Fetched on
  Sun 2026-08-23 it still showed **Fri 2026-08-21** (observed-radiation QC doesn't seem to run
  weekends — the same weekend/holiday gap noted for the ozone product). So the freshest value
  you can ever show is the **previous complete day's** hourly curve, ≥1 day behind, more over
  weekends. It cannot power a "UV ahora" figure.
- **Not OpenData — a website scrape.** AEMET OpenData still has **no** observed-radiation /
  hourly-UVI product; the only UV product there is the forecast **clear-sky daily maximum**
  (`prediccion/especifica/uvi`), which Aura already uses. This numeric table lives only on the
  public website, so consuming it means parsing HTML (fragile to layout changes). Reuse is
  authorised with attribution: *"© AEMET. Autorizado el uso de la información y su reproducción
  citando a AEMET como autora."*
- **Coverage: 26 radiometric stations, nearest-match** (like air quality / radar), not per
  municipality. Tokens (`?l=<token>`): `a-coruna, almeria, badajoz, barcelona, caceres, cadiz,
  ciudad-real, cordoba, granada, izana, leon, madrid, malaga, maspalomas, arenosillo, murcia,
  palma, navacerrada, salamanca, igueldo, santander, s-c-tenerife, roquetes, valencia,
  valladolid, zaragoza`.

## Options

1. **"UV observado" card off the table (buildable).** Fetch `?datos=tabla` once per refresh,
   parse the row for the nearest of the 26 stations, show its hourly curve + MAX, labelled
   plainly as **observed** with the table's `Fecha` (e.g. "UV observado · 21 ago · estación
   más cercana"). Honest real data, per-hour tint possible. Caveats: (a) it's **historical**
   (yesterday), so it's a "what actually happened" / context card, not "your UV now"; (b) it's
   an **HTML scrape**, so add a defensive parser (anchor on the `?l=` links + the 16 hourly
   cells) and degrade gracefully when the layout shifts or no station is near; (c) sparse
   coverage. Keep it separate from the forecast daily-max, don't conflate the two.
2. **Official station chart image** (`uvi<Token>-CRN.png`, the `?l=` view) — the radar-style
   image card. Simpler, no HTML parsing, but a picture not data, so no tint/complication.
3. **Keep only the forecast daily-max** (current behaviour) — the one genuinely forward-looking
   "is it high today" figure.

## Recommendation

The forecast clear-sky **daily maximum** stays the primary UV figure (correctly labelled "UV
máximo") — it's the only forward-looking "should I cover up *today*" number. The observed table
(option 1) is real and worth adding **as a distinct historical/context card** if a lagged
"what the UV actually did yesterday, hour by hour, near you" earns a slot — but it can't make
the live figure live. Needs a product decision on framing (and appetite for an HTML scraper)
before building. Not implemented in this batch.
