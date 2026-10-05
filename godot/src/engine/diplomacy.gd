## Casus belli, infamy and coalitions (rules >= 1).
## Taking land and attacking without a reason raises infamy; high infamy forms a coalition that gives everyone a free casus belli.
class_name TBDiplo
extends RefCounted

const D = preload("res://src/engine/data.gd")
const COALITION_ON := 22.0
const COALITION_OFF := 12.0
const NO_CB_INFAMY := 8.0
const LAND_INFAMY := 1.2
const VASSAL_INFAMY := 4.0
const DECAY := 0.45

## "" = no casus belli. Order matters: the cheapest justification wins.
static func cb(g: TBGame, n: int, t: int) -> String:
	if g.rules < 1: return ""
	if t == g.rebel or n == g.rebel: return "rebels"
	if g.coalition[t] != 0 and not g.friendly(n, t) and g.overlord[n] != t: return "coalition"
	for p in g.owned(t):
		if g.core[p] == n: return "reclaim"
	if g.grudge[n * g.N1 + t] >= 40: return "revenge"
	for o in range(1, g.N1):
		if g.alive[o] != 0 and g.get_rel(n, o) == D.REL_ALLY and g.get_rel(o, t) == D.REL_WAR: return "ally"
	return ""

## called by declareWar
static func on_declare(g: TBGame, n: int, t: int, ult: bool = false) -> String:
	if ult: return "ultimatum"                # the demand itself was the justification
	var k := cb(g, n, t)
	if g.rules >= 1 and k == "": g.infamy[n] = minf(100.0, g.infamy[n] + NO_CB_INFAMY)
	return k

static func on_land_taken(g: TBGame, p: int, from: int, to: int) -> void:
	if g.rules < 1 or from == 0 or to == 0 or from == g.rebel or to == g.rebel: return
	if g.core[p] == to: return              # taking back your own land is not aggression
	g.infamy[to] = minf(100.0, g.infamy[to] + LAND_INFAMY)

## per turn: decay and coalition hysteresis
static func tick(g: TBGame) -> void:
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel:
			g.infamy[n] = 0.0; g.coalition[n] = 0; continue
		if g.infamy[n] > 0.0: g.infamy[n] = maxf(0.0, g.infamy[n] - DECAY)
		if g.coalition[n] == 0 and g.infamy[n] >= COALITION_ON:
			g.coalition[n] = 1
			g.log.append({"turn": g.turn, "kind": "coalition", "a": n})
		elif g.coalition[n] != 0 and g.infamy[n] < COALITION_OFF:
			g.coalition[n] = 0
			g.log.append({"turn": g.turn, "kind": "coalition_end", "a": n})


# ---------------------------------------------------------------- royal marriages (rules >= 1)
const DP_MARRY := 3

static func can_marry(g: TBGame, a: int, b: int) -> bool:
	if g.rules < 1 or a == b or a == g.rebel or b == g.rebel or g.alive[a] == 0 or g.alive[b] == 0: return false
	var r := g.get_rel(a, b)
	return (r == D.REL_PEACE or r == D.REL_NAP) and TBRulers.is_hereditary(g, a) and TBRulers.is_hereditary(g, b) and g.overlord[a] == 0 and g.overlord[b] == 0

static func marry(g: TBGame, n: int, t: int) -> Dictionary:
	if g.rules < 1: return {"ok": false, "err": "rules"}
	if not can_marry(g, n, t): return {"ok": false, "err": "state"}
	if g.dp[n] < DP_MARRY: return {"ok": false, "err": "dp"}
	if g.has_truce(n, t) and g.human[t] == 0: return {"ok": false, "err": "truce"}
	if g.human[t] == 0 and not TBAI.accepts_pact(g, t, n, D.REL_ALLY): return {"ok": false, "err": "refused"}
	g.dp[n] -= DP_MARRY
	g.set_rel(n, t, D.REL_MARRIAGE)
	g.grudge[n * g.N1 + t] = maxi(0, g.grudge[n * g.N1 + t] - 40); g.grudge[t * g.N1 + n] = maxi(0, g.grudge[t * g.N1 + n] - 40)
	g.log.append({"turn": g.turn, "kind": "marriage", "a": n, "b": t})
	return {"ok": true}

