## End-of-turn pipeline: AI -> world tick -> rebels -> time -> victory. Deterministic.
class_name TBTurn
extends RefCounted

const D = preload("res://src/engine/data.gd")
const DEF_CAP := 50

static func end_turn(g: TBGame) -> PackedInt32Array:
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
		if o != 0 and warflag[o] == 0 and g.defense[p] < DEF_CAP:
			g.defense[p] += 1
		if g.b_building[p] != 0:
			g.b_turns[p] -= 1
			if g.b_turns[p] <= 0:
				if g.building[p] == g.b_building[p]: g.b_level[p] += 1
				else:
					g.building[p] = g.b_building[p]; g.b_level[p] = 1
				g.b_building[p] = 0; g.touch(p)
	var rebels_to_spawn: Array = []
	for n in range(1, N1):
		if g.alive[n] == 0: continue
		var own := g.owned(n)
		if own.is_empty():
			g.eliminate(n); continue
		var inc := g.income(n)
		var reg: Dictionary = D.REGIMES[g.regime[n]]
		var era: int = g.era[n]
		var gold_before: float = g.gold[n]
		g.gold[n] = maxf(0.0, g.gold[n] + inc["net"])
		if g.rules >= 1 and g.human[n] != 0 and gold_before > 0.0 and g.gold[n] <= 0.0: g.log.append({"turn": g.turn, "kind": "bankrupt", "a": n})
		g.manpower[n] = minf(inc["manCap"], g.manpower[n] + inc["manpower"])
		g.mp[n] = minf(6 + era * 2, g.mp[n] + 1 + era * 0.4)
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
		var bud := n * 4
		var tax: int = g.budget[bud]; var goods: int = g.budget[bud + 1]; var res_pct: int = g.budget[bud + 2]; var inv_pct: int = g.budget[bud + 3]
		var happy_target := clampf(50.0 + (goods - 20) * 0.6 - maxf(0.0, tax - 50) * 0.5 - (8.0 if at_war else 0.0) - weary * 0.15 + (TBRulers.happy_add(g, n) if g.rules >= 1 else 0.0), 0.0, 100.0)
		var invest_chance := inv_pct / 100.0 * 0.05 * (TBRulers.invest_mul(g, n) if g.rules >= 1 else 1.0)
		g.research[n] += (D.tech_gain(inc["pop"], res_pct) + inc["researchBonus"]) * (TBRulers.research_mul(g, n) if g.rules >= 1 else 1.0)
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
		var rebel_chance: float = reg["rebelChance"] * (TBRulers.rebel_mul(g, n) if g.rules >= 1 else 1.0)
		for p in own:
			if cap_shock: g.stab[p] = maxi(5, g.stab[p] - 20)
			if g.occupier[p] != 0: g.stab[p] = maxi(5, g.stab[p] - 1)
			g.stab[p] = int(maxf(5.0, minf(stab_ceil, g.stab[p] + stab_delta)))
			var h: int = g.happy[p]
			var diff := happy_target - h
			g.happy[p] = int(maxf(0.0, minf(100.0, h + signf(diff) * minf(2.0, absf(diff)))))
			var stab_mod := 0.5 + g.stab[p] / 200.0
			var farm := 1.0 + 0.05 * g.b_level[p] if g.building[p] == D.B_FARM else 1.0
			var growth := int(floor(g.pop[p] * 0.01 * (g.happy[p] / 100.0) * stab_mod * farm))
			if growth > 0: g.pop[p] = mini(2000, g.pop[p] + growth)
			if g.econ[p] < 5 and g.rng.next() < invest_chance: g.econ[p] += 1
			if g.dev[p] < dev_cap and g.rng.next() < invest_chance * 0.5: g.dev[p] += 1
			if rebel_chance > 0.0 and g.capital[p] == 0 and g.stab[p] < 30 and g.rng.next() < rebel_chance:
				rebels_to_spawn.append(p)
		if g.gold[n] <= 0 and inc["net"] < 0:
			for p in own:
				g.army[p] = maxi(1, int(floor(g.army[p] * 0.95)))
	for p in rebels_to_spawn:
		spawn_rebel(g, p)
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
	g.army[p] = maxi(g.army[p], 8); g.stab[p] = 55; g.happy[p] = 50
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
	for p in own:
		if g.army[p] < 4 or not g.rng.chance(0.35): continue
		var tgt := -1; var weakest := 1000000000
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q := g.nb[i]
			if g.owner[q] == r or g.owner[q] == 0: continue
			if g.nb_sea[i] != 0 and g.building[p] != D.B_PORT: continue
			if g.army[q] < weakest:
				weakest = g.army[q]; tgt = q
		if tgt < 0: continue
		var former := g.owner[tgt]
		if g.get_rel(r, former) != D.REL_WAR: g.set_rel(r, former, D.REL_WAR)
		g.resolve_combat(r, p, tgt, int(floor(g.army[p] * 0.7)))

## victory paths (rules >= 1): id -> progress 0..1 (>= 1 wins). Domination counts the share of the whole map.
const VICTORY_IDS := ["domination", "economic", "technological", "diplomatic", "conquest"]
const DOMINATION_SHARE := 0.25
const ECONOMIC_GOLD := 5000.0
const DIPLOMATIC_ALLIES := 8

static func victory_progress(g: TBGame, n: int) -> Dictionary:
	var allies := 0
	var alive_others := 0
	for o in range(1, g.N1):
		if o == n or g.alive[o] == 0 or o == g.rebel: continue
		alive_others += 1
		if g.get_rel(n, o) == D.REL_ALLY: allies += 1
	return {
		"domination": clampf(float(g.own_count(n)) / g.P / DOMINATION_SHARE, 0.0, 1.0),
		"economic": clampf(g.gold[n] / ECONOMIC_GOLD, 0.0, 1.0),
		"technological": clampf(g.tech_level[n] / 5.0, 0.0, 1.0),
		"diplomatic": clampf(float(allies) / DIPLOMATIC_ALLIES, 0.0, 1.0),
		"conquest": 1.0 if alive_others == 0 else clampf(float(g.own_count(n)) / maxf(1.0, g.P - g.own_count(0)), 0.0, 0.99),
	}

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
		var prog := victory_progress(g, h)
		for id in VICTORY_IDS:
			if prog[id] >= 1.0 and not (id == "technological" and g.tech_level[h] < 5.0):
				g.over = true; g.winner = h; g.victory_kind = id
				g.log.append({"turn": g.turn, "kind": "victory", "a": h, "id": id}); return
