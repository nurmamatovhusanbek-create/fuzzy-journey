# Province worth and investment

## What the ring shows now
The ring's centre shows the province's **worth** instead of its army (the army is on the map as the counter, and the move bar shows what is sent): `TBGame.province_value(p)` = 1 + 0.1 × economy + 2 × development + 0.001 × people, the capital ×4 (rules 4), rounded.
The same number prices the province in the peace table, so what a province costs at peace and what the ring says agree.

## AoC2 investment: what could be confirmed
I could not open the AoC2 wiki from this session (the host is outside the allowed network), so this is only what a web search returned, all community-sourced:
- Each province has an economy level that rises with gold put into investment, or with the budget's investment slider; if the slider is cut low enough, the economy declines.
- When the population is high against the economy, manual investment gains little; at economy 99 a very populous province can stop growing (players suggest ~140 people per economy point as the ratio at which it turns).
- Tax follows population, production follows economy (and possibly development); the income gained per investment shrinks as the economy approaches the population.
- Recruiting takes from the province's population.
- Development was a separate level that unlocks buildings (a patch note); no formula found.
Sources: the Age of Civilizations wiki (Economy), the Steam discussions of Age of History II, the Age of Civilizations forum thread "economy bug".

## What we have, and how it maps
Our provinces have people, development (0–5), economy (0–5), districts with building levels (rules 2), stability and mood; the budget has research and "capital" sliders that spend on development; growth is organic and slow (`turn.gd`).
Nothing here is changed yet. To decide with the player: whether worth should rise with *accumulated investment* shown over time (a small trend next to the number), and whether the budget's investment slider should follow the AoC2 rule that income per point shrinks as economy nears population.
