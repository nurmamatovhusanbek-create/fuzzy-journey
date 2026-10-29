## Bilateral trade deals (rules >= 1): friendly nations each earn gold from the other's size; war cancels the deal.
## Rules >= 3 prices a route like a venture: its yield follows the size of BOTH economies and the distance between them (a gravity model: trade grows with the product of
## two markets and falls with distance); opening one costs gold (caravans, warehouses) and people (escorts, factors); it needs a surplus that lasts (net income smoothed over
## ~7 turns), a treasury that can carry it and men to spare; a partner that has none of these cannot take part; and a route lapses when either side goes bankrupt or the
## two grow to hate each other. Every shortfall lowers the partner's willingness smoothly (a weighted geometric mean: no single missing ingredient can be made up by the others).
class_name TBTrade
extends RefCounted

const D = preload("res://src/engine/data.gd")
const DP_COST := 1

## ---- rules >= 3: tuning
const K_YIELD := 0.8                    # yield = 2 + K * sqrt(S) * reach, with S = sqrt(market_a * market_b)
const REACH_RAD := 0.7                  # the distance (radians of arc, about 4,000 km) at which a route earns half of what a neighbour would
const YIELD_CAP := 45
const FEE_BASE := 15.0                  # gold to open a route: FEE_BASE + FEE_PER * yield (it pays for itself in about four turns)
const FEE_PER := 3.5
const MEN_BASE := 4.0                   # people: MEN_BASE + yield / 2
const W_INCOME := 0.4                   # weights of the three ingredients in the means (sum 1)
const W_GOLD := 0.3
const W_MEN := 0.3
const MIN_MEANS := 0.15                 # below this a nation cannot take part at all
const EMA_KEEP := 0.85                  # persistent income: net_ema = 0.85 * net_ema + 0.15 * net
const SOUR_GRUDGE := 60                 # a route lapses when either side's grudge against the other reaches this
const LAPSE_BANKRUPT := 0.35            # per turn, while either side's treasury is empty

static func max_deals(g: TBGame, n: int) -> int: return 1 + g.era[n]

static func has(g: TBGame, a: int, b: int) -> bool: return g.rules >= 1 and g.trade[a * g.N1 + b] != 0

# ---------------------------------------------------------------- the size of a route (rules >= 3)
## the size of a nation's market: provinces times what an average province earns in its era (6 in the ancient world, 20 in the modern): cheap, and it does not depend on trade itself
static func market(g: TBGame, n: int) -> float:
	return float(g.own_count(n)) * (6.0 + 3.5 * float(g.era[n]))

## 0..1: how well two capitals can reach each other (1 = next door, 0.5 at REACH_RAD, 0.2 across half the world)
static func reach(g: TBGame, a: int, b: int) -> float:
	var ca: int = g.capital_of[a]; var cb: int = g.capital_of[b]
	if ca < 0 or cb < 0: return 0.5
	var d := TBGame.gc_dist(g.world.lon[ca], g.world.lat[ca], g.world.lon[cb], g.world.lat[cb])
	return 1.0 / (1.0 + (d / REACH_RAD) * (d / REACH_RAD))

## gold per turn that a deal between a and b is worth to EACH of them
static func yield_of(g: TBGame, a: int, b: int) -> int:
	if g.rules < 3: return mini(40, 4 + int(g.own_count(b) * 0.35))
	var s := sqrt(market(g, a) * market(g, b))
	return clampi(int(roundf(2.0 + K_YIELD * sqrt(s) * reach(g, a, b))), 2, YIELD_CAP)

## gold per turn that a deal with `partner` is worth to n (the old signature kept for the interface: n = the viewing nation)
static func value(g: TBGame, partner: int, n: int = -1) -> int:
	if g.rules < 3 or n <= 0: return mini(40, 4 + int(g.own_count(partner) * 0.35))
	return yield_of(g, n, partner)

static func fee_gold(v: int) -> int: return int(ceil(FEE_BASE + FEE_PER * float(v)))
static func fee_men(v: int) -> int: return int(ceil(MEN_BASE + float(v) * 0.5))

## net income smoothed over about seven turns; before the first turn has been recorded it is the current figure
static func avg_net(g: TBGame, n: int) -> float:
	var e: float = g.net_ema[n]
	return e if e != 0.0 else float(g.income(n)["net"])

## what n can bring to a route worth v: {inc, gold, men} each 0..1, and m, their weighted geometric mean
static func means(g: TBGame, n: int, v: int) -> Dictionary:
	var fi := clampf(avg_net(g, n) / (2.0 * float(v)), 0.0, 1.0)                   # a surplus twice the route's takings is full marks
	var fg := clampf(g.gold[n] / (1.5 * float(fee_gold(v))), 0.0, 1.0)             # a treasury of one and a half times the fee
	var fm := clampf(g.manpower[n] / (4.0 * float(fee_men(v))), 0.0, 1.0)          # four times the people it takes
	return {"inc": fi, "gold": fg, "men": fm, "m": pow(fi, W_INCOME) * pow(fg, W_GOLD) * pow(fm, W_MEN)}

## total trade income of n (no recursion into income())
static func income(g: TBGame, n: int) -> int:
	if g.rules < 1 or g.trade_cnt[n] == 0: return 0
	var s := 0
	for o in range(1, g.N1):
		if g.trade[n * g.N1 + o] != 0 and g.alive[o] != 0: s += value(g, o, n)
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

