# Apple Watch app + complication — wiring guide

The Watch code is written and lives in the repo; only the two Xcode targets still need creating.
Xcode's target wizard generates the fiddly parts (Info.plist keys, embed phases, companion-app
pairing) correctly, so use it rather than hand-editing `project.pbxproj`.

## What already exists

- **Shared (AuraKit, built and tested):**
  - `WatchSync` — the iPhone↔Watch bridge over WatchConnectivity. The phone calls `send(_:)` after
    each refresh (already wired in `TodayView`); the Watch calls `activate()` and receives.
  - `AuraAccessoryCircular/Rectangular/Inline/Corner` — the complication layouts, identical to the
    iPhone Lock Screen widgets.
- **Staged source (in the repo, not yet in any target):**
  - `AuraWatch/` — `AuraWatchApp.swift`, `WatchRootView.swift`, `AuraWatch.entitlements`.
  - `AuraWatchComplication/` — `AuraComplicationBundle.swift`, `AuraComplication.swift`,
    `Info.plist`, `AuraWatchComplication.entitlements`.

## Steps

1. **Add the Watch App target.** File ▸ New ▸ Target ▸ **watchOS ▸ App**.
   - Product name `AuraWatch`, bundle id `com.mab.Aura.watchkitapp`, language Swift, interface
     SwiftUI. When asked, set the companion (iOS) app to **Aura** — the wizard fills in
     `WKCompanionAppBundleIdentifier = com.mab.Aura` and adds the *Embed Watch Content* phase to the
     iOS app.
   - Delete the wizard's generated `ContentView.swift` / `*App.swift`, then add the files from
     `AuraWatch/` to this target. Set its **App Group** capability to `group.com.mab.Aura` (use the
     staged `AuraWatch.entitlements`).
   - Add **AuraKit** to the target's *Frameworks, Libraries, and Embedded Content*.

2. **Add the complication (Widget Extension) target.** File ▸ New ▸ Target ▸ **watchOS ▸ Widget
   Extension**, name `AuraWatchComplication`, bundle id `com.mab.Aura.watchkitapp.complication`.
   - Embed it in **AuraWatch** (not the iOS app). The wizard adds the *Embed Foundation Extensions*
     phase to the Watch app.
   - Replace the generated sources with the files from `AuraWatchComplication/`, set the App Group
     to `group.com.mab.Aura`, and add **AuraKit** to its frameworks.

3. **Deployment + Swift version.** Set both targets to **watchOS 10.0** and `SWIFT_VERSION = 5.0`
   (matching the other targets and AuraKit's `watchOS(.v10)`).

4. **Build & run.** Select the `AuraWatch` scheme on a paired Watch simulator. Open Aura on the
   iPhone once so it pushes a snapshot; the Watch app shows it, and the complication is then
   available in the watch-face gallery under *El tiempo*.

## Data flow (no backend, mirrors the iPhone architecture)

```
iPhone: fetch → WeatherSnapshot → SharedCache (phone)   ──WatchSync.send──▶
Watch:  WatchSync receives → SharedCache (watch) → complication reads it → reload
```

`SharedCache` is device-local, so the Watch keeps its own copy of the App Group cache; `WatchSync`
is the only thing that crosses between devices.
