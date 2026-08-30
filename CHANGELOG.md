# Changelog

## v1.2.0 (build 8)

- Two new cards on iPhone and iPad, drawn from AEMET's national products: a surface analysis map with isobars, pressure centres and fronts (pinch to zoom, with a legend), and the national text forecast written by AEMET's forecasters, with today on the card and the next four days a tap away.
- The whole interface now follows your device language. On a non-Spanish device the app, the widget setup and the Watch read in English, while the forecast itself keeps AEMET's own Spanish wording.
- Current conditions are worked out the moment you look, so a reading cached yesterday no longer shows yesterday's weather. The fix now covers the Lock Screen and the Watch complications too, and the big current temperature is always the forecast for the current hour, never the day's high by mistake.
- The nearest-station card only appears when its reading is genuinely recent, judged by the station's own timestamp and AEMET's publish marker rather than a fixed timer, and its metric tiles now share one height.
- Widgets show a small staleness marker when their cached data is old, refresh their own location when it goes stale, and recover a location that had been stuck with no reading.
- A new help page explains how fresh each reading is and when it refreshes.
- Steadier refreshing: gentler pull-to-refresh throttling, clearer wording when AEMET's rate limit is hit, and observed-temperature rounding pinned to the same result across iPhone and Android.

## v1.1.1 (build 7)

- Fixed the current conditions on the Hoy screen sometimes showing the day's high instead of the real current temperature, with a sky description that could lag a day behind. The current hour now reads correctly, and a good reading is kept when a refresh comes back empty.
- Station and air-quality values now render at one consistent size, so a longer number no longer looks smaller than the one next to it.
- The Watch wind complication now colours the speed number by wind strength, on the same Beaufort scale as the vane beside it.
- The About screen now names the open-data sources (AEMET, MITECO, Copernicus) with links, and states plainly that Aura is an independent app that does not represent any government entity.

## v1.1.0 (build 6)

- Dynamic Type: the app's text now scales with the system Larger Text setting, keeping the tuned look.
- Tapping a widget now opens the exact location it shows.
- Apple Watch: full complication coverage across every accessory family (circular, corner, rectangular and inline) for UV, rain, wind, sun, air quality and avisos, plus daily máximas and mínimas.
- A station card with the real observed values from the nearest AEMET station.
- Smaller download: the bundled background art is about 58% lighter.
- Security: the AEMET key no longer persists to the disk cache, and the Keychain item is pinned to this device.
- Available in more countries, with an English-optimised App Store listing.

## v1.0.0

First release of Aura: Spain's weather, from official AEMET open data.

- Per-municipality forecast: sky, temperature, wind, UV index (with the day's sun-protection window), chance of rain and humidity.
- A narrated daily forecast, drawn from AEMET's official text.
- Hour-by-hour detail and a full seven-day outlook.
- A 24-hour or 12-hour time format, chosen once and applied everywhere: the app, the widgets and the watch.
- Air quality by pollutant, from the official network (MITECO / ICA).
- Sun and moon: sunrise and sunset with first and last light, solar noon and day length, and moonrise and moonset.
- Official weather warnings (avisos) when they matter, and a calm all-clear when there are none.
- A living background that follows the sun across the day, from dawn to dusk.
- An Apple Watch app with the same cards as on iPhone, plus a full complication catalog
  (temperature, wind, UV, rain, humidity, sun, hours, days and avisos) across the circular,
  corner, rectangular and inline slots. The aviso complication shows a calm struck-out marker
  when there is no active warning, instead of an "open Aura" placeholder.
- Home Screen and Lock Screen widgets, configurable by location and a Nature / City scene.
- A brief first-run intro that explains the free AEMET key and where the widgets live, with a skip.
- Runs on iPhone, iPad and Mac.
