## Command layer: the only way to mutate a TBGame (single player, AI and multiplayer all go through apply()).
## Each command validates, charges its costs, mutates through the game's own helpers and returns {ok, ...}.
class_name TBCommands
extends RefCounted

const D = preload("res://src/engine/data.gd")

# ---------------------------------------------------------------- the command schema (one list for the interface, the AI and the server)
## field kinds: p province | pn province or -1 | t nation | q 0..65000 | b building type | r regime | u event uid | k choice index | v -1000..1000 | s short id string; "?name" is optional.
## `n` (the acting nation) is always required. Keys that are not listed are dropped, so a hostile client cannot smuggle a flag such as `_force` through; only a trusted caller keeps FLAGS.
const SCHEMA := {
	"move": {"from": "p", "to": "p", "?troops": "q"}, "recruit": {"p": "p", "?amount": "q"}, "hire": {"p": "p", "?amount": "q"},
	"declareWar": {"t": "t"}, "peace": {"t": "t", "?kind": "s"}, "ally": {"t": "t"}, "nap": {"t": "t"}, "breakPact": {"t": "t"},
	"build": {"p": "p", "b": "b"}, "demolish": {"p": "p", "?b": "b"}, "budget": {"key": "s", "val": "v"},
	"colonize": {"p": "p"}, "relocate": {"p": "p"}, "develop": {"p": "p"}, "regime": {"r": "r"},
	"spy": {"t": "t", "op": "s"}, "eventChoice": {"uid": "u", "i": "k"}, "decide": {"id": "s"}, "doctrine": {"id": "s"},
	"trade": {"t": "t"}, "marry": {"t": "t"}, "cancelTrade": {"t": "t"}, "ultimatum": {"t": "t", "?p": "pn"}, "appoint": {"?p": "pn"},
	"ask": {"kind": "s", "t": "t", "?op": "s", "?p": "pn"}, "noop": {},
}
const FLAGS := ["_force", "_ult"]                       # engine-internal switches (the AI and the court answers use them); never accepted from a client
const PACT_CMDS := ["ally", "nap", "marry", "trade", "ultimatum", "breakPact"]
const MAX_ID_LEN := 24

## the aimed-at nation of a command is wrong: oneself, a dead nation (except to cancel a deal or make peace), the rebels in a pact. TBCan uses the same rule, so its preview and apply() agree.
## Rules 0 is the legacy mode kept bit-identical with the JavaScript reference (tools/oracle.sh); its AI pacts with the rebel pseudo-nation, so the dead / rebel clauses start at rules 1.
static func bad_target(g: TBGame, cmd: String, n: int, t: int) -> bool:
	if t == n: return true
	if g.rules < 1: return false
	return (g.alive[t] == 0 and cmd != "cancelTrade" and cmd != "peace") or (t == g.rebel and cmd in PACT_CMDS)

## one field value in range, or null
static func _field(g: TBGame, kind: String, v: Variant) -> Variant:
	if kind == "s":
		if not (v is String) or String(v).length() > MAX_ID_LEN: return null
		return String(v)
	if not (v is int or v is float): return null
	if v is float and (is_nan(v) or is_inf(v) or absf(v) > 2.0e9): return null
	var i := int(v)
	match kind:
		"p": return i if i >= 0 and i < g.P else null
		"pn": return i if i >= -1 and i < g.P else null
		"t": return i if i >= 1 and i < g.N1 else null
		"q": return clampi(i, 0, 65000)
		"b": return i if i >= 0 and i <= 64 else null
		"r": return i if i >= 0 and i <= 32 else null
		"u": return i if i >= 0 else null
		"k": return i if i >= 0 and i <= 16 else null
		"v": return clampi(i, -1000, 1000)
	return null

