## Bilateral trade deals (rules >= 1): friendly nations each earn gold from the other's size; war cancels the deal.
class_name TBTrade
extends RefCounted

const D = preload("res://src/engine/data.gd")
const DP_COST := 1

static func max_deals(g: TBGame, n: int) -> int: return 1 + g.era[n]

static func has(g: TBGame, a: int, b: int) -> bool: return g.rules >= 1 and g.trade[a * g.N1 + b] != 0

## gold per turn that a deal with `partner` is worth to n
static func value(g: TBGame, partner: int) -> int:
	return mini(40, 4 + int(g.own_count(partner) * 0.35))

## total trade income of n (no recursion into income())
static func income(g: TBGame, n: int) -> int:
	if g.rules < 1 or g.trade_cnt[n] == 0: return 0
	var s := 0
	for o in range(1, g.N1):
		if g.trade[n * g.N1 + o] != 0 and g.alive[o] != 0: s += value(g, o)
	return s

static func partners(g: TBGame, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if g.trade_cnt[n] == 0: return out
	for o in range(1, g.N1):
		if g.trade[n * g.N1 + o] != 0 and g.alive[o] != 0: out.append(o)
	return out

static func set_deal(g: TBGame, a: int, b: int, on: bool) -> void:
	var v := 1 if on else 0
	if g.trade[a * g.N1 + b] == v: return
	g.trade[a * g.N1 + b] = v; g.trade[b * g.N1 + a] = v
	g.trade_cnt[a] = clampi(g.trade_cnt[a] + (1 if on else -1), 0, 255)
	g.trade_cnt[b] = clampi(g.trade_cnt[b] + (1 if on else -1), 0, 255)

static func cancel_all(g: TBGame, n: int) -> void:
	for o in partners(g, n): set_deal(g, n, o, false)

static func accepts(g: TBGame, t: int, p: int) -> bool:
	if g.get_rel(t, p) == D.REL_WAR or g.grudge[t * g.N1 + p] > 30: return false
	if g.trade_cnt[t] >= max_deals(g, t): return false
	return float(D.PERSONALITIES[g.personality[t]]["dipl"]) + float(D.PERSONALITIES[g.personality[t]]["econ"]) * 0.6 > 0.55

static func propose(g: TBGame, n: int, t: int) -> Dictionary:
	if g.rules < 1: return {"ok": false, "err": "rules"}
	if t <= 0 or t >= g.N1 or t == n or g.alive[t] == 0 or t == g.rebel: return {"ok": false, "err": "target"}
	if g.get_rel(n, t) == D.REL_WAR: return {"ok": false, "err": "war"}
	if has(g, n, t): return {"ok": false, "err": "active"}
	if g.trade_cnt[n] >= max_deals(g, n): return {"ok": false, "err": "tradefull"}
	if g.dp[n] < DP_COST: return {"ok": false, "err": "dp"}
	if g.human[t] == 0 and not accepts(g, t, n): return {"ok": false, "err": "refused"}
	g.dp[n] -= DP_COST
	set_deal(g, n, t, true)
	g.log.append({"turn": g.turn, "kind": "trade", "a": n, "b": t})
	return {"ok": true}

## AI: occasionally sign a deal with a friendly neighbour
static func ai_step(g: TBGame, n: int) -> void:
	if g.rules < 1 or g.trade_cnt[n] >= max_deals(g, n) or g.dp[n] < DP_COST or g.rng.next() > 0.08: return
	for o in range(1, g.N1):
		if o == n or g.alive[o] == 0 or o == g.rebel or has(g, n, o): continue
		var r := g.get_rel(n, o)
		if r == D.REL_WAR or g.own_count(o) < 4: continue
		if r == D.REL_PEACE and g.rng.next() > 0.3: continue
		if g.human[o] == 0 and accepts(g, o, n) and g.trade_cnt[o] < max_deals(g, o):
			propose(g, n, o); return