## called when n's ruler changes: the marriage may lapse, or the match may bring a personal union under the stronger partner
static func on_succession(g: TBGame, n: int, rng: TBRng) -> void:
	for x in range(1, g.N1):
		if x == n or g.alive[x] == 0 or g.get_rel(n, x) != D.REL_MARRIAGE: continue
		var roll := rng.next()
		if roll < 0.22 and g.overlord[n] == 0 and g.overlord[x] == 0 and g.own_count(x) * 10 >= g.own_count(n) * 8 and g.human[n] == 0:
			g.overlord[n] = x; g.tribute[n] = 0; g.liberty[n] = 0.0
			g.log.append({"turn": g.turn, "kind": "union", "a": x, "b": n})
		elif roll < 0.5:
			g.set_rel(n, x, D.REL_PEACE)
			g.log.append({"turn": g.turn, "kind": "marriage_end", "a": n, "b": x})
		return

static func ai_marry(g: TBGame, n: int) -> void:
	if g.rules < 1 or g.dp[n] < DP_MARRY + 1.0 or g.rng.next() > 0.04 or not TBRulers.is_hereditary(g, n): return
	for o in range(1, g.N1):
		if o != n and can_marry(g, n, o) and g.human[o] == 0 and g.own_count(o) >= 6:
			marry(g, n, o); return


# ---------------------------------------------------------------- offers from AI nations to human players (rules >= 1)
static func _offer_valid(g: TBGame, from: int, to: int, what: String) -> bool:
	if g.alive[from] == 0 or g.alive[to] == 0: return false
	var r := g.get_rel(from, to)
	match what:
		"nap": return r == D.REL_PEACE
		"ally": return r == D.REL_NAP or (r == D.REL_PEACE and g.dp[from] >= D.DP_ALLY)
		"trade": return r != D.REL_WAR and not TBTrade.has(g, from, to) and g.trade_cnt[from] < TBTrade.max_deals(g, from) and g.trade_cnt[to] < TBTrade.max_deals(g, to)
		"marry": return can_marry(g, from, to)
	return false

static func accept_offer(g: TBGame, from: int, to: int, what: String) -> void:
	if not _offer_valid(g, from, to, what): return
	match what:
		"nap":
			g.set_rel(from, to, D.REL_NAP); g.nap_expiry[mini(from, to) * g.N1 + maxi(from, to)] = g.turn + 20
			pass
		"ally": g.set_rel(from, to, D.REL_ALLY); g.log.append({"turn": g.turn, "kind": "ally", "a": from, "b": to})
		"trade": TBTrade.set_deal(g, from, to, true); g.log.append({"turn": g.turn, "kind": "trade", "a": from, "b": to})
		"marry":
			g.set_rel(from, to, D.REL_MARRIAGE); g.log.append({"turn": g.turn, "kind": "marriage", "a": from, "b": to})

## an AI nation occasionally proposes something friendly to a human (shown as a prompt; unanswered = declined next turn)
static func ai_offer(g: TBGame, n: int) -> void:
	if g.rules < 1 or g.human[n] != 0 or n == g.rebel or g.rng.next() > 0.015: return
	var pers: Dictionary = D.PERSONALITIES[g.personality[n]]
	if float(pers["dipl"]) < 0.4: return
	for h in g.humans():
		if g.alive[h] == 0 or g.grudge[n * g.N1 + h] >= 20 or g.get_rel(n, h) == D.REL_WAR: continue
		var busy := false
		for e in g.pending: if int(e["n"]) == h and e["kind"] == "prop": busy = true
		if busy: return
		var kinds: Array = []
		for w in ["nap", "ally", "trade", "marry"]:
			if _offer_valid(g, n, h, w): kinds.append(w)
		if kinds.is_empty(): continue
		var what: String = kinds[g.rng.randi_n(kinds.size())]
		g.ev_uid += 1
		g.pending.append({"uid": g.ev_uid, "n": h, "kind": "prop", "id": what, "from": n, "icon": "🤝", "cat": "", "count": 2})
		return

## once per turn, after unanswered prompts were cleared: AI nations may make offers to humans
static func offers_turn(g: TBGame) -> void:
	if g.rules < 1 or g.humans().is_empty(): return
	for n in range(1, g.N1):
		if g.alive[n] != 0 and g.human[n] == 0: ai_offer(g, n)


# ---------------------------------------------------------------- ultimatums (rules >= 1)
## demand a border province without declaring war: yield and it changes hands quietly; refuse and the demander gets a free casus belli
const DP_ULT := 2
const ULT_RATIO := 2.4          # an AI target yields when the demander is this much stronger (allies of the target count)

static func power(g: TBGame, n: int) -> float:
	var s := 0.0
	for p in g.owned(n): s += g.army[p]
	return s * g.combat_mul(n)

