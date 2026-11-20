## Events: random (per nation, with choices) + scheduled historical events (date-anchored, world or country scope).
## Data-driven (res://data/events/*.json). Human nations get a pending prompt; AI nations auto-resolve with rng.
## Only active for rules >= 1 so the oracle (rules 0) stays bit-exact.
class_name TBEvents
extends RefCounted

const D = preload("res://src/engine/data.gd")
const BASE_CHANCE := 0.15
const COOLDOWN_ANY := 3
const GRACE_TURNS := 3
const AI_CHANCE := 0.04

static var _random: Array = []
static var _sched_cache := {}
static var _loaded := false

static func _load() -> void:
	if _loaded: return
	_loaded = true
	_random = _read("res://data/events/random.json")

static func _read(path: String) -> Array:
	if not FileAccess.file_exists(path): return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Array else []

static func scheduled_for(era_id: String) -> Array:
	if _sched_cache.has(era_id): return _sched_cache[era_id]
	var out: Array = _read("res://data/events/sched_global.json")
	out.append_array(_read("res://data/events/sched_%s.json" % era_id))
	_sched_cache[era_id] = out
	return out

## the effects of choice i of a random event, or []
static func random_effects(id: String, i: int) -> Array:
	_load()
	for ev in _random:
		if String(ev["id"]) == id: return (ev["choices"][i]["effects"] as Array) if i >= 0 and i < (ev["choices"] as Array).size() else []
	return []

static func random_defs() -> Array:
	_load()
	return _random

static func run(g: TBGame) -> void:
	_load()
	# per-turn timed effects
	for n in range(1, g.N1):
		if g.alive[n] == 0: continue
		if g.trade_bonus[n] != 0:
			g.gold[n] = maxf(0.0, g.gold[n] + g.trade_bonus[n]); g.trade_bonus[n] = 0
		if g.combat_turns[n] > 0:
			g.combat_turns[n] -= 1
			if g.combat_turns[n] == 0: g.combat_bonus[n] = 0.0
	# unresolved prompts from last turn: auto-pick the last (default) choice
	for e in g.pending.duplicate():
		_resolve(g, e, int(e["count"]) - 1)
	g.pending = []
	_scheduled(g)
	_randoms(g)
	TBDiplo.offers_turn(g)

# ---------------------------------------------------------------- scheduled historical events
const STALE_YEARS := 3

static func _scheduled(g: TBGame) -> void:
	var evs := scheduled_for(g.era_id)
	for ev in evs:
		var id: String = ev["id"]
		if g.ev_fired.has(id): continue
		var t: Dictionary = ev.get("trigger", {})
		var ty: int = int(t.get("year", -9999)); var tm: int = int(t.get("monthIdx", 0))
		if g.year < ty or (g.year == ty and g.month_idx < tm): continue
		# events dated before the scenario start never fire
		if ty < g.start_year or (ty == g.start_year and tm < g.start_month):
			g.ev_fired[id] = true; continue
		# an event that is long overdue never fires: it came with a newer version than the save (a game played turn by turn meets every date within a year)
		if g.year - ty >= STALE_YEARS:
			g.ev_fired[id] = true; continue
		if t.has("chance") and g.rng.next() > float(t["chance"]):
			g.ev_fired[id] = true; continue
		g.ev_fired[id] = true
		var targets: Array = []
		if String(ev.get("scope", "world")) == "world":
			for n in range(1, g.N1):
				if g.alive[n] != 0 and n != g.rebel: targets.append(n)
		else:
			var want := String(t.get("nation", "")).to_lower()
			for n in range(1, g.N1):
				if g.alive[n] == 0 or n == g.rebel: continue
				if want != "" and g.nat_name[n].to_lower() != want and g.nat_code[n].to_lower() != want: continue
				if t.has("minTechLevel") and g.tech_level[n] < float(t["minTechLevel"]): continue
				targets.append(n)
		var choices: Array = ev.get("choices", [])
		for n in targets:
			if g.human[n] != 0:
				g.ev_uid += 1
				g.pending.append({"uid": g.ev_uid, "n": n, "kind": "sched", "id": id, "icon": ev.get("icon", "📜"), "title": ev.get("title", {}), "flavor": ev.get("flavor", {}),
					"count": maxi(1, choices.size()), "labels": choices.map(func(c): return c.get("label", {})), "fx": choices.map(func(c): return c.get("effects", [])), "world": String(ev.get("scope", "world")) == "world"})
				# auto-effects of world events hit humans immediately; choice effects wait for the answer
				_apply_sched_effects(g, n, ev.get("autoEffects", []))
			else:
				_apply_sched_effects(g, n, ev.get("autoEffects", []))
				if choices.size() > 0:
					_apply_sched_effects(g, n, choices[g.rng.randi_n(choices.size())].get("effects", []))
		g.log.append({"turn": g.turn, "kind": "event", "a": targets[0] if targets.size() == 1 else 0, "id": id, "world": targets.size() > 1, "title": ev.get("title", {}), "icon": ev.get("icon", "📜")})

