# Hourly observed UVI — findings

**Question:** can Aura show the UV index *observed per hour* (like AEMET's page
`https://www.aemet.es/es/eltiempo/observacion/radiacion/ultravioleta?l=madrid&f=diario`),
instead of only the clear-sky daily maximum it shows today?

**Short answer: not as numeric data.** There is no hourly observed UVI anywhere in AEMET
OpenData, and the public website does not expose it as JSON, CSV or even an HTML table —
only as a rendered chart image.

## What I checked (2026-08-23)

- **OpenData.** The only UV product is the forecast **clear-sky daily maximum**
  (`prediccion/especifica/uvi`), which Aura already uses. There is no observed-radiation /
  hourly-UVI product. This matches the earlier note that AEMET UV = daily max, no hourly
  granularity. So the user's own conclusion ("can't reverse-engineer it with OpenData") holds.
- **The observation website.** Both the "Gráfica" and the "Tabla" views of the UVI
  observation page render the **same static PNG** per radiometric station, e.g.
  `https://www.aemet.es/imagenes_d/eltiempo/observacion/radiacionuv/uviMadrid-CRN.png`.
  There is no Highcharts/JS series, no backing JSON, and the "Tabla" tab is not a numeric
  HTML table — it's the image again. So there is nothing clean to parse into per-hour values.
- **Coverage.** Observed UVI exists only for the ~26 radiometric stations listed on the page
  (A Coruña, Badajoz, Barcelona, Madrid–Ciudad Universitaria, Izaña, Murcia, Zaragoza, …),
  not per municipality. Each station's chart is `uvi<Token>-CRN.png`, where `<Token>` is the
  station key behind the `?l=<token>` selector.

## Options if we still want observed hourly UVI

1. **Show AEMET's official station chart image** (recommended if we do this at all).
   Pick the nearest of the ~26 radiometric stations (Aura already does nearest-station
   selection for air quality) and display `uvi<Token>-CRN.png` as an "UV observado" card —
   the same *official-image* pattern Aura uses for the radar. Honest, attributed, no scraping
   of numbers, and it degrades to "no nearby station" gracefully. Downside: it's a picture,
   not data, so no per-hour tint/complication, and coverage is sparse.
2. **OCR / pixel-read the PNG.** Technically possible, but fragile and dishonest as a data
   source — rejected.
3. **Scrape a numeric table.** There isn't one to scrape.

## Recommendation

Keep the current clear-sky **daily maximum** UV (correctly labelled "UV máximo") as the data
figure. If observed hourly UV is wanted, add it as an **optional official-image card** for the
nearest radiometric station (option 1), not as a fake numeric series. Needs a product decision
before building — flagged in BACKLOG, not implemented in this batch.
