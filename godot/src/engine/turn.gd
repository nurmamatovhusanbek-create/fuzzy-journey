## End-of-turn pipeline: AI -> world tick -> rebels -> time -> victory. Deterministic.
class_name TBTurn
extends RefCounted

const D = preload("res://src/engine/data.gd")
const DEF_CAP := 50

## ---- economy, tech race, unrest: tuning (rules >= 1). The reasoning behind each number is in docs/MODEL.md.
const INFL_K := 0.012                   # extra inflation per turn of world production sitting in treasuries above INFL_M0
const INFL_M0 := 1.0
const INFL_MAX := 0.05
const STAB_OVEREXT := 18.0              # stability lost by an empire 1.5x the size the era's administration can hold
const STAB_SPEED_UP := 2.0              # a province's stability moves toward the nation's target by at most this per turn...
const STAB_SPEED_DOWN := 1.5            # ...and at most this when falling
const CONQUEST_UNREST := 12.0           # stability target lost on land the nation does not hold by right of birth (core)...
const ASSIMILATE_TURNS := 40            # ...until it has been held this long, when it becomes core
const REB_THRESHOLD := 45.0             # rebels can only rise where stability is below this
const REB_BASE := 0.02                  # even the sternest regime sees riots where stability has collapsed
const REB_HAZARD_CAP := 0.25
const REB_MAX_PER_TURN := 2             # one government loses at most this many provinces to a single turn of uprisings
const REB_MOMENTUM := 12                # turns during which fresh rebels can still spread
const REB_RECON := 0.04                 # per-turn chance a calm rebel province takes the amnesty (scaled by the government's stability)
const REB_DISSOLVE := 60                # turns after which a rebel province with no one to fight settles into self-rule
const CATCHUP_MAX := 0.5                # research bonus of a nation 2 levels behind the leader (diffusion of knowledge)
const LEADER_DRAG := 0.25               # research malus of a nation 1.5 levels above the world mean (diminishing returns)

## a nation's gross income share, tech stats and the era's goals; cheap enough to call every turn
static func refresh_world(g: TBGame) -> void:
	if g.rules < 1: return
	var y := 0.0; var top := 0.0; var second := 0.0; var sum := 0.0; var cnt := 0
	var best := 0.0
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		var gi := float(g.income(n)["gold"])
		y += gi; best = maxf(best, gi)
		var t: float = g.tech_level[n]; sum += t; cnt += 1
		if t > top: second = top; top = t
		elif t > second: second = t
	g.world_y = y; g.tech_top = top; g.tech_second = second; g.tech_avg = sum / maxf(1.0, cnt)
	if g.econ_goal <= 0.0 and y > 0.0:
		g.econ_goal = clampf(1.8 * best / y, 0.10, 0.30)      # the era's biggest economy must grow by ~80% to count as supreme
	if g.tech_start_top <= 0.0: g.tech_start_top = top

## per-turn share of every treasury lost to inflation: the era's base rate plus a money-supply term
static func inflation(g: TBGame) -> float:
	if g.rules < 1: return 0.0
	var m := 0.0
	for n in range(1, g.N1):
		if g.alive[n] != 0 and n != g.rebel: m += g.gold[n]
	var ratio: float = m / maxf(1.0, g.world_y)
	return clampf(D.infl_base(g.era_id) + INFL_K * maxf(0.0, ratio - INFL_M0), 0.0, INFL_MAX)

## the stability a nation's provinces drift toward (rules >= 1): the regime's ceiling minus what war, taxes and overextension cost
static func stab_target(g: TBGame, n: int, weary: float, at_war: bool, stab_ceil: int, lands: int) -> float:
	var tax: int = g.budget[n * 4]
	var s_era: float = 30.0 + 15.0 * g.era[n]
	var over: float = clampf((lands - s_era) / s_era, 0.0, 1.5) * STAB_OVEREXT
	var t: float = stab_ceil - weary * 0.5 - 0.4 * maxf(0.0, tax - 40.0) - over - (6.0 if at_war else 0.0) + TBRulers.stab_add(g, n) * 8.0
	return clampf(t, 10.0, float(stab_ceil))

