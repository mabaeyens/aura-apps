# Battery

An assessment of Aura's energy cost on iPhone and Apple Watch, and the guardrails that
keep it low. The short version: there is **no always-on work** — no timers, no background
refresh, no animation, no continuous location. Everything is one-shot and event-driven,
so the app costs energy only while it's on screen or when the OS chooses to refresh a
widget. On-device numbers still need capturing (see the last section); this documents the
design that makes those numbers small.

## What does work, and when

| Work | Trigger | Cadence | Cost |
|------|---------|---------|------|
| App forecast refresh | "Hoy" appears / app foregrounds | throttled to **once per 15 min** per location; pull-to-refresh forces | one burst of network, then idle |
| AEMET staleness skip | any refresh | a location cached **< 1 h** is not re-fetched (unless forced) | avoids repeat bursts |
| Widget timeline | WidgetKit | reload **every 3 h** (`.after(+3h)`) | one snapshot render |
| Complication timeline | ClockKit/WidgetKit | reload **every 2 h** (`.after(+2h)`) | one snapshot render |
| Watch sync | after a successful app refresh | one `updateApplicationContext` | coalesced, OS-scheduled |
| Location | adding/using "current location" | `requestLocation()` **one-shot**, `kCLLocationAccuracyKilometer` | coarse, no GPS fix, no tracking |
| Radar frame | radar card shown | **10-min** disk cache | at most one image / 10 min |
| News (RTVE + AEMET) | "Hoy" refresh | **30-min** disk cache, separate hosts | at most one fetch / 30 min |

### Network burst, per refresh
A cold three-location refresh is roughly: ~13 AEMET calls for the primary location, +4
per extra location, plus one national observations call, UV, and avisos — paced by the
Phase-A `RequestPacer` (≤45 calls / rolling 60 s) with 429 backoff. Air-quality components
and news hit **separate hosts** (MITECO backend, RTVE) and don't count against the AEMET
budget. After the burst the app is idle — it does not poll.

## Why it's low

- **No timers.** No `Timer`, no `TimelineView(.animation)`, no `.repeatForever`, no
  `withAnimation` in the render path. The sky — including the Phase-F sun/moon disc — is
  drawn **once per render** from the `now` passed in; the light's position is a
  calculation, not an animation. Recomputed on appearance and on sync, nothing in between.
- **No background execution.** No `BGTaskScheduler`, no background app refresh, no
  background location. The widget/complication timelines are the only OS-scheduled work,
  and they're snapshots, not live views.
- **Coalesced watch sync.** `updateApplicationContext` replaces any pending payload and is
  delivered by the OS when convenient — not a live `sendMessage`, so it never keeps the
  radio up or wakes the watch on a schedule.
- **Coarse, one-shot location.** Kilometre accuracy with `requestLocation()` — no GPS
  lock, no continuous updates, no background authorization requested.

## Guardrails for new work

Keep these true so the baseline doesn't drift:

- [ ] No `Timer` / `TimelineView(.animation)` / `.repeatForever` in any render path.
- [ ] Scene and complication geometry stays **static per render** — position from `now`,
      never a running animation (this covers the Phase-B wind rose and the Phase-F disc).
- [ ] No `BGTaskScheduler` / background app refresh / background location added without a
      deliberate battery review.
- [ ] Watch stays on `updateApplicationContext` (coalesced), not live `sendMessage`, for
      routine data.
- [ ] New network sources are cached with a sensible TTL and, if on a non-AEMET host, kept
      off the AEMET pacer only because they're genuinely a different domain.

## Measuring on device (needs hands + hardware)

Can't be done from code — capture these when I get a chance:

1. **Xcode → Debug Navigator → Energy gauge** during a foreground "Hoy" session (watch for
   anything above "Low" while idle — there should be nothing).
2. **Instruments → Energy Log** across a refresh + a few minutes idle, iPhone and Watch.
3. **Settings → Battery** per-app breakdown after a normal day of real use, both devices.

Expectation: near-zero background attribution, a small foreground cost dominated by the
network burst and the screen itself.
