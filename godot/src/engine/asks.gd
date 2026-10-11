## Requests to an AI court are answered NEXT turn (rules >= 1): pact, alliance, marriage, peace terms, trade deal, ultimatum and spy operations.
## One press sends the request: the cost (diplomacy points, or intel for agents) is spent at once, even if the court declines. At the start of the next turn
## the court answers: it accepts with the likelihood the button showed (computed from the same sums as TBDipView at that moment, rolled on the game's rng so
## every peer agrees), the real command is applied, and an "ans" entry lands in the log (the interface shows it as a flag notice).
## ask = {n, t, kind, op, p, turn}   kind: nap | ally | marry | peace | trade | ult | spy   op: peace kind | spy op   p: ultimatum province
class_name TBAsks
extends RefCounted

const D = preload("res://src/engine/data.gd")
const KINDS := ["nap", "ally", "marry", "peace", "trade", "ult", "spy"]
const REFUSAL_GRUDGE := 5

static func _real(kind: String) -> String:
	return {"nap": "nap", "ally": "ally", "marry": "marry", "peace": "peace", "trade": "trade", "ult": "ultimatum"}.get(kind, "")

## the engine command an ask stands for
static func real_cmd(n: int, kind: String, t: int, op: String, p: int) -> Dictionary:
	var c := {"cmd": _real(kind), "n": n, "t": t}
	if kind == "peace": c["kind"] = op
	if kind == "ult": c["p"] = p
	if kind == "spy": c = {"cmd": "spy", "n": n, "t": t, "op": op}
	return c

## the court's reading of a request (TBDipView result) or {} when the request has no such sum (ultimatum, spies)
static func view(g: TBGame, n: int, kind: String, t: int, op: String) -> Dictionary:
	match kind:
		"nap": return TBDipView.pact(g, t, n, D.REL_NAP)
		"ally", "marry": return TBDipView.pact(g, t, n, D.REL_ALLY)
		"trade": return TBDipView.trade(g, t, n)
		"peace": return TBDipView.peace(g, t, n, op if op != "" else "white")
	return {}

## the likelihood the button shows, 0 to 100 (0 = the court will not hear it)
static func chance(g: TBGame, n: int, kind: String, t: int, op: String = "", p: int = -1) -> int:
	if kind == "spy":
		return int(roundf(clampf(0.60 + (g.tech_level[n] - g.tech_level[t]) * 0.08, 0.25, 0.9) * 100.0))
	if kind == "ult":
		return clampi(int(roundf(50.0 + (TBDiplo.ult_ratio(g, n, t) - TBDiplo.ULT_RATIO) / TBDiplo.ULT_RATIO * 50.0)), 3, 97)
	var v := view(g, n, kind, t, op)
	if v.is_empty() or String(v["blocked"]) != "": return 0
	return clampi(int(roundf(TBDipView.meter(v))), 3, 97)

## is a request to t already on its way? kind "" = any court request (not spies), "spy" = a spy operation, else that kind
static func pending(g: TBGame, n: int, t: int, kind: String = "") -> bool:
	for a in g.asks:
		if int(a["n"]) != n or int(a["t"]) != t: continue
		var spy: bool = String(a["kind"]) == "spy"
		if kind == "spy":
			if spy: return true
		elif not spy and (kind == "" or kind == String(a["kind"])):
			return true
	return false

## the request on its way to t: the ask itself ({} = none); spies = true looks for an agent party instead of a court request
static func find(g: TBGame, n: int, t: int, spy: bool = false) -> Dictionary:
	for a in g.asks:
		if int(a["n"]) == n and int(a["t"]) == t and (String(a["kind"]) == "spy") == spy: return a
	return {}

static func pending_kind(g: TBGame, n: int, t: int) -> String:
	for a in g.asks:
		if int(a["n"]) == n and int(a["t"]) == t and String(a["kind"]) != "spy": return String(a["kind"])
	return ""

## validation without the court's answer: {ok, reason, dp, intel}
static func check(g: TBGame, n: int, kind: String, t: int, op: String = "", p: int = -1) -> Dictionary:
	var out := {"ok": false, "reason": "", "dp": 0, "intel": 0.0}
	if g.rules < 1 or not (kind in KINDS): out["reason"] = "rules"; return out
	if t <= 0 or t >= g.N1 or t == n or g.alive[t] == 0 or t == g.rebel: out["reason"] = "target"; return out
	if g.human[t] != 0: out["reason"] = "human"; return out
	if pending(g, n, t, "spy" if kind == "spy" else ""): out["reason"] = "asked"; return out
	if kind == "spy":
		var cost: float = TBCommands.SPY_COST.get(op, -1.0)
		if cost < 0.0: out["reason"] = "type"; return out
		if g.friendly(n, t): out["reason"] = "ally"; return out
		out["intel"] = cost
		if g.intel[n] < cost: out["reason"] = "intel"; return out
		out["ok"] = true; return out
	var pre := g.can(real_cmd(n, kind, t, op, p))
	out["dp"] = int(pre["dp"])
	if not bool(pre["ok"]): out["reason"] = String(pre["reason"]); return out
	out["ok"] = true
	return out

