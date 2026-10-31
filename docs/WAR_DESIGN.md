# War, recruitment and peace: design for rules 4

Status: design contract, agreed with the owner in the Q&A of this session. Every step below is built, tested and simulated on its own, then pushed, before the next one starts.

## 0. What the owner decided

| Topic | Decision |
|---|---|
| Troop number | One picker everywhere: slider + presets (10 / 25 / 50 / 75 / 100 %) + a typed number. Used by Move/Attack and by Recruit. |
| Recruiting | Per-province levy pool (men that province can raise), costs gold, refills with population. Overdrawing a province hurts its growth and mood. |
| Upkeep | Gold per soldier each turn **plus** lost taxes/output from men away from work. |
| Battles | Predictable, with a shown range (best / expected / worst). No dice. |
| Peace | A peace screen like Age of Civilizations II: spend the **war score** you earned on demands (provinces, gold, vassalage). The AI accepts or refuses by the same rule. War exhaustion makes both sides yield with time. |
| Occupation | Occupied provinces earn war score every turn, pay you part of their tax, and their resistance falls the longer you hold them. Too few troops: rebels. Peace turns them into yours. |
| War systems | Supply and attrition, morale and war exhaustion, forts and sieges, casus belli and war goals. |
| Allies | A call to arms; each ally answers by loyalty, danger and distance. You can ask yours and refuse theirs, at a cost to trust. |
| AI | Same rules and the same numbers as the player, smarter targets. No cheating bonuses. |
| Old saves | Not a goal. Rules 4 becomes the default for new games. Rules 0 stays only so the JS-reference oracle and the old tests still pass. |

## 1. Sources and honesty about them

- Age of Civilizations II is a closed-source mobile game and its wiki (fandom) is not reachable from this build environment, so the AoC2 items below come from what the game is known to do: manpower tied to provinces, an army moved with a chosen number, a peace window where occupied provinces and demands are bought with a war score, AI nations that also demand what they hold, a treaty that can be refused. Detail I could not verify is marked *ours*.
- Forum and wiki reading for Europa Universalis, Hearts of Iron and Victoria supplies the *ideas* (war score from occupation + battles + goals, war exhaustion fed by attrition, battles and occupation, supply limits per province). Numbers there are player reports, not specifications, so every constant here is **ours** and is tuned by simulation.
- Real-life anchors used for the maths: Lanchester's square law for concentration, Clausewitz's culminating point (an offensive weakens as it runs away from its base), the logistic limit (an army cannot be larger than what the ground it stands on can feed), and mobilisation ratios (pre-industrial states sustained about 1-3 % of their people under arms, industrial states 5-10 %, total war peaks of 10-15 %).

## 2. The troop picker (R4-A)

One reusable control `TBTroopPicker(min, max, value, presets)` :

- slider (integer steps, step grows with the maximum so it stays usable), preset buttons, a text field that accepts digits only, and a live caption (`3 200 of 7 450`, and for a move "leaves 4 250 behind").
- Move/Attack: replaces the 25/50/75/100 % row in the province card and the command ring. The `troops` field of the `move` command already exists; the picker feeds it an absolute number (clamped to `army - 1`). `OrderFlow.troops_for` returns that number, previews and the arrow use it.
- Recruit: `amount` of the `recruit` command is no longer clamped to 5..30. Under rules 4 it is `1 .. pool[p]` and the gold cost is shown live.
- Touch: the slider thumb and the buttons are at least 44 px high at every UI scale; the typed field opens the platform keyboard.
- Keyboard: `[` `]` change by one step, Shift by ten steps, Enter confirms, Esc cancels.

## 3. Levy pools and upkeep (R4-B)

State per province: `levy[p]` (men available now, float32 in the save as int).

