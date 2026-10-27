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
* Tests: `tests/districts.gd` (slots, price, demolish, job fill, save and net round trips, AI builds several per province).

## 8. Where to look

| thing | code |
|---|---|
| inflation, stability target, hazard, catch-up, lifecycle, victory | `engine/turn.gd` |
| era inflation table, aggression table | `engine/data.gd` |
| AI use of the level | `engine/ai.gd` (`_nation`, `_maybe_declare`, `_fight`, `peace_bar`) |
| selector | `ui/pick_flow.gd` (card), saved as `cfg.aggression` |
| districts | `engine/game.gd` (`bl`, `b_slots`, `set_bl`, `b_price`, `job_income`), `engine/ai.gd` (`_districts`), `ui/build_picker.gd` |
| tests | `tests/districts.gd`, `tests/model.gd`, `tests/victory.gd`, `tests/chron_keys.gd`, `tests/dipview.gd` |
| balance matrix | `tools/sim.sh`, `docs/SIM_REPORT.md` |
