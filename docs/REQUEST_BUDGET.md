# AEMET request budget per platform

How many AEMET requests each Aura surface makes on a refresh, and where the cost concentrates. Written 2026-08-29, after shipping the national text forecast card (commit a103cf7).

## Model

AEMET's OpenData API is a two-step model: every product is an envelope call (returns a temporary `datos` URL) followed by the `datos` download. Both go through `AEMETClient.perform`, so **one product costs 2 HTTP requests** and both count against `RequestPacer` (sliding window, 45 requests / 60 s, sitting under AEMET's 50/min per-key cap). Exceptions: the observation RSS notifier is a single keyless GET, and MITECO air quality is a separate host that never touches the AEMET budget.

## Per platform (cold refresh, one primary location, quiet day)

| Platform | How it fetches | Cold HTTP |
|---|---|---|
| Watch | Zero AEMET calls. Snapshots arrive from the phone over WatchConnectivity (`WatchSync`); the Watch reads its own `SharedCache`. | 0 |
| Widget | Shared `AuraRefreshCore.refresh(onlyINE:)`, single location, only when `isStale`. No radar, surface or national. | ~14 (7 products) |
| iPhone | Full `AuraRefreshCore` plus the iOS-only radar, surface map and national text. | ~23 |

## iPhone breakdown

Shared core, ~15 HTTP:

- Observation RSS notifier: 1 (keyless)
- `observacionTodas`: 2 (gated on the RSS publish marker)
- `uviCities(dia:0)`: 2
- `avisos(area:)`: 2 per distinct area (one area for one location)
- `comunidadBulletin`: 4 on a quiet day (`hoy` is amendment-only and stale, so `manana` also fires)
- `municipioDiaria` + `municipioHoraria`: 4

iOS-only extras, ~8 HTTP:

- Radar: 2, on demand, cached in `RadarService`
- Surface analysis map: 2, gated 12 h
- National text (new): 4 on a quiet day (`hoy` stale, `manana` fallback), gated 6 h

Add ~4 HTTP per extra favorite location (its `municipioDiaria` + `municipioHoraria`), plus a handful of POSTs per location to MITECO for the air-quality breakdown on its own host.

Warm refreshes are far cheaper: surface and national are skipped inside their gates, radar is cached, and the observation download only fires when the RSS marker has advanced. The full ~23 only lands on the first cold refresh in each window.

## Where the cost concentrates

On a quiet day the app runs two amendment-fallback pairs for prose alone: `comunidadBulletin` (hoy + manana) and `nacionalBulletin` (hoy + manana) = 8 HTTP just for narrative text, because `hoy` is always stale-dated so `manana` always fires. Everything is fetched up front on the foreground refresh, whether or not the user scrolls to the card that needs it.

## Progressive disclosure: three directions to weigh

Instead of fetching everything from everywhere on the foreground refresh, fetch the below-the-fold and secondary products only when they are about to be seen. Three shapes, to review later and not yet decided between.

### 1. Lazy per-card fetch on scroll or appear

Split the refresh into a core (hero, today/hourly, observation, avisos) that still fetches up front, and a set of secondary cards (radar, surface map, national text, air-quality breakdown) that fetch on their own `.task`/`onAppear` when the card scrolls into view. The card renders a lightweight placeholder until its own fetch lands, exactly as radar/surface/national already self-hide today.

- Saves the most on the common case where the user opens the app, reads the hero and leaves without scrolling: the ~8 HTTP of surface + national never fire.
- Costs a visible fill-in as cards appear, and needs per-card in-flight and cache state so a fast scroll does not fire duplicate fetches. The existing 6 h / 12 h disk gates already absorb most of the repeat cost.
- Watch and widget are unaffected (they never fetched these).

### 2. Tiered refresh by cadence, not by scroll

Keep fetching everything up front but split by how often each product actually changes, and let each tier own its own TTL so a foreground refresh only re-pulls the tier that is due. Fast tier (observation, hourly) on the current gate, slow tier (national text, surface map, medium range, community bulletin) on a long TTL that a normal foreground refresh usually finds fresh.

- Simplest to reason about and keeps the UI eager (no fill-in), just spends fewer requests over a session because the slow tier rarely re-fires.
- Saves less than lazy fetch on the open-and-leave case, since the slow tier still fires on a genuine cold start.
- Mostly a re-labelling of gates that already exist; low risk, moderate saving.

### 3. Collapse the narrative pairs behind one resolved fetch

Attack the 8-HTTP prose cost directly. The two amendment-fallback pairs (community and national) each spend a wasted `hoy` request that is almost always stale. Resolve narrative once: try `hoy` only when a cheap signal says an intraday amendment likely exists, otherwise go straight to `manana` and skip the `hoy` round trip. Optionally fold the community and national text behind a single "forecast in words" section that only fetches the national product when its tab is opened (the national sheet already fetches its other horizons lazily).

- Saves 2 to 4 HTTP on every cold refresh with no visible change, and composes with either option above.
- Needs a reliable "was there an amendment today" signal to avoid ever showing yesterday's `hoy`; getting that wrong reintroduces the stale-forecast bug the amendment resolve was built to prevent.
- Narrowest scope, highest confidence, smallest UI change.