## a clean copy of a command (only the listed fields, typed and in range), or {} when it cannot be made valid. `err` (optional) gets the reason.
static func normalize(g: TBGame, c: Dictionary, trusted: bool = false) -> Dictionary:
	var cmd = c.get("cmd", "")
	if not (cmd is String) or not SCHEMA.has(cmd): return {}
	var out := {"cmd": cmd}
	if cmd == "noop": return out
	var n = _field(g, "t", c.get("n", 0))
	if n == null: return {}
	out["n"] = n
	var spec: Dictionary = SCHEMA[cmd]
	for key in spec:
		var optional: bool = String(key).begins_with("?")
		var name: String = String(key).substr(1) if optional else String(key)
		if not c.has(name):
			if optional: continue
			return {}
		var v = _field(g, String(spec[key]), c[name])
		if v == null: return {}
		out[name] = v
	if trusted:
		for f in FLAGS:
			if c.has(f): out[f] = (c[f] is bool) and c[f]
	return out

# ---------------------------------------------------------------- commands (the ONLY mutation API)
static func apply(g: TBGame, c: Dictionary) -> Dictionary:
	var raw_cmd = c.get("cmd", "")
	if not (raw_cmd is String) or not SCHEMA.has(raw_cmd): return {"ok": false, "err": "unknown"}
	var n0 = _field(g, "t", c.get("n", 0))
	if raw_cmd != "noop" and (n0 == null or g.alive[n0] == 0): return {"ok": false, "err": "dead"}
	c = normalize(g, c, true)
	if c.is_empty(): return {"ok": false, "err": "bad"}
	var cmd: String = c["cmd"]
	var n: int = int(c.get("n", 0))
	if c.has("t"):                                                              # whoever the command is aimed at: another living nation, never the actor, never the rebels in a pact
		var t: int = c["t"]
		if bad_target(g, cmd, n, t): return {"ok": false, "err": "target"}
	match cmd:
		"move": return _c_move(g, c)
		"recruit": return _c_recruit(g, c)
		"declareWar": return _c_declare_war(g, c)
		"peace": return _c_peace(g, c)
		"ally": return _c_ally(g, c)
		"nap": return _c_nap(g, c)
		"breakPact": return _c_break_pact(g, c)
		"build": return _c_build(g, c)
		"budget": return _c_budget(g, c)
		"colonize": return _c_colonize(g, c)
		"relocate": return _c_relocate(g, c)
		"regime": return _c_regime(g, c)
		"develop": return _c_develop(g, c)
		"demolish": return _c_demolish(g, c)
		"decide": return TBDecisions.apply(g, n, String(c.get("id", "")))
		"trade": return TBTrade.propose(g, n, int(c.get("t", 0)), bool(c.get("_force", false)))
		"ultimatum": return TBDiplo.ultimatum(g, n, int(c.get("t", 0)), int(c.get("p", -1)))
		"marry": return TBDiplo.marry(g, n, int(c.get("t", 0)), bool(c.get("_force", false)))
		"cancelTrade":
			TBTrade.set_deal(g, n, int(c.get("t", 0)), false)
			return {"ok": true}
		"hire": return _c_hire(g, c)
		"ask": return TBAsks.send(g, c)
		"appoint": return TBGenerals.appoint(g, n, int(c.get("p", -1)))
		"doctrine": return TBDoctrine.adopt(g, n, String(c.get("id", "")))
		"spy": return _c_spy(g, c)
		"eventChoice": return TBEvents.resolve_choice(g, n, int(c.get("uid", 0)), int(c.get("i", 0)))
		"noop": return {"ok": true}
	return {"ok": false, "err": "unknown"}

static func _err(e: String) -> Dictionary: return {"ok": false, "err": e}

