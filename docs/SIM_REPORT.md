# Simulation report

Tools: `godot/tests/sim_balance.gd` (one all-AI game, one JSON line), `tools/sim.sh` (every era x seeds, parallel), `tools/sim_report.py` (summary).
Run: `tools/sim.sh 300 "1 2 3 4 5 6" /tmp/sim && python3 tools/sim_report.py /tmp/sim/sim.jsonl` (about 8 minutes on 4 cores, 78 games of 300 turns).
AIs do not trigger victory themselves, so the probe records the first turn any nation *would* have met each victory path.

## What the first run found (before the fixes)
| Finding | Evidence | Status |
|---|---|---|
| **Economic victory (5,000 gold) was trivial.** All nations start with 79 gold, but income grows with provinces: a large nation earns 800-1,000 a turn. | The largest nation met it by turn 5-10 in every era, in 6 of 6 games (e.g. Ottoman Empire 9,010 gold at turn 10, median nation 139). A human playing a big nation could win without playing. | **Fixed:** needs a full trade network (as many deals as the era allows) and turn 30 or later. |
| **Technological victory (tech 5.0)** is on an absolute scale, but eras start higher and higher (ancient 0.3 ... Cold War 4.9). | Cold War leaders start at 4.89: a win in about 10 turns. WWII 4.7: about 30 turns. | **Fixed (partly):** not before turn 60. Late eras are still close to automatic once that turn passes: see open items. |
| **Diplomatic victory (8 alliances)** does not scale with the number of nations. | Modern era (251 nations): some AI had 8 allies by turn 50 in 6 of 6 games. | **Fixed:** 8 or 5% of living nations, whichever is more. |
| Domination (25% of the map) and conquest were never reached by any AI. | Best AI held 14% of the map at most; conquest progress 0.06-0.15. | By design: AIs are defensive. Humans have to take it. |

No engine invariant broke in 78 games x 300 turns (negative or NaN gold, army or manpower out of range, a dead nation owning land, a nation with no ruler).
The engine test suite (`tests/run_all.gd`) passes, including the bit-exact oracle.

## Re-run after the economy / tech / aggression / rebellion model (rules >= 1, docs/MODEL.md)
78 games x 300 turns, same seeds, `tools/sim.sh` then `tools/sim_report.py`:

| era | alive start->end | top nation (provinces) | HHI | at war | rebel provs | max treasury | AI would have won |
|---|---|---|---|---|---|---|---|
| ancient | 78->78 | 187->181 | 0.041 | 43 | 3 | 38,373 | diplomatic 2 runs, turn 240 |
| roman | 54->54 | 268->413 | 0.121 | 20 | 4 | 150,419 | tech 6 runs, turn 190 |
| medieval | 122->120 | 135->102 | 0.026 | 58 | 1 | 1,140 | diplomatic 6 runs, turn 90 |
| mongol | 97->96 | 148->95 | 0.025 | 42 | 2 | 5,125 | diplomatic 1 run, turn 260 |
| timurid | 94->94 | 158->158 | 0.033 | 44 | 2 | 37,185 | none |
| discovery | 116->115 | 124->100 | 0.025 | 62 | 1 | 6,537 | diplomatic 2 runs, turn 230 |
| gunpowder | 109->108 | 202->191 | 0.040 | 50 | 0 | 31,831 | diplomatic 2 runs, turn 290 |
| napoleonic | 94->94 | 206->198 | 0.042 | 49 | 0 | 29,563 | diplomatic 4 runs, turn 220 |
| victorian | 130->128 | 168->154 | 0.031 | 71 | 1 | 7,765 | diplomatic 5 runs, turn 90 |
| ww1 | 94->94 | 218->126 | 0.029 | 45 | 0 | 9,706 | diplomatic 2 runs, turn 200 |
| ww2 | 94->93 | 230->119 | 0.028 | 46 | 1 | 13,797 | diplomatic 2 runs, turn 190 |
| coldwar | 109->109 | 199->103 | 0.025 | 56 | 0 | 14,568 | diplomatic 4 runs, turn 230 |
| modern | 251->250 | 79->86 | 0.014 | 88 | 0 | 2,570 | diplomatic 4 runs, turn 130 |

* **No invariant broke** in 78 games (0 in every era).
* **Economic victory is gone as an AI path** (share-based rule): no era reports it. Max treasuries were 160,000 (Napoleonic) and over 1,000,000 (Roman) in the first run; now Napoleonic peaks at 29,563 and Roman at 150,419 (a 413-province empire), the other eras between 1,140 and 38,373.
* **Technology** is only reachable in the Roman era (6 of 6 runs, turn 190 at the earliest): the lead rule (0.4 over the second) makes it a race there, and late eras are skipped on purpose.
* **Rebels:** 0-4 rebel-held provinces on average at the end of 300 turns (first run: 3-5% of the map). Individual games still spike (ancient seed 3 had 33 rebel provinces at turn 75).
* **Diplomatic hegemony** is the AI's easiest path (turn 90 in the medieval and Victorian worlds). Open item: scale the threshold by era or require the alliances to hold for N turns.
* **Roman** is the one runaway world (top nation 268 -> 413 provinces, HHI 0.12): worth a look at supply and overextension for very large empires.

## Open items (design decisions, not changed)
1. **Economic victory is still the fastest path (about turn 30)** for the largest nations, because the AI giants fill their trade deals and hoard. The root cause is economic: income is linear in provinces and nothing drains it.
2. **Gold hoarding:** one or two nations end up holding almost all the world's gold (napoleonic turn 100: 53,000 of 57,000). Maximum treasuries reach 160,000 (Napoleonic) and over 1,000,000 (Roman). Suggest an AI gold sink (buildings, decrees, bribes) or an upkeep/inflation term.
3. **Late-era technology** is capped at 5.0, so from WWII on the tech race is a clock, not a contest. Suggest a "technology lead" path (first to 5.0 by a margin) or a higher cap in late eras.
4. **The world is calm:** in 300 turns 94 nations lose 1 (743 wars, 889 peaces, 347 occupations, 57 cessions, 42 annexations); large powers barely change size. Suggest more decisive AI war goals if a livelier map is wanted.
5. **Rebels:** about 7 rebel events a turn, with 3-5% of the map rebel-held in the long run (more in the Napoleonic era). Check whether that is intended.
