## Fog of war (rules >= 1): which armies of other nations the player may see.
## You always see your own. You see a nation's armies when it is your ally, in a royal marriage with you, your vassal or overlord; when its friendliness toward you is
## above 80; while a spy report on it lasts (a successful covert operation, SPY_TURNS turns); and any army standing next to a province you hold. A Watchtower
## widens that sight to TOWER_SIGHT provinces round it. Everything else is hidden: no token on the map, no figure on the cards.
## Pure view helper: the engine, the AI and the battles ignore it (the AI plays without fog).
class_name TBVision
extends RefCounted

const D = preload("res://src/engine/data.gd")
const SPY_TURNS := 6
const SIGHT := 1
const TOWER_SIGHT := 3
const FRIENDLY_ABOVE := 80

## 0..100: how warmly nation o stands toward n. Peace is 50; a pact, a trade deal and a clean slate raise it, a grudge and war lower it. Allies are 100.
static func friendliness(g: TBGame, n: int, o: int) -> int:
	if o == n or g.friendly(n, o): return 100
	var r: int = g.get_rel(n, o)
	if r == D.REL_WAR: return 0
	var f := 50
	if r == D.REL_NAP: f += 25
	if g.rules >= 1 and TBTrade.has(g, n, o): f += 15
	f += 10 if g.grudge[o * g.N1 + n] == 0 else -int(g.grudge[o * g.N1 + n])
	return clampi(f, 0, 100)

## all of nation o's armies are in view of n
static func nation_seen(g: TBGame, n: int, o: int) -> bool:
	if o == n or o == 0: return true
	if g.friendly(n, o): return true
	if g.see_until[n * g.N1 + o] > g.turn: return true
	return friendliness(g, n, o) > FRIENDLY_ABOVE

# ---- the sight mask (provinces within sight of what n holds), kept per game and rebuilt only when ownership, buildings or the turn change ---------------------
static var _mask := PackedByteArray()
static var _sig := -1
static var _for_game: int = 0

static func _signature(g: TBGame) -> int:
	return hash([g.turn, g.human_id, hash(g.owner), hash(g.occupier), hash(g.building), hash(g.b_lv), g.occ_rev])

## bring the mask up to date for the game's human player (call once before a loop of `sees_fast`)
static func sync(g: TBGame) -> void:
	var sig: int = _signature(g)
	if sig == _sig and _for_game == g.get_instance_id() and _mask.size() == g.P: return
	_sig = sig; _for_game = g.get_instance_id()
	_mask = PackedByteArray(); _mask.resize(g.P)
	var n: int = g.human_id
	if n <= 0: _mask.fill(1); return
	for p in g.P:
		if g.controller(p) != n: continue
		var r: int = TOWER_SIGHT if g.bl(p, D.B_WATCHTOWER) > 0 else SIGHT
		_mark(g, p, r)

static func _mark(g: TBGame, src: int, radius: int) -> void:
	_mask[src] = 1
	var frontier: Array = [src]
	var seen := {src: true}
	for _d in radius:
		var next: Array = []
		for p in frontier:
			for i in range(g.nb_off[p], g.nb_off[p + 1]):
				var q: int = g.nb[i]
				if seen.has(q): continue
				seen[q] = true; _mask[q] = 1; next.append(q)
		frontier = next

## may the human player see the army in province p? (without a prior sync call: syncs itself)
static func sees(g: TBGame, p: int) -> bool:
	if g.rules < 1 or g.human_id <= 0 or p < 0: return true
	sync(g)
	return sees_fast(g, p)

static func sees_fast(g: TBGame, p: int) -> bool:
	if g.rules < 1 or g.human_id <= 0 or p < 0: return true
	var c: int = g.controller(p)
	if c == g.human_id or c == 0: return true
	if nation_seen(g, g.human_id, c): return true
	return p < _mask.size() and _mask[p] != 0