static func _c_move(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var to: int = c["to"]
	if g.rules >= 1 and g.sea_edge(int(c["from"]), to) < 0:                    # not a neighbour: a march (TBMarch) over land you hold, allies' land and your ports
		var pl := TBMarch.plan(g, n, int(c["from"]), to)
		if not bool(pl["ok"]): return _err(String(pl["err"]))
		if g.mp[n] < float(pl["mp"]): return _err("mp")
		var rm := TBMarch.order(g, n, int(c["from"]), to, int(c.get("troops", 0)))
		if rm.begins_with("!"): return _err(rm.substr(1))
		g.mp[n] -= float(pl["mp"])
		var at := -1                                                          # where the army stands now (still on the way: the march order says)
		for m in g.marches:
			if int(m["n"]) == n and int(m["to"]) == to and g.controller(int(m["at"])) == n: at = int(m["at"])
		return {"ok": true, "result": rm, "at": at}
	var att := g.controller(to) != n
	var need: float = D.MP_ATTACK if att else D.MP_MOVE
	if g.mp[n] < need: return _err("mp")
	if g.rules >= 1: TBMarch.cancel_at(g, n, int(c["from"]))                  # a hand-given move replaces the standing order of that army
	var r := g.move_or_attack(n, int(c["from"]), to, int(c.get("troops", 0)))
	if r.begins_with("!"): return _err(r.substr(1))
	g.mp[n] -= need
	return {"ok": true, "result": r}

static func _c_recruit(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if g.controller(p) != n or g.owner[p] != n: return _err("notyours")
	var reg: Dictionary = D.REGIMES[g.regime[n]]
	var amount := clampi(int(c.get("amount", 15)), 5, 30)
	var gold_cost := int(ceil((D.COST_RECRUIT_GOLD + amount * 0.6) * float(reg["recruitCost"]) * (0.5 if g.bl(p, D.B_ARMORY) > 0 else 1.0)))
	var man_cost: int = D.COST_RECRUIT_MAN + amount
	if g.gold[n] < gold_cost: return _err("gold")
	if g.manpower[n] < man_cost: return _err("manpower")
	if g.mp[n] < D.MP_RECRUIT: return _err("mp")
	g.gold[n] -= gold_cost; g.manpower[n] -= man_cost; g.mp[n] -= D.MP_RECRUIT
	g.army[p] = mini(65000, g.army[p] + amount); g.touch(p)
	return {"ok": true}

static func _c_declare_war(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	if n == t or t <= 0 or t >= g.N1 or g.alive[t] == 0: return _err("target")
	if g.get_rel(n, t) == D.REL_WAR: return _err("already")
	if g.has_truce(n, t): return _err("truce")
	var ult: bool = g.rules >= 1 and bool(c.get("_ult", false))
	if g.dp[n] < D.DP_WAR and not ult: return _err("dp")
	if g.overlord[n] == t or g.overlord[t] == n: return _err("vassal")
	var was := g.get_rel(n, t)
	if not ult: g.dp[n] -= D.DP_WAR
	g.set_rel(n, t, D.REL_WAR); g.last_war_turn[n] = g.turn
	var cb_kind := TBDiplo.on_declare(g, n, t, ult)
	var gi := t * g.N1 + n
	g.grudge[gi] = mini(100, g.grudge[gi] + (80 if was == D.REL_ALLY else (60 if was == D.REL_NAP else 40)))
	g.log.append({"turn": g.turn, "kind": "war", "a": n, "b": t, "cb": cb_kind})
	for o in range(1, g.N + 1):
		if o != n and o != t and g.alive[o] != 0 and g.get_rel(t, o) == D.REL_ALLY and not g.friendly(n, o) and g.get_rel(n, o) != D.REL_WAR and not g.has_truce(n, o):
			g.set_rel(n, o, D.REL_WAR)
			g.log.append({"turn": g.turn, "kind": "war", "a": o, "b": n, "ally": 1})
	return {"ok": true}

static func _c_peace(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	if g.get_rel(n, t) != D.REL_WAR: return _err("notwar")
	var ws := g.war_score[n * g.N1 + t]
	var kind: String = c.get("kind", "white")
	if g.human[t] == 0 and not c.get("_force", false) and not TBAI.accepts_peace(g, t, n, kind): return _err("refused")
	if kind == "vassal":
		if g.rules < 1 or ws < 50: return _err("warscore")
		if g.overlord[t] != 0 or g.overlord[n] != 0: return _err("vassal")
		g.overlord[t] = n; g.tribute[t] = 30; g.liberty[t] = 0.0
		if g.rules >= 1: g.infamy[n] = minf(100.0, g.infamy[n] + TBDiplo.VASSAL_INFAMY)
		g.log.append({"turn": g.turn, "kind": "vassal", "a": n, "b": t})
	if kind == "cede":
		if ws < 25: return _err("warscore")
		var budget_pts := ws * 0.9
		var taken := 0
		var prov: Array = []
		for p in g.owned(t):
			if g.occupier[p] == n: prov.append(p)
		prov.sort_custom(func(a, b):
			var va := g.province_value(a); var vb := g.province_value(b)
			return a < b if va == vb else va < vb)
		var total_val := 0.0
		for p in g.owned(t): total_val += g.province_value(p)
		if total_val == 0.0: total_val = 1.0
		for p in prov:
			var pct := g.province_value(p) / total_val * 100.0
			if pct > budget_pts: continue
			budget_pts -= pct; g.cede(p, n); taken += 1
		g.log.append({"turn": g.turn, "kind": "ceded", "a": n, "b": t, "k": taken})
	for p in g.owned(t):
		if g.occupier[p] == n:
			g.occupier[p] = 0; g.touch(p)
	for p in g.owned(n):
		if g.occupier[p] == t:
			g.occupier[p] = 0; g.touch(p)
	g.occ_rev += 1
	g.set_rel(n, t, D.REL_PEACE)
	var tt: int = D.TRUCE_TURNS if g.rules == 0 else 12
	g.truce[n * g.N1 + t] = g.turn + tt; g.truce[t * g.N1 + n] = g.turn + tt
	g.dp[n] = maxf(0.0, g.dp[n] - D.DP_PEACE)
	g.log.append({"turn": g.turn, "kind": "peace", "a": n, "b": t})
	return {"ok": true}

static func _c_ally(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	if g.get_rel(n, t) == D.REL_WAR: return _err("war")
	if g.dp[n] < D.DP_ALLY: return _err("dp")
	if g.human[t] == 0 and not c.get("_force", false) and not TBAI.accepts_pact(g, t, n, D.REL_ALLY): return _err("refused")
	g.dp[n] -= D.DP_ALLY; g.set_rel(n, t, D.REL_ALLY)
	g.log.append({"turn": g.turn, "kind": "ally", "a": n, "b": t})
	return {"ok": true}

static func _c_nap(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	if g.get_rel(n, t) != D.REL_PEACE: return _err("state")
	if g.dp[n] < D.DP_NAP: return _err("dp")
	if g.human[t] == 0 and not c.get("_force", false) and not TBAI.accepts_pact(g, t, n, D.REL_NAP): return _err("refused")
	g.dp[n] -= D.DP_NAP; g.set_rel(n, t, D.REL_NAP)
	g.nap_expiry[mini(n, t) * g.N1 + maxi(n, t)] = g.turn + 20
	return {"ok": true}

static func _c_break_pact(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	var r := g.get_rel(n, t)
	if r != D.REL_ALLY and r != D.REL_NAP: return _err("state")
	g.set_rel(n, t, D.REL_PEACE)
	var gi := t * g.N1 + n
	g.grudge[gi] = mini(100, g.grudge[gi] + 25)
	return {"ok": true}

static func _c_build(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]; var b: int = int(c["b"])
	if b < 1 or b > D.BUILDINGS.size(): return _err("type")
	var bt: Dictionary = D.BUILDINGS[b - 1]
	if g.owner[p] != n or g.occupier[p] != 0: return _err("notyours")
	if g.b_building[p] != 0: return _err("busy")
	var cur: int = g.bl(p, b)
	if cur == 0 and g.b_used(p) >= g.b_slots(p): return _err("slots" if g.rules >= 2 else "occupied")
	var lvl := cur + 1
	if lvl > int(bt["maxLevel"]): return _err("max")
	if g.tech_level[n] < float(bt["tech"][lvl - 1]): return _err("tech")
	var reg: Dictionary = D.REGIMES[g.regime[n]]
	var mpc := maxi(1, int(round(float(bt["mp"][lvl - 1]) * float(reg["moveCost"]))))
	var price: int = g.b_price(p, b, lvl)
	if g.gold[n] < float(price): return _err("gold")
	if g.mp[n] < mpc: return _err("mp")
	g.gold[n] -= float(price); g.mp[n] -= mpc
	g.b_building[p] = b; g.b_turns[p] = int(bt["buildTime"][lvl - 1]); g.touch(p)
	return {"ok": true}

static func _c_budget(g: TBGame, c: Dictionary) -> Dictionary:
	var i: int = ["tax", "goods", "research", "invest"].find(c.get("key", ""))
	if i < 0: return _err("key")
	var o: int = int(c["n"]) * 4
	var v := clampi(int(c.get("val", 0)), 0, 100)
	g.budget[o + i] = v
	var sum: int = g.budget[o] + g.budget[o + 1] + g.budget[o + 2] + g.budget[o + 3]
	var guard := 8
	while sum != 100 and guard > 0:
		guard -= 1
		var d := 100 - sum
		var k := -1; var best := -1
		for j in 4:
			if j != i and ((g.budget[o + j] > 0) if d < 0 else (g.budget[o + j] < 100)):
				var wgt: int = g.budget[o + j] if d < 0 else 100 - g.budget[o + j]
				if wgt > best:
					best = wgt; k = j
		if k < 0: break
		g.budget[o + k] = clampi(g.budget[o + k] + d, 0, 100)
		sum = g.budget[o] + g.budget[o + 1] + g.budget[o + 2] + g.budget[o + 3]
	return {"ok": true}

static func _c_colonize(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if g.owner[p] != 0: return _err("taken")
	if g.discoverable[p] != 0 and g.tech_level[n] < 2: return _err("tech")
	var adj := false
	for i in range(g.nb_off[p], g.nb_off[p + 1]):
		var q := g.nb[i]
		if g.owner[q] == n and (g.nb_sea[i] == 0 or g.bl(q, D.B_PORT) > 0):
			adj = true; break
	if not adj: return _err("notadjacent")
	var reg: Dictionary = D.REGIMES[g.regime[n]]
	var cost: int = 0 if reg["colonyFree"] else 60 + g.own_count(n) * 2
	if g.gold[n] < cost: return _err("gold")
	if g.mp[n] < 2: return _err("mp")
	g.gold[n] -= cost; g.mp[n] -= 2; g.set_owner(p, n); g.army[p] = maxi(g.army[p], 8); g.discoverable[p] = 0
	return {"ok": true}

static func _c_relocate(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if g.owner[p] != n: return _err("notyours")
	if g.gold[n] < 80: return _err("gold")
	g.gold[n] -= 80
	var old := g.capital_of[n]
	if old >= 0:
		g.capital[old] = 0; g.touch(old)
	g.capital[p] = 1; g.capital_of[n] = p; g.touch(p)
	return {"ok": true}

static func _c_regime(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var r: int = int(c["r"])
	if r < 0 or r >= D.REGIMES.size() or r == D.REGIME_REBELS: return _err("type")
	if g.era[n] < int(D.REGIMES[r]["sinceEra"]): return _err("era")
	if g.gold[n] < 120: return _err("gold")
	g.gold[n] -= 120; g.regime[n] = r
	for p in g.owned(n):
		g.stab[p] = maxi(5, g.stab[p] - 15)
	return {"ok": true}

## covert operations (rules >= 1): steal | sabotage | incite
const SPY_COST := {"steal": 6.0, "sabotage": 8.0, "incite": 10.0}
static func _c_spy(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]; var op: String = c.get("op", "")
	if not SPY_COST.has(op): return _err("type")
	if t <= 0 or t >= g.N1 or t == n or g.alive[t] == 0 or t == g.rebel: return _err("target")
	if g.friendly(n, t): return _err("ally")
	var cost: float = SPY_COST[op]
	if g.intel[n] < cost: return _err("intel")
	g.intel[n] -= cost
	var tech_gap := g.tech_level[n] - g.tech_level[t]
	var chance := clampf(0.60 + tech_gap * 0.08, 0.25, 0.9)
	var ok := g.rng.next() < chance
	if ok and g.rules >= 1: g.see_until[n * g.N1 + t] = g.turn + TBVision.SPY_TURNS                # a report from their court: their armies stay in view for a while
	var own := g.owned(t)
	if ok and not own.is_empty():
		match op:
			"steal":
				var amt := minf(g.gold[t] * 0.15, 150.0)
				g.gold[t] -= amt; g.gold[n] += amt
			"sabotage":
				for k in 3:
					var p := own[g.rng.randi_n(own.size())]
					g.stab[p] = maxi(5, g.stab[p] - 12)
					if k == 0 and g.building[p] != 0:
						if g.rules >= 2: g.set_bl(p, g.building[p], 0)
						else: g.building[p] = 0; g.b_level[p] = 0
					g.touch(p)
			"incite":
				var best := own[0]
				for p in own: if g.stab[p] < g.stab[best]: best = p
				g.stab[best] = maxi(5, g.stab[best] - 30); g.touch(best)
	else:
		var gi := t * g.N1 + n
		g.grudge[gi] = mini(100, g.grudge[gi] + 25)
	g.log.append({"turn": g.turn, "kind": "spy", "a": n, "b": t, "op": op, "ok": ok})
	return {"ok": true, "success": ok}

## mercenaries: converts gold directly into troops (no manpower), pricey
static func _c_hire(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if g.controller(p) != n or g.owner[p] != n: return _err("notyours")
	var amount := clampi(int(c.get("amount", 30)), 10, 60)
	var cost := int(ceil(amount * 5.0 * float(D.REGIMES[g.regime[n]]["recruitCost"])))
	if g.gold[n] < cost: return _err("gold")
	if g.mp[n] < 1: return _err("mp")
	g.gold[n] -= cost; g.mp[n] -= 1
	g.army[p] = mini(65000, g.army[p] + amount); g.touch(p)
	return {"ok": true}

## rules >= 2: pull down one building to free its slot (no refund; the level is lost)
static func _c_demolish(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]; var b: int = int(c.get("b", 0))
	if g.rules < 2 or b < 1 or b > g.NB: return _err("unknown")
	if g.owner[p] != n or g.occupier[p] != 0: return _err("notyours")
	if g.bl(p, b) == 0: return _err("none")
	if g.b_building[p] == b: return _err("busy")
	g.set_bl(p, b, 0)
	return {"ok": true}

static func _c_develop(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if g.owner[p] != n or g.occupier[p] != 0: return _err("notyours")
	var cap := clampi(int(floor(g.tech_level[n])) + 1, 1, 5)
	if g.dev[p] >= cap: return _err("max")
	var cost: int = g.develop_cost(p)
	var mpc := 2 if g.rules < 2 else 1
	if g.gold[n] < cost: return _err("gold")
	if g.mp[n] < mpc: return _err("mp")
	g.gold[n] -= cost; g.mp[n] -= mpc
	g.dev[p] += 1; g.stab[p] = mini(100, g.stab[p] + 4); g.pop[p] = mini(2000, g.pop[p] + 20); g.touch(p)
	return {"ok": true}

