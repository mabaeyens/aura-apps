#!/usr/bin/env bash
set -euo pipefail

# Pin the Apple Watch app to a chosen moment + sky (+ city/aviso) on a booted watchOS simulator,
# for hand-taken screenshots. The Watch renders from the shared App Group snapshot (SharedCache),
# NOT from launch-env overrides like the phone — a standalone watch sim isn't paired, so its cache
# starts empty and the app shows "Abre Aura en el iPhone". This script:
#
#   1. seeds the watch's group.com.mab.Aura container from the iPhone sim's real snapshots.json
#      (first run, or whenever --seed-from is passed), then
#   2. patches the first cached snapshot's moment/sky/city/aviso and relaunches the watch app.
#
# So run the iPhone once with a location + AEMET key to produce a real snapshot, then pin the watch
# off it. The patch is a screenshot aid only — it never touches the phone or the real data source.
#
# Usage:
#   scripts/pin_watch.sh <moment> <sky> [--city NAME] [--aviso LEVEL[:TEXT]|none] [--shot PATH] [--seed-from IPHONE_UDID]
#
#   <moment>  dawn|morning|noon|sunset|dusk|night, or a raw ISO instant (e.g. 2026-08-22T11:30:00Z).
#             Presets are peninsular-Spain UTC hours that read as that band on the sun arc.
#   <sky>     clear|few|cloudy|overcast|rain|storm|snow|fog, or a raw AEMET code.
#   --city    relabel the hero, e.g. "Sevilla" or "Sevilla,Sevilla" (name,provincia).
#   --aviso   inject a synthetic aviso card (amarillo|naranja|rojo[:TEXT]), or "none" to clear any.
#   --shot    also write a PNG screenshot to PATH after relaunch.
#   --seed-from  re-copy the snapshot from this iPhone sim UDID before patching (default: auto once).
#
# Examples:
#   scripts/pin_watch.sh noon clear
#   scripts/pin_watch.sh sunset rain --city "Sevilla" --shot ~/Desktop/watch_sunset.png
#   scripts/pin_watch.sh noon storm --aviso amarillo:Tormentas --shot ~/Desktop/watch_aviso.png

BUNDLE_ID="com.mab.Aura.watchkitapp"
APP_GROUP="group.com.mab.Aura"
IPHONE_BUNDLE_GROUP="group.com.mab.Aura"
SETTLE="${SETTLE:-4}"
TODAY="${PIN_DATE:-2026-08-22}"
DEVICES="$HOME/Library/Developer/CoreSimulator/Devices"

usage() { sed -n '5,33p' "$0"; exit 1; }
[ "$#" -ge 2 ] || usage

MOMENT="$1"; SKY="$2"; shift 2
SHOT=""; CITY=""; AVISO=""; SEED_FROM=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --shot)      SHOT="${2:?--shot needs a path}"; shift 2 ;;
    --city)      CITY="${2:?--city needs a name}"; shift 2 ;;
    --aviso)     AVISO="${2:?--aviso needs a level}"; shift 2 ;;
    --seed-from) SEED_FROM="${2:?--seed-from needs a UDID}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

# Find the group.com.mab.Aura container dir for a given device UDID (empty if the app isn't installed).
group_dir() {
  local udid="$1" base="$DEVICES/$1/data/Containers/Shared/AppGroup"
  [ -d "$base" ] || return 0
  local p id
  while IFS= read -r p; do
    id="$(plutil -extract MCMMetadataIdentifier raw "$p" 2>/dev/null || true)"
    if [ "$id" = "$APP_GROUP" ]; then dirname "$p"; return 0; fi
  done < <(find "$base" -maxdepth 2 -name ".com.apple.mobile_container_manager.metadata.plist" 2>/dev/null)
}

# First booted watchOS simulator (match by name — watch sims carry "Watch").
WATCH_UDID="$(xcrun simctl list devices booted | grep -i "Watch" \
  | sed -n 's/.*(\([0-9A-Fa-f-]\{36\}\)).*/\1/p' | head -1)"
[ -n "$WATCH_UDID" ] || { echo "No booted watchOS simulator. Booted:" >&2; xcrun simctl list devices booted >&2; exit 1; }

WATCH_GROUP="$(group_dir "$WATCH_UDID")"
[ -n "$WATCH_GROUP" ] || { echo "AuraWatch not installed on the booted watch ($WATCH_UDID) — install it first." >&2; exit 1; }

