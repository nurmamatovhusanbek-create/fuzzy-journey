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

## Open items (design decisions, not changed)
1. **Economic victory is still the fastest path (about turn 30)** for the largest nations, because the AI giants fill their trade deals and hoard. The root cause is economic: income is linear in provinces and nothing drains it.
2. **Gold hoarding:** one or two nations end up holding almost all the world's gold (napoleonic turn 100: 53,000 of 57,000). Maximum treasuries reach 160,000 (Napoleonic) and over 1,000,000 (Roman). Suggest an AI gold sink (buildings, decrees, bribes) or an upkeep/inflation term.
3. **Late-era technology** is capped at 5.0, so from WWII on the tech race is a clock, not a contest. Suggest a "technology lead" path (first to 5.0 by a margin) or a higher cap in late eras.
4. **The world is calm:** in 300 turns 94 nations lose 1 (743 wars, 889 peaces, 347 occupations, 57 cessions, 42 annexations); large powers barely change size. Suggest more decisive AI war goals if a livelier map is wanted.
5. **Rebels:** about 7 rebel events a turn, with 3-5% of the map rebel-held in the long run (more in the Napoleonic era). Check whether that is intended.
