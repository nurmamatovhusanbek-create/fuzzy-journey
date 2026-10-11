## Marching (rules >= 1): an army may be ordered to ANY province it can reach in one turn, not only a neighbour.
## The route runs over provinces you hold (and allies' land, which an army may cross but not stop in); a sea crossing needs a Port on the shore it leaves from,
## and between two of your own Ports a fleet crosses any distance (cost grows with it). Every step costs a move point; the last step costs more when it is an attack.
## The whole march happens in the order: the men arrive (or fight) at once. The cost is the brake: a long march uses up the turn.
class_name TBMarch
extends RefCounted

const D = preload("res://src/engine/data.gd")
const VOYAGE_BASE := 2
const VOYAGE_DEG := 25.0            # one extra move point per 25 degrees of voyage

## move points of a voyage between two of your ports
static func voyage_cost(g: TBGame, a: int, b: int) -> int:
	var d: float = rad_to_deg(TBGame.gc_dist(g.world.lon[a], g.world.lat[a], g.world.lon[b], g.world.lat[b]))
	return VOYAGE_BASE + int(d / VOYAGE_DEG)

## provinces the army of `from` may stand in on the way: held by n, or an ally's (pass-through only)
static func _pass(g: TBGame, n: int, p: int) -> bool:
	var c: int = g.controller(p)
	return c == n or (c != 0 and g.friendly(n, c))

## Dijkstra over move points from `from` (every cost is a whole number, so the queue is a list of buckets): {province: [cost, prev]} for every province that can be stood in or
## crossed, plus (as a third entry `true`) the unheld provinces an attack or a landing could end in
static func reach(g: TBGame, n: int, from: int, budget: float = 12.0) -> Dictionary:
	var best := {from: [0.0, -1]}
	var maxc: int = int(floorf(budget))
	var buckets: Array = []
	for _i in maxc + 1: buckets.append([])
	buckets[0].append(from)
	var done := {}
	var ports: Array = []
	for p in g.P:
		if g.building[p] == D.B_PORT and g.controller(p) == n: ports.append(p)
	for c in maxc + 1:
		var bucket: Array = buckets[c]
		var qi := 0
		while qi < bucket.size():
			var u: int = bucket[qi]; qi += 1
			if done.has(u) or int(best[u][0]) != c: continue
			done[u] = true
			for i in range(g.nb_off[u], g.nb_off[u + 1]):
				var q: int = g.nb[i]
				if g.nb_sea[i] != 0 and g.building[u] != D.B_PORT: continue
				_relax(g, n, best, buckets, q, u, c + 1, maxc)
			if g.building[u] == D.B_PORT and g.controller(u) == n:
				for q2 in ports:
					if q2 != u: _relax(g, n, best, buckets, q2, u, c + voyage_cost(g, u, q2), maxc)
	return best

static func _relax(g: TBGame, n: int, best: Dictionary, buckets: Array, q: int, u: int, cost: int, maxc: int) -> void:
	if cost > maxc: return
	if not _pass(g, n, q):
		var last: int = cost + (D.MP_ATTACK - D.MP_MOVE)                  # an unheld province can only end the march: an attack or a landing, one point dearer
		if last <= maxc and (not best.has(q) or last < int(best[q][0])): best[q] = [float(last), u, true]
		return
	if not best.has(q) or cost < int(best[q][0]):
		best[q] = [float(cost), u]
		buckets[cost].append(q)

## the order from -> to: {ok, err, path (provinces from `from` to `to`), mp, kind ("move" | "attack"), last (the province the attack leaves from)}
static func plan(g: TBGame, n: int, from: int, to: int, budget: float = -1.0) -> Dictionary:
	var out := {"ok": false, "err": "notadjacent", "path": PackedInt32Array(), "mp": 0.0, "kind": "", "last": from}
	if g.rules < 1: return out
	if g.controller(from) != n: out["err"] = "notyours"; return out
	if g.army[from] <= 1: out["err"] = "noarmy"; return out
	if to == from or to < 0 or to >= g.P: out["err"] = "target"; return out
	var r := reach(g, n, from, budget if budget >= 0.0 else maxf(12.0, g.mp[n] + 6.0))         # a little beyond what the turn allows, so the answer can say how many points it would take
	if not r.has(to): return out
	# the final province's own rules are the move / attack rules of the engine
	var ct: int = g.controller(to)
	var kind := "move"
	var err := ""
	if ct == n: kind = "move"
	elif ct != 0 and g.friendly(n, ct): err = "friendly"
	elif ct != 0 and g.get_rel(n, ct) != D.REL_WAR: err = "nowar"
	elif g.discoverable[to] != 0 and g.tech_level[n] < 2 and g.owner[to] == 0: err = "undiscovered"
	else: kind = "attack"
	if err != "": out["err"] = err; return out
	var path: Array = [to]
	var cur: int = to
	while int(r[cur][1]) >= 0:
		cur = int(r[cur][1]); path.push_front(cur)
	var cost: float = float(r[to][0])
	out["ok"] = true; out["err"] = ""; out["path"] = PackedInt32Array(path); out["mp"] = cost; out["kind"] = kind
	out["last"] = path[path.size() - 2] if path.size() >= 2 else from
	return out

## every province the army of `from` can be ordered to within `budget` move points: {to: plan-lite {mp, kind}}
static func targets(g: TBGame, n: int, from: int, budget: float) -> Dictionary:
	var out := {}
	if g.rules < 1 or g.controller(from) != n or g.army[from] <= 1: return out
	var r := reach(g, n, from, budget)
	for q in r:
		if q == from: continue
		var ct: int = g.controller(q)
		var kind := "move"
		if ct == n: kind = "move"
		elif ct != 0 and g.friendly(n, ct): continue
		elif ct != 0 and g.get_rel(n, ct) != D.REL_WAR: continue
		elif g.discoverable[q] != 0 and g.tech_level[n] < 2 and g.owner[q] == 0: continue
		else: kind = "attack"
		out[q] = {"mp": float(r[q][0]), "kind": kind}
	return out

## carry out the march (the caller has checked the move points). A move goes straight to the destination; an attack first brings the men to the province it leaves from
static func execute(g: TBGame, n: int, from: int, to: int, troops: int) -> String:
	var pl := plan(g, n, from, to)
	if not bool(pl["ok"]): return "!" + String(pl["err"])
	var k: int = mini(troops if troops != 0 else g.army[from] - 1, g.army[from] - 1)
	if k <= 0: return "!noarmy"
	var last: int = int(pl["last"])
	if String(pl["kind"]) == "move":
		var left: int = g.army[from] - k
		g.army[from] = left; g.army[to] = mini(65000, g.army[to] + k); g.touch(from); g.touch(to)
		if g.rules >= 1 and TBGenerals.follows(g, from, left): TBGenerals.transfer(g, from, to)
		return "move"
	if last != from:
		var left2: int = g.army[from] - k
		g.army[from] = left2; g.army[last] = mini(65000, g.army[last] + k); g.touch(from); g.touch(last)
		if g.rules >= 1 and TBGenerals.follows(g, from, left2): TBGenerals.transfer(g, from, last)
	return g.move_or_attack(n, last, to, k)