static func _apply_sched_effects(g: TBGame, n: int, effects: Array) -> void:
	for e in effects:
		var d: float = float(e.get("delta", 0))
		match String(e.get("op", "")):
			"nation.gold": g.gold[n] = maxf(0.0, g.gold[n] + amount(g, n, "gold", d))
			"nation.manpower": g.manpower[n] = maxf(0.0, g.manpower[n] + amount(g, n, "manpower", d))
			"nation.mp": g.mp[n] += d
			"nation.dp": g.dp[n] += d
			"nation.stability":
				for p in g.owned(n): g.stab[p] = clampi(g.stab[p] + int(d), 0, 100)
			"nation.happy":
				for p in g.owned(n): g.happy[p] = clampi(g.happy[p] + int(d), 0, 100)
			"nation.infamy": g.infamy[n] = clampf(g.infamy[n] + d, 0.0, 100.0)
			"nation.research": g.research[n] = maxf(0.0, g.research[n] + amount(g, n, "research", d))
			"nation.intel": g.intel[n] = clampf(g.intel[n] + d, 0.0, 20.0)
			"nation.army_pct":
				for p in g.owned(n): g.army[p] = maxi(g.au(3.0), int(g.army[p] * (1.0 + d / 100.0))); g.touch(p)
			"nation.pop_pct":
				for p in g.owned(n): g.pop[p] = clampi(int(g.pop[p] * (1.0 + d / 100.0)), 10, g.pop_hard()); g.touch(p)
			"nation.dev":
				var best := -1; var bs := -1
				for p in g.owned(n):
					if g.dev[p] < 5 and g.pop[p] > bs: bs = g.pop[p]; best = p
				if best >= 0: g.dev[best] += 1; g.touch(best)
			"nation.trade": g.trade_bonus[n] += int(amount(g, n, "trade", d))
			"nation.combat":
				g.combat_bonus[n] += d / 100.0; g.combat_turns[n] = maxi(int(g.combat_turns[n]), int(e.get("turns", 6)))

# ---------------------------------------------------------------- random events
static func _randoms(g: TBGame) -> void:
	if g.turn < GRACE_TURNS: return
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		var human := g.human[n] != 0
		if g.turn - g.ev_last_any[n] < COOLDOWN_ANY: continue
		if g.rng.next() > (BASE_CHANCE if human else AI_CHANCE): continue
		var eligible: Array = []
		for i in _random.size():
			var ev: Dictionary = _random[i]
			var last: int = g.ev_last.get("%d:%s" % [n, ev["id"]], -999)
			if g.turn - last < int(ev["cooldown"]): continue
			if _conds_ok(g, n, ev["cond"]): eligible.append(i)
		if eligible.is_empty(): continue
		var ev: Dictionary = _random[eligible[g.rng.randi_n(eligible.size())]]
		g.ev_last["%d:%s" % [n, ev["id"]]] = g.turn
		g.ev_last_any[n] = g.turn
		if human:
			g.ev_uid += 1
			g.pending.append({"uid": g.ev_uid, "n": n, "kind": "rand", "id": ev["id"], "icon": ev["icon"], "cat": ev["cat"], "count": ev["choices"].size()})
		else:
			var ch: Dictionary = ev["choices"][g.rng.randi_n(ev["choices"].size())]
			apply_effects(g, n, ch["effects"])

static func _conds_ok(g: TBGame, n: int, conds: Array) -> bool:
	var inc: Dictionary = {}
	for c in conds:
		for k in c:
			match k:
				"not_war": if g.at_war(n): return false
				"at_war": if not g.at_war(n): return false
				"lands_min": if g.own_count(n) < int(c[k]): return false
				"gold_min": if g.gold[n] < float(c[k]): return false
				"dp_min": if g.dp[n] < float(c[k]): return false
				"era_min": if g.era[n] < int(c[k]): return false
				"chance": if g.rng.next() >= float(c[k]): return false
				"stab_below":
					var any := false
					for p in g.owned(n):
						if g.stab[p] < int(c[k]): any = true; break
					if not any: return false
				"broke":
					inc = g.income(n)
					if not (inc["net"] < 0 and g.gold[n] < inc["upkeep"]): return false
				"inst_has":                                                                    # an institution of the age you have embraced (data/institutions.json id)
					var ii := TBInstitutions.index_of(String(c[k]))
					if ii < 0 or not TBInstitutions.embraced(g, n, ii): return false
				"est_below":                                                                   # {"estate": id, "v": loyalty}: that estate is angrier than v
					var ee := TBEstates.index_of(String((c[k] as Dictionary).get("estate", "")))
					if ee < 0 or TBEstates.loyalty(g, n, ee) >= float((c[k] as Dictionary).get("v", 35)): return false
				"inst_behind": if TBInstitutions.lag(g, n) <= 0: return false              # the world has moved on and this nation has not followed
				"has_neighbors":
					var found := false
					for p in g.owned(n):
						for e in range(g.nb_off[p], g.nb_off[p + 1]):
							var o := g.owner[g.nb[e]]
							if o != 0 and o != n: found = true; break
						if found: break
					if not found: return false
	return true

