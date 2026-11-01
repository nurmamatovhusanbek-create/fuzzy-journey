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

## What rules 4 does now (`TBInvest`)
- The budget's investment share no longer rolls a die per province per turn. Each province has two progress bars, economy and development (`inv_e`, `inv_d`, 0..1, saved). Every turn the bar gains
  `investment % × 0.05 × the ruler's gift` (economy) or a seventh of that (development), the same speed on average as the old die; a level is gained when a bar is full.
- **Returns shrink**: the people can work only so much economy (potential = 1 + people / 70, at most 5). Past it, each level above takes 0.6 off the efficiency, down to 10 %; the dossier says "Economy beyond its people".
  About 17 % of provinces start above their potential, so they grow slowly until their people grow.
- **Development waits for workers**: the bar does not fill while the next level lacks its workers (job fill under 90 %), as before.
- A hand-made development (the Develop verb) still gives the level at once and starts the slow bar again.
- The dossier of your provinces shows "Growth in progress: economy 62 % · development 18 %". The ring shows the worth.
- Not done: spending real gold on the share (the sliders are still shares of effort, not money); a visible trend arrow next to the worth.

## What we have, and how it maps
Our provinces have people, development (0–5), economy (0–5), districts with building levels (rules 2), stability and mood; the budget has research and "capital" sliders that spend on development; growth is organic and slow (`turn.gd`).
Nothing here is changed yet. To decide with the player: whether worth should rise with *accumulated investment* shown over time (a small trend next to the number), and whether the budget's investment slider should follow the AoC2 rule that income per point shrinks as economy nears population.
