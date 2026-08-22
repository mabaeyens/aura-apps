# Aura — App Store submission sheet

Everything App Store Connect asks for, ready to paste. Version **1.0.0 (build 1)**, first
submission. Primary language **Spanish (Spain)**; English (U.S.) secondary.
Bundle ID `com.mab.Aura` · Team `HTVGRBVW58` · Category **Weather**.

---

## 1. App name (must be unique store-wide — DECISION NEEDED)

"Aura" alone is almost certainly taken. Candidates (≤ 30 chars), in order of preference:

1. **Aura· El tiempo** — clean, says what it is
2. **Aura Tiempo**
3. **Aura Meteo**
4. **Aura — AEMET** _(don't: implies official AEMET endorsement; avoid)_

Subtitle (≤ 30 chars): **El tiempo de España, con alma** / EN: **Spain's weather, with soul**

---

## 2. Promotional text (≤ 170 chars, editable anytime without review)

ES: El tiempo de tu municipio con datos oficiales de AEMET: cielo, lluvia, viento, UV y
calidad del aire. Con sol y luna en su posición real, en iPhone, iPad, Mac y Watch.

---

## 3. Description (≤ 4000 chars)

### Spanish (primary)

Aura es el tiempo de España contado con calma y con datos oficiales.

Toda la previsión viene directa de AEMET, la Agencia Estatal de Meteorología, y la calidad
del aire del MITECO. Sin intermediarios, sin inventar: lo que dice el organismo oficial es lo
que ves.

CADA DÍA, DE UN VISTAZO
• La previsión de tu municipio: estado del cielo, temperatura, lluvia y viento.
• El texto de AEMET para hoy, mañana y los próximos días.
• Próximas horas, hora a hora.
• Índice UV máximo del día y calidad del aire por contaminante.

SOL Y LUNA EN SU SITIO
El sol recorre la pantalla siguiendo su posición real: amanece por un lado, cae por el otro.
Al anochecer, la luna toma el relevo en el mismo lugar, con su orto y su ocaso reales. El
fondo cambia con la hora y el tiempo, y puedes elegir entre paisaje o ciudad.

EN TODOS TUS APARATOS
Aura es la misma app en iPhone, iPad y Mac, y trae un compañero para el Apple Watch con
complicaciones para la esfera: probabilidad de lluvia, índice UV y las horas de sol. Además,
widgets para la pantalla de inicio y la de bloqueo.

PRIVADA POR DISEÑO
Sin cuenta, sin registro, sin seguimiento, sin anuncios. Tu ubicación solo se usa para saber
tu municipio y pedir su previsión a los servicios oficiales. Nada llega a mí: no hay servidor
mío. Es código abierto y puedes revisarlo.

Aura cubre el territorio español y está en español.

### English (secondary)

Aura is Spain's weather, told calmly and from official data.

Every forecast comes straight from AEMET (the State Meteorological Agency), with air quality
from MITECO. No middlemen, nothing invented — what the official source says is what you see.

AT A GLANCE • Your municipality's forecast: sky, temperature, rain and wind • AEMET's own
written outlook for today and the days ahead • Next hours, hour by hour • The day's maximum UV
index and air quality by pollutant.

SUN AND MOON, WHERE THEY REALLY ARE • The sun crosses the screen at its real position; after
dark the moon takes over in the same place, with true moonrise and moonset. The background
shifts with the hour and the weather — pick landscape or cityscape.

EVERYWHERE • The same app on iPhone, iPad and Mac, plus an Apple Watch companion with face
complications for rain chance, UV and sun times, and Home/Lock Screen widgets.

PRIVATE BY DESIGN • No account, no tracking, no ads. Your location is used only to find your
municipality and request its forecast from the official services. Nothing reaches me — there's
no server of mine. Open source.

Aura covers Spain and is in Spanish.

---

## 4. Keywords (≤ 100 chars, comma-separated, no spaces)

`tiempo,clima,AEMET,meteorología,previsión,lluvia,UV,calidad aire,España,pronóstico,sol,luna`

_(94 chars. Don't repeat the app name or words already in name/subtitle — Apple indexes those
separately.)_

---

## 5. URLs & copyright

- **Support URL:** https://github.com/mabaeyens/aura-apps/issues
- **Marketing URL** (optional): https://github.com/mabaeyens/aura-apps
- **Privacy Policy URL:** https://github.com/mabaeyens/aura-apps/blob/main/PRIVACY.md
- **Copyright:** © 2026 Miguel A. Baeyens

---

## 6. Availability & pricing (DECISION: confirm)

- **Price:** Free (no in-app purchases).
- **Availability:** **Spain only.** In ASC → Pricing and Availability, deselect all
  territories except Spain. Rationale: the data is Spain-only (AEMET/MITECO) and the app is
  Spanish-language; offering it worldwide invites rejection for "limited usefulness" outside
  the covered region.

---

## 7. Age rating

**4+.** Answer every content question **None / Does not occur**. No unrestricted web access,
no user-generated content, no gambling, no data-driven ads. Weather app, general audience.

---

## 8. App Privacy — nutrition label

**Recommended answer: "No, we do not collect data from this app."**

Why this is accurate: Aura takes only a coarse (kilometre-level) location fix and resolves the
nearest municipality **on the device**, against a list bundled in the app. Only public
identifiers ever leave the device — the municipality's INE code (to AEMET) and the nearest
air-quality station's code (to MITECO) — never a coordinate, and nothing tied to a user. There
is no account, no analytics, no ads, no server of mine, and nothing is retained. Under Apple's
definition of "collect" (data leaving the device in a way the developer or a partner can access
beyond servicing the request in real time), no user location is collected: what's sent is a
"which town" selector, identical to a place the user could pick by hand.

**Conservative alternative** — if you'd rather leave no room for a reviewer to quibble, answer
**Yes** with one type only:

| Data type | Collected | Linked to identity | Used for tracking | Purpose |
|---|---|---|---|---|
| **Location — Coarse** | Yes | **No** | **No** | App Functionality (fetch the local forecast) |
| Everything else (contact, identifiers, usage, diagnostics, purchases, etc.) | **No** | — | — | — |

Notes for the questionnaire:
- **Never select Precise Location.** Precise coordinates never leave the device, so declaring
  Precise would be inaccurate — the choice is between "No data collected" (recommended) and
  "Coarse Location / App Functionality" (conservative).
- A future tip jar would not change this: StoreKit handles the payment and nothing is logged to
  a server of mine, so there is no "Purchases" data type to declare, and it is never Advertising.
- No analytics, no crash SDK, no ads → nothing else to declare.
- This matches PRIVACY.md (on-device resolution; only public town/station codes are sent). Keep
  the two in sync.

---

## 9. Accessibility Nutrition Labels (verify on-device before ticking)

Apple's 2025 accessibility labels must be **accurate** — declare only what genuinely works.
Assessment for Aura (iOS), to confirm with a VoiceOver + Dynamic Type + Reduce Motion pass:

| Feature | Claim | Status |
|---|---|---|
| Dark Interface | Supported | ✅ theme-aware throughout |
| Larger Text (Dynamic Type) | Supported | ⚠️ verify — cards use semantic fonts; check no clipping at XXL |
| VoiceOver | Supported | ⚠️ verify — standard SwiftUI controls; add labels to the sun/moon arc + hero |
| Sufficient Contrast | Supported | ⚠️ verify — check text over hero art at both themes |
| Reduced Motion | Supported | ⚠️ verify/implement — honor `.accessibilityReduceMotion` for the sun/moon animation |
| Differentiate Without Color | — | N/A unless a state relies on colour alone |
| Captions / Audio Descriptions | — | N/A (no audio/video) |
| Voice Control | Supported | ⚠️ inherits from VoiceOver labelling |

Ship 1.0 declaring only what's confirmed; the label can be updated without a new binary.

---

## 10. Review notes (App Review Information)

```
Aura shows official Spanish weather. No account or login is required.

DATA SOURCES (public, official):
• AEMET OpenData — forecasts, warnings, UV (api key server-side of AEMET's own service).
• MITECO ICA — air quality.

HOW TO TEST:
1. Launch the app. When prompted, allow location "While Using the App" — Aura resolves your
   municipality and loads its forecast. (In the simulator, set a Spain location, e.g. Madrid.)
2. Or decline location and pick a municipality manually; the app works the same.
3. Scroll for the AEMET written outlook, next hours, UV (daily max), and air quality.
4. The sun/moon card and hero background reflect the real solar/lunar position for the hour.

Apple Watch: the companion app and the rain-chance / UV / sun-times complications read the
same data. Widgets appear on the Home and Lock screens.

The app is Spain-only by design (data coverage + Spanish language).
```

**Export compliance:** `ITSAppUsesNonExemptEncryption = NO` is set in the build → no encryption
docs, no compliance prompt on upload.

**Sign-in required:** No. **Demo account:** Not needed.

---

## 11. Screenshots (you're providing — 4, one per device)

Required sizes for a universal + watch app:
- **iPhone 6.9"** (1320 × 2868 or 1290 × 2796) — required.
- **iPad 13"** (2064 × 2752) — required because the app supports iPad.
- **Apple Watch** (the series you shoot — e.g. Ultra 410 × 502) — required for the watch app.
- **Mac**: because Aura ships as "Designed for iPad", the Mac listing reuses the iPad
  screenshots — a separate Mac shot is optional. (Your "one per device" 4th shot is welcome as
  the Mac/iPad hero.)

Drop them in and ASC accepts the set once each required size has at least one.

---

## 12. What's New (first release)

ES: Primera versión de Aura. El tiempo de España con datos oficiales de AEMET y MITECO, sol y
luna en su posición real, y compañeros para Apple Watch, iPad y Mac.