# Seed the watch cache from an iPhone sim when it's empty (or when --seed-from is given).
if [ -n "$SEED_FROM" ] || [ ! -f "$WATCH_GROUP/snapshots.json" ]; then
  IPHONE_UDID="$SEED_FROM"
  if [ -z "$IPHONE_UDID" ]; then
    IPHONE_UDID="$(xcrun simctl list devices booted | grep -i "iPhone" \
      | sed -n 's/.*(\([0-9A-Fa-f-]\{36\}\)).*/\1/p' | head -1)"
  fi
  [ -n "$IPHONE_UDID" ] || { echo "Watch cache is empty and no booted iPhone to seed from. Pass --seed-from UDID." >&2; exit 1; }
  IPHONE_GROUP="$(group_dir "$IPHONE_UDID")"
  [ -n "$IPHONE_GROUP" ] && [ -f "$IPHONE_GROUP/snapshots.json" ] || { echo "iPhone ($IPHONE_UDID) has no cached snapshot to seed from — run Aura on it with a location + key first." >&2; exit 1; }
  cp "$IPHONE_GROUP/snapshots.json" "$WATCH_GROUP/snapshots.json"
  cp "$IPHONE_GROUP/locations.json" "$WATCH_GROUP/locations.json" 2>/dev/null || true
  echo "▸ seeded watch cache from iPhone $IPHONE_UDID"
fi

# Patch the first cached snapshot in place.
SNAP="$WATCH_GROUP/snapshots.json" MOMENT="$MOMENT" SKY="$SKY" CITY="$CITY" AVISO="$AVISO" TODAY="$TODAY" \
python3 - <<'PY'
import json, os, sys

snap = os.environ["SNAP"]
moment = os.environ["MOMENT"]; sky = os.environ["SKY"]
city = os.environ["CITY"]; aviso = os.environ["AVISO"]; today = os.environ["TODAY"]

# Peninsular-Spain (UTC+2 summer) hours that read as each band on the sun arc; snapshot.updated is UTC 'Z'.
moment_iso = {
    "dawn":    f"{today}T05:30:00Z", "morning": f"{today}T08:00:00Z",
    "noon":    f"{today}T11:30:00Z", "sunset":  f"{today}T18:45:00Z",
    "dusk":    f"{today}T19:30:00Z", "night":   f"{today}T21:30:00Z",
}.get(moment, moment)  # else assume a raw ISO instant

sky_code = {
    "clear": "11", "few": "13", "cloudy": "14", "overcast": "16",
    "rain": "23", "storm": "51", "snow": "33", "fog": "81",
}.get(sky, sky)

sky_label = {
    "11": "Despejado", "17": "Nubes altas", "12": "Poco nuboso", "13": "Intervalos nubosos",
    "14": "Nuboso", "15": "Muy nuboso", "16": "Cubierto",
    "23": "Lluvia", "24": "Lluvia", "25": "Chubascos", "26": "Chubascos",
    "43": "Intervalos nubosos con lluvia", "45": "Lluvia escasa",
    "51": "Tormenta", "52": "Tormenta", "61": "Tormenta",
    "33": "Nieve", "34": "Nieve", "71": "Nieve escasa",
    "81": "Niebla", "82": "Bruma", "83": "Calima",
}

d = json.load(open(snap, encoding="utf-8"))
if not d:
    sys.exit("watch snapshots.json is empty")
s = d[0]
s["updated"] = moment_iso
s["currentSky"] = sky_code
base = sky_code[:-1] if sky_code.endswith("n") else sky_code
if base in sky_label:
    s["currentSkyText"] = sky_label[base]

if city:
    name, _, prov = city.partition(",")
    name = name.strip(); prov = prov.strip()
    if name: s["localidad"] = name
    if prov: s["provincia"] = prov

if aviso:
    if aviso.lower() == "none":
        s["alert"] = None
    else:
        level, _, text = aviso.partition(":")
        level = level.strip().lower() or "naranja"
        text = text.strip() or "Aviso meteorológico"
        s["alert"] = {
            "level": level, "phenomenon": text,
            "event": f"Aviso de {text.lower()} de nivel {level}",
            "areaDesc": s.get("localidad"), "zona": "000000",
            "onset": None, "expires": None,
        }

json.dump(d, open(snap, "w", encoding="utf-8"), ensure_ascii=False)
tag = f"{s.get('localidad')} · updated {moment_iso} · sky {sky_code} {s.get('currentSkyText','')}"
if aviso: tag += f" · aviso {aviso}"
print("▸ patched", tag)
PY

xcrun simctl terminate "$WATCH_UDID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1
xcrun simctl launch "$WATCH_UDID" "$BUNDLE_ID" >/dev/null
printf '\033[1;36m▸ pinned watch\033[0m %s → %s / %s%s%s\n' "$WATCH_UDID" "$MOMENT" "$SKY" \
  "${CITY:+ / city $CITY}" "${AVISO:+ / aviso $AVISO}"

if [ -n "$SHOT" ]; then
  sleep "$SETTLE"
  xcrun simctl io "$WATCH_UDID" screenshot "$SHOT" >/dev/null
  printf '\033[1;36m▸ saved\033[0m %s\n' "$SHOT"
fi
