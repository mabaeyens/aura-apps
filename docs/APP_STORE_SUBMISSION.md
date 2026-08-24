# App Store submission — metadata & custom product pages

Companion to the `aura-release` skill. That skill gets a signed build up to App Store Connect;
this file tracks the **App Store metadata** that lives in the ASC UI, not in the build — the parts
I set by hand when I promote a build to an App Store version and submit it for review.

App: **Aura · El tiempo** · bundle `com.mab.Aura` · ASC app id **6804193524** · primary locale `es-ES`,
also `en-US`. Live version: **1.0.0 (Ready for Distribution)**.

---

## ⚠️ Apply on the NEXT App Store version — expanded keywords

**Why this is parked:** keywords are *version metadata*. They can't be edited on the live 1.0.0 page
(that field is locked once Ready for Distribution), and keywords are **not** in the edit-without-review
set (only promotional text is). Changing them needs a **new version + App Review**. A new iOS version
needs a build anyway, so I fold this into the next release instead of a standalone submission — 1.0.0
stays for sale throughout, no downtime.

**When I cut the next version (via `aura-release`), before submitting: replace the keyword field on
BOTH localizations (`es-ES` and `en-US`) with this — no space after commas (spaces cost characters):**

```
AEMET,España,meteorología,previsión,lluvia,UV,calidad aire,avisos,alertas,radar,widget,reloj,sol
```

(96 / 100 chars.)

- **New vs the current 12** (`tiempo, clima, AEMET, meteorología, previsión, lluvia, UV, calidad aire,
  España, pronóstico, sol, luna`): **avisos, alertas, radar, widget, reloj** — the terms the custom
  product pages need to differentiate by angle.
- **Dropped:** `tiempo` (already in the app name "Aura · El tiempo", so Apple indexes it — repeating
  wastes characters), `clima` and `pronóstico` (redundant with `previsión`). `luna` didn't fit under 100.

---

## Listing URLs — own domain, not GitHub (both pages live)

Point the listing at askmira.es pages instead of a raw GitHub markdown viewer. All three destinations
exist and are deployed:

| ASC field | Set to | Replaces |
|---|---|---|
| Support URL | `https://askmira.es/aura/soporte` | (the 1.5 fix — already set) |
| Marketing URL | `https://askmira.es/aura` | (empty / GitHub repo) |
| Privacy Policy URL | `https://askmira.es/aura/privacidad` | the GitHub-rendered `PRIVACY.md` |

- All three are **app-level** ASC fields, editable without a new version or review, so the Marketing and
  Privacy URLs can be swapped in **anytime** — no need to wait for the next build.
- `aura/privacidad` is a hosted bilingual (ES/EN) privacy page (last updated 22 Aug 2026), so it reads
  far better than GitHub's file viewer and won't 404 if the repo is ever made private.

---

## Custom product pages (created 2026-08-24, via the ASC API)

Four CPPs exist, all `PREPARE_FOR_SUBMISSION`, both locales, **promotional text set, no screenshots,
nothing submitted**. The marketing art (CARROT-style living-sky screenshots) is still parked — full
plan lives in mira-web `notes/aura-custom-product-page.md` (gitignored, local). Reference names + URLs:

| Page | `ppid` (URL = `…/id6804193524?ppid=<ppid>`) |
|---|---|
| Widgets | `b74d293f-cd98-46a8-a48c-4ce675492b23` |
| Avisos oficiales (CAP) | `d431b8e7-f876-457a-a2f9-9eda1c2b4149` |
| Apple Watch | `6ad58e23-b7b0-4ec7-ad78-7fea652b1b3c` |
| Datos oficiales AEMET | `7d5eab58-c116-4ada-88b4-b7aea29d9968` |

### Promotional text already set (≤170 chars, per locale)

- **Widgets** — ES: *Widgets de inicio y pantalla de bloqueo con los datos oficiales de AEMET, configurables por lugar guardado. Sin servidores, sin cuenta: tu clave vive en el dispositivo.* · EN: *Home & Lock Screen weather widgets for Spain, from AEMET's official data — configurable per saved place, no backend, no account. Your key stays on device.*
- **Avisos (CAP)** — ES: *Avisos oficiales CAP de AEMET, asignados a cada lugar guardado por provincia. Y la temperatura real observada en la estación de AEMET más cercana.* · EN: *Official CAP weather warnings for Spain, matched to each saved place by province — plus real observed temperatures from the nearest AEMET station.*
- **Apple Watch** — ES: *El tiempo de AEMET en la muñeca: app de Apple Watch y complicaciones de UV, lluvia, viento, sol y avisos, en cualquier esfera y sobre el cielo vivo.* · EN: *AEMET weather on your wrist: an Apple Watch app and complications for UV, rain, wind, sun and warnings — on any face, over the living sky.*
- **Datos oficiales AEMET** — ES: *Datos oficiales de AEMET, sin intermediarios: predicción, sol y luna, calidad del aire y radar. Privado por diseño, tu clave vive solo en tu dispositivo.* · EN: *Official AEMET data, no middleman: forecast, sun & moon, air quality and radar. Private by design — your API key lives only on your device.*

### CPP keyword selection — do AFTER the expanded keywords are approved

CPP keywords are **checkboxes drawn from the app's latest approved version keyword field**, so these
can only be ticked once the expanded list above ships and is approved. Then, per page (unique combo
each, each led by its differentiator), tick:

- **Widgets:** widget, previsión, lluvia, sol, España
- **Avisos (CAP):** avisos, alertas, AEMET, lluvia, España
- **Apple Watch:** reloj, UV, sol, meteorología, España
- **Datos oficiales AEMET:** AEMET, radar, calidad aire, meteorología, previsión

Then submit each CPP for its own (quick, independent) review — the `ppid` URLs don't change.

---

## Order of operations at next release

1. `aura-release` → new build up to ASC, new App Store version created.
2. In the version's metadata, **swap in the expanded keyword list** (both locales) → submit the
   version for review. 1.0.0 stays live until it's approved.
3. Once approved, **tick each CPP's keyword set** (table above) and add screenshots when the art is
   ready → submit each CPP.

## Notes

- Screenshots: up to 10 per size; **app previews are videos** (15–30 s, ≤3/size) — none yet, skip them.
- CPPs never rotate; each is a fixed-URL destination (or surfaces in search via its unique keywords).
  Automatic traffic-splitting would be **Product Page Optimization**, a separate feature — not set up.
- Everything above was done with the shared ASC API key (the `aura-release` credentials); no keyword
  or default-listing metadata on the live 1.0.0 was touched.
