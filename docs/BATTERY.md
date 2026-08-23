# Battery

An assessment of Aura's energy cost on iPhone and Apple Watch, and the guardrails that keep it low. The short version: the only recurring work is one opt-in background top-up roughly every half hour, gated by the system Background App Refresh setting. There are no timers, no animation in the render path, and no continuous location. Everything is one-shot and event-driven, so the app costs energy only while it is on screen, when the OS refreshes a widget, or during that occasional background top-up. On-device numbers still need capturing (see the last section); this documents the design that keeps them small.

## What does work, and when

| Work | Trigger | Cadence | Cost |
|------|---------|---------|------|
| App forecast refresh | "Hoy" appears / app foregrounds | throttled to once per 15 min per location; pull-to-refresh forces | one burst of network, then idle |
| Background top-up | `BGAppRefreshTask`, if the system setting is on | requested every 30 min; the OS decides the real timing | one refresh, reschedules itself, then idle |
| AEMET staleness skip | any refresh | a location cached under 1 h is not re-fetched (unless forced) | avoids repeat bursts |
| Notifications | a refresh finds a new naranja/rojo aviso or an updated forecast for the active location | at most one local notification per change | negligible, no polling |
| Widget timeline | WidgetKit | reload every 3 h (`.after(+3h)`) | one snapshot render |
| Complication timeline | ClockKit/WidgetKit | reload every 2 h (`.after(+2h)`) | one snapshot render |
| Watch sync | after a successful app refresh | one `updateApplicationContext` | coalesced, OS-scheduled |
| Location | adding/using "current location" | `requestLocation()` one-shot, `kCLLocationAccuracyKilometer` | coarse, no GPS fix, no tracking |
| Radar frame | radar card shown | 10-min disk cache | at most one image per 10 min |
| News (RTVE, AEMET, Meteored, AEMET Blog) | "Hoy" refresh | 30-min disk cache, separate hosts | at most one fetch per 30 min |

### Network burst, per refresh
A cold three-location refresh is roughly: ~13 AEMET calls for the primary location, plus 4 per extra location, plus one national observations call, UV, and avisos, paced by the Phase-A `RequestPacer` (at most 45 calls per rolling 60 s) with 429 backoff. Air-quality components and news hit separate hosts (MITECO backend, RTVE) and do not count against the AEMET budget. After the burst the app is idle. A background top-up runs the same refresh, then reschedules the next one and stops.

## Background refresh and notifications

Both are opt-in and cost effectively nothing when idle.

- **Background top-up** uses one `BGAppRefreshTask` (identifier `com.mab.Aura.refresh`, `UIBackgroundModes = fetch`). The app submits a request with `earliestBeginDate` about 30 minutes out whenever it goes to the background and again at the end of each background run, so the chain continues on its own. iOS only actually runs it when the user has Background App Refresh enabled for Aura and the system judges it a good moment, so the real cadence is the OS's call, not a fixed timer. The handler runs the same coalesced refresh the foreground uses: it shows new data when there is any and leaves the cached snapshots untouched otherwise, then reloads the widgets and pushes the primary snapshot to the Watch.
- **Notifications** are local only, no push and no server. On each refresh the app compares the freshly built snapshot for the active location against the one already cached and posts a notification only when something the user asked about changed: a new naranja or rojo aviso, or an updated forecast bulletin. The comparison is also the deduplication, so a still-active aviso never re-notifies. The user chooses none, avisos only, or avisos plus forecasts in onboarding and in Ajustes. Nothing is scheduled or polled for notifications; they ride on refreshes that were going to happen anyway.

## Why it stays low

- **No timers.** No `Timer`, no `TimelineView(.animation)`, no `.repeatForever`, no `withAnimation` in the render path. The sky, including the Phase-F sun/moon disc, is drawn once per render from the `now` passed in; the light's position is a calculation, not an animation. Recomputed on appearance and on sync, nothing in between.
- **Background work is one bounded refresh.** The only background execution is the `BGAppRefreshTask`, and it is a single refresh that reschedules itself and returns. No background location, no continuous fetch. It runs solely at the OS's discretion under the user's Background App Refresh setting.
- **Coalesced watch sync.** `updateApplicationContext` replaces any pending payload and is delivered by the OS when convenient, not a live `sendMessage`, so it never keeps the radio up or wakes the watch on a schedule.
- **Coarse, one-shot location.** Kilometre accuracy with `requestLocation()`, no GPS lock, no continuous updates, no background authorization requested.

## Guardrails for new work

Keep these true so the baseline does not drift:

- [ ] No `Timer` / `TimelineView(.animation)` / `.repeatForever` in any render path.
- [ ] Scene and complication geometry stays static per render, position from `now`, never a running animation (this covers the Phase-B wind rose and the Phase-F disc).
- [ ] Background execution stays limited to the single `BGAppRefreshTask` top-up. No background location, no additional background modes, no shortening the ~30 min request cadence, without a deliberate battery review.
- [ ] Notifications stay local and change-gated (only on a genuinely new aviso or forecast for the active location). No scheduled or repeating notifications.
- [ ] Watch stays on `updateApplicationContext` (coalesced), not live `sendMessage`, for routine data.
- [ ] New network sources are cached with a sensible TTL and, if on a non-AEMET host, kept off the AEMET pacer only because they are genuinely a different domain.

## Measuring on device (needs hands and hardware)

Cannot be done from code. Capture these on a real iPhone (and Watch):

1. **Xcode, Debug Navigator, Energy gauge** during a foreground "Hoy" session (watch for anything above "Low" while idle; there should be nothing).
2. **Force a background run.** Run the app from Xcode to the device, background it, then in the debugger pause and enter:
   `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.mab.Aura.refresh"]`
   Confirm the handler runs once, refreshes, reschedules, and returns. (To simulate expiration instead, use `_simulateExpirationForTaskWithIdentifier`.)
3. **Instruments, Energy Log** across a refresh plus a few minutes idle, and across one background top-up, iPhone and Watch.
4. **Settings, Battery** per-app breakdown after a normal day of real use, both devices. Note the background attribution specifically now that the top-up exists.

Expectation: near-zero background attribution beyond the occasional bounded top-up, and a small foreground cost dominated by the network burst and the screen itself.

### Measured numbers

To be filled in once captured on device:

- [ ] Foreground idle energy (Energy gauge level):
- [ ] Energy per foreground refresh:
- [ ] Energy per background top-up:
- [ ] Settings, Battery background attribution after a day:
