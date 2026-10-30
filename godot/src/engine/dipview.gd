## Read-only view of how an AI nation weighs a diplomatic request: the same sums as TBAI.accepts_pact / accepts_peace and TBTrade.accepts,
## broken into named terms. The interface draws them (disposition meter, the "why they feel this way" list, the negotiation dial).
## Nothing here changes state, and `ok` always equals what the engine decides (tests/dipview.gd checks it on random positions).
class_name TBDipView
extends RefCounted

const D = preload("res://src/engine/data.gd")

## result: {"score", "need", "terms": [[key, value], ...], "blocked": "" | key, "ok": bool}
static func _res(score: float, need: float, terms: Array, blocked: String) -> Dictionary:
	return {"score": score, "need": need, "terms": terms, "blocked": blocked, "ok": blocked == "" and score > need}

## t (an AI nation) weighing a pact of kind rel (D.REL_NAP / D.REL_ALLY) with p
static func pact(g: TBGame, t: int, p: int, rel: int) -> Dictionary:
	var pers: Dictionary = D.PERSONALITIES[g.personality[t]]
	var blocked := ""
	if g.grudge[t * g.N1 + p] > 20: blocked = "grudge"
	elif g.has_truce(t, p) and rel == D.REL_ALLY: blocked = "truce"
	elif g.rules >= 3 and rel == D.REL_ALLY and TBDiplo.ally_count(g, t) >= TBDiplo.max_allies(g, t): blocked = "allies"
	var terms: Array = []
	var s: float = float(pers["dipl"]) * 0.6
	terms.append(["dv_temper", s])
	if rel == D.REL_NAP: s += 0.3; terms.append(["dv_nap", 0.3])
	if g.rules >= 1:
		var inf: float = -maxf(0.0, g.infamy[p] - 12.0) * 0.02
		if inf != 0.0: s += inf; terms.append(["dv_infamy", inf])
	var shared := 0
	for o in range(1, g.N + 1):
		if g.get_rel(t, o) == D.REL_WAR and g.get_rel(p, o) == D.REL_WAR: shared += 1
	if shared > 0: s += 0.3 * shared; terms.append(["dv_shared", 0.3 * shared])
	if g.own_count(p) > g.own_count(t) * 3: s -= 0.2; terms.append(["dv_size", -0.2])
	if g.rules >= 3:
		for tm in TBDiplo.pact_terms(g, t, p, rel):
			s += float(tm[1]); terms.append(tm)
	return _res(s, 0.45, terms, blocked)

## t weighing a trade deal with p (the sums are TBTrade.weigh: the AI decides with the very same terms)
static func trade(g: TBGame, t: int, p: int) -> Dictionary:
	var w := TBTrade.weigh(g, t, p)
	var score := 0.0
	for tm in w["terms"]: score += float(tm[1])
	return _res(score, 0.55, w["terms"], String(w["blocked"]))

## t (AI) weighing the peace terms p (the proposer) offers: kind = "white" | "cede" | "vassal"
static func peace(g: TBGame, t: int, p: int, kind: String) -> Dictionary:
	var N1 := g.N1
	var my_ws: float = float(g.war_score[t * N1 + p])
	var their_ws: float = float(g.war_score[p * N1 + t])
	var dur: float = float(g.war_turns[t * N1 + p])
	var terms: Array = []
	var want: float = (their_ws - my_ws) * 0.04
	terms.append(["dv_front", want])
	var weary: float = minf(1.5, dur / 20.0)
	want += weary; terms.append(["dv_weary", weary])
	var gr: float = -float(g.grudge[t * N1 + p]) / 80.0
	want += gr
	if gr != 0.0: terms.append(["dv_grudge", gr])
	if kind == "cede":
		var c: float = -(0.5 + their_ws * 0.02)
		want += c; terms.append(["dv_cede", c])
	elif kind == "vassal":
		var v: float = -(1.5 + their_ws * 0.03)
		want += v; terms.append(["dv_vassal", v])
	return _res(want, TBAI.peace_bar(g), terms, "")

## the disposition meter value 0..100 for a result: need sits at 45
static func meter(r: Dictionary) -> float:
	var span: float = 2.0 * float(r["need"])
	return clampf(50.0 + (float(r["score"]) - float(r["need"])) / maxf(0.2, span) * 55.0, 0.0, 100.0)