# ---------------------------------------------------------------- how a court weighs a request for a route
## t (an AI court) weighing a route with p: {"blocked": "" | key, "terms": [[key, value], ...]}. The AI decides with exactly these sums and the interface shows them (TBDipView.trade).
static func weigh(g: TBGame, t: int, p: int) -> Dictionary:
	var pers: Dictionary = D.PERSONALITIES[g.personality[t]]
	var blocked := ""
	if g.get_rel(t, p) == D.REL_WAR: blocked = "war"
	elif g.grudge[t * g.N1 + p] > 30: blocked = "grudge"
	elif g.trade_cnt[t] >= max_deals(g, t): blocked = "full"
	var terms: Array = [["dv_temper", float(pers["dipl"])], ["dv_commerce", float(pers["econ"]) * 0.6]]
	if g.rules >= 3:
		var v := yield_of(g, t, p)
		var mp := means(g, p, v)
		var mt := means(g, t, v)
		if blocked == "" and float(mt["m"]) < MIN_MEANS: blocked = "poor"
		terms.append(["dv_means", -1.0 * (1.0 - float(mp["m"]))])                           # you: can you carry it?
		terms.append(["dv_theirmeans", -0.6 * (1.0 - float(mt["m"]))])                     # they: can they?
		terms.append(["dv_reach", -0.4 * (1.0 - reach(g, t, p))])                          # the farther away, the less they care
		for tm in TBDiplo.loyalty_terms(g, t, p): terms.append(tm)                          # you are at war with their friend
	return {"blocked": blocked, "terms": terms}

static func accepts(g: TBGame, t: int, p: int) -> bool:
	var w := weigh(g, t, p)
	if String(w["blocked"]) != "": return false
	var s := 0.0
	for tm in w["terms"]: s += float(tm[1])
	return s > 0.55

static func propose(g: TBGame, n: int, t: int, force: bool = false) -> Dictionary:
	if g.rules < 1: return {"ok": false, "err": "rules"}
	if t <= 0 or t >= g.N1 or t == n or g.alive[t] == 0 or t == g.rebel: return {"ok": false, "err": "target"}
	if g.get_rel(n, t) == D.REL_WAR: return {"ok": false, "err": "war"}
	if has(g, n, t): return {"ok": false, "err": "active"}
	if g.trade_cnt[n] >= max_deals(g, n): return {"ok": false, "err": "tradefull"}
	if g.dp[n] < DP_COST: return {"ok": false, "err": "dp"}
	var v := 0
	if g.rules >= 3:
		v = yield_of(g, n, t)
		if g.gold[n] < float(fee_gold(v)): return {"ok": false, "err": "gold"}
		if g.manpower[n] < float(fee_men(v)): return {"ok": false, "err": "manpower"}
		if g.trade_cnt[t] >= max_deals(g, t) and g.human[t] != 0: return {"ok": false, "err": "tradefull"}
	if g.human[t] == 0 and not force and not accepts(g, t, n): return {"ok": false, "err": "refused"}
	g.dp[n] -= DP_COST
	if g.rules >= 3:
		g.gold[n] -= float(fee_gold(v)); g.manpower[n] -= float(fee_men(v))
	set_deal(g, n, t, true)
	g.log.append({"turn": g.turn, "kind": "trade", "a": n, "b": t})
	return {"ok": true}

## AI: occasionally sign a deal with a friendly neighbour. Rules >= 3: a court looks over its prospects and opens the most valuable route it can carry and that the other side will take.
static func ai_step(g: TBGame, n: int) -> void:
	if g.rules < 1 or g.trade_cnt[n] >= max_deals(g, n) or g.dp[n] < DP_COST or g.rng.next() > 0.08: return
	var best := -1; var best_v := -1
	for o in range(1, g.N1):
		if o == n or g.alive[o] == 0 or o == g.rebel or has(g, n, o): continue
		var r := g.get_rel(n, o)
		if r == D.REL_WAR or g.own_count(o) < 4: continue
		if g.rules < 3:
			if r == D.REL_PEACE and g.rng.next() > 0.3: continue
			if g.human[o] == 0 and accepts(g, o, n) and g.trade_cnt[o] < max_deals(g, o):
				propose(g, n, o); return
			continue
		if g.human[o] != 0 or g.trade_cnt[o] >= max_deals(g, o): continue
		var v := yield_of(g, n, o)
		if v <= best_v: continue
		if g.gold[n] < float(fee_gold(v)) or g.manpower[n] < float(fee_men(v)) or float(means(g, n, v)["m"]) < 0.5: continue    # a court only opens a route it can carry
		if accepts(g, o, n): best = o; best_v = v
	if best > 0: propose(g, n, best)

## rules >= 3, once a turn: a route is not forever. It lapses when either side is bankrupt (chance per turn) or when the two courts have come to hate each other.
static func maintain(g: TBGame) -> void:
	if g.rules < 3: return
	for a in range(1, g.N1):
		if g.alive[a] == 0 or g.trade_cnt[a] == 0: continue
		for b in range(a + 1, g.N1):
			if g.trade[a * g.N1 + b] == 0: continue
			var why := ""
			if g.grudge[a * g.N1 + b] >= SOUR_GRUDGE or g.grudge[b * g.N1 + a] >= SOUR_GRUDGE: why = "sour"
			elif (g.gold[a] < 1.0 or g.gold[b] < 1.0) and g.rng.chance(LAPSE_BANKRUPT): why = "poor"
			if why == "": continue
			set_deal(g, a, b, false)
			if g.human[a] != 0 or g.human[b] != 0: g.log.append({"turn": g.turn, "kind": "trade_end", "a": a, "b": b, "why": why})
