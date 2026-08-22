#!/usr/bin/env bash
set -euo pipefail

# Pin Aura to a chosen moment + sky on a running simulator, for hand-taken screenshots.
#
# Relaunches the already-installed app with the DEBUG-only overrides from Aura/ScreenshotSupport.swift
# (AURA_FAKE_DATE / AURA_FAKE_SKY), forwarded through simctl's SIMCTL_CHILD_ mechanism. It re-times and
# re-skins the snapshot the app already loaded — so add a location and a valid AEMET key once per
# simulator first (this script never touches the key), then pin away and grab each frame from the
# Simulator window (Cmd-S) or with:  scripts/pin.sh … --shot out.png
#
# Usage:
#   scripts/pin.sh <device> <moment> <sky> [--shot PATH]
#
#   <device>  iphone | ipad   (or any substring of a booted simulator's name)
#   <moment>  a preset label (dawn|morning|noon|sunset|dusk|night) or a raw ISO instant
#             like 2026-08-22T08:30:00. Presets use today's date at a representative hour.
#   <sky>     a preset label (clear|few|cloudy|overcast|rain|storm|snow|fog) or a raw AEMET code.
#
# Examples:
#   scripts/pin.sh ipad noon clear
#   scripts/pin.sh iphone sunset rain
#   scripts/pin.sh ipad 2026-12-21T17:15:00 snow --shot ~/Desktop/winter.png

BUNDLE_ID="com.mab.Aura"
SETTLE="${SETTLE:-4}"
TODAY="${PIN_DATE:-2026-08-22}"   # override with PIN_DATE=YYYY-MM-DD for a different day/season

usage() { sed -n '3,25p' "$0"; exit 1; }
[ "$#" -ge 3 ] || usage

DEVICE_ARG="$1"; MOMENT="$2"; SKY="$3"; shift 3
SHOT=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --shot) SHOT="${2:?--shot needs a path}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

# Resolve a friendly device word to a booted simulator UDID + name.
resolve_device() {
  local q="$1"
  case "$q" in
    iphone|iPhone) q="iPhone" ;;
    ipad|iPad)     q="iPad" ;;
  esac
  xcrun simctl list devices booted \
    | grep -i "$q" \
    | sed -n 's/.*(\([0-9A-Fa-f-]\{36\}\)).*/\1/p' | head -1
}

# Preset moment label -> local ISO instant (today at a representative hour for that band).
moment_iso() {
  case "$1" in
    dawn)    echo "${TODAY}T07:15:00" ;;
    morning) echo "${TODAY}T09:30:00" ;;
    noon)    echo "${TODAY}T13:30:00" ;;
    sunset)  echo "${TODAY}T20:45:00" ;;
    dusk)    echo "${TODAY}T21:15:00" ;;
    night)   echo "${TODAY}T23:30:00" ;;
    *)       echo "$1" ;;   # assume it's already an ISO instant
  esac
}

# Preset sky label -> AEMET sky code (see ScreenshotSupport.swift / Palette.sky mapping).
sky_code() {
  case "$1" in
    clear)    echo 11 ;;
    few)      echo 13 ;;
    cloudy)   echo 14 ;;
    overcast) echo 16 ;;
    rain)     echo 23 ;;
    storm)    echo 51 ;;
    snow)     echo 33 ;;
    fog)      echo 81 ;;
    *)        echo "$1" ;;  # assume it's already a numeric code
  esac
}

UDID="$(resolve_device "$DEVICE_ARG")"
[ -n "$UDID" ] || { echo "No booted simulator matches '$DEVICE_ARG'. Booted:" >&2; \
  xcrun simctl list devices booted >&2; exit 1; }

ISO="$(moment_iso "$MOMENT")"
CODE="$(sky_code "$SKY")"

xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
SIMCTL_CHILD_AURA_FAKE_DATE="$ISO" \
SIMCTL_CHILD_AURA_FAKE_SKY="$CODE" \
  xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null

printf '\033[1;36m▸ pinned\033[0m %s → %s / sky %s\n' "$DEVICE_ARG" "$ISO" "$CODE"

if [ -n "$SHOT" ]; then
  sleep "$SETTLE"
  xcrun simctl io "$UDID" screenshot "$SHOT" >/dev/null
  printf '\033[1;36m▸ saved\033[0m %s\n' "$SHOT"
fi