## the per-turn chance a province rises: zero above stability 45, rising with the 1.5 power of the shortfall, worse when the people are unhappy
static func rebel_hazard(g: TBGame, p: int, base: float) -> float:
	var short: float = clampf((REB_THRESHOLD - g.stab[p]) / 40.0, 0.0, 1.0)
	return minf(REB_HAZARD_CAP, base * pow(short, 1.5) * (0.6 + 0.8 * (1.0 - g.happy[p] / 100.0)))

## research multiplier: backward nations catch up, leaders slow down
static func catchup(g: TBGame, n: int) -> float:
	var tl: float = g.tech_level[n]
	return 1.0 + CATCHUP_MAX * clampf((g.tech_top - tl) / 2.0, 0.0, 1.0) - LEADER_DRAG * clampf((tl - g.tech_avg) / 1.5, 0.0, 1.0)

static func end_turn(g: TBGame) -> PackedInt32Array:
	if g.rules >= 1: TBMarch.advance(g)
	TBAI.run(g)
	_tick(g)
	rebel_turn(g)
	g.turn += 1
	g.month_idx += 6
	if g.month_idx >= 12:
		g.month_idx -= 12
		g.year += 1
	if g.rules >= 1:
		TBGenerals.tick(g)
		TBRulers.tick(g)
		TBDiplo.tick(g)
		TBTrade.maintain(g)
		TBAsks.resolve(g)
		TBStats.record(g)
		TBRealms.tick(g)
		TBEvents.run(g)
	check_victory(g)
	return g.take_dirty()

