#!/usr/bin/env bash
set -euo pipefail
# Capture the iPad App Store set. The iPad sim MUST already be in LANDSCAPE (click the sim, Cmd-→).
# simctl captures the landscape render into a device-native portrait-dimensioned file rotated 90°,
# so every shot is rotated 90° CW afterwards to true landscape (2752x2064). idb's input axis is
# transposed vs its describe output on the landscape iPad, so scrolling uses scroll_to_ipad()
# (a horizontal swipe scrolls the content). Feature shots are scroll-only (no taps), so the
# tap-dependent "expanded card" is captured on iPhone instead.
#
# Usage: scripts/shoot_ipad.sh    (with the iPad sim in landscape)
export PATH="$HOME/.local/bin:$PATH"
IPAD=1FAA616C-C269-4B23-9C13-559FE9264ACE
OUT=/Users/miguel/Projects/aura-apps/screenshots/ipad
DRV=/Users/miguel/Projects/aura-apps/scripts/adrv.py
PIN=/Users/miguel/Projects/aura-apps/scripts/pin.sh
mkdir -p "$OUT"; rm -f "$OUT"/*.png

xcrun simctl status_bar "$IPAD" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100 --operatorName "" 2>/dev/null || true

rot() { sips -r 90 "$1" >/dev/null 2>&1; }   # correct simctl's rotated-portrait capture to landscape
relaunch_real() { xcrun simctl terminate "$IPAD" com.mab.Aura 2>/dev/null||true; sleep 1; xcrun simctl launch "$IPAD" com.mab.Aura >/dev/null; sleep 4; }
feature() { # $1=anchor $2=target-y $3=outfile
  relaunch_real
  python3 - "$IPAD" "$1" "$2" <<'PY'
import sys; sys.path.insert(0,"/Users/miguel/Projects/aura-apps/scripts"); import adrv
adrv.scroll_to_ipad(sys.argv[1], sys.argv[2], int(sys.argv[3]))
PY
  xcrun simctl io "$IPAD" screenshot "$3" >/dev/null 2>&1; rot "$3"
}

# The iPad hero uses a conditionless wide base + a mild veil, so it can't render dramatic
# rain/storm the way the phone/watch condition-baked art does. So the iPad heroes stay clear
# and lean on TIME OF DAY for variety (blue noon → golden sunset → starry night); the severe-
# weather story is carried by the aviso ("Tormentas") card shot instead.
echo "### heroes ###"
"$PIN" ipad noon   clear --shot "$OUT/01_hero_clear.png" 2>&1 | grep -viE "Detected|Note:|Wrote"; rot "$OUT/01_hero_clear.png"
"$PIN" ipad sunset clear --shot "$OUT/02_hero_dusk.png"  2>&1 | grep -viE "Detected|Note:|Wrote"; rot "$OUT/02_hero_dusk.png"
"$PIN" ipad night  clear --shot "$OUT/03_hero_night.png" 2>&1 | grep -viE "Detected|Note:|Wrote"; rot "$OUT/03_hero_night.png"

echo "### scroll features ###"
feature "PRÓXIMAS HORAS" 90  "$OUT/04_prediccion.png"
feature "Tormentas"      150 "$OUT/05_aviso.png"
feature "Sol"            300 "$OUT/06_sol_luna.png"   # 300 (not lower): keeps the black-in-sim RADAR map below the fold

echo "iPad set saved to $OUT"; ls "$OUT"