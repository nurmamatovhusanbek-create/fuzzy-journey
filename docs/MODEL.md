# Economy, research, aggression and rebellion model (rules ≥ 1)

Everything here is gated on `rules >= 1`; rules 0 stays oracle-exact against the JS reference. One turn is half a year.
Constants live at the top of `godot/src/engine/turn.gd` and in `data.gd`; `tests/model.gd` and `tests/victory.gd` pin the behaviour.

## 1. Inflation

**Why.** Income is linear in provinces and nothing drained the treasury, so a large nation banked 800–1000 gold a turn and the
AI hoarded 160 000 (Napoleonic) to over a million (Roman). A flat "hold 5 000 gold" goal was reached in the first turns.

**Model.** Every turn each treasury loses a share `π` of its balance:

    π = clamp( base(era) + K · max(0, M/Y − M0), 0, 0.05 )

* `base(era)` = `(1 + annual)^0.5 − 1`, from `INFLATION_ANNUAL` (ancient 0.2 %/yr … discovery 1.5 % — the price revolution —
  Napoleonic 2 %, WWI/WWII 5 %, Cold War 4 %, modern 3 %).
* `M` = gold in all treasuries, `Y` = world gross income per turn. `M/Y` is "turns of world production sitting idle".
  Above `M0 = 1` each extra turn of idle production adds `K = 1.2 %` per turn (money supply outrunning goods — quantity theory).

**Steady state.** A treasury fed `s` per turn and taxed `π` per turn follows `G(t+1) = G(t)(1−π) + s`, which converges to

    G* = s (1 − π) / π

so a nation making 800/turn at π = 1.5 % settles near 52 000, not 160 000+, and one at 5 % near 15 000. The hoard is a
*level*, not a runaway; spending (recruiting, building, buying peace) beats saving. The budget screen shows the loss per turn.

## 2. Economic victory

Old rule: 5 000 gold + trade network + turn 30. With ~100 gold start and 1 000/turn income every big nation qualified.

New rule (all four must hold; checked for human players only):

1. **Income share** `income(n) / Y ≥ econ_goal`, where `econ_goal = clamp(1.8 × (largest start share), 0.10, 0.30)`.
   Supremacy is relative: the era's biggest economy must grow by ~80 %, which means swallowing neighbours or out-growing the field.
   (Start shares: 12–19 % in most eras, ≈5 % in the modern 190-nation world, hence the floor.)
2. **5 000 gold** in the treasury — and with inflation that needs `s·(1−π)/π ≥ 5000` sustained, i.e. a real surplus.
3. **Full trade network** (`trade_cnt = max_deals`).
4. **Turn ≥ 30.**

Progress is the minimum of the three ratios (share, gold, deals), so the goals screen shows the weakest link.

## 3. Technology race

* **Catch-up (diffusion).** Research is multiplied by
  `1 + 0.5·clamp((top − t)/2, 0, 1) − 0.25·clamp((t − avg)/1.5, 0, 1)`. A nation two levels behind the leader gains +50 %;
  one 1.5 levels above the world mean loses 25 % (diminishing returns). Followers close the gap, leaders cannot run away freely.
* **Victory.** Level 5.0 *and* a lead of ≥ 0.4 over the second-best nation, turn ≥ 40. Progress =
  `min(t/5, (t − rival)/0.4)`.
* **No race in late eras.** If the world already starts within 1.0 of the cap (`tech_start_top > 4.0` — WWI 4.3, WWII 4.7, Cold War 4.89)
  everyone arrives at 5.0 together, so the path is unavailable there (progress 0). In the early and mid eras it is a real race.

* **Measured pace (rules 3, 80 turns, nations with 8+ provinces).** Mean gain per nation: ancient 0.76, Roman 0.65, medieval 0.23, Mongol 0.20, Timurid 0.22, Discovery 0.17, gunpowder 0.18, Napoleonic 0.17, Victorian 0.10, WWI 0.07, WWII 0.04, Cold War 0.03, modern 0.04. The cost of a level is `60 · 1.08^(10·level) · 0.4`, so late levels cost 500+ points against a few points a turn. A flatter late curve would speed every era's AI and change the balance; left as it is, and the budget screen now shows the turns to the next level.