static func _tick(g: TBGame) -> void:
	var P := g.P
	var N1 := g.N1
	# NAP expiry
	for k in g.nap_expiry.keys():
		if g.nap_expiry[k] <= g.turn:
			var a: int = int(k) / N1
			var b: int = int(k) % N1
			if g.get_rel(a, b) == D.REL_NAP: g.set_rel(a, b, D.REL_PEACE)
			g.nap_expiry.erase(k)
	# per-nation war flag (cache: relations do not change inside this loop)
	var warflag := PackedByteArray(); warflag.resize(N1)
	for n in range(1, N1):
		warflag[n] = 1 if g.war_cnt[n] > 0 else 0
	# defence accrual + construction (+ rules>=1: long occupation annexes the province)
	for p in P:
		var o := g.owner[p]
		if g.rules >= 1:
			var oc := g.occupier[p]
			if oc != 0:
				if g.occ_turns[p] < 250: g.occ_turns[p] += 1
				if o != 0 and g.occ_turns[p] >= (10 if g.capital[p] != 0 else 5) and g.get_rel(o, oc) == D.REL_WAR:
					if g.human[o] != 0 or g.human[oc] != 0 or g.capital[p] != 0: g.log.append({"turn": g.turn, "kind": "annexed", "a": oc, "b": o, "p": p})
					g.cede(p, oc); g.army[p] = maxi(g.army[p], 6); g.stab[p] = mini(g.stab[p], 50); g.touch(p)
					continue
			else:
				g.occ_turns[p] = 0
		if g.rules >= 1 and g.army[p] > 20:
			var lost := g.attrition(p)
			if lost > 0:
				g.army[p] -= lost; g.touch(p)
		if o != 0 and warflag[o] == 0 and g.defense[p] < DEF_CAP:
			g.defense[p] += 1
		if g.b_building[p] != 0:
			g.b_turns[p] -= 1
			if g.b_turns[p] <= 0:
				if g.rules >= 2: g.set_bl(p, g.b_building[p], g.bl(p, g.b_building[p]) + 1)
				elif g.building[p] == g.b_building[p]: g.b_level[p] += 1
				else:
					g.building[p] = g.b_building[p]; g.b_level[p] = 1
				if g.rules >= 2 and o != 0 and g.human[o] != 0: g.log.append({"turn": g.turn, "kind": "built", "a": o, "p": p, "b": int(g.b_building[p]), "lv": g.bl(p, g.b_building[p])})
				g.b_building[p] = 0; g.touch(p)
	var rebels_to_spawn: Array = []
	g.infl = inflation(g)
	var y_sum := 0.0
	for n in range(1, N1):
		if g.alive[n] == 0: continue
		var own := g.owned(n)
		if own.is_empty():
			g.eliminate(n); continue
		var inc := g.income(n)
		if g.rules >= 3:                                                                      # persistent income: the surplus smoothed over ~7 turns (trade routes need it)
			var e0: float = g.net_ema[n]
			g.net_ema[n] = float(inc["net"]) if e0 == 0.0 else e0 * TBTrade.EMA_KEEP + float(inc["net"]) * (1.0 - TBTrade.EMA_KEEP)
		var reg: Dictionary = D.REGIMES[g.regime[n]]
		var era: int = g.era[n]
		var gold_before: float = g.gold[n]
		g.gold[n] = maxf(0.0, g.gold[n] + inc["net"])
		if g.rules >= 1 and n != g.rebel:
			g.gold[n] *= 1.0 - g.infl                          # idle money loses value
			y_sum += float(inc["gold"])
		if g.rules >= 1 and g.human[n] != 0 and gold_before > 0.0 and g.gold[n] <= 0.0: g.log.append({"turn": g.turn, "kind": "bankrupt", "a": n})
		g.manpower[n] = minf(inc["manCap"], g.manpower[n] + inc["manpower"])
		if g.rules >= 3 and g.human[n] != 0: g.mp[n] = minf(TBAdvisor.mp_cap(g, n), g.mp[n] + TBAdvisor.mp_gain(g, n))      # a human ruler's clerks grow with the realm
		else: g.mp[n] = minf(6 + era * 2, g.mp[n] + 1 + era * 0.4)
		if g.rules >= 1 and g.human[n] == 0: g.mp[n] = minf(8 + era * 2, g.mp[n] + 1.2)    # AI acts less cleverly: extra action points
		g.dp[n] = minf(4 + era * 2, g.dp[n] + 1 + era * 0.3 + (TBRulers.dp_add(g, n) if g.rules >= 1 else 0.0))
		if g.rules >= 1: g.intel[n] = minf(20.0, g.intel[n] + 0.8 + minf(1.5, own.size() / 40.0))
		var cap_shock: bool = inc["capLost"] and g.cap_lost[n] == 0
		g.cap_lost[n] = 1 if inc["capLost"] else 0
		var weary := 0.0
		var at_war := false
		var o_end: int = N1 if g.war_cnt[n] > 0 else 1
		for o in range(1, o_end):
			var i := n * N1 + o
			if g.rel[i] != D.REL_WAR or g.alive[o] == 0: continue
			at_war = true
			g.war_turns[i] += 1
			weary = maxf(weary, minf(40.0, g.war_turns[i] * 1.5))
			var tot := 0.0; var occ := 0.0
			for q in g.owned(o):
				var v := g.province_value(q)
				tot += v
				if g.occupier[q] == n: occ += v
			g.war_score[i] = clampi(int(round(occ / (tot if tot != 0.0 else 1.0) * 100.0)), 0, 100)
		var stab_delta: float = ((-0.5 - weary / 100.0) if g.rules == 0 else (-0.15 - weary / 250.0)) if at_war else 2.0
		if g.rules >= 1: stab_delta += TBRulers.stab_add(g, n)
		var stab_goal := 0.0
		var bud := n * 4
		var tax: int = g.budget[bud]; var goods: int = g.budget[bud + 1]; var res_pct: int = g.budget[bud + 2]; var inv_pct: int = g.budget[bud + 3]
		var happy_target := clampf(50.0 + (goods - 20) * 0.6 - maxf(0.0, tax - 50) * 0.5 - (8.0 if at_war else 0.0) - weary * 0.15 + (TBRulers.happy_add(g, n) if g.rules >= 1 else 0.0), 0.0, 100.0)
		var invest_chance := inv_pct / 100.0 * 0.05 * (TBRulers.invest_mul(g, n) if g.rules >= 1 else 1.0)
		g.research[n] += (D.tech_gain(inc["pop"], res_pct) + inc["researchBonus"]) * (TBRulers.research_mul(g, n) * catchup(g, n) if g.rules >= 1 else 1.0)
		var need := _need(g, g.tech_level[n])
		var era_before: int = g.era[n]
		while g.research[n] >= need:
			g.research[n] -= need
			g.tech_level[n] = minf(5.0, round((g.tech_level[n] + D.TECH_STEP) * 100.0) / 100.0)
			g.era[n] = mini(D.ERAS.size() - 1, int(floor(g.tech_level[n])))
			need = _need(g, g.tech_level[n])
		if g.rules >= 1 and g.era[n] > era_before and (g.human[n] != 0 or g.era[n] >= 3): g.log.append({"turn": g.turn, "kind": "era", "a": n, "k": g.era[n]})
		var dev_cap := clampi(int(floor(g.tech_level[n])) + 1, 1, 5)
		var stab_ceil: int = reg["stabCeil"]
		var rebel_chance: float = (reg["rebelChance"] + (REB_BASE if g.rules >= 1 else 0.0)) * (TBRulers.rebel_mul(g, n) if g.rules >= 1 else 1.0)
		if g.rules >= 1: stab_goal = stab_target(g, n, weary, at_war, stab_ceil, own.size())
		var spawned := 0
		for p in own:
			if cap_shock: g.stab[p] = maxi(5, g.stab[p] - 20)
			if g.occupier[p] != 0: g.stab[p] = maxi(5, g.stab[p] - 1)
			if g.rules >= 1:
				if g.core[p] != n and g.core[p] != 0 and g.turn - g.own_since[p] >= ASSIMILATE_TURNS: g.core[p] = n; g.touch(p)           # time makes it home
				var goal_p: float = stab_goal - (CONQUEST_UNREST if (g.core[p] != n and g.core[p] != 0) else 0.0)
				g.stab[p] = clampi(g.stab[p] + int(round(clampf(goal_p - g.stab[p], -STAB_SPEED_DOWN, STAB_SPEED_UP))), 5, stab_ceil)
			else: g.stab[p] = int(maxf(5.0, minf(stab_ceil, g.stab[p] + stab_delta)))
			var h: int = g.happy[p]
			var diff := happy_target - h
			g.happy[p] = int(maxf(0.0, minf(100.0, h + signf(diff) * minf(2.0, absf(diff)))))
			var stab_mod := 0.5 + g.stab[p] / 200.0
			var farm := 1.0 + 0.05 * g.bl(p, D.B_FARM)
			var growth := int(floor(g.pop[p] * 0.01 * (g.happy[p] / 100.0) * stab_mod * farm))
			if growth > 0: g.pop[p] = mini(2000, g.pop[p] + growth)
			if g.econ[p] < 5 and g.rng.next() < invest_chance: g.econ[p] += 1
			if g.dev[p] < dev_cap and g.rng.next() < invest_chance * (0.5 if g.rules < 2 else 0.15) and (g.rules < 2 or g.job_fill(p, g.dev[p] + 1) >= 0.9): g.dev[p] += 1       # districts: slow organic growth, and only where the people are there to staff it
			if g.rules >= 1:
				if rebel_chance > 0.0 and g.capital[p] == 0 and spawned < REB_MAX_PER_TURN and g.stab[p] < REB_THRESHOLD and g.rng.next() < rebel_hazard(g, p, rebel_chance):
					rebels_to_spawn.append(p); spawned += 1
			elif rebel_chance > 0.0 and g.capital[p] == 0 and g.stab[p] < 30 and g.rng.next() < rebel_chance:
				rebels_to_spawn.append(p)
		if g.gold[n] <= 0 and inc["net"] < 0:
			for p in own:
				g.army[p] = maxi(1, int(floor(g.army[p] * 0.95)))
	for p in rebels_to_spawn:
		spawn_rebel(g, p)
	if g.rules >= 1:
		g.world_y = y_sum
		var top := 0.0; var second := 0.0; var sum := 0.0; var cnt := 0
		for n in range(1, N1):
			if g.alive[n] == 0 or n == g.rebel: continue
			var t: float = g.tech_level[n]; sum += t; cnt += 1
			if t > top: second = top; top = t
			elif t > second: second = t
		g.tech_top = top; g.tech_second = second; g.tech_avg = sum / maxf(1.0, cnt)
	# vassals
	for n in range(1, N1):
		var ov := g.overlord[n]
		if g.alive[n] == 0 or ov == 0: continue
		if g.alive[ov] == 0:
			g.overlord[n] = 0; continue
		var t: int = g.tribute[n]
		if t > 0:
			var amt := int(floor(maxf(0.0, g.income(n)["gold"]) * t / 100.0))
			g.gold[n] = maxf(0.0, g.gold[n] - amt); g.gold[ov] += amt
		g.liberty[n] = clampf(g.liberty[n] + t * 0.04 - 0.5, 0.0, 100.0)
		if g.liberty[n] >= 100.0:
			g.overlord[n] = 0; g.tribute[n] = 0; g.liberty[n] = 0
			g.set_rel(n, ov, D.REL_WAR)
			g.log.append({"turn": g.turn, "kind": "independence", "a": n, "b": ov})
	# grudges cool
	if g.turn % 4 == 0:
		for i in g.grudge.size():
			if g.grudge[i] != 0: g.grudge[i] -= 1

