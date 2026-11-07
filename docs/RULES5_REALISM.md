# Rules 5: a realistic scale (people, gold, armies)

Status: design + data (R1). Everything below is gated on `rules >= 5`; rules 0-4 and saved games keep their numbers. Rules 5 becomes the default for new games only when every mechanism below is rebalanced (R6).

## 1. The scale: how many real people one game person stands for

| eras | ratio (real : game) | why |
|---|---|---|
| ancient, Roman, medieval, Mongol, Timurid, discovery | 10 : 1 | small worlds (200-470 million real people); at 10:1 a province still holds thousands of people and a battle still moves a nation |
| gunpowder, Napoleonic, Victorian | 20 : 1 | 660 million to 1.2 billion real |
| WW1, WW2, Cold War, modern | 30 : 1 | 1.7 to 8 billion real: the 30:1 the player asked for |

So France is about 2.3 million game people today (68 million real), about 1.1 million in 1804 (22 million at 20:1), and about 0.6 million under Rome (6 million at 10:1). The ratio is stored per game (`g.scale`) and applies to people AND soldiers: one soldier in the game is 30 (or 20, or 10) real ones.

## 2. Where each province's people come from (`tools/pop_build.py` -> `data/pop_real.json`)

1. **Modern**: the 2024 population of every country (UN figures, rounded, from memory, +-5 %), shared over the country's provinces by `area^0.6 x lie of the land x climate x a fixed per-province city factor`. Deserts, mountains and the far north hold fewer people, plains more.
2. **Every other era**: 13 world regions (Western Europe, Eastern Europe + western Russia, Middle East, North Africa, sub-Saharan Africa, Central Asia + Siberia, South Asia, China, Japan + Korea, South-East Asia, North America, Latin America, Oceania) each have a real population estimate per era (McEvedy and Jones, HYDE, Maddison, from memory, +-15 %). A region's people are shared over its provinces by `(modern people)^0.6 x (area, land, climate)^0.4`, so the mass moves with history but the geography stays real.
3. **Every new game**: each province is jittered at random (+-20 %), then each nation's provinces drift together by +-6 %. A game of 1914 and a game of today therefore never hold the same figures, and neither do two games of 1914.

World totals the data gives (real, millions): -218: 207, 117: 268, 1096: 342, 1300: 387, 1400: 381, 1492: 473, 1700: 660, 1804: 975, 1850: 1,208, 1914: 1,728, 1939: 2,053, 1947: 2,188, 2024: 8,027 (the rest of the 8.1 billion is micro-states and territories with no province of their own). Limits: nations inside a region get their share from today's geography, so e.g. 1804 France is 22.5 million (history: about 29), 1804 Germany 18 (about 25), Italy 14 (about 18): the right order, not the exact figure. A per-nation correction table can be added later.

## 3. People: growth with a ceiling (R2)

Per province per turn (half a year):

    growth = pop x r(tech) x happiness x order x farms x (1 - pop / K)

* `r(year, tech)`: net natural growth per year, from the CALENDAR so the world's people follow history whatever the game does with technology (0.05 % in the ancient world, 0.1 % around 1000, 0.05 % in the plague and Mongol years around 1300, 0.25 % in 1500, 0.45 % in 1800, 0.6 % in 1850, 0.8 % in 1914, 1.7 % in 1950, 1.2 % in 2000, 0.9 % today, falling towards 0.2 % by 2100), times a technology factor `0.75 + 0.12 x tech` (0.75 to 1.35). Half of it per turn.
* `K`, the ceiling the land can feed: `modern people x (0.25 + 0.17 x tech) x (0.85 + 0.06 x development) x (1 + 0.05 x farm levels)`. A province above its ceiling shrinks. Development and technology raise the ceiling; nothing else can.
* A drained levy pool, a siege and an occupation cost people (famine, flight): 0.1-0.3 % a turn.
* The old cap of 2,000 per province is gone; people are an integer in a 32-bit array (a Chinese province today is about 3 million game people).

## 4. Gold: what people make (R3)

* Output per person per turn: `y(tech) = 0.25 x e^(0.42 x tech)` gold (so a modern worker makes about 5.4 times an ancient one; real figures are 21 times, the game keeps its eras comparable).
* A province's output = workers (45 % of its people) x `y` x a development, economy and building factor x order. Taxes take a share of it (the tax slider), as before.
* Every PRICE is relative to the thing it buys, never a fixed number: a project or building costs turns of the province's own output; soldiers cost a multiple of a worker's output; national decrees cost turns of national income; the AI's "rich enough to spend" thresholds are turns of income. This is what keeps one rules set honest from 2,000 people to 3 million.
* Gold is shown with K and M (125k, 3.2M).

## 5. Soldiers: a share of the people, laid out like Age of Civilizations 2 (R4)

* **Start**: every nation's whole standing army stands in its **capital province**, and nowhere else. The rest of its provinces are empty; the nation must recruit in provinces and march armies where it needs them (the AoC2 way).
* **Standing army at the start** = people x a peacetime share by era (about 0.4 % ancient and medieval, 0.8 % gunpowder, 1.0 % Napoleonic, 1.5 % WW1, 2.0 % WW2, 1.2 % Cold War, 0.5 % today) x the ruler's bent (0.6 to 1.6).
* **Levy pool of a province** = people x the share that can be raised in a war (8 % ancient, 6 % medieval, 5 % gunpowder, 8 % Napoleonic, 15 % WW1, 18 % WW2, 8 % today) x order; refills 6 % of its cap a turn; recruiting empties it (a drained province grows slowly and sulks, as in rules 4).
* **Upkeep** of a soldier = 1.5 workers' output per turn; men under arms also stop working (the work-loss term of rules 4, unchanged).
* **Army cap per province** scales with the province's people instead of a fixed 65,000.

## 6. The rest follows (R5)

Development staffing (`POP_NEED`), province worth (peace-table prices), victory thresholds, standing stars, war score and casualties are rewritten as ratios (to people, to income, to the world), so they hold at any scale. The formulas are listed as each lands, with the measured effect on the 13-era simulation (`tools/sim.sh`).

## 7. Work order

R1 data and this design (done) -> R2 people in the engine -> R3 gold and prices -> R4 soldiers -> R5 ratios -> R6 numbers on screen, tests, simulation of all 13 eras, default.
