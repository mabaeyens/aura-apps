#!/usr/bin/env bash
set -euo pipefail

# App Store screenshot capture for Aura.
#
# Renders the app at chosen times of day and sky conditions using the DEBUG-only overrides in
# Aura/ScreenshotSupport.swift (AURA_FAKE_DATE / AURA_FAKE_SKY), driven through the simulator. simctl
# forwards any env var prefixed with SIMCTL_CHILD_ into the launched app, which is how the overrides
# reach ProcessInfo. It is not faking the UI: the same render runs with a chosen instant and sky, so each
# frame is exactly what the device would show then.
#
# PREREQUISITE (yours to set up — it involves your AEMET key, which this script never touches):
#   Run Aura once normally on each target simulator first, add a location and enter a valid AEMET API
#   key, and let it load. The overrides only re-time and re-skin the already-loaded snapshot; with no
#   cached snapshot there is nothing to render.
#
# Usage:  scripts/screenshots.sh           # builds Debug, installs, captures the whole matrix
#         OUT_DIR=~/Desktop/aura scripts/screenshots.sh
#
# Output: OUT_DIR/<device>/<time>_<sky>.png

SCHEME="Aura"
BUNDLE_ID="com.mab.Aura"
CONFIG="Debug"                                   # Debug so the #if DEBUG overrides are compiled in
OUT_DIR="${OUT_DIR:-screenshots}"
DERIVED="${DERIVED:-build/screenshots-dd}"
SETTLE="${SETTLE:-5}"                            # seconds to let the app load + render before the shot

# Simulator device names (must appear in `xcrun simctl list devices available`).
DEVICES=(
  "iPhone 16 Pro Max"
  "iPad Pro 13-inch (M4)"
)

# label : local ISO instant. Pick a real clear-sky day for your location; the sun sits by true
# sunrise/sunset, so use times that fall in each band for that day.
TIMES=(
  "morning:2026-08-22T08:30:00"
  "noon:2026-08-22T13:30:00"
  "sunset:2026-08-22T20:45:00"
  "night:2026-08-22T23:30:00"
)

# label : AEMET sky code, one per veil (see ScreenshotSupport.swift). Trim this list to what you want.
SKIES=(
  "clear:11"
  "cloudy:14"
  "rain:23"
)

say() { printf '\033[1;36m▸ %s\033[0m\n' "$*"; }

udid_for() {  # device name -> booted/available udid
  xcrun simctl list devices available | sed -n "s/.*${1} (\([0-9A-F-]\{36\}\)).*/\1/p" | head -1
}

say "Building $SCHEME ($CONFIG) for the simulator…"
xcodebuild -scheme "$SCHEME" -configuration "$CONFIG" \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  build >/dev/null

APP_PATH="$DERIVED/Build/Products/${CONFIG}-iphonesimulator/${SCHEME}.app"
[ -d "$APP_PATH" ] || { echo "Build product not found at $APP_PATH" >&2; exit 1; }
say "Built: $APP_PATH"

for device in "${DEVICES[@]}"; do
  udid="$(udid_for "$device")"
  [ -n "$udid" ] || { echo "!! No available simulator named '$device' — skipping." >&2; continue; }
  say "Device: $device ($udid)"

  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  xcrun simctl install "$udid" "$APP_PATH"

  dev_out="$OUT_DIR/${device// /_}"
  mkdir -p "$dev_out"

  for t in "${TIMES[@]}"; do
    tlabel="${t%%:*}"; tdate="${t#*:}"
    for s in "${SKIES[@]}"; do
      slabel="${s%%:*}"; scode="${s#*:}"
      xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
      SIMCTL_CHILD_AURA_FAKE_DATE="$tdate" \
      SIMCTL_CHILD_AURA_FAKE_SKY="$scode" \
        xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
      sleep "$SETTLE"
      out="$dev_out/${tlabel}_${slabel}.png"
      xcrun simctl io "$udid" screenshot "$out" >/dev/null
      say "  $tlabel / $slabel  →  $out"
    done
  done
done

say "Done. Screenshots in: $OUT_DIR"