## the interface sends every plain request to an AI court as an ask: nap / ally / marry / trade / ultimatum / peace terms / spy operations become {"cmd": "ask", ...}
static func wrap(g: TBGame, c: Dictionary) -> Dictionary:
	if g.rules < 1: return c
	var t: int = int(c.get("t", 0))
	if t <= 0 or t >= g.N1 or g.human[t] != 0: return c
	var out := {"cmd": "ask", "n": c.get("n", g.human_id), "t": t, "op": "", "p": -1}
	match String(c.get("cmd", "")):
		"nap": out["kind"] = "nap"
		"ally": out["kind"] = "ally"
		"marry": out["kind"] = "marry"
		"trade": out["kind"] = "trade"
		"ultimatum": out["kind"] = "ult"; out["p"] = int(c.get("p", -1))
		"peace": out["kind"] = "peace"; out["op"] = String(c.get("kind", "white"))
		"spy": out["kind"] = "spy"; out["op"] = String(c.get("op", ""))
		_: return c
	return out

## the command "ask": {n, kind, t, op, p}
static func send(g: TBGame, c: Dictionary) -> Dictionary:
	var n: int = int(c["n"]); var kind: String = String(c.get("kind", "")); var t: int = int(c.get("t", 0))
	var op: String = String(c.get("op", "")); var p: int = int(c.get("p", -1))
	var r := check(g, n, kind, t, op, p)
	if not bool(r["ok"]): return {"ok": false, "err": String(r["reason"])}
	if kind == "spy": g.intel[n] -= float(r["intel"])
	else: g.dp[n] = maxf(0.0, g.dp[n] - float(r["dp"]))
	g.asks.append({"n": n, "t": t, "kind": kind, "op": op, "p": p, "turn": g.turn})
	return {"ok": true}

## the start of a turn: every ask sent before it is answered
static func resolve(g: TBGame) -> void:
	if g.rules < 1 or g.asks.is_empty(): return
	var todo: Array = []
	var keep: Array = []
	for a in g.asks:
		if int(a["turn"]) < g.turn: todo.append(a)
		else: keep.append(a)
	g.asks = keep
	for a in todo:
		var n: int = int(a["n"]); var t: int = int(a["t"]); var kind: String = String(a["kind"]); var op: String = String(a["op"]); var p: int = int(a["p"])
		if g.alive[n] == 0 or g.alive[t] == 0: continue
		var ok := false
		var void_ask := false
		if kind == "spy":
			g.intel[n] += float(TBCommands.SPY_COST.get(op, 0.0))                          # prepaid at send: refund, then the command charges itself
			var r := g.apply({"cmd": "spy", "n": n, "t": t, "op": op})
			if not bool(r["ok"]): g.intel[n] -= float(TBCommands.SPY_COST.get(op, 0.0)); void_ask = true
			else: ok = bool(r.get("success", false))
		elif kind == "ult":
			var p_now := chance(g, n, kind, t, op, p)
			var win: bool = g.rng.next() * 100.0 < float(p_now)
			var r2 := TBDiplo.resolve_ultimatum(g, n, t, p, win)
			if not bool(r2["ok"]): void_ask = true
			else: ok = win
		else:
			var pct := chance(g, n, kind, t, op, p)
			var win2: bool = g.rng.next() * 100.0 < float(pct)
			var cmd := real_cmd(n, kind, t, op, p)
			var cost: int = int(g.can(cmd)["dp"])
			if win2:
				g.dp[n] += float(cost)                                                       # prepaid at send: refund, then the command charges itself
				cmd["_force"] = true
				var r3 := g.apply(cmd)
				if bool(r3["ok"]): ok = true
				else: g.dp[n] = maxf(0.0, g.dp[n] - float(cost)); void_ask = true
			else:
				g.grudge[t * g.N1 + n] = mini(100, g.grudge[t * g.N1 + n] + REFUSAL_GRUDGE)
		if void_ask: continue
		g.log.append({"turn": g.turn, "kind": "ans", "a": n, "b": t, "what": kind, "op": op, "ok": ok})