- Capacity: `cap[p] = floor(pop[p] * rate(era) * (1 + 0.25 * barracks_level[p]) * regime_factor * stability_factor)`. `rate(era)` follows the mobilisation anchors above (ancient/classical 1.5 %, medieval 2 %, early modern 3 %, industrial 5 %, modern 7 % of the province's people). The unit is whatever `pop` counts, tuned so a typical start army equals the current one.
- Refill: `levy += cap * 0.10` each turn (about a decade of turns to refill from zero at 1 turn = 1 year; faster in eras with shorter turns because the refill is per turn, not per year: **ours**, tuned in the sim), never above `cap`.
- Recruit: the player picks `amount <= levy[p]`. Gold cost = `amount * unit_cost(era) * regime.recruitCost`. The men appear in the province as a **raw** army that trains: for 2 turns they fight at 60 % (a training state per province, `raw[p]`, shown in the tip).
- Overdraw: drawing a province under 25 % of its capacity cuts its population growth by 50 % and its happiness by 8 for 5 turns (a village without its young men).
- Manpower becomes the sum of pools. The nation figure on the HUD is `sum(levy)`, the existing nation `manpower` resource is retired in rules 4.
- Upkeep: `pay = army_total * pay(era)` gold, plus a **production loss** `loss[p] = army_stationed[p] * 0.4 * output_per_head[p]` charged to the province the men come from: units remember their home province in aggregate (`home_share`), a simple model: men away from work reduce tax by `0.4 * (army / pop)` of the nation's tax. Both lines are shown separately in the budget.
- Mercenaries (`hire`) stay: no pool, 2.5x gold, dismissed when unpaid.
- Disband: `disband(p, amount)` returns 60 % of the men to the province's pool and stops their pay (new command).


### 3.1 As built (R4-B, first slice)

Measured on the real start data (`tests/probe_levy.gd`): province population 100-199 (median 139), start army about 0.19 of the population, so the "pop" figure is an index, not people; the constants below are calibrated to it, not to real millions.

- `levy_cap(p) = floor(pop * rate(era) * (0.5 + stab/200)) * 1.25 with an armoury`, rate by era 0.22 / 0.28 / 0.34 / 0.42 / 0.50 (ancient to modern, the era the owner has reached). Floor 4.
- Refill each turn `max(1, cap / 10)`; none while the province is held by an enemy. A new game starts with 35 % of the cap ready. A ceded, conquered or settled province starts at 0.
- Drained (pool under a quarter of the cap): population growth halves and happiness falls 1 per turn.
- Recruit: 1 .. min(pool, room under 65 000). Gold = `(fee + 0.6 per man) * regime * (0.5 armoury)`; no nation-wide people cost any more. The nation's `manpower` is the sum of the pools, so every old read of it still works.
- Men under arms cost taxes and production: `loss = min(0.35, 0.45 * under_arms / people)`, shown in the budget as `workLoss`.
- The AI raises up to 20 (30 at war) men from a province with a pool; provinces with an empty pool are skipped.
- Tests: `tests/levy.gd` (engine), the recruit card and the preview chip in `tests/ui_cmdcard.gd`, the control in `tests/troop_picker.gd`.

## 4. Movement and splitting (R4-C)

- A move sends exactly the picked number; what is left stays. Armies of the same nation in one province merge into the province's stack (already the model: `army[p]`).
- Marches over several provinces keep their number (existing `TBMarch`). The remaining march shows the number in the order chip.
- Movement points stay as they are; attacking costs more (existing `MP_ATTACK`).
- Forced march: spending double points moves one extra province but costs 3 % of the men (exhaustion on the road). **ours**.

## 5. Battles with a range (R4-D)

Today `resolve_combat` is one deterministic round: attack vs defence strength, loser fights to the end. Rules 4 keeps determinism and adds structure the player can read:

- Strength: `S = men * combat_mul * terrain * morale * supply * (1 + general)`; `morale` and `supply` are new factors in 0.5-1.1.
- Lanchester: a battle runs 3 rounds; each round each side loses `0.18 * enemy_strength / own_strength^(0.5)` of its men (bounded 4-35 %), so a 2:1 army wins with fewer losses than a 1:1 and a hopeless attack stops after the first round (retreat when morale < 25 %).
- Preview shows three outcomes: best (+10 % strength), expected, worst (-10 % strength), with the win line between them; no random number is drawn.
- Retreat: the loser's survivors fall back to the nearest own province (new), instead of vanishing: `lost = casualties`, `retreat = survivors * 0.8`.

## 6. Supply, attrition and forts (R4-E)

- Existing: `supply_limit(p)` and `attrition(p)` (armies above the limit in foreign land waste away at 7 % of the excess). Rules 4 adds: friendly land counts double, a connected road/port chain to a province you own is *supplied*; a stack more than 3 provinces from supply loses 2 % per turn (the culminating point). Occupying the enemy's depot province (`supplycamp`) cuts their supply.
- Forts: `fortress` gives level 1-2 (existing +50 / +80 % defence). Rules 4: a fort province must be **besieged** — an attacker who wins the field battle starts a siege (`siege[p]` counter) instead of taking the province at once; the garrison holds for `1 + fort_level` turns, shortened by `attacker_men / garrison`. Capital holds one turn longer. A relieving army ends the siege.
- Everything above is visible: the province tip lists supply status, siege counter and what attrition is expected next turn.

## 7. Morale and war exhaustion (R4-F)

- Army morale per nation `morale[n]` in 0-100: +1 per turn at peace, -(losses/army) * 40 per lost battle, +10 per won battle, -2 per turn of attrition. Below 30 the nation's armies fight at 70 % and sometimes desert (1 %/turn).
- War exhaustion `exh[n]` in 0-100 grows with the length of the war, casualties as a share of the nation's pop, occupied own provinces, and unpaid armies; it lowers stability and happiness and raises the AI's willingness to take peace (see section 9). Decays 3/turn at peace.
- The HUD already has a Wars gauge; exhaustion becomes its tooltip line and a filled bar on the peace screen.

## 8. Casus belli and war goals (R4-G)

Existing: `TBDiplo.on_declare` already knows a `cb_kind` and infamy. Rules 4 makes it explicit:

- Declaring war needs a **war goal**: *conquer* province(s) that the nation holds a claim on, *humble* (gold + prestige), *liberate* an ally's land, *vassalise*, or *defend* when attacked. A goal costs less infamy when it is a claim (claims come from history, borders, events and `forge claim`, a 6-turn mission). A war without a cb costs 25 infamy and 10 stability.
- The goal sets the war score you need: conquest of the province you hold a claim on is 25 % cheaper in the peace screen; goals you pursue earn +10 % score.
- Only goals declared at the start (or added by an ally joining) can be spent in the peace screen at the discount.

## 9. War score and the peace screen (R4-H)

Existing: `war_score[n*N1+t]`, `cede`, `vassal`, `accepts_peace`. Rules 4:

- Earned score (cap 100 per side): occupation `+province_value%` on capture, then `+0.5 * value%` per 5 turns held (up to 50 % of the value); battles won `+ casualties_inflicted / enemy_total_men * 30`; sieges won `+4`; capital taken `+15`; exhausted enemy `+exh/5`.
- The peace screen (a new window): the winner ticks demands from a list — each occupied province (cost = its value in %, discounts for goals and cores), gold (`1 point per 2 % of the enemy's yearly income`), release/vassalise (`50`), disarm (`20`), war reparations in time (`10 turns of tribute`). The sum must not exceed the war score (with exhaustion bonus).
- The loser may offer peace with demands to the winner too (white peace, small tribute) when it is the one ahead.
- AI acceptance: `accept = score_asked <= my_war_score_equivalent + 0.8 * exh_me - 0.4 * exh_them + 20 * (alliance_help)`; below the threshold the AI says why in one line.
- Peace sets a truce (existing 12 turns) and a short 'peace shock' stability dip for the winner proportional to the land annexed (overextension).

## 10. Occupation (R4-I)

- Occupation yields 50 % of the province's tax to the occupier (existing `occupier[p]`), 0 to the owner; `occ_turns[p]` counts up.
- Resistance: `unrest[p]` starts at 40 and falls 2/turn while the garrison is >= `pop[p] * 0.06`, rises 3/turn otherwise; at 100 the province revolts to the rebels (existing rebel nation) with a few men. Resistance is visible in the tip.
- The owner can liberate by winning the battle back (existing); a peace without taking it returns it automatically.

## 11. Alliances and calls to arms (R4-J)

Existing: allies join automatically when the target's ally is attacked (`_c_declare_war` loop). Rules 4:

- A war creates a **call**: each ally of the attacked (and of the attacker) gets a call to arms. Willingness `w = 0.5*trust + 0.3*threat_to_self + 0.2*shared_border - 0.4*distance - 0.3*exh_self`; AI answers yes if `w > 0.5` and its dp/truce state allows. A human sees a prompt with the factors.
- Refusing an ally's call costs trust (-20 relation, -10 prestige); joining a war you did not choose costs nothing. Ripple notice (existing) shows the result.

## 12. AI (R4-K)

The AI uses the same commands. New logic only where the decisions are new:

- recruit by pool and by threat; keep a reserve at the capital; never draw a province under 40 % of cap in peace.
- choose a target by `value / (defenders * terrain + distance)` among provinces it holds a claim on; stack before attacking (Lanchester); retreat damaged stacks to a fort.
- peace: sue when `exh` high or war score negative, accept when the formula in section 9 holds.
- difficulty only changes how many mistakes it is allowed to make, never its income.

## 13. Build order

1. R4-A picker (UI, `OrderFlow`, recruit command), no rules change yet — reusable at once.
2. R4-B levy pools + upkeep; rules 4 flag; save fields; AI recruit.
3. R4-C disband, forced march, retreat paths.
4. R4-D battle rounds + range preview.
5. R4-E supply and sieges.
6. R4-F morale and exhaustion.
7. R4-G war goals / casus belli.
8. R4-H war score and the peace screen.
9. R4-I occupation resistance.
10. R4-J calls to arms.
11. R4-K AI.
12. Balance: sims across all eras with fixed seeds; compare the old rules; report.

Each step: engine change behind `g.rules >= 4`; command schema in `commands.gd` and `can.gd`; tests (engine + UI); `tools/sim.sh` before and after; `docs/CHANGELOG.md`; commit and push. Rules 0 must stay bit-identical to the JS reference (`tools/oracle.sh`).