# ---------------------------------------------------------------- applying
static func resolve_choice(g: TBGame, n: int, uid: int, choice: int) -> Dictionary:
	for e in g.pending:
		if int(e["uid"]) == uid:
			if int(e["n"]) != n: return {"ok": false, "err": "notyours"}
			_resolve(g, e, choice)
			g.pending.erase(e)
			return {"ok": true}
	return {"ok": false, "err": "gone"}

static func _resolve(g: TBGame, e: Dictionary, choice: int) -> void:
	var n: int = e["n"]
	choice = clampi(choice, 0, int(e["count"]) - 1)
	if e["kind"] == "prop" and e["id"] == "ultimatum":
		TBDiplo.resolve_ultimatum(g, int(e["from"]), n, int(e["p"]), choice == 0)
		return
	if e["kind"] == "prop" and e["id"] == "call":                                       # an ally asks for help: 0 = join its war, 1 = stay out (and be remembered for it)
		var caller: int = int(e["from"]); var foe: int = int(e.get("e", 0))
		if choice == 0 and TBWar.call_why(g, caller, n, foe) == "": TBWar.join(g, n, caller, foe)
		else: TBWar.snub(g, n, caller, foe)
		return
	if e["kind"] == "prop":
		if choice == 0: TBDiplo.accept_offer(g, int(e["from"]), n, String(e["id"]))
		g.log.append({"turn": g.turn, "kind": "offer_" + ("yes" if choice == 0 else "no"), "a": int(e["from"]), "b": n, "id": e["id"]})
		return
	if e["kind"] == "rand":
		for ev in _random:
			if ev["id"] == e["id"]:
				apply_effects(g, n, ev["choices"][choice]["effects"])
				break
	else:
		for ev in scheduled_for(g.era_id):
			if ev["id"] == e["id"]:
				var chs: Array = ev.get("choices", [])
				if chs.size() > 0: _apply_sched_effects(g, n, chs[choice].get("effects", []))
				break
	g.log.append({"turn": g.turn, "kind": "event_choice", "a": n, "id": e["id"], "k": choice, "rand": e["kind"] == "rand", "title": e.get("title", {})})

static func _provs(g: TBGame, n: int, scope: String) -> PackedInt32Array:
	var own := g.owned(n)
	var out := PackedInt32Array()
	if own.is_empty(): return out
	match scope:
		"all": return own
		"capital": if g.capital_of[n] >= 0: out.append(g.capital_of[n])
		"third": out = own.slice(0, ceili(own.size() / 3.0))
		"half": out = own.slice(0, ceili(own.size() / 2.0))
		"two": out = own.slice(0, 2)
		"best":
			var b := own[0]
			for p in own: if g.army[p] > g.army[b]: b = p
			out.append(b)
		"best_dev":
			var b := own[0]
			for p in own: if g.dev[p] > g.dev[b]: b = p
			out.append(b)
		"weakest":
			var w := own[0]
			for p in own: if g.army[p] < g.army[w]: w = p
			out.append(w)
		"random": out.append(own[g.rng.randi_n(own.size())])
	return out

## What an effect really adds for this nation, in the game's own units. The appliers use it and so do the event cards, so a card says what will happen.
## Gold and a trade windfall are in the nation's gold (the data's numbers are for a nation of 400 workers), manpower in men, research as tenths of a turn of its research.
static func amount(g: TBGame, n: int, op: String, d: float) -> float:
	match op:
		"gold", "trade": return g.gu(n, d)
		"manpower": return float(g.au(d)) if d >= 0.0 else -float(g.au(-d))
		"research": return d / 10.0 * research_unit(g, n)
	return d

## one turn of the nation's research at its present budget (at least a tenth of its income goes to it, so a nation that spends nothing still gains from a windfall)
static func research_unit(g: TBGame, n: int) -> float:
	var inc: Dictionary = g.income(n)
	return maxf(1.0, D.tech_gain(TBTurn._research_pop(g, float(inc["pop"])), float(maxi(10, g.budget[n * 4 + 2]))))

