# Aura — planning conversation (record)

A faithful record of the planning session that created Aura, so the reasoning behind every decision lives in the repo. Turns are labelled **Me** (the owner) and **Claude**. Dated 2026-08-19.

> **Historical — superseded by `BACKLOG.md`.** This is the origin conversation, kept verbatim. Some early intentions here were later dropped (Home Screen / StandBy / Mac widgets, per-metric widget configuration); the shipped shape is Lock Screen + Watch complication plus the app's "Hoy" card stack. Read this for the *why*, not the current state.

---

## 1. The idea

**Me:** I want to start a new project — an iOS app that exposes widgets and Apple Watch complications from AEMET (the Spanish National Weather Agency) data. AEMET has a native app, but it's iPhone/iPad only, no Watch support, and a small widget set. Personal use; I have an API key.

My rough notes:
- Complications app based on AEMET endpoints (mind rate limits / account limits).
- Beautiful complications.
- iOS/iPadOS/macOS Lock Screen widgets.
- From location data and fixed chosen locations. Spain only.
- Complications wanted: weather icons; forecast min/max temp; observed temp & conditions; humidity; rain; sun position (official Spanish source, not AEMET); sunrise/sunset (same); observed wind.
- Want a four-letter name like Mira / Vera — play with Latin, Greek, weather, tiempo, meteorología, Spanish.

**Claude:** Researched the AEMET API first. Key facts that shaped everything: 50 req/min limit, a two-call model (request → temporary `datos` URL → fetch it = 2 calls per reading), API key tied to email and valid only 3 months, `estadoCielo` pictogram codes for icons. Sun data: neither ROA nor the OAN expose a clean API — they publish tables — but the values are deterministic and computable on-device. Presented a phased plan built around a shared caching layer.

## 2. Name and fetch architecture

**Claude asked two questions.**
- **Name → Aura** (Latin/Greek for breeze/air; four letters, -a ending like Mira/Vera).
- **Fetch → on-device hub** (free): the iPhone fetches, shares to widgets + Watch via App Group cache and WatchConnectivity; no backend, key stays on-device. Trade-off accepted: the Watch shows last-synced data when away from the phone with no signal.

## 3. Six refinements

**Me:**
1. Location comes from the widget/complication's own location (iPhone + Watch). Abroad = no data, expected.
2. Refresh on AEMET's cadence (1h/4h), not live. Say if it needs background permissions.
3. No connection → show last cached values.
4. Icons: clean, legible, colorful — red hot / blue cold, sun yellow, clouds white–grey by condition.
5. Observed vs forecasted are separate options (temp now vs day min/max; same for wind, rain).
6. Wind needs a direction graphic + Spanish rose (N, S, E, O and composites like ONO, NNE...).

**Claude:**
- Confirmed all six. Refresh needs two one-time permission toggles: **Background App Refresh** and **widget location access**.
- Raised the one hard platform constraint: **full color only renders on Home Screen / StandBy / Mac widgets and color-capable watch faces. Lock Screen widgets and many Watch complication slots are forced monochrome by the OS.** Design rule: every glyph must read in one flat tint and in full color; temperature-hue is a bonus where allowed.
- Gaps surfaced: units (°C, km/h, mm, %); AEMET attribution ("Elaborado con datos de AEMET"); reuse the `mabaeyens` dev team / TestFlight.

## 4. Language and extra data

**Me:** UI **Spanish only**. Include AEMET **weather warnings (avisos)** and **UV index**.

**Claude:** Locked in; avisos + UV land in Phase 2.5.

## 5. Two more decisions

**Me:** Does the OAN provide the formula for sun times? Else just show the times. Also — important: there must be an option to read the forecast **as issued officially by AEMET** for the location I'm watching. Start Phase 0; create the repo (public); no "co-authored-by" in commits (README credits instead).

**Claude:**
- OAN has no special formula/API — standard ephemerides. Compute on-device with NOAA/Meeus (matches OAN to the minute) and just show the times.
- Added the **official AEMET forecast-text screen** as a first-class Phase 1 feature.
- Built Phase 0 and created the repo.

## 6. Phase 0 built

**Claude:** Scaffolded `aura-apps` and the `AuraKit` Swift package:
- `AEMETClient` — two-call model + ISO-8859-1 payload handling + rate-limit signalling.
- `WindDirection` — 16-point Spanish rose (N…NNO) with names, abbreviations, bearings.
- `SolarTimes` — NOAA sunrise/sunset, offline.
- `aura-smoke` executable + 7 unit tests (all passing). `swift build` clean.
- Public repo created: **mabaeyens/aura-apps**, Phase 0 committed and pushed.

## 7. Widgets & complications interview

**Claude** ran a design interview. **Me:** support all four watch shapes (circular, rectangular, inline, corner); plan for both single-metric and rich combos, scaling by space; tiny circular slot = icon + temp together; Home Screen / Mac = rich all-in-one card. Then attached two reference watch faces (Modular Ultra + California Ultra) and named the style anchors: **Apple Weather** (clean), **new AEMET app** (simple), **Carrot Weather** (customizable). Aura replaces my Carrot family subscription.

**Claude** read the faces back element by element (temp gauge with min/max range, hourly strip, wind rose + bearing°, UV gauge, precip-probability gauge, sun + daylight-remaining, avisos) and wrote the full spec to `docs/WIDGETS.md`, with per-shape layouts, color scales, and the hard requirement that every surface be App-Intent-configurable (location + metric choice).

---

## Where this leaves us

- **Repo:** mabaeyens/aura-apps (public). Plan → `docs/PLAN.md`; widget spec → `docs/WIDGETS.md`.
- **Phase 0:** foundations built, unit-tested, pushed. Live smoke test against the real API is the last verification step.
- **Next — Phase 1:** iOS app shell (locations + favorites) and the official AEMET forecast-text screen.

See `docs/PLAN.md` and `docs/WIDGETS.md` for the durable specs.