## research cost: rules>=1 makes eras reachable within a normal game
static func _need(g: TBGame, lvl: float) -> int:
	var base := D.tech_needed(lvl)
	return base if g.rules == 0 else maxi(1, int(base * 0.4))

static func spawn_rebel(g: TBGame, p: int) -> void:
	var former := g.owner[p]
	if former == 0: return
	g.cede(p, g.rebel)
	g.set_alive(g.rebel, 1)
	g.army[p] = maxi(g.army[p], 8) if g.rules < 1 else clampi(g.army[p], 8, 30); g.stab[p] = 55; g.happy[p] = 50
	g.set_rel(g.rebel, former, D.REL_WAR)
	g.last_war_turn[g.rebel] = g.turn
	g.gold[g.rebel] = 40; g.manpower[g.rebel] = 60
	if g.capital_of[g.rebel] < 0: g.reassign_capital(g.rebel)
	g.log.append({"turn": g.turn, "kind": "rebels", "a": former, "p": p})

static func rebel_turn(g: TBGame) -> void:
	var r := g.rebel
	if g.alive[r] == 0: return
	var own := g.owned(r)
	if own.is_empty():
		g.set_alive(r, 0); return
	if g.rules >= 1: _rebel_lifecycle(g, own)
	for p in own:
		if g.owner[p] != r: continue
		if g.army[p] < 4 or not g.rng.chance(0.35): continue
		if g.rules >= 1 and g.reb_age[p] > REB_MOMENTUM: continue          # an old uprising holds what it has instead of spreading
		var tgt := -1; var weakest := 1000000000
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q := g.nb[i]
			if g.owner[q] == r or g.owner[q] == 0: continue
			if g.nb_sea[i] != 0 and g.bl(p, D.B_PORT) == 0: continue
			if g.army[q] < weakest:
				weakest = g.army[q]; tgt = q
		if tgt < 0: continue
		var former := g.owner[tgt]
		if g.get_rel(r, former) != D.REL_WAR: g.set_rel(r, former, D.REL_WAR)
		g.resolve_combat(r, p, tgt, int(floor(g.army[p] * 0.7)))

