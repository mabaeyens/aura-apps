# Apple Watch app + complication

The Watch surface is a full part of the project: two targets, `AuraWatch` (the watchOS app) and
`AuraWatchComplication` (its widget/complication extension), both rendering from the shared `AuraKit`
so the complication is identical to the iPhone Lock Screen widgets.

## Targets & layout

- **`AuraWatch/`** — `AuraWatchApp.swift` (the `@main` app; calls `WatchSync.activate()`),
  `WatchRootView.swift` (reads the latest snapshot from `SharedCache` and renders the full shared
  `AuraForecastStack` at `.watch` size over `AuraSky` — the same cards, in the same order, as the
  iPhone's "Hoy" screen, resized to the wrist), `Info.plist`
  (`WKApplication`, `WKCompanionAppBundleIdentifier = com.mab.Aura`), `AuraWatch.entitlements`
  (App Group `group.com.mab.Aura`). Bundle id `com.mab.Aura.watchkitapp`.
- **`AuraWatchComplication/`** — `AuraComplicationBundle.swift` (`@main` bundle),
  `AuraComplication.swift` (the timeline provider + `StaticConfiguration` widget covering
  `.accessoryCircular / .accessoryRectangular / .accessoryInline / .accessoryCorner`),
  `Info.plist`, `AuraWatchComplication.entitlements`. Bundle id
  `com.mab.Aura.watchkitapp.complication`, embedded in `AuraWatch`.

Both are watchOS 10.0, `SWIFT_VERSION = 5.0`, team `HTVGRBVW58`, matching the other targets and
`AuraKit`'s `watchOS(.v10)`.

## Building

Building the **`Aura`** scheme builds and embeds the Watch app + complication automatically. Let each
target use its own SDK — build with `-destination` only, **never** `-sdk`, which forces one SDK onto
every target and makes the watch extension try to link the iOS build of `AuraKit`:

```bash
# builds iOS app + widget + watch app + complication
xcodebuild -project Aura.xcodeproj -scheme Aura \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build

# or the watch app on its own
xcodebuild -project Aura.xcodeproj -scheme AuraWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)' build
```

## Running to a physical watch

1. Select the **`AuraWatch`** scheme and your watch as the destination. Building to it the first time
   is what makes watchOS surface the **Developer Mode** toggle (Settings ▸ Privacy & Security ▸
   Developer Mode) — it stays hidden until an Xcode build has targeted the watch. Enable it and let
   the watch restart.
2. The "connect on demand" pairing dialog is normal — keep the watch unlocked and near the Mac.
3. Open Aura on the iPhone once so it fetches and pushes a snapshot; the watch app shows it, and the
   complication becomes available in the watch-face gallery under *El tiempo*.

## Data flow (no backend, mirrors the iPhone architecture)

```
iPhone: fetch → WeatherSnapshot → SharedCache (phone)   ──WatchSync.send──▶
Watch:  WatchSync receives → SharedCache (watch) → complication reads it → reload
```

`SharedCache` is device-local, so the watch keeps its own copy of the App Group cache; `WatchSync`
(WatchConnectivity `updateApplicationContext`) is the only thing that crosses between the two devices.
