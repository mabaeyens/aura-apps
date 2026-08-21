# Cityscape hero — visual QA

**Verdict: ship it.** All 48 cells pass. Nothing needs a re-roll. The grid reads as one coherent quiet town — cream/stone buildings, a central tower, curving street, a couple of lampposts — with a light direction that tracks the time of day. The sunless rule holds everywhere (no disc, moon, halo, or flare painted in any sky), the veiled conditions stay honestly overcast at all six times, and the disc/glow landing zones are clear of tall geometry.

## Re-roll

None. Every cell clears the six rules.

## Acceptable but watch

| Cell | Note |
| --- | --- |
| `city_stormy_afternoon` | A brighter break in the cloud sits upper-right, roughly where the live afternoon disc lands. It's diffuse storm cloud, not a clear-sky gap, so it passes — but if the live disc glow stacks on top it could read a touch hot. Fine as-is; flagging only. |
| `city_foggy_dusk` | The warm haze on the lower-right is fairly saturated. No disc is painted and it stays veiled, but it leans close to "sun glowing through fog." Acceptable; keep an eye on how the live disc reads over it. |
| `city_foggy_dawn` | Same idea, milder — warm glow lower-left exactly in the dawn disc zone. Open and veiled, so it's fine; noting for consistency. |
| Snowy series (`morning`, `noon`, `night`) | The landmark reads as a pointed church spire here rather than the square campanile/turret used elsewhere. It still looks like the same town, just a different building on the same street — minor vocabulary drift, not a defect. |

## Coherence

Very good. The architectural kit is consistent across all eight conditions: pitched cream roofs, one taller tower/turret as the anchor, black lampposts, a curved street sweeping to a horizon. Lit windows and street lamps behave correctly — on at dawn/dusk/night, off in daylight. Light direction is coherent per time: warm low-left at dawn, warm low-right at dusk, cool top-centre light at noon, faint stars at night.

- **Clear / few_clouds** keep genuinely open sky with calm tops for editorial text; few_clouds adds a couple of soft clouds without crowding the top.
- **Cloudy** sits correctly in between — scattered cloud with blue gaps.
- **Overcast, rainy, stormy, snowy, foggy** are all convincingly veiled at every time, including noon and morning where a clear-sky gap would have been the failure mode. No veiled cell shows a hole where the disc would sit.
- **Rainy** and **stormy** both deliver falling rain and wet, reflective streets; stormy adds the heavier, more turbulent cloud it should. **Snowy** reads unmistakably as snow — flakes, snow-capped roofs, snow on the ground.
- The top ~55% is calm enough for white editorial text in every cell, storm and cloud included (tone stays uniform even when dark).

One palette observation, not a problem: a few daylight cells lean slightly Mediterranean (terracotta roofs in a couple of clear/cloudy frames) while others stay cooler grey-blue. It still reads as the same town under different light, so I'm leaving it.
