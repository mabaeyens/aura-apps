# Sharing fetched forecasts across my devices via iCloud

## Why I'm writing this

I run Aura on four devices — iPhone, iPad and Mac, and Apple Watch — and each one that
can reach the network fetches from AEMET on its own schedule. That means up to
three independent bursts of requests against my AEMET key for the *same*
forecast, for the *same* saved locations. AEMET rate-limits per key, so this is
pure waste: three devices, one weather. I want one device's fetch to serve the
others, the same way the Watch already rides on the iPhone's fetch today.

This note captures the current data-sharing architecture, which iCloud option
fits, the size and staleness trade-offs, and exactly what I have to set up by
hand (entitlements/provisioning) before any of it can ship. No iCloud code has
landed yet — it needs an entitlement I can't add headless — so this is a design
note plus a marked TODO, not an implementation.

## Current architecture (what's already here)

- **`SharedCache`** (`Sources/AuraKit/SharedCache.swift`) — an App Group cache
  (`group.com.mab.Aura`) that stores `snapshots.json`, one `WeatherSnapshot` per
  location (`upsert` dedupes by INE code, newest write wins). It's **device-local**:
  the App Group is shared between the app and its widgets/complication *on the
  same device*, not across devices. I just added `prune(...)` so it can't grow
  unbounded as favourites come and go.
- **`AEMETService.refreshAllForWidgets`** (`Aura/AEMETService.swift`) — the single,
  *coalesced* fetch path. If a refresh is already running, every other caller
  awaits that same run, so a cold launch never fires two or three overlapping
  bursts. This coalescing is *within one device only.*
- **`WatchSync`** (`Sources/AuraKit/WatchSync.swift`) — the existing cross-device
  seam, but only iPhone → Watch. The phone encodes the primary snapshot and pushes
  it via `WCSession.updateApplicationContext` (system-coalesced: only the newest
  survives). The Watch writes it into its *own* App Group cache. There's a nice
  guard there already: a "thin" snapshot (hourly fetch came back empty, current-hour
  fields nil) is not allowed to overwrite a good one for the same location.

So the pattern to extend is clear: **one device fetches, others consume a pushed
snapshot instead of hitting AEMET.** WatchConnectivity only bridges iPhone↔Watch;
iCloud is the natural bridge to the iPad (and back to the iPhone).

## Which iCloud option fits: KVS vs CloudKit

### NSUbiquitousKeyValueStore (key-value store) — my recommendation

Best fit for this payload. It's a tiny iCloud-backed key/value store that syncs
automatically in the background and posts
`didChangeExternallyNotification` when another device writes.

- **Budget:** 1 MB total, up to 1024 keys, 1 MB per value. A `WeatherSnapshot`
  encoded as JSON is small — roughly 3–8 KB (7 `DaySnapshot`s, ~24 `HourSlot`s, a
  short bulletin string; no image bytes — radar frames are deliberately kept out of
  the snapshot). Even a dozen saved locations at the top of the range is well under
  100 KB, comfortably inside the 1 MB ceiling.
- **Keying:** one key per INE, e.g. `snapshot.<INE>`, value = the same ISO-8601
  JSON `SharedCache` already encodes. That maps cleanly onto the existing
  `upsert`/`snapshot(forINE:)` shape.
- **Semantics:** last-writer-wins per key, background sync, no schema, no records,
  no subscriptions. Exactly the "latest value only" model a forecast wants — I never
  need history.
- **Cost:** minimal — reuse the existing `JSONEncoder`/`Decoder` and mirror writes.

### CloudKit — overkill here, keep in reserve

CloudKit (private database) is the right tool only if the payload outgrows KVS:
if I ever want to sync **radar image frames** across devices (hundreds of KB to MB
each — these already live outside the snapshot for exactly this reason), keep a
**history** of snapshots, or push server-driven updates. It brings record types,
`CKRecord`/`CKAsset`, subscriptions, conflict handling, and more provisioning.
None of that is justified by a 3–8 KB text snapshot. **Decision: KVS now; revisit
CloudKit only if radar or history sync becomes a goal.**

