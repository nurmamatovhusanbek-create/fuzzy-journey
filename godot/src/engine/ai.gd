## Budgeted AI for province mode. Each nation scans only its own provinces + frontier.
## All randomness via g.rng; decision order mirrors reference/engine-js/src/ai.js exactly.
class_name TBAI
extends RefCounted

const D = preload("res://src/engine/data.gd")

static func run(g: TBGame) -> void:
	var n_count := g.N
	var start := g.turn % n_count
	for k in n_count:
		var n := ((start + k) % n_count) + 1
		if n == g.rebel or g.alive[n] == 0 or g.human[n] != 0: continue
		_nation(g, n)

## flat [mine0, theirs0, mine1, theirs1, ...] for edges leaving my controlled provinces
static func _frontier(g: TBGame, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var owner := g.owner; var occ := g.occupier; var nbo := g.nb_off; var nbl := g.nb; var sea := g.nb_sea; var bld := g.building
	for p in g.owned(n):
		if (occ[p] if occ[p] != 0 else owner[p]) != n: continue
		var port: bool = bld[p] == D.B_PORT
		for e in range(nbo[p], nbo[p + 1]):
			var q := nbl[e]
			if (occ[q] if occ[q] != 0 else owner[q]) == n: continue
			if sea[e] != 0 and not port: continue
			out.append(p); out.append(q)
	return out

static func _nation(g: TBGame, n: int) -> void:
	var pers: Dictionary = D.PERSONALITIES[g.personality[n]]
	var own := g.owned(n)
	if own.is_empty(): return
	var aggr: float = float(pers["aggr"]) * float(g.diff["aiAggr"])
	var fr := _frontier(g, n)
	var at_war := g.at_war(n)

	# 0. rules>=1: AI manages its budget (rich nations convert tax into research/investment)
	if g.rules >= 1 and (g.turn + n) % 4 == 0:
		_budget(g, n, pers, at_war)
	# 1. economy
	if g.gold[n] > 150 and g.mp[n] >= 2 and g.rng.chance(0.3 + float(pers["econ"]) * 0.2):
		var best := -1; var bs := -1
		var step := 1 + (2 if own.size() > 30 else 0)
		var i := 0
		while i < own.size():
			var p := own[i]
			i += step
			if g.building[p] != 0 or g.b_building[p] != 0 or g.occupier[p] != 0: continue
			var s: int = g.pop[p] + g.dev[p] * 20 + (100 if g.capital[p] != 0 else 0)
			if s > bs:
				bs = s; best = p
		if best >= 0:
			var want_mil: bool = at_war or float(pers["def"]) > 0.7
			var choice: int
			if want_mil: choice = D.B_FORTRESS
			elif g.tech_level[n] > 0.8 and g.rng.chance(0.4): choice = D.B_LIBRARY
			else: choice = D.B_MARKET if g.rng.chance(0.5) else D.B_FARM
			g.apply({"cmd": "build", "n": n, "p": best, "b": choice})
	# 1b. rules>=1: rich nations invest in development (gold sink, grows the economy)
	if g.rules >= 1 and g.gold[n] > 300 and g.mp[n] >= 2 and g.rng.chance(0.25 + float(pers["econ"]) * 0.3):
		var bp := -1; var bsc := -1.0
		for p in own:
			if g.occupier[p] != 0: continue
			var sc2: float = g.pop[p] / 100.0 + g.stab[p] / 50.0 - g.dev[p]
			if sc2 > bsc:
				bsc = sc2; bp = p
		if bp >= 0: g.apply({"cmd": "develop", "n": n, "p": bp})
	# 2. colonize adjacent neutral land
	if g.gold[n] > 90 and g.mp[n] >= 2:
		var i := 0
		while i < fr.size():
			var q := fr[i + 1]
			i += 2
			if g.owner[q] != 0: continue
			if g.apply({"cmd": "colonize", "n": n, "p": q})["ok"]: break
	# 3. recruit (rich nations raise several levies)
	var levies := 3 if g.gold[n] > 500 else (2 if g.gold[n] > 250 else 1)
	if g.rules >= 1 and g.gold[n] > 900: levies = 5
	var lv := 0
	while lv < levies and g.gold[n] > 30 and g.manpower[n] > 40 and g.mp[n] >= 1 and (lv > 0 or g.rng.chance(0.3 + aggr * 0.4 + (0.3 if at_war else 0.0))):
		var best2 := -1; var bs2 := -1e9
		var i := 0
		while i < fr.size():
			var p := fr[i]; var q := fr[i + 1]
			i += 2
			var hostile: bool = g.owner[q] != 0 and g.get_rel(n, g.controller(q)) == D.REL_WAR
			var s: float = (3.0 if hostile else 0.5) - g.army[p] / 60.0 + g.rng.next() * 0.3
			if s > bs2:
				bs2 = s; best2 = p
		if best2 >= 0: g.apply({"cmd": "recruit", "n": n, "p": best2, "amount": 20})
		lv += 1
	# 3b. rules>=1: hoarded gold buys mercenaries (turns wealth into power; the game's main gold sink)
	if g.rules >= 1 and g.gold[n] > 500:
		var hires := mini(3, int(g.gold[n] / 400.0))
		for h in hires:
			if g.mp[n] < 1: break
			var hb := -1; var hs := -1e9
			var j := 0
			while j < fr.size():
				var pp := fr[j]; var qq := fr[j + 1]
				j += 2
				var sc3: float = (2.0 if g.owner[qq] != 0 and g.get_rel(n, g.controller(qq)) == D.REL_WAR else 0.6) - g.army[pp] / 80.0 + g.rng.next() * 0.2
				if sc3 > hs:
					hs = sc3; hb = pp
			if hb < 0:
				hb = own[g.rng.randi_n(own.size())]
			g.apply({"cmd": "hire", "n": n, "p": hb, "amount": 40})
	if g.rules >= 1: TBDecisions.ai_pick(g, n)
	# 4. war
	if g.mp[n] >= D.MP_ATTACK: _maybe_declare(g, n, aggr, fr)
	if at_war or g.at_war(n): _fight(g, n, fr)
	# 5. peace when losing
	if g.war_cnt[n] > 0: _seek_peace(g, n)
	# 5b. rules>=1: spies strike current enemies
	if g.rules >= 1 and at_war and g.intel[n] >= 10.0 and g.rng.chance(0.12 + float(pers["aggr"]) * 0.1):
		for o in range(1, g.N1):
			if o != n and g.alive[o] != 0 and o != g.rebel and g.get_rel(n, o) == D.REL_WAR:
				g.apply({"cmd": "spy", "n": n, "t": o, "op": ["steal", "sabotage", "incite"][g.rng.randi_n(3)]}); break
	# 6. diplomacy
	if g.dp[n] >= D.DP_NAP and g.rng.chance(float(pers["dipl"]) * 0.15): _diplomacy(g, n, fr)

static func _budget(g: TBGame, n: int, pers: Dictionary, at_war: bool) -> void:
	var o := n * 4
	var tax: int; var goods: int; var res: int; var inv: int
	if g.gold[n] > 800:       tax = 20; goods = 20; res = 40; inv = 20
	elif g.gold[n] > 300:     tax = 35; goods = 20; res = 30; inv = 15
	elif at_war or g.gold[n] < 80: tax = 60; goods = 15; res = 10; inv = 15
	else:                     tax = 45; goods = 20; res = 20; inv = 15
	if float(pers["econ"]) > 0.8: res += 5; tax -= 5
	g.budget[o] = tax; g.budget[o + 1] = goods; g.budget[o + 2] = res; g.budget[o + 3] = inv

static func _maybe_declare(g: TBGame, n: int, aggr: float, fr: PackedInt32Array) -> void:
	if g.turn < 6 or g.turn - g.last_war_turn[n] < (6 if g.rules == 0 else 10) or g.dp[n] < D.DP_WAR: return
	if g.rules >= 1 and g.war_cnt[n] >= 2: return          # no endless multi-front wars
	if not g.rng.chance(minf(1.0, aggr * 0.5)): return
	var tgt := 0; var ts := -1.0
	var seen := {}
	# rules>=1 anti-runaway: nations unite against any power holding a large share of the world
	var total_owned := g.P - g.own_count(0)
	var i := 0
	while i < fr.size():
		var p := fr[i]; var q := fr[i + 1]
		i += 2
		var t := g.owner[q]
		if t == 0 or t == n or seen.has(t) or g.alive[t] == 0 or g.friendly(n, t) or g.has_truce(n, t) or g.get_rel(n, t) == D.REL_NAP or g.get_rel(n, t) == D.REL_WAR: continue
		seen[t] = true
		if float(g.army[p]) / maxf(8.0, g.army[q] + 10.0) < 1.15: continue
		var s: float = float(g.army[p]) / (g.army[q] + 10.0) + g.grudge[n * g.N1 + t] / 50.0 + g.rng.next() * 0.5
		if g.rules >= 1:
			var share := float(g.own_count(t)) / maxf(1.0, total_owned)
			if share > 0.04: s += (share - 0.04) * 25.0       # hegemon: everyone's favourite target
			s += g.infamy[t] / 15.0 + (2.0 if g.coalition[t] != 0 else 0.0)      # coalition against the notorious
			var cbk := TBDiplo.cb(g, n, t)
			if cbk != "": s += 0.8
			elif aggr < 0.5: s -= 1.5                             # peaceful rulers avoid unjustified wars
			if cbk == "" and g.infamy[n] >= 18.0: s -= 2.0
		if s > ts:
			ts = s; tgt = t
	if tgt != 0:
		var cap := g.capital_of[n]
		if g.stab[cap if cap >= 0 else 0] < 25: return
		if g.rules >= 1 and aggr < 0.5 and TBDiplo.cb(g, n, tgt) == "" and g.rng.chance(0.6): return
		g.apply({"cmd": "declareWar", "n": n, "t": tgt})

static func _fight(g: TBGame, n: int, fr: PackedInt32Array) -> void:
	var attacks := mini(3, int(floor(g.mp[n] / D.MP_ATTACK)))
	if attacks <= 0: return
	var cands: Array = []
	var i := 0
	while i < fr.size():
		var p := fr[i]; var q := fr[i + 1]
		i += 2
		var c := g.controller(q)
		if c == 0 or g.get_rel(n, c) != D.REL_WAR: continue
		if g.army[p] < 12: continue
		var atk := g.army[p] * 0.9
		var dfn := g.army[q] * g.def_mul(q) + 1.0
		var score := atk / dfn + g.province_value(q) * 0.05 + (1.0 if g.capital[q] != 0 else 0.0)
		if atk > dfn * 1.1: cands.append([score, p, q])
	cands.sort_custom(func(a, b):
		if a[0] != b[0]: return a[0] > b[0]
		if a[1] != b[1]: return a[1] < b[1]
		return a[2] < b[2])
	var used := {}
	for c in cands:
		if attacks <= 0: break
		var p: int = c[1]; var q: int = c[2]
		if used.has(p): continue
		var r := g.apply({"cmd": "move", "n": n, "from": p, "to": q, "troops": g.army[p] - 1})
		if r["ok"]:
			attacks -= 1; used[p] = true
	# reinforcements toward the front
	if g.mp[n] >= 1:
		var own := g.owned(n)
		var oi := 0
		while oi < own.size() and g.mp[n] >= 1:
			var p := own[oi]
			oi += 1
			if g.army[p] < 25 or g.controller(p) != n: continue
			var has_front := false; var best := -1; var bs := -1.0
			for e in range(g.nb_off[p], g.nb_off[p + 1]):
				var q := g.nb[e]
				if g.controller(q) != n:
					has_front = true; break
				var touches := false
				for e2 in range(g.nb_off[q], g.nb_off[q + 1]):
					var r2 := g.nb[e2]
					var c2 := g.controller(r2)
					if c2 != 0 and c2 != n and g.get_rel(n, c2) == D.REL_WAR:
						touches = true; break
				if touches and g.nb_sea[e] == 0 and 1.0 / (1.0 + g.army[q]) > bs:
					bs = 1.0 / (1.0 + g.army[q]); best = q
			if not has_front and best >= 0 and g.rng.chance(0.5):
				g.apply({"cmd": "move", "n": n, "from": p, "to": best, "troops": g.army[p] - 10})

static func _seek_peace(g: TBGame, n: int) -> void:
	var N1 := g.N1
	for o in range(1, N1):
		if g.rel[n * N1 + o] != D.REL_WAR or g.alive[o] == 0: continue
		var mine := g.war_score[n * N1 + o]
		var theirs := g.war_score[o * N1 + n]
		var dur := g.war_turns[n * N1 + o]
		if g.human[o] != 0:
			if dur > 24 and mine < 5 and theirs < 5 and g.rng.chance(0.2):
				g.apply({"cmd": "peace", "n": n, "t": o, "kind": "white", "_force": true})
			continue
		var losing := theirs - mine
		if losing > 15 or (dur > (8 if g.rules == 0 else 14) and absi(losing) < 12 and g.rng.chance(0.3)):
			var force: bool = (not accepts_peace(g, o, n, "white")) and losing > 35
			g.apply({"cmd": "peace", "n": n, "t": o, "kind": "cede" if mine >= 25 else "white", "_force": force})
		elif g.rules >= 1 and mine >= 60 and g.overlord[o] == 0 and g.overlord[n] == 0 and g.rng.chance(0.4):
			g.apply({"cmd": "peace", "n": n, "t": o, "kind": "vassal", "_force": true})
		elif mine >= (40 if g.rules == 0 else 25) and g.rng.chance(0.3 if g.rules == 0 else 0.6):
			g.apply({"cmd": "peace", "n": n, "t": o, "kind": "cede"})

static func _diplomacy(g: TBGame, n: int, fr: PackedInt32Array) -> void:
	var i := 0
	while i < fr.size():
		var q := fr[i + 1]
		i += 2
		var t := g.controller(q)
		if t == 0 or t == n or g.alive[t] == 0 or g.human[t] != 0: continue
		var r := g.get_rel(n, t)
		if r == D.REL_PEACE and g.grudge[t * g.N1 + n] < 20:
			var k: String = "nap" if g.rng.chance(0.5) else "ally"
			if k == "ally" and g.dp[n] >= D.DP_ALLY: g.apply({"cmd": "ally", "n": n, "t": t})
			else: g.apply({"cmd": "nap", "n": n, "t": t})
			return

## target t evaluating proposer p
static func accepts_peace(g: TBGame, t: int, p: int, kind: String) -> bool:
	var N1 := g.N1
	var my_ws := g.war_score[t * N1 + p]
	var their_ws := g.war_score[p * N1 + t]
	var dur := g.war_turns[t * N1 + p]
	var want := 0.0
	want += (their_ws - my_ws) * 0.04
	want += minf(1.5, dur / 20.0)
	want -= g.grudge[t * N1 + p] / 80.0
	if kind == "cede": want -= 0.5 + their_ws * 0.02
	if kind == "vassal": want -= 1.5 + their_ws * 0.03
	return want > 0.2

static func accepts_pact(g: TBGame, t: int, p: int, rel: int) -> bool:
	var pers: Dictionary = D.PERSONALITIES[g.personality[t]]
	if g.grudge[t * g.N1 + p] > 20 or (g.has_truce(t, p) and rel == D.REL_ALLY): return false
	var s: float = float(pers["dipl"]) * 0.6 + (0.3 if rel == D.REL_NAP else 0.0)
	if g.rules >= 1: s -= maxf(0.0, g.infamy[p] - 12.0) * 0.02
	for o in range(1, g.N + 1):
		if g.get_rel(t, o) == D.REL_WAR and g.get_rel(p, o) == D.REL_WAR: s += 0.3
	var mine := g.own_count(t)
	var theirs := g.own_count(p)
	if theirs > mine * 3: s -= 0.2
	return s > 0.45
