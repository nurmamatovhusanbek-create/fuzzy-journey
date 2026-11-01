class_name TBPeace
extends RefCounted
## Rules 4: the peace table (docs/WAR_DESIGN.md sections 8-9). The winner spends its war score on demands; every demand has a price in points:
##   a province you hold: its share of the loser's land in percent (a claim of yours, a core, costs three quarters of that)
##   gold: GOLD_PT points buy a share of the loser's yearly income each
##   vassalise the loser: VASSAL_PTS; disarm him (his armies are halved): DISARM_PTS
## The score you may spend is your war score, plus a tenth when you had a justified cause. An AI loser accepts up to a limit that grows with his exhaustion and falls with your own
## and with his own successes, so the table can show the real ceiling before a deal is offered; a human loser always has the offer put to him by the caller.

const D = preload("res://src/engine/data.gd")

const VASSAL_PTS := 50.0
const DISARM_PTS := 20.0
const GOLD_MAX_PTS := 20
const GOLD_SHARE := 0.5               # one point of gold asks this share of the loser's gross yearly income per turn... (income is per turn, so one point = 0.5 turns of it)
const CLAIM_MUL := 0.75
const CAUSE_BONUS := 1.10
const LIMIT_SHARE := 0.85
const LIMIT_EXH_OWN := 0.8            # per point of the loser's exhaustion... (they are 0-100, so the limit moves by up to +80 / -40)
const LIMIT_EXH_FOE := 0.4
const LIMIT_RIVAL := 0.5              # his own score against you takes from what he will give

## the score the winner may spend
static func budget(g: TBGame, n: int, t: int) -> float:
	var ws := float(g.war_score[n * g.N1 + t])
	if TBDiplo.cb(g, n, t) != "": ws *= CAUSE_BONUS
	return minf(100.0, ws)

## the provinces of t that n holds and may ask for: [{p, pct, cost}] dearest first
static func offers(g: TBGame, n: int, t: int) -> Array:
	var total := 0.0
	for p in g.owned(t): total += g.province_value(p)
	if total <= 0.0: total = 1.0
	var out: Array = []
	for p in g.owned(t):
		if g.occupier[p] != n or g.siege[p] > 0: continue
		var pct := g.province_value(p) / total * 100.0
		var cost := pct * (CLAIM_MUL if g.core[p] == n else 1.0)
		out.append({"p": p, "pct": pct, "cost": cost})
	out.sort_custom(func(a, b): return float(a["cost"]) > float(b["cost"]) if float(a["cost"]) != float(b["cost"]) else int(a["p"]) < int(b["p"]))
	return out

## gold that one point of the demand asks of t
static func gold_per_point(g: TBGame, t: int) -> float:
	return maxf(8.0, GOLD_SHARE * float(g.income(t)["gold"]))

## the most points of gold t can pay now
static func gold_room(g: TBGame, t: int) -> int:
	return clampi(int(floor(g.gold[t] / gold_per_point(g, t))), 0, GOLD_MAX_PTS)

## how many points t (an AI) is ready to give up in total
static func limit(g: TBGame, n: int, t: int) -> float:
	var ws := float(g.war_score[n * g.N1 + t])
	var lim := ws * LIMIT_SHARE + g.exh[t] * LIMIT_EXH_OWN - g.exh[n] * LIMIT_EXH_FOE - float(g.war_score[t * g.N1 + n]) * LIMIT_RIVAL
	return clampf(lim, 0.0, budget(g, n, t))

## deal = {"provs": [p...], "gold": points, "vassal": bool, "disarm": bool}  ->  {"pts", "ok", "why", "gold", "budget", "limit"}
static func price(g: TBGame, n: int, t: int, deal: Dictionary) -> Dictionary:
	var out := {"pts": 0.0, "ok": false, "why": "", "gold": 0, "budget": 0.0, "limit": 0.0}
	if g.rules < 4: out["why"] = "rules"; return out
	if g.get_rel(n, t) != D.REL_WAR: out["why"] = "notwar"; return out
	var pts := 0.0
	var by_p := {}
	for o in offers(g, n, t): by_p[int(o["p"])] = float(o["cost"])
	var seen := {}
	for p in deal.get("provs", []):
		var pi := int(p)
		if seen.has(pi): continue
		if not by_p.has(pi): out["why"] = "province"; return out
		seen[pi] = true
		pts += float(by_p[pi])
	var gp := clampi(int(deal.get("gold", 0)), 0, GOLD_MAX_PTS)
	if gp > gold_room(g, t): out["why"] = "gold"; return out
	pts += float(gp)
	if bool(deal.get("vassal", false)):
		if g.overlord[t] != 0 or g.overlord[n] != 0: out["why"] = "vassal"; return out
		pts += VASSAL_PTS
	if bool(deal.get("disarm", false)): pts += DISARM_PTS
	out["pts"] = pts; out["gold"] = int(round(float(gp) * gold_per_point(g, t))) if gp > 0 else 0
	out["budget"] = budget(g, n, t); out["limit"] = out["budget"] if g.human[t] != 0 else limit(g, n, t)
	if pts > float(out["budget"]) + 0.0001: out["why"] = "warscore"; return out
	if pts > float(out["limit"]) + 0.0001: out["why"] = "limit"; return out
	out["ok"] = true
	return out

## a sensible deal for the winner: the dearest provinces first while they fit under `cap` points
static func auto_deal(g: TBGame, n: int, t: int, cap: float) -> Dictionary:
	var left := cap
	var provs: Array = []
	for o in offers(g, n, t):
		if float(o["cost"]) <= left: provs.append(int(o["p"])); left -= float(o["cost"])
	return {"provs": provs, "gold": 0, "vassal": false, "disarm": false}

## carry a priced deal out: land changes hands, gold moves, the loser may become a vassal, his armies shrink; occupations lapse and a truce is made
static func execute(g: TBGame, n: int, t: int, deal: Dictionary, cost: Dictionary) -> void:
	var taken := 0
	for p in deal.get("provs", []):
		var pi := int(p)
		if g.owner[pi] == t and g.occupier[pi] == n:
			g.cede(pi, n); taken += 1
	if int(cost["gold"]) > 0:
		var amt := minf(g.gold[t], float(cost["gold"]))
		g.gold[t] -= amt; g.gold[n] += amt
	if bool(deal.get("vassal", false)):
		g.overlord[t] = n; g.tribute[t] = 30; g.liberty[t] = 0.0
		g.infamy[n] = minf(100.0, g.infamy[n] + TBDiplo.VASSAL_INFAMY)
		g.log.append({"turn": g.turn, "kind": "vassal", "a": n, "b": t})
	if bool(deal.get("disarm", false)):
		for p in g.owned(t):
			if g.controller(p) == t and g.army[p] > 1:
				g.army[p] = maxi(1, g.army[p] / 2); g.touch(p)
	if taken > 0: g.log.append({"turn": g.turn, "kind": "ceded", "a": n, "b": t, "k": taken})