static func ult_ratio(g: TBGame, n: int, t: int) -> float:
	var theirs := power(g, t)
	for o in range(1, g.N1):
		if o != n and g.alive[o] != 0 and g.get_rel(t, o) == D.REL_ALLY: theirs += 0.6 * power(g, o)
	return power(g, n) / maxf(1.0, theirs)

static func borders(g: TBGame, n: int, p: int) -> bool:
	for i in range(g.nb_off[p], g.nb_off[p + 1]):
		if g.nb_sea[i] == 0 and g.controller(g.nb[i]) == n: return true
	return false

static func can_ultimatum(g: TBGame, n: int, t: int, p: int) -> String:
	if g.rules < 1 or n == t or t <= 0 or t >= g.N1 or t == g.rebel or n == g.rebel: return "target"
	if g.alive[t] == 0 or g.owner[p] != t or g.controller(p) != t: return "target"
	if g.get_rel(n, t) != D.REL_PEACE: return "notpeace"
	if g.has_truce(n, t): return "truce"
	if g.overlord[n] == t or g.overlord[t] == n: return "vassal"
	if g.capital[p] != 0: return "capital"
	if not borders(g, n, p): return "notadjacent"
	return ""

## the province of t that n would most like: highest value among those touching n's land
static func ult_target(g: TBGame, n: int, t: int) -> int:
	var best := -1; var bv := -1.0
	for p in g.owned(t):
		if can_ultimatum(g, n, t, p) != "": continue
		var v := g.province_value(p)
		if v > bv: bv = v; best = p
	return best

static func ultimatum(g: TBGame, n: int, t: int, p: int) -> Dictionary:
	var why := can_ultimatum(g, n, t, p)
	if why != "": return {"ok": false, "err": why}
	if g.human[n] != 0 and g.dp[n] < DP_ULT: return {"ok": false, "err": "dp"}
	g.dp[n] = maxf(0.0, g.dp[n] - DP_ULT)
	if g.human[t] != 0:
		for e in g.pending:
			if int(e["n"]) == t and e["kind"] == "prop" and e["id"] == "ultimatum" and int(e["from"]) == n: return {"ok": true, "result": "pending"}
		g.ev_uid += 1
		g.pending.append({"uid": g.ev_uid, "n": t, "kind": "prop", "id": "ultimatum", "from": n, "p": p, "icon": "📜", "cat": "", "count": 2})
		return {"ok": true, "result": "pending"}
	if ult_ratio(g, n, t) >= ULT_RATIO: return resolve_ultimatum(g, n, t, p, true)
	return resolve_ultimatum(g, n, t, p, false)

static func resolve_ultimatum(g: TBGame, n: int, t: int, p: int, yielded: bool) -> Dictionary:
	if g.alive[n] == 0 or g.alive[t] == 0 or g.get_rel(n, t) != D.REL_PEACE: return {"ok": false, "err": "gone"}
	if yielded:
		if g.owner[p] == t and g.capital[p] == 0: g.cede(p, n)
		g.grudge[t * g.N1 + n] = mini(100, g.grudge[t * g.N1 + n] + 25)
		g.truce[n * g.N1 + t] = g.turn + 8; g.truce[t * g.N1 + n] = g.turn + 8
		g.log.append({"turn": g.turn, "kind": "ultimatum", "a": n, "b": t, "p": p, "k": "yield"})
		return {"ok": true, "result": "yield"}
	g.log.append({"turn": g.turn, "kind": "ultimatum", "a": n, "b": t, "p": p, "k": "refuse"})
	var r := g.apply({"cmd": "declareWar", "n": n, "t": t, "_ult": true})
	return {"ok": r["ok"], "result": "war"}

## an aggressive AI that is clearly stronger sometimes presents a demand before reaching for the sword
static func ai_ultimatum(g: TBGame, n: int, aggr: float) -> void:
	if g.rules < 1 or g.human[n] != 0 or n == g.rebel or aggr < 0.5 or g.mp[n] < 1: return
	if TBRulers._h(g, n, 61).next() > 0.04: return
	var best := -1; var bt := 0; var br := 0.0
	var seen := {}
	for p in g.owned(n):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]; var t := g.owner[q]
			if t == 0 or t == n or seen.has(t): continue
			seen[t] = true
			var need := ULT_RATIO - 0.4 if g.human[t] != 0 else ULT_RATIO
			var rr := ult_ratio(g, n, t)
			if rr < need or rr < br: continue
			var tp := ult_target(g, n, t)
			if tp < 0: continue
			best = tp; bt = t; br = rr
	if best >= 0:
		g.dp[n] += DP_ULT                  # AI nations do not pay diplomacy points for this
		ultimatum(g, n, bt, best)
