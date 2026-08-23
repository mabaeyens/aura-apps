# pin.sh: pinning Aura to a moment and sky for screenshots

`scripts/pin.sh` relaunches an already-installed Aura on a booted simulator, forcing it to a chosen time of day and weather condition. I use it to grab clean, repeatable App Store and marketing shots without waiting for the real sky to cooperate. It re-times and re-skins the snapshot the app already loaded, so the temperatures and forecast stay real; only the clock, the sky, and (optionally) the place name and an aviso card change.

There is a Watch counterpart, `scripts/pin_watch.sh`, covered at the end.

## How it works

The script forwards a few DEBUG-only overrides into the app through simctl's `SIMCTL_CHILD_` mechanism:

| Override | Set from | Effect |
|----------|----------|--------|
| `AURA_FAKE_DATE` | `<moment>` | the instant the sky and sun/moon disc are drawn for |
| `AURA_FAKE_SKY` | `<sky>` | the AEMET condition code the hero renders |
| `AURA_FAKE_CITY` | `--city` | relabels the hero (name only, data stays the loaded snapshot's) |
| `AURA_FAKE_ALERT` | `--aviso` | injects a synthetic warning card |

These are read by `Aura/ScreenshotSupport.swift`, which only exists in DEBUG builds. So the installed app has to be a DEBUG build. A Release build ignores every override and the script does nothing visible.

The script never touches the AEMET key or the location list. It relaunches what is already there.

## Prerequisites

1. A booted simulator (iPhone or iPad). Boot one from Xcode or with `xcrun simctl boot <udid>`.
2. Aura installed on it as a **DEBUG build** (run it once from Xcode to the simulator).
3. A location and a valid AEMET key added once in the app on that simulator, so there is a real snapshot to re-skin. The script assumes this is already done.

## Usage

```
scripts/pin.sh <device> <moment> <sky> [--city NAME] [--aviso LEVEL[:TEXT]] [--shot PATH]
```

- **`<device>`**: `iphone`, `ipad`, or any substring of a booted simulator's name. The script matches the first booted device that contains that word.
- **`<moment>`**: a preset label or a raw local ISO instant like `2026-08-22T08:30:00`. Presets use today's date at a representative hour.
- **`<sky>`**: a preset label or a raw AEMET sky code.
- **`--city NAME`**: show this name on the hero, e.g. `"Sevilla"` or `"Sevilla,Sevilla"` (`name,provincia`). It relabels the hero only. The numbers stay the loaded snapshot's.
- **`--aviso LEVEL[:TEXT]`**: inject a synthetic AEMET warning card. `LEVEL` is `amarillo`, `naranja`, or `rojo`. The optional `:TEXT` is the phenomenon shown, e.g. `--aviso naranja:Tormentas`. Pair it with a matching sky.
- **`--shot PATH`**: after relaunch, wait for the app to settle and save a PNG screenshot to `PATH`.

### Moment presets

| Preset | Time of day |
|--------|-------------|
| `dawn` | 07:15 |
| `morning` | 09:30 |
| `noon` | 13:30 |
| `sunset` | 20:45 |
| `dusk` | 21:15 |
| `night` | 23:30 |

Anything that is not one of these labels is passed through as a raw ISO instant.

### Sky presets

| Preset | AEMET code |
|--------|-----------|
| `clear` | 11 |
| `few` | 13 |
| `cloudy` | 14 |
| `overcast` | 16 |
| `rain` | 23 |
| `storm` | 51 |
| `snow` | 33 |
| `fog` | 81 |

Anything that is not one of these labels is passed through as a raw numeric code.

## Examples

```bash
# iPad, midday, clear sky
scripts/pin.sh ipad noon clear

# iPhone, rainy sunset over Sevilla
scripts/pin.sh iphone sunset rain --city "Sevilla"

# iPad storm with an orange warning, saved to disk
scripts/pin.sh ipad noon storm --aviso naranja:Tormentas --shot ~/Desktop/aviso.png

# A specific winter instant with snow
scripts/pin.sh ipad 2026-12-21T17:15:00 snow --shot ~/Desktop/winter.png
```

After a successful run the script prints the pinned device, instant, and sky, and (with `--shot`) the saved path.

## Environment knobs

- **`SETTLE`**: seconds to wait after relaunch before the `--shot` screenshot (default `4`). Raise it on a slow machine if a shot lands mid-animation.
- **`PIN_DATE`**: the date the moment presets use, as `YYYY-MM-DD` (default `2026-08-22`). Set it to pin a different day or season, e.g. `PIN_DATE=2026-12-21 scripts/pin.sh ...` for a winter sun arc.

## Troubleshooting

- **"No booted simulator matches ..."**: nothing is booted, or no booted device name contains your `<device>` word. The script prints the booted list. Boot the one you want first.
- **Nothing changes on screen**: the installed app is a Release build (the overrides are DEBUG-only), or the app never loaded a snapshot (add a location and key first).
- **The shot is blank or half-drawn**: raise `SETTLE`.
- **The date looks wrong for a preset**: set `PIN_DATE` to the day you actually want.

## Watch counterpart: pin_watch.sh

`scripts/pin_watch.sh` does the same for the Apple Watch app on a booted watch simulator. It seeds the watch's snapshot from the paired iPhone simulator, then patches the moment and sky the same way.

```
scripts/pin_watch.sh <moment> <sky> [--city NAME] [--aviso LEVEL[:TEXT]|none] [--shot PATH] [--seed-from IPHONE_UDID]
```

The moment and sky presets match `pin.sh`. Two differences worth knowing:

- Watch presets are peninsular-Spain UTC hours chosen to read as that band on the sun arc, so a raw instant here is UTC (e.g. `2026-08-22T11:30:00Z`).
- `--aviso none` clears any injected warning, and `--seed-from <IPHONE_UDID>` re-copies the snapshot from a specific iPhone simulator before patching (it auto-seeds once otherwise).

```bash
scripts/pin_watch.sh noon clear
scripts/pin_watch.sh sunset rain --city "Sevilla" --shot ~/Desktop/watch_sunset.png
```