## how a rebellion ends (rules >= 1): the rebels run out of men and money, the government takes them back with an amnesty when it is stable, or after
## REB_DISSOLVE turns the province settles into self-rule. (The fourth way, reconquest, is ordinary war.)
static func _rebel_lifecycle(g: TBGame, own: PackedInt32Array) -> void:
	var r := g.rebel
	for p in own:
		if g.owner[p] != r: continue
		if g.reb_age[p] < 255: g.reb_age[p] += 1
		var former: int = g.reb_from[p]
		var floor_n: int = 6 + g.pop[p] / 200                                   # a militia the land can feed
		if g.army[p] > floor_n:
			g.army[p] -= int(ceil((g.army[p] - floor_n) * 0.04)); g.touch(p)     # no pay, no supply: rebel armies melt away
		var gone: bool = former <= 0 or g.alive[former] == 0
		if not gone and g.reb_age[p] >= 6 and g.army[p] < 20 and g.occupier[p] == 0:
			var cap := g.capital_of[former]
			var calm: float = clampf((g.stab[cap] if cap >= 0 else 40) / 60.0, 0.0, 1.2)
			if g.rng.chance(REB_RECON * calm):
				g.cede(p, former); g.stab[p] = 45; g.happy[p] = mini(100, g.happy[p] + 10); g.army[p] = maxi(1, g.army[p] / 2); g.touch(p)
				g.log.append({"turn": g.turn, "kind": "reconciled", "a": former, "p": p})
				continue
		if gone or g.reb_age[p] >= REB_DISSOLVE:
			var was := former
			g.set_owner(p, 0); g.occupier[p] = 0; g.stab[p] = 50; g.army[p] = maxi(2, g.army[p] / 3); g.touch(p)
			g.log.append({"turn": g.turn, "kind": "rebels_end", "a": was, "p": p})

