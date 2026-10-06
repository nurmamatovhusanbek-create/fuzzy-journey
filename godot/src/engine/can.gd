## Read-only eligibility query for every verb the command card shows: TBGame.can({cmd, ...}) -> {ok, reason, cost...}.
## It mirrors the validation of commands.gd (same order, same error codes) WITHOUT changing any state, drawing from the RNG
## or touching the dirty lists, so it is safe to call from the UI every refresh. It does not predict the AI's answer to a
## proposal (nap / ally / trade / marry / peace): "refused" can only be learnt by asking.
##
## Result keys
##   ok       bool          the command would pass validation right now
##   reason   String        engine error code ("gold", "mp", "notyours", ...) when not ok; "" otherwise (maps to i18n err_<code>)
##   gold, moves, men, dp   what the command costs (men = manpower); filled whether or not it is affordable
##   short    Dictionary    {gold|moves|men|dp: missing amount} for every resource the player lacks (may hold several)
##   gain     int           troops added (recruit / hire) or sent (move)
##   kind     String        move: "move" | "attack"; declareWar: casus belli id or ""
##   infamy   float         declareWar: infamy the act adds
##   levels   int           build: level the building reaches
class_name TBCan
extends RefCounted

const D = preload("res://src/engine/data.gd")

static func check(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = int(c.get("n", g.human_id))
	var out := {"ok": true, "reason": "", "gold": 0, "moves": 0, "men": 0, "dp": 0, "short": {}, "gain": 0, "kind": "", "infamy": 0.0}
	var cmd: String = c.get("cmd", "")
	if n <= 0 or n >= g.N1 or g.alive[n] == 0: return _fail(out, "dead")
	match cmd:
		"move": return _move(g, n, c, out)
		"recruit": return _recruit(g, n, c, out)
		"hire": return _hire(g, n, c, out)
		"appoint": return _appoint(g, n, c, out)
		"build": return _build(g, n, c, out)
		"colonize": return _colonize(g, n, c, out)
		"develop": return _develop(g, n, c, out)
		"declareWar": return _declare_war(g, n, c, out)
		"peace": return _peace(g, n, c, out)
		"ally": return _ally(g, n, c, out)
		"nap": return _nap(g, n, c, out)
		"breakPact": return _break_pact(g, n, c, out)
		"ultimatum": return _ultimatum(g, n, c, out)
		"marry": return _marry(g, n, c, out)
		"trade": return _trade(g, n, c, out)
	return _fail(out, "unknown")

static func _fail(out: Dictionary, why: String) -> Dictionary:
	out["ok"] = false
	if out["reason"] == "": out["reason"] = why
	return out

## record a shortfall of one resource; the first one recorded becomes the reason when no earlier rule failed
static func _need(out: Dictionary, key: String, have: float, need: float, code: String) -> void:
	if have + 0.0001 < need:
		out["short"][key] = int(ceil(need - have))
		out["ok"] = false
		if out["reason"] == "": out["reason"] = code

# ---------------------------------------------------------------- units and fights
static func _move(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var from: int = int(c.get("from", -1)); var to: int = int(c.get("to", -1))
	if from < 0 or to < 0 or from >= g.P or to >= g.P: return _fail(out, "notadjacent")
	var att := g.controller(to) != n
	var need: float = D.MP_ATTACK if att else D.MP_MOVE
	out["moves"] = int(need)
	out["kind"] = "attack" if att else "move"
	var troops: int = int(c.get("troops", 0))
	out["gain"] = mini(troops if troops != 0 else g.army[from] - 1, g.army[from] - 1)
	_need(out, "moves", g.mp[n], need, "mp")                           # the engine tests move points before the geometry
	var chk := g.move_check(n, from, to)
	if chk.begins_with("!"):
		out["geometry"] = chk.substr(1)
		out["ok"] = false
		if out["reason"] == "": out["reason"] = chk.substr(1)
	else:
		out["kind"] = chk
	return out

static func _recruit(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var p: int = int(c.get("p", -1))
	if p < 0 or p >= g.P: return _fail(out, "notyours")
	var reg: Dictionary = D.REGIMES[g.regime[n]]
	var amount := clampi(int(c.get("amount", 15)), 5, 30)
	var gold_cost := int(ceil((D.COST_RECRUIT_GOLD + amount * 0.6) * float(reg["recruitCost"]) * (0.5 if g.building[p] == D.B_ARMORY else 1.0)))
	var man_cost: int = D.COST_RECRUIT_MAN + amount
	out["gold"] = gold_cost; out["men"] = man_cost; out["moves"] = D.MP_RECRUIT; out["gain"] = amount
	if g.controller(p) != n or g.owner[p] != n: return _fail(out, "notyours")
	_need(out, "gold", g.gold[n], gold_cost, "gold")
	_need(out, "men", g.manpower[n], man_cost, "manpower")
	_need(out, "moves", g.mp[n], D.MP_RECRUIT, "mp")
	return out

static func _hire(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var p: int = int(c.get("p", -1))
	if p < 0 or p >= g.P: return _fail(out, "notyours")
	var amount := clampi(int(c.get("amount", 30)), 10, 60)
	var cost := int(ceil(amount * 5.0 * float(D.REGIMES[g.regime[n]]["recruitCost"])))
	out["gold"] = cost; out["moves"] = 1; out["gain"] = amount
	if g.controller(p) != n or g.owner[p] != n: return _fail(out, "notyours")
	_need(out, "gold", g.gold[n], cost, "gold")
	_need(out, "moves", g.mp[n], 1, "mp")
	return out

static func _appoint(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var p: int = int(c.get("p", -1))
	if g.rules < 1: return _fail(out, "unknown")
	if p < 0 or p >= g.P: return _fail(out, "notyours")
	out["gold"] = TBGenerals.cost(g, n)
	if g.owner[p] != n or g.controller(p) != n: return _fail(out, "notyours")
	if g.gen[p] != 0: return _fail(out, "has")
	if g.army[p] < TBGenerals.MIN_ARMY: return _fail(out, "army")
	if TBGenerals.count(g, n) >= TBGenerals.cap(g, n): return _fail(out, "cap")
	_need(out, "gold", g.gold[n], out["gold"], "gold")
	return out

static func _build(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var p: int = int(c.get("p", -1)); var b: int = int(c.get("b", 0))
	if b < 1 or b > D.BUILDINGS.size(): return _fail(out, "type")
	if p < 0 or p >= g.P: return _fail(out, "notyours")
	var bt: Dictionary = D.BUILDINGS[b - 1]
	var cur: int = g.b_level[p] if g.building[p] == b else 0
	var lvl := cur + 1
	if lvl <= int(bt["maxLevel"]):
		var reg: Dictionary = D.REGIMES[g.regime[n]]
		out["gold"] = int(bt["cost"][lvl - 1]); out["moves"] = maxi(1, int(round(float(bt["mp"][lvl - 1]) * float(reg["moveCost"]))))
		out["levels"] = lvl
	if g.owner[p] != n or g.occupier[p] != 0: return _fail(out, "notyours")
	if g.b_building[p] != 0: return _fail(out, "busy")
	if g.building[p] != 0 and g.building[p] != b: return _fail(out, "occupied")
	if lvl > int(bt["maxLevel"]): return _fail(out, "max")
	if g.tech_level[n] < float(bt["tech"][lvl - 1]): return _fail(out, "tech")
	_need(out, "gold", g.gold[n], out["gold"], "gold")
	_need(out, "moves", g.mp[n], out["moves"], "mp")
	return out

static func _develop(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var p: int = int(c.get("p", -1))
	if p < 0 or p >= g.P: return _fail(out, "notyours")
	out["gold"] = 80 + g.dev[p] * 80; out["moves"] = 2
	if g.owner[p] != n or g.occupier[p] != 0: return _fail(out, "notyours")
	var cap := clampi(int(floor(g.tech_level[n])) + 1, 1, 5)
	if g.dev[p] >= cap: return _fail(out, "max")
	_need(out, "gold", g.gold[n], out["gold"], "gold")
	_need(out, "moves", g.mp[n], 2, "mp")
	return out

static func _colonize(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var p: int = int(c.get("p", -1))
	if p < 0 or p >= g.P: return _fail(out, "taken")
	var reg: Dictionary = D.REGIMES[g.regime[n]]
	out["gold"] = 0 if reg["colonyFree"] else 60 + g.own_count(n) * 2
	out["moves"] = 2
	if g.owner[p] != 0: return _fail(out, "taken")
	if g.discoverable[p] != 0 and g.tech_level[n] < 2: return _fail(out, "tech")
	var adj := false
	for i in range(g.nb_off[p], g.nb_off[p + 1]):
		var q := g.nb[i]
		if g.owner[q] == n and (g.nb_sea[i] == 0 or g.building[q] == D.B_PORT):
			adj = true; break
	if not adj: return _fail(out, "notadjacent")
	_need(out, "gold", g.gold[n], out["gold"], "gold")
	_need(out, "moves", g.mp[n], 2, "mp")
	return out

# ---------------------------------------------------------------- diplomacy
static func _target_ok(g: TBGame, n: int, t: int) -> bool:
	return not (n == t or t <= 0 or t >= g.N1 or g.alive[t] == 0)

static func _declare_war(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = int(c.get("t", 0))
	out["dp"] = D.DP_WAR
	if not _target_ok(g, n, t): return _fail(out, "target")
	var ult: bool = g.rules >= 1 and bool(c.get("_ult", false))
	var cb := TBDiplo.cb(g, n, t)
	out["kind"] = "ultimatum" if ult else cb
	out["infamy"] = TBDiplo.NO_CB_INFAMY if (g.rules >= 1 and cb == "" and not ult) else 0.0
	if ult: out["dp"] = 0
	if g.get_rel(n, t) == D.REL_WAR: return _fail(out, "already")
	if g.has_truce(n, t): return _fail(out, "truce")
	_need(out, "dp", g.dp[n], 0.0 if ult else float(D.DP_WAR), "dp")
	if g.overlord[n] == t or g.overlord[t] == n:
		out["ok"] = false
		if out["reason"] == "": out["reason"] = "vassal"       # engine order: dp first, then the vassal link
	return out

static func _peace(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = int(c.get("t", 0))
	if t <= 0 or t >= g.N1: return _fail(out, "notwar")
	if g.get_rel(n, t) != D.REL_WAR: return _fail(out, "notwar")
	var ws := g.war_score[n * g.N1 + t]
	var kind: String = c.get("kind", "white")
	out["kind"] = kind
	out["dp"] = D.DP_PEACE                                     # charged (never refused for lack of it: the engine floors dp at 0)
	if kind == "vassal":
		if g.rules < 1 or ws < 50: return _fail(out, "warscore")
		if g.overlord[t] != 0 or g.overlord[n] != 0: return _fail(out, "vassal")
	if kind == "cede" and ws < 25: return _fail(out, "warscore")
	return out

static func _ally(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = int(c.get("t", 0))
	out["dp"] = D.DP_ALLY
	if t <= 0 or t >= g.N1: return _fail(out, "target")
	if g.get_rel(n, t) == D.REL_WAR: return _fail(out, "war")
	_need(out, "dp", g.dp[n], D.DP_ALLY, "dp")
	return out

static func _nap(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = int(c.get("t", 0))
	out["dp"] = D.DP_NAP
	if t <= 0 or t >= g.N1: return _fail(out, "state")
	if g.get_rel(n, t) != D.REL_PEACE: return _fail(out, "state")
	_need(out, "dp", g.dp[n], D.DP_NAP, "dp")
	return out

static func _break_pact(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = int(c.get("t", 0))
	if t <= 0 or t >= g.N1: return _fail(out, "state")
	var r := g.get_rel(n, t)
	if r != D.REL_ALLY and r != D.REL_NAP: return _fail(out, "state")
	return out

static func _ultimatum(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = int(c.get("t", 0)); var p: int = int(c.get("p", -1))
	out["dp"] = TBDiplo.DP_ULT
	if p < 0 or p >= g.P: return _fail(out, "target")
	var why := TBDiplo.can_ultimatum(g, n, t, p)
	if why != "": return _fail(out, why)
	if g.human[n] != 0: _need(out, "dp", g.dp[n], TBDiplo.DP_ULT, "dp")
	return out

static func _marry(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = int(c.get("t", 0))
	out["dp"] = TBDiplo.DP_MARRY
	if g.rules < 1: return _fail(out, "rules")
	if t <= 0 or t >= g.N1: return _fail(out, "state")
	if not TBDiplo.can_marry(g, n, t): return _fail(out, "state")
	_need(out, "dp", g.dp[n], TBDiplo.DP_MARRY, "dp")
	if out["ok"] and g.has_truce(n, t) and g.human[t] == 0: return _fail(out, "truce")
	return out

static func _trade(g: TBGame, n: int, c: Dictionary, out: Dictionary) -> Dictionary:
	var t: int = int(c.get("t", 0))
	out["dp"] = TBTrade.DP_COST
	if g.rules < 1: return _fail(out, "rules")
	if t <= 0 or t >= g.N1 or t == n or g.alive[t] == 0 or t == g.rebel: return _fail(out, "target")
	if g.get_rel(n, t) == D.REL_WAR: return _fail(out, "war")
	if TBTrade.has(g, n, t): return _fail(out, "active")
	if g.trade_cnt[n] >= TBTrade.max_deals(g, n): return _fail(out, "tradefull")
	_need(out, "dp", g.dp[n], TBTrade.DP_COST, "dp")
	return out