## 4. AI aggression ("World" selector on the nation-pick card)

Stored per game (`aggr_level`, saved). Level 1 is the original behaviour.

| level | mul | extra wars | declare cooldown | army edge to declare | edge to attack | peace bar |
|---|---|---|---|---|---|---|
| Calm | 0.5 | +0 | 20 | 1.30 | 1.25 | 0.20 |
| Normal | 1.0 | +0 | 10 | 1.15 | 1.10 | 0.20 |
| Warlike | 1.7 | +1 | 6 | 1.00 | 1.00 | 0.30 |
| Total war | 2.6 | +2 | 3 | 0.90 | 0.90 | 0.45 |

Declaration chance per eligible AI is `min(1, aggr·mul·0.5)`; the AI accepts peace when its want exceeds the peace bar, so
a hungry world refuses to stop. The Council's peace-readiness hint uses the same `TBAI.peace_bar` so UI and engine agree.

## 5. Rebellion

**When it appears.** Per province per turn, only where stability < 45:

    h = min(0.25, base · short^1.5 · (0.6 + 0.8·(1 − happy/100)))     short = (45 − stab)/40,  base = regime rebelChance + 0.02

at most 2 provinces per government per turn, never a capital. Quiet above 45; rare at 40; real danger below 20.

**What pushes stability.** Each province drifts (+2 up / −1.5 down per turn) toward the nation's target:

    target = ceiling − 0.5·war_weariness − 0.4·max(0, tax − 40) − overextension − 6·[at war] + ruler

* overextension = `18 · clamp((lands − s)/s, 0, 1.5)` with `s = 30 + 15·era` provinces (an empire twice that size loses 18, at most 27);
* land not held by right of birth (non-core) loses 12 until it has been held 40 turns, then assimilates into core;
* so a rebellion needs a cause: a lost war, a tax rate above 60, an overgrown empire or fresh conquests.

**How it ends.** Rebel provinces carry age and origin (`reb_age`, `reb_from`).

1. *Exhaustion* — without pay the militia melts: 4 % of the army above `6 + pop/200` per turn.
2. *Momentum* — fresh rebels spread to neighbours only for 12 turns, then hold what they have.
3. *Amnesty* — after 6 turns, once the army is below 20, unoccupied, with chance `4 % × (capital stability/60)` the province returns
   to its government (stability 45, chronicle "returned under an amnesty").
4. *Dissolution* — the origin has fallen, or 60 turns have passed: the province settles into self-rule (unowned, chronicle "revolt is over").
5. *Reconquest* — ordinary war against the rebel nation, as before.

**Measured** (300-turn AI-only games): ~75–100 uprisings per game in later eras, ~380 in the Ancient world; standing rebel provinces mostly 0–5
at any time. The old model gave 2 056 in 300 turns, concentrated on giant empires at tax 60 with the regime chance applied blindly.