## victory paths (rules >= 1): id -> progress 0..1 (>= 1 wins). Domination counts the share of the whole map.
## Rules >= 3 (docs/MODEL.md section 9): a victory is a position HELD, not a moment: the condition must stay true for HOLD turns in a row (the chronicle of a hegemon is written
## over years); diplomatic hegemony is no longer an ending but an achievement (alliances are made in almost every turn of any game); and domination needs the people as well
## as the land (an empire of empty provinces rules nothing), counting a vassal's lands and people at half.
const VICTORY_IDS := ["domination", "economic", "technological", "diplomatic", "conquest"]
const WIN_IDS_3 := ["domination", "economic", "technological", "conquest"]
const HOLD := {"domination": 8, "economic": 8, "technological": 6, "diplomatic": 20}          # turns (one turn = half a year); conquest ends the game at once
const DOMINATION_SHARE := 0.25
const DOMINATION_POP := 0.25               # rules >= 3: ...and this share of the world's people
const VASSAL_WEIGHT := 0.5
const ECONOMIC_GOLD := 5000.0
const ECONOMIC_MIN_TURN := 30              # a flat 5000 gold fell in the first turns to every large nation, so it also takes a full trade network and some time
const TECH_MIN_TURN := 40
const TECH_LEAD := 0.4                     # the race is won by being this far ahead of the second-best nation, not by merely arriving
const TECH_ROOM := 1.0                     # ...and only in eras where the world starts at least this far below the cap (from WWI on there is no race to run)
const DIPLOMATIC_ALLIES := 8
const DIPLOMATIC_SHARE := 0.05            # in the largest eras (250 nations) 8 allies was reached by turn 50 in every simulated game

## the paths that end the game (rules >= 3 leaves out the diplomatic one, which is an achievement)
static func win_ids(g: TBGame) -> Array:
	return WIN_IDS_3 if g.rules >= 3 else VICTORY_IDS

static func _hold_key(n: int, id: String) -> String: return "%d:%s" % [n, id]

## how many turns in a row n has held the condition of `id`, and how many it takes (rules >= 3; need 0 = no holding needed)
static func hold_status(g: TBGame, n: int, id: String) -> Vector2i:
	if g.rules < 3 or not HOLD.has(id): return Vector2i(0, 0)
	return Vector2i(int(g.vic_hold.get(_hold_key(n, id), 0)), int(HOLD[id]))

## the share of the world's land and people that n commands (a vassal's counts at VASSAL_WEIGHT)
static func reach_shares(g: TBGame, n: int) -> Vector2:
	var land := 0.0; var pop_mine := 0.0; var pop_all := 0.0
	for p in g.P:
		var o: int = g.owner[p]
		if o == 0: continue
		var w := 1.0 if o == n else (VASSAL_WEIGHT if g.overlord[o] == n else 0.0)
		pop_all += g.pop[p]
		if w > 0.0: land += w; pop_mine += w * g.pop[p]
	return Vector2(land / float(g.P), pop_mine / maxf(1.0, pop_all))

