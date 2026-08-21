# Hero background prompts

Prompts for generating Aura's hero background images. These are the images that **sit
behind** the dissolved hero — the full-bleed sky and landscape — while Aura keeps drawing
the live sun/moon disc and the editorial text on top. They do **not** replace `AuraSky`:
the procedural sky logic stays underneath, the image just enriches the backdrop, and if an
image is missing Aura falls back to the procedural sky.

## The one rule that matters: no sun, no moon

**The art is generated without any sun, moon, or bright light-source disc in the sky.**
Aura draws the sun (by day) and moon (by night) itself, at the position they really occupy
for the location and the hour — rising east (left), high at noon, setting west (right).
If the image carried its own painted sun there would be *two* suns, and the real one
wouldn't move. So: clean sky, no disc. Diffuse warmth toward the light's side is fine (a
low warm glow at the horizon at dawn/dusk); a defined sun/moon is not.

Two more framing rules, because the composition is fixed so the live layers always land in
the right place:

- **Keep the top ~55% calm.** The editorial temperature and two lines of prose float over
  it (there's no card any more — the text sits straight on the sky), so it needs quiet,
  uncluttered negative space with enough contrast for white text.
- **Same framing across all 48.** Low horizon in the bottom third; layered silhouetted
  mountains, soft near hills, a single rounded tree to the right, a calm river ribbon.
  Identical composition every time, so switching condition/time (or, later, families) is
  seamless and the sun/text zones never move.

Portrait phone-wallpaper ratio **9:19.5** (e.g. ~886×1920). No text, no people, no
buildings (that's the future cityscape family), no watermark.

## The grid — 8 conditions × 6 times = 48 images

Every cell is one image, named `condition_time` (snake_case, `.png`). These names are the
contract with the app: they are exactly `HeroBackground.allAssetNames`, and the selector
resolves the current sky+time to one of them (see below).

- **Conditions** (map to `Palette.Sky` / `HeroBackground.Condition`):
  `clear · few_clouds · cloudy · overcast · rainy · stormy · snowy · foggy`
- **Times** (map to `HeroBackground.Time`, derived from the real sun path):
  `dawn · morning · noon · afternoon · dusk · night`

So the filenames run `clear_dawn`, `clear_morning`, … `foggy_night` — e.g. `few_clouds_dawn`,
`rainy_afternoon`, `clear_night`. (My earlier `sunset`→`dusk`, `early_morning` folds into
`morning`.)

## Base style (paste first, then add a time line + a condition line)

> Flat, minimalist vector illustration of a landscape, seen straight on. Vertical
> phone-wallpaper composition (9:19.5). Clean geometric shapes, smooth gradients, no
> texture, no outlines, no text, no people, no buildings. A low horizon in the bottom
> third: layered silhouetted mountains, soft rounded near hills, a single rounded tree to
> the right, a calm river ribbon that catches the light. The sky fills the upper two thirds
> and is **empty, quiet negative space — no sun, no moon, no bright disc of any kind**.
> Calm, modern, Apple-Weather-meets-Behance mood.

## Time of day — sky palette + where the light sits

Add one after the base. There is **no disc** — convey the hour with the **sky colour** and a
**diffuse** warmth on the light's side (low-left at dawn/morning, overhead-pale at noon,
low-right at afternoon/dusk), never a defined sun.

| Time | Sky palette | Ambient light (diffuse, no disc) |
|------|-------------|----------------------------------|
| **dawn** | deep indigo top → warm peach at the horizon | soft warm glow low on the **left**, most of the sky still dim |
| **morning** | soft blue top → warm haze low | gentle warm light from the **low-left**, brightening |
| **noon** | even bright blue, palest near the top-centre | bright, near-even; palest overhead, no hotspot |
| **afternoon** | blue, slightly warm | warm light from the **high-right**, long soft shadows |
| **dusk** | violet top → burning orange/pink at the horizon | strong warm glow low on the **right**, sky darkening above |
| **night** | deep navy → dark slate, a few faint scattered stars | cool and dim; **stars are fine, the moon is not** |

## Condition — what veils the sky

Add one too. Conditions only **dull and veil** the sky; they never add a light source. Aura
also dims its own disc under cloud (via `AuraSky.veil`), so the art just needs to *look* the
part — an overcast image should read flat-grey, a rainy one wet and low-contrast.

| Condition | Modifier |
|-----------|----------|
| **clear** | nothing — clean, saturated sky |
| **few_clouds** | a few soft flat clouds drifting |
| **cloudy** | broad flat cloud banks, muted palette |
| **overcast** | the whole sky a flat cool grey |
| **fog** *(foggy)* | low haze swallowing the mountains' feet, desaturated |
| **rain** *(rainy)* | grey-blue veil, fine diagonal rain streaks low, the river brighter |
| **storm** *(stormy)* | dark heavy sky, deep contrast, a dramatic break of light low at the horizon |
| **snow** *(snowy)* | pale cool sky, soft falling flakes, hills dusted lighter, low contrast |

## Ready-to-paste examples (sunless)

**clear_noon**
> [base style] An even bright blue sky, palest overhead, completely clear — no sun, no disc,
> just clean saturated daylight. Cool blue-haze mountains, a green tree, a silver river.

**clear_dawn**
> [base style] The sky runs deep indigo at the top to warm peach low on the left horizon,
> where a soft diffuse warm glow sits — but no sun disc. Mountains and tree in near-silhouette,
> the river catching the faint warm light. Quiet, first-light.

**few_clouds_dusk**
> [base style] The sky burns from violet at the top to orange and pink low on the right, a
> few soft flat clouds lit from beneath — but no sun disc anywhere. Long warm light across the
> hills, the river glowing.

**clear_night**
> [base style] A deep navy sky fading to dark slate, scattered with a few small faint stars —
> and **no moon**. Mountains, hills and tree as dark silhouettes; the river catches a faint
> cool light. Calm, cold.

**rainy_afternoon**
> [base style] A muted grey-blue overcast sky, no visible sun. Fine diagonal rain low over the
> hills, the river bright against the dim land. Soft, low-contrast, damp.

**overcast_morning**
> [base style] The whole sky a flat, even cool grey, no sun, no break in the cloud. Mountains
> and hills muted, the river a dull silver. Still, quiet, low contrast.

## How the app uses them

- Drop the 48 PNGs into the app's asset catalog under their canonical names.
- The app probes `HeroBackground.allAssetNames` against its bundle to learn which shipped,
  resolves the current sky + time with `HeroBackground.resolve(...)`, loads that `Image`, and
  passes it to `AuraSky(snapshot:now:heroImage:)`.
- `AuraSky` then draws the image behind the **glow + live sun/moon disc**, skipping its own
  gradient, veil, stars and scenery. The disc still dims under cloud/rain via `veil`.
- **Fallback chain:** exact `condition_time` → nearest existing time for the same condition →
  procedural `AuraSky`. So I can ship art incrementally — a half-full grid still looks right,
  and shipping zero images costs nothing (it's all procedural until then).

## Future: a second family (cityscape)

I plan a second set of 48 with a **cityscape** instead of the landscape, switchable and
persisted (the choice stays until I switch back). Same 8×6 grid, same times/conditions, same
sunless rule and calm-top framing — only the scenery changes (flat building skyline, windows
that could light at night). Naming gets a family axis (a prefix or folder, e.g.
`cityscape/clear_noon`); see `specs/cityscape-background-switch.md`. Keep the horizon line and
the text/sun zones identical to the landscape family so switching is seamless.

## Keep it static

Position and colour are computed once per render from `now` — no timers, no animation — so the
battery baseline stays flat. Same on iPhone and Watch.
