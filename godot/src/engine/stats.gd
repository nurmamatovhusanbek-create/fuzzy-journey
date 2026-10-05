## Per-game history for the Statistics screen: every 2 turns, the top powers' provinces / army / gold / tech.
## Pure function of the state, so multiplayer clients record it themselves after each delta (no extra traffic).
class_name TBStats
extends RefCounted

const EVERY := 2
const KEEP_TOP := 10
const MAX_SAMPLES := 400

static func record(g: TBGame) -> void:
	if g.turn % EVERY != 0: return
	if not g.stats.is_empty() and int(g.stats[g.stats.size() - 1]["t"]) == g.turn: return
	var army := PackedInt32Array(); army.resize(g.N1)
	for p in g.P:
		var o := g.owner[p]
		if o != 0: army[o] += g.army[p]
	var order: Array = []
	for n in range(1, g.N1):
		if g.alive[n] != 0 and n != g.rebel: order.append(n)
	order.sort_custom(func(a, b): return g.own_count(a) > g.own_count(b) if g.own_count(a) != g.own_count(b) else a < b)
	var ids := PackedInt32Array()
	for i in mini(KEEP_TOP, order.size()): ids.append(order[i])
	for h in g.humans():
		if not ids.has(h): ids.append(h)
	var s := {"t": g.turn, "y": g.year, "n": ids, "p": PackedInt32Array(), "a": PackedInt32Array(), "g": PackedInt32Array(), "k": PackedFloat32Array()}
	for n in ids:
		s["p"].append(g.own_count(n)); s["a"].append(army[n]); s["g"].append(int(g.gold[n])); s["k"].append(g.tech_level[n])
	g.stats.append(s)
	if g.stats.size() > MAX_SAMPLES: g.stats = g.stats.slice(g.stats.size() - MAX_SAMPLES)

## series for nation n: Array of [turn, value] for metric key p/a/g/k
static func series(g: TBGame, n: int, key: String) -> Array:
	var out: Array = []
	for s in g.stats:
		var i: int = (s["n"] as PackedInt32Array).find(n)
		if i >= 0: out.append([int(s["t"]), float(s[key][i])])
	return out

## nations worth drawing: the human plus the biggest powers now
static func featured(g: TBGame, count: int = 6) -> Array:
	var out: Array = []
	if g.human_id > 0: out.append(g.human_id)
	if g.stats.is_empty(): return out
	var last: Dictionary = g.stats[g.stats.size() - 1]
	for n in last["n"]:
		if not out.has(n): out.append(n)
		if out.size() >= count: break
	return out