## the conditions as they stand now, 0..1 each (>= 1 = met), whether or not they have been held long enough
static func raw_progress(g: TBGame, n: int) -> Dictionary:
	var allies := 0
	var alive_others := 0
	for o in range(1, g.N1):
		if o == n or g.alive[o] == 0 or o == g.rebel: continue
		alive_others += 1
		if g.get_rel(n, o) == D.REL_ALLY: allies += 1
	var deals: float = float(g.trade_cnt[n]) / maxf(1.0, float(TBTrade.max_deals(g, n)))
	var share: float = float(g.income(n)["gold"]) / maxf(1.0, g.world_y)
	var econ: float = minf(minf(share / maxf(0.05, g.econ_goal), g.gold[n] / ECONOMIC_GOLD), deals)
	var tech := 0.0
	if 5.0 - g.tech_start_top >= TECH_ROOM:
		var rival: float = g.tech_second if g.tech_level[n] >= g.tech_top else g.tech_top
		tech = clampf(minf(g.tech_level[n] / 5.0, (g.tech_level[n] - rival) / TECH_LEAD), 0.0, 1.0)
	var dom: float = clampf(float(g.own_count(n)) / g.P / DOMINATION_SHARE, 0.0, 1.0)
	if g.rules >= 3:
		var sh := reach_shares(g, n)
		dom = clampf(minf(sh.x / DOMINATION_SHARE, sh.y / DOMINATION_POP), 0.0, 1.0)
	return {
		"domination": dom,
		"economic": clampf(econ, 0.0, 1.0 if g.turn >= ECONOMIC_MIN_TURN else 0.99),
		"technological": clampf(tech, 0.0, 1.0 if g.turn >= TECH_MIN_TURN else 0.99),
		"diplomatic": clampf(float(allies) / maxf(DIPLOMATIC_ALLIES, ceilf(alive_others * DIPLOMATIC_SHARE)), 0.0, 1.0),
		"conquest": 1.0 if alive_others == 0 else clampf(float(g.own_count(n)) / maxf(1.0, g.P - g.own_count(0)), 0.0, 0.99),
	}

## what the goals screen shows: the conditions, with a position that has not yet been held long enough kept just short of complete (rules >= 3)
static func victory_progress(g: TBGame, n: int) -> Dictionary:
	var pr := raw_progress(g, n)
	if g.rules >= 3:
		for id in HOLD.keys():
			var hs := hold_status(g, n, id)
			if float(pr[id]) >= 1.0 and hs.x < hs.y: pr[id] = 0.99
	return pr

## once a turn, after the world has moved: count how long each condition has been held in a row
static func _count_holds(g: TBGame, h: int, raw: Dictionary) -> void:
	for id in HOLD.keys():
		var met: bool = float(raw[id]) >= 1.0 and not (id == "technological" and g.tech_level[h] < 5.0)
		var k := _hold_key(h, id)
		g.vic_hold[k] = int(g.vic_hold.get(k, 0)) + 1 if met else 0

static func check_victory(g: TBGame) -> void:
	if g.over: return
	var hs := g.humans()
	if hs.is_empty(): return
	var alive_humans := 0
	for h in hs:
		if g.alive[h] != 0: alive_humans += 1
	if alive_humans == 0:
		g.over = true; g.winner = 0; g.victory_kind = ""; g.log.append({"turn": g.turn, "kind": "defeat", "a": hs[0]}); return
	if g.rules == 0:
		var total := 0
		for p in g.P:
			if g.owner[p] != 0: total += 1
		for h in hs:
			if g.alive[h] == 0: continue
			if float(g.own_count(h)) / (total if total != 0 else 1) >= 0.6:
				g.over = true; g.winner = h; g.victory_kind = "domination"; g.log.append({"turn": g.turn, "kind": "victory", "a": h}); return
		return
	for h in hs:
		if g.alive[h] == 0: continue
		var prog := raw_progress(g, h)
		if g.rules >= 3: _count_holds(g, h, prog)
		for id in win_ids(g):
			var met: bool = prog[id] >= 1.0 and not (id == "technological" and g.tech_level[h] < 5.0)
			if met and g.rules >= 3 and HOLD.has(id): met = hold_status(g, h, id).x >= int(HOLD[id])
			if met:
				g.over = true; g.winner = h; g.victory_kind = id
				g.log.append({"turn": g.turn, "kind": "victory", "a": h, "id": id}); return