## 6. Requests to a court, marches and fog of war (rules ≥ 1)
**Requests** (`engine/asks.gd`, command `ask`): a pact, alliance, marriage, trade deal, peace terms (white / cede / vassal), an ultimatum and a spy operation sent to an AI court
are *sent* now (the cost, diplomacy points or intel, is spent at once) and *answered at the start of the next turn*. The answer is rolled on the game's rng with the
likelihood the button showed (`TBAsks.chance`: the same sums as `TBDipView`, spy chance, ultimatum strength ratio, 3..97 %); an accepted request runs the real command
(`_force`), a refused one adds 5 grudge. The answer lands in the log as `ans`; the interface shows it as a flag notice until it is tapped away. One court request per
court at a time, one spy party per court.
**Marching** (`engine/march.gd`): an army may be ordered to any province it can reach, near or far, and walks there ONE province per turn. Route: land you hold, allies' land
(crossed in the same stride, never stopped in), a sea hop from a Port, and between your own Ports any distance (a longer voyage weighs more in the route's choice, but is one stride).
The order costs one move (the attack price when the target is an enemy next door) and is kept as a standing order in `g.marches` (`{n, at, to, k}`, saved): the army takes its
first stride at once, then one more at every end of turn (`TBMarch.advance`, before the AI plays) until it stands in the target or fights there. A hand-given move from the same
province replaces the order; an order whose army or way is gone lapses with a `march_stop` log entry. The map keeps a thin dashed line for each of your standing orders until it arrives.
Rules 0 and neighbour moves keep the old behaviour (they happen at once).
**Fog of war** (`engine/vision.gd`, view only): your armies always; another nation's armies when it is an ally / marriage / vassal / overlord, friendliness above 80
(50 at peace, +25 pact, +15 trade deal, +10 no grudge, minus the grudge), a spy report (6 turns after a successful operation), or when they stand next to a province you hold
(3 provinces round a Watchtower). Hidden armies get no marker, no figure on the cards and no outcome in a preview; the AI plays without fog.

## 7. Districts (rules ≥ 2, the default for new games)
Rules 2 turns a province into a *district* with room for several buildings and a development level that has to be staffed. Rules 0 and 1 keep the single building.
* **Slots** (`TBGame.b_slots`): `1 + floor(development / 2)`, plus one in the capital. A province holds one level per building type (`b_lv`, nine bytes per province;
  `building` / `b_level` still mirror its highest building for the old single view, the map's Buildings lens and the net protocol's old fields). A new type needs a free slot;
  upgrading a type already there does not. One construction per province at a time, as before.
* **Price** (`b_price`): a NEW type costs +20 % for each building already standing (`SLOT_COST_STEP`); upgrades keep the table price.
* **Demolish** (command `demolish`, free, no refund): frees the slot; the level is lost. The Build picker has a Demolish button on a building that stands.
* **People to staff it** (`job_income`, `POP_NEED = [0, 40, 80, 130, 200, 300]`): development level `d` pays `DEV_INCOME[d-1] + (DEV_INCOME[d] - DEV_INCOME[d-1]) x min(1, pop / POP_NEED[d])`.
  Below the need only that share of the top step is earned, so a rich district with too few people is a poor buy: farms (growth) and time fix it. Province cards show
  "N % staffed" on the Develop verb (red under 70 %).
* **Development is bought** (`develop`, key E): `develop_cost = 28 x (DEV_INCOME[d+1] - DEV_INCOME[d])` gold (about 30 turns to pay back), 1 move, instant; +20 people and +4 stability as before. The
  budget's Invest slider still rolls organic growth, now at 15 % of the old chance (was 50 %) and only where the next level would be 90 % staffed.
* **AI** (`TBAI._districts`): each court may raise one building a turn in its best province (a new type if a slot is free, else a level; weights favour farms where people are short, forts when
  at war) and buy development where the next level is at least 60 % staffed; courts with over 700 gold do both twice. This is the gold sink the first sim report asked for:
  300-turn maximum treasuries fell from 29,563 to 2,873 (Napoleonic), 13,797 to 2,175 (WWII), 14,568 to 3,206 (Cold War).
* **Overextension** (`OVEREXTEND_FROM = 60`, `OVEREXTEND_STEP = 0.004`): administration costs 0.4 % more for every province beyond 60 (a 200-province empire pays 56 % more for its governors). In the 26-game sim the Roman runaway shrank from 419 to 395 provinces; no other era changed noticeably.
* Tests: `tests/districts.gd` (slots, price, demolish, job fill, save and net round trips, AI builds several per province).

## 9. Rules 3: how quarrels spread, what a trade route needs, and endings that must be held
Rules 3 is the default for new games; games saved under rules 0-2 keep their old behaviour exactly (rules 0 is still oracle-exact). Everything below is gated on `rules >= 3`.

**Quarrels spread, weaker than the quarrel itself** (`TBDiplo.hurt`, `befriend`, `tie`). Every wrong done to a nation (war declared on it, a pact broken, an ultimatum it yielded to,
a failed spy operation, a province taken) goes through `hurt(victim, offender, amount)`. The victim takes `amount` as grudge; each other nation `o` takes
`amount x tie(o, victim) x (1 - 0.6 x tie(o, offender) / 0.5)`: an ally of the victim half of it (a war declared on an ally: 80 for the victim, 40 for its friend), kin by marriage 40 %, a vassal or
its liege 45 %, a trade partner 12 %; a friend of both is torn and feels about 40 % of that. Enemies of the victim who are not at war with the offender warm to it by a quarter of the amount.
Goodwill travels the same ties: a new alliance (16), marriage (20), pact (8) or trade deal (5) cools the partner's friends toward the actor by `amount x tie x 0.8`; a military bond (alliance, marriage)
makes the partner's enemies 30 % wary. Breaking an alliance costs 6 infamy (a pact 3): an oath broken is remembered by everyone. Grudges cool one point a turn and a grudge above 20 stops pacts (30 trade, 60 cuts a route).
When a court weighs a request: being at war with its friends costs -0.5 each (cap -1), friends in common +0.15 each (cap +0.45), and an alliance with no record of trust (no pact, trade deal, marriage or common war) -0.45,
so friendship climbs a ladder: peace, then a pact, then an alliance. The AI follows the same ladder and asks for a pact when an alliance would be refused. `tests/realism.gd` pins the numbers.

**A trade route is a venture** (`TBTrade`). Its yield, the same for both sides, follows a gravity model: `2 + 0.8 x sqrt(S) x reach`, `S = sqrt(market_a x market_b)`, `market = provinces x (6 + 3.5 x era)`,
`reach = 1 / (1 + (d / 0.7 rad)^2)` between the capitals (capped at 45). Opening one costs `15 + 3.5 x yield` gold and `4 + yield / 2` people, paid by the one who asks (an AI court that offers one pays too).
The partner's willingness is the usual temper + appetite plus three terms: your means -(1 - m), their means -0.6 (1 - m) and distance -0.4 (1 - reach), where the means
`m = inc^0.4 x gold^0.3 x men^0.3` is a weighted geometric mean of: persistent income (`net_ema`, net income smoothed over about 7 turns, 2 x the route's yield is full marks), a treasury of 1.5 x the fee, and people at 4 x the cost. A nation with
no surplus, no money or no men has no means at all (the geometric mean is zero) and a partner whose own means are under 0.15 cannot take part. A route lapses when either court's grudge reaches 60, or with a 35 % chance a turn
while either treasury is empty. Measured (300 turns, 13 eras x 2 seeds): AI routes per world fell to 40-55 % of rules 2 (the old rule signed nearly everyone up), no invariant broke, turn cost rose from 51 to 68 ms.

**Endings that must be held** (`TBTurn`). Domination, economic and technological victories need the position to be true for 8, 8 and 6 turns in a row (`HOLD`; `vic_hold`, saved); the goals screen shows the
card at 99 % and "Holding n of N turns" until then. Domination needs 25 % of the provinces AND 25 % of the world's people (a vassal's land and people count half), so an empire of empty land does not rule.
Total conquest still ends the game at once. **Diplomatic hegemony is no longer an ending**: it is the achievement "Concert of Nations" (8 alliances or 5 % of all nations, held 20 turns); games of rules 2 and older keep the old ending.
In the 26-game sim the old ending was reachable by an AI from turn 90 in six eras; the new alliance ladder cut AI alliances to a third and none of the endings is reached by an AI before turn 200.

**Alliance capacity** (`TBDiplo.max_allies`, rules 3). A promise to answer for another court is finite: a court holds `2 + sqrt(provinces) + era / 2` alliances (a modern realm of 11 provinces holds 7, one of 62 holds 10). Both courts must have room: `ally_room` is checked by the command, `TBCan`, the AI (`accepts_pact`) and the diplomacy view (`blocked = "allies"`). Before it a 9-province nation collected 28 allies and every run's diplomatic bar hit 100 %; with it allies stop at the cap.

**What idle people and envoys are for** (`TBMissions`, rules 3). *Veteran colony* (`settle`): 60 people and 1 move settle discharged soldiers in a province (+30 people, +8 stability), as Rome's coloniae, the Habsburg Military Frontier, Cossack hosts and Israel's Nahal did. *Embassy* (`embassy`): 2 envoys and 40 gold cool the grudge a court holds against you by 12, warm its friends a little (`befriend`) and add 5 intelligence (a resident ambassador was also the court's eyes). Neither is used by the AI; the advisor's "at cap" alerts (`idle_men`, `idle_dp`) point to them.

**Terrain follows the geography** (rules 3, `data/terrain.bin`, baked by `tools/bake_terrain.py`). Terrain used to be drawn from a hash of the province id (mountains in Holland). A new rules 3 game now reads one byte per province from mountain ranges (Alps, Himalaya, Andes, Rockies, Urals, Caucasus, Atlas and about 40 more), forests (Amazon, Congo, taiga, South-East Asia, eastern America), steppe (Eurasian steppe, Great Plains, Pampas, Sahel, the great deserts and tundra as open ground) and marsh (deltas, Pripet, Sudd, Low Countries); foothills are hills, and lowland is plains with a fifth rolling hills. Result: 28 % plains, 18 % hills, 19 % mountain, 17 % forest, 2 % marsh, 16 % steppe; every Swiss province is mountain and no Dutch one is hills. Rules 0 to 2 keep the hash (the reference engine and the oracle depend on it). A 39-game AI-only sim shows no change in wars, occupations or concentration.

**Speed.** Measured on the largest worlds: the AI's trade step asked every court for its verdict (about 470 microseconds each); it now ranks routes by their best possible worth and asks courts in that order, and `loyalty_terms` skips nations at peace. `income()` reads building levels directly and caches each province's distance to its capital (exact float64, never saved). Turn cost fell from about 190 ms to about 110 ms in the modern world with identical results (checked by hashing 80 turns of three eras before and after). The remaining cost is GDScript's per-province loop in `income()` and the AI's frontier scans; a native core would be the next step, only if a phone shows it is needed.

## 8. Where to look

| thing | code |
|---|---|
| inflation, stability target, hazard, catch-up, lifecycle, victory | `engine/turn.gd` |
| era inflation table, aggression table | `engine/data.gd` |
| AI use of the level | `engine/ai.gd` (`_nation`, `_maybe_declare`, `_fight`, `peace_bar`) |
| selector | `ui/pick_flow.gd` (card), saved as `cfg.aggression` |
| districts | `engine/game.gd` (`bl`, `b_slots`, `set_bl`, `b_price`, `job_income`), `engine/ai.gd` (`_districts`), `ui/build_picker.gd` |
| rules 3 | `engine/diplomacy.gd` (hurt, befriend, ties, alliance capacity), `engine/trade.gd` (yield, means, maintain), `engine/missions.gd` (veteran colony, embassy), `engine/turn.gd` (holds), `tests/realism.gd` |
| terrain | `tools/bake_terrain.py`, `data/terrain.bin`, `engine/world.gd` (terr), `engine/game.gd` |
| era starts and playtests | `tests/era_audit.gd`, `tests/playtest.gd`, `docs/PLAYTEST.md` |
| tests | `tests/districts.gd`, `tests/model.gd`, `tests/victory.gd`, `tests/chron_keys.gd`, `tests/dipview.gd` |
| balance matrix | `tools/sim.sh`, `docs/SIM_REPORT.md` |
