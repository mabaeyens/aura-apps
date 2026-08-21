# Hero background prompts

Prompts for generating Aura's hero background images. These are the images that **sit behind** the dissolved hero — the full-bleed sky and landscape — while Aura keeps drawing the live sun/moon disc and the editorial text on top. They do **not** replace `AuraSky`: the procedural sky logic stays underneath, the image just enriches the backdrop, and if an image is missing Aura falls back to the procedural sky.

## The one rule that matters: no sun, no moon

**The art is generated without any sun, moon, or bright light-source disc in the sky.** Aura draws the sun (by day) and moon (by night) itself, at the position they really occupy for the location and the hour — rising east (left), high at noon, setting west (right). If the image carried its own painted sun there would be *two* suns, and the real one wouldn't move. So: clean sky, no disc — and **no concentrated brightest point at all**: no glow, no hotspot, no flare, no shaft or "break of light", no back-lighting from behind the hills or tree. Any of those reads as a hidden sun and clashes with the live disc. Warm horizon *colour* is welcome, but only spread as a flat, even band — never gathered into a point. (This is exactly what bakes a frozen sun into dawn and dusk art if the prompt asks for a "glow low on the right" or a "break of light".)

Two more framing rules, because the composition is fixed so the live layers always land in the right place:

- **Keep the top ~55% calm.** The editorial temperature and two lines of prose float over it (there's no card any more — the text sits straight on the sky), so it needs quiet, uncluttered negative space with enough contrast for white text.
- **Same framing across all 48.** Low horizon in the bottom third; layered silhouetted mountains, soft near hills, a single rounded tree to the right, a calm river ribbon. Identical composition every time, so switching condition/time (or, later, families) is seamless and the sun/text zones never move.

Portrait phone-wallpaper ratio **9:19.5** (e.g. ~886×1920). No text, no people, no buildings (that's the future cityscape family), no watermark.

## The grid — 8 conditions × 6 times = 48 images

Every cell is one image, named `condition_time` (snake_case, `.png`). These names are the contract with the app: they are exactly `HeroBackground.allAssetNames`, and the selector resolves the current sky+time to one of them (see below).

- **Conditions** (map to `Palette.Sky` / `HeroBackground.Condition`): `clear · few_clouds · cloudy · overcast · rainy · stormy · snowy · foggy`
- **Times** (map to `HeroBackground.Time`, derived from the real sun path): `dawn · morning · noon · afternoon · dusk · night`

So the filenames run `clear_dawn`, `clear_morning`, … `foggy_night` — e.g. `few_clouds_dawn`, `rainy_afternoon`, `clear_night`. (My earlier `sunset`→`dusk`, `early_morning` folds into `morning`.)

## Base style (paste first, then add a time line + a condition line)

> Flat, minimalist vector illustration of a landscape, seen straight on. Vertical phone-wallpaper composition (9:19.5). Clean geometric shapes, smooth gradients, no texture, no outlines, no text, no people, no buildings. A low horizon in the bottom third: layered silhouetted mountains, soft rounded near hills, a single rounded tree to the right, a calm river ribbon that catches the light. The sky fills the upper two thirds and is **empty, quiet negative space — no sun, no moon, no bright disc of any kind**. Calm, modern, Apple-Weather-meets-Behance mood.

## Time of day — sky palette + where the light sits

Add one after the base. There is **no disc, and no concentrated brightest point of any kind** — convey the hour with the **sky colour** and warmth spread as a **flat, even horizontal band** across the horizon, never a glow, hotspot, flare, or light emanating from behind the hills/tree. A broad directional tint (warmer toward one side) is fine; a single bright spot is a sun, and the image must not carry one. This is the failure mode that bites dawn and dusk: any phrase like "warm glow low on the right" or "a break of light at the horizon" makes the model bake in a frozen sun, so the wording below deliberately avoids it.

| Time | Sky palette | Horizon warmth (flat band, no hotspot) |
|------|-------------|----------------------------------------|
| **dawn** | deep indigo top → warm peach at the horizon | warm peach spread **evenly** as a low, flat band across the whole horizon; the sky stays dim above; no bright point, no radiating glow, no back-lit hills |
| **morning** | soft blue top → warm haze low | a gentle, even warm haze low across the horizon; brightening overall, no single source |
| **noon** | even bright blue, palest near the top-centre | bright and near-even; palest overhead, no hotspot |
| **afternoon** | blue, slightly warm | an even, faint warm cast low across the sky; no concentrated light, no radiating glow |
| **dusk** | violet top → burning orange/pink at the horizon | the orange/pink runs **evenly** as a flat band along the whole horizon; darkening above; no single brightest point, no glow, no light from behind the hills/tree |
| **night** | deep navy → dark slate, a few faint scattered stars | cool and dim; **stars are fine, the moon is not** |

## Condition — what veils the sky

Add one too. Conditions only **dull and veil** the sky; they never add a light source. Aura also dims its own disc under cloud (via `AuraSky.veil`), so the art just needs to *look* the part — an overcast image should read flat-grey, a rainy one wet and low-contrast.

| Condition | Modifier |
|-----------|----------|
| **clear** | nothing — clean, saturated sky |
| **few_clouds** | a few soft flat clouds drifting |
| **cloudy** | broad flat cloud banks, muted palette |
| **overcast** | the whole sky a flat cool grey |
| **fog** *(foggy)* | low haze swallowing the mountains' feet, desaturated |
| **rain** *(rainy)* | grey-blue veil, fine diagonal rain streaks low, the river brighter |
| **storm** *(stormy)* | dark heavy sky, deep contrast; any lightness at the horizon is an even, low band — **not** a break of light, a bright spot, or a shaft breaking through |
| **snow** *(snowy)* | pale cool sky, soft falling flakes, hills dusted lighter, low contrast |

**Failure mode — condition must win over time for heavy cloud.** Each baked prompt is base + a *time* sentence (sky colour) + a *condition* sentence (cloud cover). For heavy-cloud conditions (**overcast**, **storm**) the vivid time sentence, sitting **earlier** in the prompt, silently overrides the later condition sentence: `stormy_noon` renders as a clear bright-blue sky and `overcast_dusk` as an open violet/orange sunset, even when the prompt *ends* with correct "flat cool grey / no bright break" language. Appending a stronger tail does **not** fix it — the earlier time line must be **demoted to a subordinate tint** ("a dim, desaturated violet-to-muted-orange tint low down", not "burning orange and pink"), or dropped, so the whole prompt is internally consistent and the heavy-cloud read dominates. This bites overcast at dawn/noon/dusk and storm at morning/noon/afternoon; the dim-sky hours (night, and the already-dark storm dawn/dusk) survive because their time colour isn't bright enough to defeat the cloud. Same rule will apply to the cityscape set.

## Ready-to-paste examples (sunless)

**clear_noon**
> [base style] An even bright blue sky, palest overhead, completely clear — no sun, no disc, just clean saturated daylight. Cool blue-haze mountains, a green tree, a silver river.

**clear_dawn**
> [base style] The sky runs deep indigo at the top to warm peach low across the horizon, the peach spread evenly as a flat band — no bright point, no glow, no light behind the hills, no sun disc. Mountains and tree in near-silhouette, the river a faint cool ribbon. Quiet, first-light.

**few_clouds_dusk**
> [base style] The sky runs from violet at the top to an even band of orange and pink along the whole horizon, a few soft flat clouds tinted the same — no single brightest point, no glow, no light from behind the hills, no sun disc anywhere. The land in soft silhouette.

**clear_night**
> [base style] A deep navy sky fading to dark slate, scattered with a few small faint stars — and **no moon**. Mountains, hills and tree as dark silhouettes; the river catches a faint cool light. Calm, cold.

**rainy_afternoon**
> [base style] A muted grey-blue overcast sky, no visible sun. Fine diagonal rain low over the hills, the river bright against the dim land. Soft, low-contrast, damp.

**overcast_morning**
> [base style] The whole sky a flat, even cool grey, no sun, no break in the cloud. Mountains and hills muted, the river a dull silver. Still, quiet, low contrast.

## How the app uses them

- Drop the 48 PNGs into the app's asset catalog under their canonical names.
- The app probes `HeroBackground.allAssetNames` against its bundle to learn which shipped, resolves the current sky + time with `HeroBackground.resolve(...)`, loads that `Image`, and passes it to `AuraSky(snapshot:now:heroImage:)`.
- `AuraSky` then draws the image behind the **glow + live sun/moon disc**, skipping its own gradient, veil, stars and scenery. The disc still dims under cloud/rain via `veil`.
- **Fallback chain:** exact `condition_time` → nearest existing time for the same condition → procedural `AuraSky`. So I can ship art incrementally — a half-full grid still looks right, and shipping zero images costs nothing (it's all procedural until then).

## Cityscape family

The second family of 48 is a **cityscape** instead of the landscape — switchable in Ajustes and persisted (`@AppStorage("heroFamily")`, values `landscape`/`cityscape`, labelled *Paisaje*/*Ciudad*). It's the same 8×6 grid, the same times and conditions, the same sunless rule and calm-top framing; only the scenery changes — a flat, layered building skyline with a low roofline, windows that can warm at night, the same calm water ribbon where the landscape has its river. The two families coexist in one flat asset catalog, so I keep the landscape names bare and give the cityscape a **`city_` prefix** on the otherwise identical `condition_time` token (see `HeroBackground.Family.assetPrefix`). The resolver only ever probes the chosen family's 48 names, and a family with no art for the current sky falls straight to the procedural `AuraSky` — never to the other family — so I can ship the cityscape set incrementally, or before it's finished, at no cost.

### The 48-name grid

Every cell is `city_<condition>_<time>.png`, the same axes as the landscape family:

- **Conditions:** `clear · few_clouds · cloudy · overcast · rainy · stormy · snowy · foggy`
- **Times:** `dawn · morning · noon · afternoon · dusk · night`

So the filenames run `city_clear_dawn`, `city_clear_morning`, … `city_foggy_night` — e.g. `city_few_clouds_dusk`, `city_rainy_afternoon`, `city_clear_night`. These are exactly `HeroBackground.assetNames(for: .cityscape)`.

### The edge/occlusion constraint — keep the skyline clear of the disc

This is the rule the cityscape adds on top of the shared sunless rule. Aura draws the live sun (by day) and moon (by night) on top of the art at the true solar position, with a soft glow around it. A building must **never rise in front of the disc or its glow** at any of the six light positions — if a tower crosses where the live disc sits, the disc reads as painted onto the building instead of floating in the sky, and the whole illusion breaks. So the skyline has to stay low, or leave a clear gap, around each of these positions (x across the frame, y down from the top):

| Time | Light position | Where to keep the skyline clear |
|------|----------------|---------------------------------|
| **dawn** | low-left, ~6% x · ~68% y | leave the lower-left corner open; no tower crossing the left edge low down |
| **morning** | ~26% x · ~32% y | nothing tall in the left third reaching up past the roofline into the upper-middle |
| **noon** | ~50% x · ~14% y | the disc sits high and central — the whole skyline is well below it, so this one's naturally safe |
| **afternoon** | ~74% x · ~32% y | mirror of morning: nothing tall in the right third reaching into the upper-middle |
| **dusk** | low-right, ~94% x · ~68% y | leave the lower-right corner open; no tower crossing the right edge low down |
| **night** | moon, ~50% x · ~20% y | high and central, like noon — keep the tallest towers off-centre so they don't spear the moon |

The dawn and dusk positions are the tight ones: the light is low and near the frame edge, exactly where a tall building on that side would sit. Push the tallest towers toward the centre and keep the outer thirds low, so the low corners stay open for the rising and setting disc.

### The veiled-sky honesty rule

Same as the landscape family, and it matters just as much here: under **overcast, rainy, stormy, snowy, foggy** the sky is veiled, so at **every** time — including noon and the golden hours — Aura shows only a soft diffuse glow where the light would be, never a sharp disc (this mirrors `AuraSky.hidesDisc` / `veil`). The art for those five conditions must therefore read genuinely overcast: flat grey, wet, storm-dark, snow-pale or fog-swallowed, with **no** bright break, hotspot, halo or shaft anywhere in the sky. Only `clear`, `few_clouds` and `cloudy` keep a defined live disc, and even those dim and soften as the cloud thickens. The heavy-cloud-beats-bright-time failure mode from the landscape prompts (a vivid time line silently overriding a later cloud line, e.g. `city_stormy_noon` rendering as clear blue) applies identically — demote the time colour to a subordinate tint for overcast and storm.

### Reviewing and dropping the set

`docs/hero-review-cityscape.html` is the cityscape contact sheet — the same 8×6 veil-aware live-hero preview as `docs/hero-review.html`, but reading the `city_*` thumbnails. Once the 48 `hero_asset_creation/output/city_*.png` land, the drop step copies each full-res PNG into `Aura/Assets.xcassets/city_<name>.imageset/` and a 512px-wide copy into `AuraWatch/Assets.xcassets/`, regenerates the thumbnails, and rebuilds that review page. The in-app *Ciudad* switch only appears once at least one `city_*` asset is actually in the bundle, so shipping the switch ahead of the art is safe.

## Keep it static

Position and colour are computed once per render from `now` — no timers, no animation — so the battery baseline stays flat. Same on iPhone and Watch.
