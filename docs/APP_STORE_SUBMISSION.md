# App Store submission — metadata & custom product pages

Companion to the `aura-release` skill. That skill gets a signed build up to App Store Connect;
this file tracks the **App Store metadata** that lives in the ASC UI, not in the build — the parts
I set by hand when I promote a build to an App Store version and submit it for review.

App: **Aura · El tiempo** · bundle `com.mab.Aura` · ASC app id **6804193524** · primary locale `es-ES`,
also `en-US`. Live version: **1.0.0 (Ready for Distribution)**.

---

## Expanded keywords — APPLIED on 1.1.0 (build 6), submitted 2026-08-26

> Status: done. Staged and submitted with build 6 on 2026-08-26 (state WAITING_FOR_REVIEW).
> Change from the original plan: es-ES uses the Spanish set below; en-US instead got an
> English-optimised set, since the app is now sold worldwide and English users search English words:
> `weather,Spain,AEMET,forecast,rain,UV,air quality,warnings,alerts,radar,widget,watch,sun` (87/100).
> The rest of this section is kept for reference.

**Why this was parked (historical):** keywords are *version metadata*. They can't be edited on the live 1.0.0 page
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

## Availability — worldwide except China (DONE 2026-08-26, toggled in the ASC UI)

Decision: available in all ~174 territories, China mainland excluded (avoids ICP filing / local-entity
requirements). No new paperwork: the paid-apps agreement, tax/banking, export compliance and EU DSA
trader status were all cleared for the Spain launch.

**Must be set in the ASC UI, not the API.** The App Store Connect API's `appAvailabilities` resource
allows only CREATE and GET, and one already exists from the 1.0.0 setup, so it cannot be changed via
the API (confirmed 2026-08-26: POST returns "already exists", PATCH returns 403 "does not allow UPDATE").
Do it under App Store version > Pricing and Availability > Availability: select all, deselect China
mainland, Save. App-level and review-free, effective immediately on the live app.

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

---

## 1.1.0 submission log (2026-08-26)

Done via the ASC API (all on the 1.1.0 version / its editable appInfo, so nothing on live 1.0.0 changed):

- Version 1.1.0 (build 6) created and build attached.
- Keywords: es-ES Spanish 13-term set; en-US English-optimised set (see the keywords section).
- What's New: Spanish and English, describing the 1.1.0 changes (guideline 2.3.12).
- Marketing + Support URLs: en-US moved off GitHub to askmira.es (es-ES was already correct).
- Privacy Policy URL: both locales moved to askmira.es/aura/privacidad (on the editable appInfo).
- Description: added a coverage line to both locales ("Coverage: Spain, using official AEMET data.").
- Reviewer notes: added one line explaining the app is intentionally available worldwide though coverage is Spain-only. API key left untouched.
- Submitted for review: state WAITING_FOR_REVIEW.

Still to do by hand:

- Territory availability -> worldwide except China, in the ASC UI (API cannot change it; see the Availability section).
- CPP keywords + marketing art: after 1.1.0 is approved (unchanged from the plan above).
- Keyword idea for the NEXT version: add "complications" (I search that term myself). The keyword
  field is the only search-indexed lever besides the app name and subtitle; description text is NOT
  indexed, so putting it only in the description does nothing for search. Fit check against the 100-char
  limit: en-US has room for the singular `complication` (12 chars) at exactly 100/100 with nothing
  dropped; the plural `complications` (13) needs one weak term dropped (e.g. `radar`). es-ES
  `complicaciones` (14) does not fit the current 96/100 string, so swap a weaker term for it (e.g. drop
  `meteorología` -> ~98/100). Can't be changed now (1.1.0 is locked in review); fold into the next build.
- Known minor typo still in the es-ES description ("un \"no pasa nada\" no hay ninguno", missing "cuando"); left as-is because 1.1.0 was already submitted. Fix in a future version.
