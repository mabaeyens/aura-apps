# Hero background prompts

A set of prompts for generating Aura hero/background images with ChatGPT (or any
image model), for my own experiments. This is **not** the in-app background — the app
draws its sky in SwiftUI (`AuraSky`), sun-as-light-source, no shipped images. This file
is a scratchpad for exploring a richer illustrated look I might fold back into the
drawing later, or use as reference art.

The whole point of Aura's sky is that the **light source (sun by day, moon by night)
sits where it really is for the hour** — rising east (left), high at noon, setting west
(right). Any generated image has to respect that, and has to leave the **upper third
calm** so the frosted hero card stays readable on top.

## Base style (paste this first, then add a time + condition line)

> Flat, minimalist vector illustration of a landscape, seen straight on. A vertical
> phone-wallpaper composition (9:19.5). Clean geometric shapes, smooth gradients, no
> texture, no outlines, no text, no people, no buildings. A low horizon in the bottom
> third: layered silhouetted mountains, soft rounded near hills, a single rounded tree
> to the right, and a calm river ribbon that catches the light. The sky fills the upper
> two thirds and is mostly empty, quiet negative space (a card will sit over it).
> A single clear light source — a defined disc with a soft corona — is the focal point.
> Calm, modern, Apple-Weather-meets-Behance mood.

## Time of day — where the light sits + palette

Add one of these after the base. `x` is horizontal position of the disc (0 = left/east,
1 = right/west); keep the disc **low near the horizon at dawn/dusk, high near the top at
noon**.

| Time | Light position | Sky palette | Light colour |
|------|----------------|-------------|--------------|
| **Dawn** | sun low, far left (x≈0.05) | deep indigo top → warm peach at the horizon | deep orange disc |
| **Morning** | sun low-left rising (x≈0.2) | soft blue top → warm haze low | warm gold-orange |
| **Noon** | sun high, centre (x≈0.5, near top) | even bright blue, pale near the sun | bright near-white gold |
| **Afternoon** | sun high-right (x≈0.7) | blue, slightly warm | warm gold |
| **Sunset / dusk** | sun low, far right (x≈0.95) | violet top → burning orange/pink at the horizon | deep orange-red disc |
| **Night** | moon mid-left (x≈0.3), gentler arc | deep navy → dark slate, scattered stars | pale silver-blue moon |

## Condition — what veils the light

Add one of these too. Clouds never move the light — they only **dull and veil** it.

| Condition | Modifier |
|-----------|----------|
| **Clear** | (nothing — full, clean light and saturated sky) |
| **Few clouds** | a few soft flat clouds drifting, light still strong |
| **Cloudy** | broad flat cloud banks, the disc softened and partly hidden, muted palette |
| **Overcast** | the whole sky a flat cool grey, the disc a faint bright patch only |
| **Fog** | low haze swallowing the mountains' feet, the disc a dim halo, desaturated |
| **Rain** | grey-blue veil, diagonal rain streaks low, the river brighter, disc barely visible |
| **Storm** | dark heavy sky, a break of dramatic light near the horizon, deep contrast |
| **Snow** | pale cool sky, soft falling flakes, hills dusted lighter, gentle low contrast |

## Ready-to-paste examples

**Clear noon**
> [base style] The sun is a bright near-white gold disc with a soft corona, high near the
> top centre of the sky. The sky is an even bright blue, palest around the sun. Full clean
> daylight, saturated, calm. Mountains in cool blue haze, a green tree, a silver river.

**Clear dawn**
> [base style] The sun is a deep-orange disc low on the far-left horizon, rising, with a
> warm glow. The sky runs deep indigo at the top to warm peach at the horizon. Mountains
> and tree in near-silhouette, the river catching the warm light. Quiet, still, first-light.

**Sunset, few clouds**
> [base style] The sun is a deep orange-red disc low on the far-right horizon, setting.
> The sky burns from violet at the top to orange and pink at the horizon, with a few soft
> flat clouds lit from beneath. Long warm light across the hills, the river glowing.

**Clear night**
> [base style] A pale silver-blue full moon with a soft halo sits mid-left in a deep navy
> sky scattered with small stars. The mountains, hills and tree are dark silhouettes; the
> river catches a faint cool moonlight. Calm, quiet, cold.

**Rainy afternoon**
> [base style] A muted grey-blue sky, the sun only a faint bright patch high-right behind
> broad flat cloud. Fine diagonal rain low over the hills, the river bright against the
> dim land. Soft, low-contrast, damp mood.

**Snowy morning**
> [base style] A pale cool sky, the sun a soft dim disc low-left behind thin cloud. Gentle
> flakes falling, the hills and mountains dusted lighter, the tree carrying a little snow.
> Quiet, soft, low contrast.

## Notes for folding back into SwiftUI

If any of these reads better than the current `AuraSky`, the drawable pieces are:
- disc colour/size per time → `AuraSky.discColors` + the disc layer
- sky gradient stops per hour → `Palette.skyBaseColors(at:)`
- veil amount per condition → `AuraSky.veil`
- scenery tints → `AuraSky.sceneColors`

Keep it **static per render** (position from `now`, no timers/animation) so the battery
baseline stays flat.
