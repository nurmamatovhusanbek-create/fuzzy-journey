## Marching (rules >= 1): an army may be ordered to ANY province it can reach, not only a neighbour, and walks there one province per turn.
## The route runs over provinces you hold (and allies' land, which an army may cross but not stop in); a sea crossing needs a Port on the shore it leaves from,
## and between two of your own Ports a fleet crosses any distance (a longer voyage weighs more in the choice of route, but is still one stage).
## The order costs one move (an attack, when the target is next door) and is a standing order (g.marches): the army steps at once, then once more at every end of turn,
## until it stands in the target (or a battle there is fought), or the way is closed (the land lost, a pact broken), when the order lapses and a notice says so.
class_name TBMarch
extends RefCounted

const D = preload("res://src/engine/data.gd")
const VOYAGE_BASE := 2
const VOYAGE_DEG := 25.0            # one extra move point per 25 degrees of voyage
const REACH := 80                   # the longest march worth planning, in weighted stages (a whole continent)

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
static func plan(g: TBGame, n: int, from: int, to: int, r_in: Dictionary = {}) -> Dictionary:
	var out := {"ok": false, "err": "notadjacent", "path": PackedInt32Array(), "mp": 0.0, "kind": "", "last": from}
	if g.rules < 1: return out
	if g.controller(from) != n: out["err"] = "notyours"; return out
	if g.army[from] <= 1: out["err"] = "noarmy"; return out
	if to == from or to < 0 or to >= g.P: out["err"] = "target"; return out
	var r: Dictionary = r_in if not r_in.is_empty() else reach(g, n, from, float(REACH))          # a caller that asks about many targets from one province passes its own reach
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
	out["ok"] = true; out["err"] = ""; out["path"] = PackedInt32Array(path); out["kind"] = kind
	out["mp"] = float(D.MP_ATTACK if (kind == "attack" and path.size() == 2) else D.MP_MOVE)    # what the order costs now; the walking after that is free
	out["last"] = path[path.size() - 2] if path.size() >= 2 else from
	out["turns"] = turns(g, n, PackedInt32Array(path), kind)
	return out

## turns the walk takes: one per province you hold on the way (an ally's land is crossed in the same stride), and the last stride is the battle for an attack
static func turns(g: TBGame, n: int, path: PackedInt32Array, kind: String) -> int:
	var t := 0
	var limit: int = path.size() - 1 if kind == "move" else path.size() - 2
	for i in range(1, limit + 1):
		if g.controller(path[i]) == n or i == limit: t += 1
	return t + (1 if kind == "attack" else 0)

## every province the army of `from` can be ordered to: {to: plan-lite {mp, kind}}
static func targets(g: TBGame, n: int, from: int, r_in: Dictionary = {}) -> Dictionary:
	var out := {}
	if g.rules < 1 or g.controller(from) != n or g.army[from] <= 1: return out
	var r: Dictionary = r_in if not r_in.is_empty() else reach(g, n, from, float(REACH))
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

## give the march order: the army steps at once, and the rest of the way is a standing order. Returns what happened at the first stride ("march" on the way, "move" arrived, or a battle's result)
static func order(g: TBGame, n: int, from: int, to: int, troops: int) -> String:
	var pl := plan(g, n, from, to)
	if not bool(pl["ok"]): return "!" + String(pl["err"])
	var k: int = mini(troops if troops != 0 else g.army[from] - 1, g.army[from] - 1)
	if k <= 0: return "!noarmy"
	cancel_at(g, n, from)
	var m := {"n": n, "at": from, "to": to, "k": k}
	var res := _stride(g, m, pl)
	if not bool(m.get("done", false)): g.marches.append(m)
	return res

## drop the standing order of the army standing in `p`
static func cancel_at(g: TBGame, n: int, p: int) -> void:
	var i := g.marches.size() - 1
	while i >= 0:
		var m: Dictionary = g.marches[i]
		if int(m["n"]) == n and int(m["at"]) == p: g.marches.remove_at(i)
		i -= 1

## the standing order of the army standing in `p`, or {}
static func order_at(g: TBGame, n: int, p: int) -> Dictionary:
	for m in g.marches:
		if int(m["n"]) == n and int(m["at"]) == p: return m
	return {}

## one stride of a standing order along `pl` (its plan): over the provinces you hold up to the next one you hold (allies' land is crossed), or the attack when it is next door
static func _stride(g: TBGame, m: Dictionary, pl: Dictionary) -> String:
	var n: int = int(m["n"]); var at: int = int(m["at"]); var to: int = int(m["to"])
	var path: PackedInt32Array = pl["path"]
	var k: int = mini(int(m["k"]), g.army[at] - 1)
	if k <= 0: m["done"] = true; return "!noarmy"
	if String(pl["kind"]) == "attack" and path.size() == 2:
		m["done"] = true
		return g.move_or_attack(n, at, to, k)
	var limit: int = path.size() - 1 if String(pl["kind"]) == "move" else path.size() - 2
	var idx := 1
	while idx < limit and g.controller(path[idx]) != n: idx += 1
	var nxt: int = path[idx]
	var left: int = g.army[at] - k
	g.army[at] = left; g.army[nxt] = mini(65000, g.army[nxt] + k); g.touch(at); g.touch(nxt)
	if g.rules >= 1 and TBGenerals.follows(g, at, left): TBGenerals.transfer(g, at, nxt)
	m["at"] = nxt
	if nxt == to: m["done"] = true; return "move"
	return "march"

## the end of the turn: every standing order takes its next stride. A lapsed order (the army or the way is gone) says so in the log
static func advance(g: TBGame) -> void:
	if g.marches.is_empty(): return
	var keep: Array = []
	var work: Array = g.marches.duplicate()
	g.marches = keep
	for m in work:
		var n: int = int(m["n"])
		if g.alive[n] == 0: continue
		var at: int = int(m["at"])
		var from_at := at
		if g.controller(at) != n or g.army[at] <= 1:
			g.log.append({"turn": g.turn, "kind": "march_stop", "a": n, "p": at, "why": "noarmy"}); continue
		var pl := plan(g, n, at, int(m["to"]))
		if not bool(pl["ok"]):
			g.log.append({"turn": g.turn, "kind": "march_stop", "a": n, "p": at, "why": String(pl["err"])}); continue
		var res := _stride(g, m, pl)
		if g.human[n] != 0 and g.march_fx.size() < 40: g.march_fx.append([from_at, int(m["at"]) if (res == "march" or res == "move") else int(m["to"]), res, n])
		if res.begins_with("!"):
			g.log.append({"turn": g.turn, "kind": "march_stop", "a": n, "p": at, "why": res.substr(1)}); continue
		if not bool(m.get("done", false)): keep.append(m)
