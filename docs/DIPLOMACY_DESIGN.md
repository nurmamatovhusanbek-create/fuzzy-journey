# Diplomacy logic (rules 4)

Problem found in play: a country in North America offered a non-aggression pact to the Timurids. Before this change the AI courts picked any country, anywhere, at random (`TBDiplo.ai_offer`),
and a pact asked of a far court was weighed like one asked of a neighbour.

## Contact: who knows whom (`TBDiplo.contact`)
- **border**: the two countries share a border.
- **near**: the capitals are within half of the *sphere*; **far**: within the sphere. The distance is the angle between the capitals, 0 (same place) to 1 (the far side of the world).
- The **sphere** grows with the era of the country: 0.12 + 0.06 × era (0 ancient … 4 modern): 0.12 to 0.36. Between the larger of the two spheres decides.
- Ties already made (any relation but plain peace, or a trade route) keep two countries in contact.
- **none**: everything else. A court does not write to a country it has no contact with.

## What a court offers (`TBDiplo.offer_fit`, weights 0 to 1, drawn by weight)
| offer | border | near | far | note |
|---|---|---|---|---|
| non-aggression pact | 1.0 | 0.5 | 0.12 | security between neighbours |
| alliance | 1.0 | 0.8 | 0.25 | only with a *shared concern*: a war both fight, or a stronger third country bordering both. Without one, only a neighbour with whom a pact already stands (0.2) |
| trade deal | 0.8 | 0.8 | 0.5 | |
| royal marriage | 0.7 | 0.6 | 0.15 | AI-to-AI marriages need ≥ 0.5 (border or near) |

## What a court accepts (`pact_terms`, shown on the button as "Too far apart to matter to them", `dv_far`)
- pact: near 0, far −0.3, none −0.9; alliance: near −0.15, far −0.7, none −1.5 (added to the existing sum; the bar stays 0.45).
- AI-to-AI pacts were already between neighbours (`TBAI._diplomacy` works along the front line), so they stay as they are.

## Not done here
- Existing alliances in saves are not removed.
- Trade routes keep their own distance rules (`TBTrade`).
- Tests: `tests/diplo_logic.gd` (contact, no offer out of contact in 3000 turns of offers, alliances only with a concern, the far term; rules 3 untouched), `tests/dipview.gd` (view mirrors engine).