## Staleness & coalescing strategy (cross-device)

The point is to avoid three devices all fetching. Proposed rules, mirroring the
one-hour freshness window `refreshAllForWidgets` already uses:

1. **Read iCloud before fetching.** In the freshness check inside `performRefresh`,
   before deciding a location is "stale", also consult the iCloud KVS copy. If
   another device wrote a snapshot for that INE within the last hour (its
   `updated` date), adopt it into the local `SharedCache` and **skip the AEMET
   call.** This is the whole win.
2. **Write iCloud after fetching.** Whenever this device does fetch, mirror each
   fresh snapshot into KVS (`store.set(data, forKey: "snapshot.<INE>")`), so the
   other devices can adopt it.
3. **React to remote writes.** Observe `didChangeExternallyNotification`; on a
   remote change, decode and `upsert` into `SharedCache`, reload widget timelines,
   and post the existing `WatchSync.snapshotDidUpdate`-style nudge so open views
   re-read. Reuse the **thin-snapshot guard** from `WatchSync.cache(...)` verbatim
   so an incoming thin snapshot never clobbers good current-hour data.
4. **Keep it last-writer-wins.** No merge logic — a forecast is a whole-object
   replacement per INE, and `updated` breaks ties.
5. **Don't fight the existing coalescer.** The in-device coalescing gate stays; the
   iCloud check just short-circuits the *network* step for locations another device
   already refreshed. The Watch keeps getting its push from the iPhone as today
   (WatchConnectivity is faster and works when the Watch is off-Wi-Fi).

Net effect: the first device to wake and refresh within any hour pays the AEMET
cost; the others read the KVS copy and stay silent. Three devices collapse toward
one set of requests per hour instead of three.

## Entitlements / provisioning I must do by hand

This is the part that can't be done headless — it needs my Apple Developer account
and Xcode signing:

1. **App Store Connect / Developer portal:** enable the **iCloud** capability for
   the `Aura` App ID, with **Key-Value storage** turned on. (If I ever go
   CloudKit, also create the container there.)
2. **Xcode → Aura target → Signing & Capabilities:** add the **iCloud** capability
   and tick **Key-value storage**. This makes Xcode add
   `com.apple.developer.ubiquity-kvstore-identifier` to `Aura/Aura.entitlements`
   (today that file only holds `application-groups`). The value is normally
   `$(TeamIdentifierPrefix)$(CFBundleIdentifier)`.
3. **iPad target:** the iPad runs the same app, so it inherits the capability — just
   confirm the iPad build uses the same signing/provisioning profile with iCloud
   enabled.
4. **Watch:** leave as-is. The Watch keeps receiving via WatchConnectivity from the
   iPhone; it doesn't need its own iCloud KVS entitlement for this design.
5. **Regenerate provisioning profiles** after enabling the capability (Xcode's
   automatic signing handles this, but verify the profiles list iCloud).
6. **Same iCloud account** on all devices (already true for me) — KVS is scoped to
   the signed-in Apple Account, so this only ever shares *my own* forecasts across
   *my own* devices. Nothing leaves my account.

## TODO (blocked on the entitlement above)

- [ ] Enable iCloud Key-Value storage capability + entitlement (manual, steps above).
- [ ] Add an `ICloudForecastStore` in `AuraKit` wrapping `NSUbiquitousKeyValueStore`:
      `set(_:forINE:)`, `snapshot(forINE:)`, and a `didChangeExternally` observer that
      upserts into `SharedCache` (reusing the thin-snapshot guard).
- [ ] Hook the iCloud read into the freshness check in `AEMETService.performRefresh`
      (skip the AEMET call when a fresh remote snapshot exists) and mirror every
      fetched snapshot out to iCloud.
- [ ] Verify on two devices that device B skips the network when device A refreshed
      within the hour, and that widgets/complication update on the remote-change nudge.

Until the entitlement is in place I've deliberately shipped **no** iCloud code —
adding `NSUbiquitousKeyValueStore` calls without the entitlement would compile but
silently no-op at runtime, which is worse than not having it.