## the effects of a choice as rows a card can print: [{op, v, scope, estate, turns}] with v already in the nation's units. Reads both data shapes (random events: op/d,
## scheduled events: nation.op/delta).
static func preview(g: TBGame, n: int, effects: Array) -> Array:
	var out: Array = []
	for e in effects:
		var op := String(e.get("op", "")).trim_prefix("nation.")
		var d: float = float(e.get("d", e.get("delta", 0)))
		var scope := String(e.get("scope", ""))
		match op:
			"gold", "manpower", "research": out.append({"op": op, "v": amount(g, n, op, d)})
			"trade": out.append({"op": "trade", "v": amount(g, n, "trade", d)})
			"stab", "stability": out.append({"op": "stability", "v": d, "scope": scope})
			"happy", "infamy", "intel", "dp", "mp": out.append({"op": op, "v": d})
			"loyalty": out.append({"op": "loyalty", "v": d, "estate": String(e.get("estate", ""))})
			"dev": out.append({"op": "dev", "v": 1.0, "scope": scope})
			"army_pct": out.append({"op": "army_pct", "v": d})
			"pop_pct": out.append({"op": "pop_pct", "v": d})
			"army":
				if e.has("pct"): out.append({"op": "army_pct", "v": float(e["pct"]), "scope": scope})
				else: out.append({"op": "army", "v": float(g.au(d)) if d >= 0.0 else -float(g.au(-d)), "scope": scope})
			"pop":
				if e.has("abs"): out.append({"op": "pop", "v": float(g.pu(float(e["abs"]))), "scope": scope})
				else: out.append({"op": "pop_pct", "v": float(e.get("pct", 0)), "scope": scope})
			"bonus":
				if String(e.get("kind", "")) == "trade": out.append({"op": "trade", "v": amount(g, n, "trade", float(e.get("amount", 0)))})
				else: out.append({"op": "combat", "v": float(e.get("amount", 0)), "turns": int(e.get("turns", 1))})
			"combat": out.append({"op": "combat", "v": d, "turns": int(e.get("turns", 6))})
	return out

static func apply_effects(g: TBGame, n: int, effects: Array) -> void:
	for e in effects:
		var d: float = float(e.get("d", 0))
		match String(e.get("op", "")):
			"gold": g.gold[n] = maxf(0.0, g.gold[n] + amount(g, n, "gold", d))
			"infamy": g.infamy[n] = clampf(g.infamy[n] + d, 0.0, 100.0)
			"research": g.research[n] = maxf(0.0, g.research[n] + amount(g, n, "research", d))
			"intel": g.intel[n] = clampf(g.intel[n] + d, 0.0, 20.0)
			"loyalty": TBEstates.shift(g, n, String(e.get("estate", "")), d)
			"manpower": g.manpower[n] = maxf(0.0, g.manpower[n] + amount(g, n, "manpower", d))
			"mp": g.mp[n] += d
			"dp": g.dp[n] = maxf(0.0, g.dp[n] + d)
			"stab":
				for p in _provs(g, n, String(e.get("scope", "all"))):
					g.stab[p] = clampi(g.stab[p] + int(d), 5, 100); g.touch(p)
			"pop":
				for p in _provs(g, n, String(e.get("scope", "all"))):
					if e.has("abs"): g.pop[p] = mini(g.pop_hard(), g.pop[p] + g.pu(float(e["abs"])))
					else: g.pop[p] = maxi(10, int(g.pop[p] * (1.0 + float(e.get("pct", 0)) / 100.0)))
					g.touch(p)
			"army":
				for p in _provs(g, n, String(e.get("scope", "all"))):
					if e.has("pct"): g.army[p] = maxi(g.au(5.0), int(g.army[p] * (1.0 + float(e["pct"]) / 100.0)))
					else: g.army[p] = clampi(g.army[p] + (g.au(d) if d > 0.0 else -g.au(-d)), g.au(5.0), g.army_cap(p))
					g.touch(p)
			"dev":
				var scope := String(e.get("scope", "best"))
				for p in _provs(g, n, "best_dev" if scope == "best" else scope):
					if g.dev[p] < 5:
						g.dev[p] += 1; g.pop[p] = mini(g.pop_hard(), int(g.pop[p] * 1.06) + g.pu(25.0)); g.touch(p)
			"bonus":
				if String(e.get("kind", "")) == "trade": g.trade_bonus[n] += int(amount(g, n, "trade", float(e.get("amount", 0))))
				else:
					g.combat_bonus[n] += float(e.get("amount", 0)) / 100.0; g.combat_turns[n] += int(e.get("turns", 1))
