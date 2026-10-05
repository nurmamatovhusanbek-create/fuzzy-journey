## Regional unification (rules >= 1): own ~75 % of a geographic region you did not already hold at the start and you are
## "Unifier of <region>": a one-off reward and a place in the chronicle. Regions are lon/lat boxes over province centroids.
class_name TBRealms
extends RefCounted

const NEED := 0.75
# id, [lon0, lat0, lon1, lat1]
const LIST := [
	["iberia", [-9.6, 36.0, 3.4, 43.9]], ["gaul", [-5.2, 42.3, 8.3, 51.1]], ["italy", [6.6, 36.6, 18.6, 46.7]], ["isles", [-10.7, 49.9, 1.8, 60.9]],
	["germania", [5.9, 47.3, 15.1, 55.1]], ["scandinavia", [4.5, 55.3, 31.5, 71.2]], ["balkans", [13.4, 36.4, 28.6, 45.3]], ["anatolia", [26.0, 36.0, 44.8, 42.1]],
	["levant", [34.2, 29.1, 42.5, 37.3]], ["nile", [24.7, 21.9, 35.0, 31.7]], ["maghreb", [-13.2, 27.6, 11.5, 37.3]], ["persia", [44.0, 25.0, 63.4, 39.8]],
	["mesopotamia", [38.8, 29.0, 48.6, 37.4]], ["hindustan", [68.0, 8.0, 89.0, 30.0]], ["cathay", [98.0, 21.0, 122.2, 41.0]], ["nippon", [129.4, 31.0, 145.8, 45.6]],
	["korea", [124.5, 33.1, 130.9, 43.0]], ["indochina", [97.3, 8.4, 109.5, 23.4]], ["turan", [50.2, 35.0, 87.3, 55.0]], ["mexica", [-118.4, 14.5, -86.7, 32.7]],
	["andes", [-81.3, -23.4, -66.9, 12.5]], ["brazil", [-74.0, -33.8, -34.7, 5.3]], ["platense", [-73.5, -55.0, -53.0, -23.0]], ["usa", [-125.0, 24.5, -66.9, 49.4]],
	["oceania", [113.0, -39.0, 153.6, -10.5]], ["westafrica", [-17.6, 4.3, 4.3, 16.0]], ["eastafrica", [28.8, -11.7, 51.4, 12.5]], ["southafrica", [11.6, -34.9, 40.5, -17.5]],
]

static var _members: Array = []        # per realm: PackedInt32Array of province ids
static var _world: TBWorld

static func _build(w: TBWorld) -> void:
	if _world == w: return
	_world = w
	_members = []
	for r in LIST:
		var b: Array = r[1]
		var m := PackedInt32Array()
		for p in w.P:
			if w.lon[p] >= b[0] and w.lon[p] <= b[2] and w.lat[p] >= b[1] and w.lat[p] <= b[3]: m.append(p)
		_members.append(m)

static func count() -> int: return LIST.size()

static func members(g: TBGame, i: int) -> PackedInt32Array:
	_build(g.world)
	return _members[i]

## share (0..1) of realm i's provinces owned by n
static func share(g: TBGame, n: int, i: int) -> float:
	var m := members(g, i)
	if m.size() < 6: return 0.0
	var c := 0
	for p in m: if g.owner[p] == n: c += 1
	return float(c) / float(m.size())

## mark realms already held at game start so only new unifications are rewarded
static func init(g: TBGame) -> void:
	g.realm_done.resize(g.N1 * LIST.size())
	_build(g.world)
	for i in LIST.size():
		var m: PackedInt32Array = _members[i]
		if m.size() < 6: continue
		var cnt := {}
		for p in m: cnt[g.owner[p]] = cnt.get(g.owner[p], 0) + 1
		for o in cnt:
			if o != 0 and float(cnt[o]) / m.size() >= NEED: g.realm_done[o * LIST.size() + i] = 1

static func tick(g: TBGame) -> void:
	if g.rules < 1 or g.turn % 2 != 0: return
	_build(g.world)
	var R := LIST.size()
	if g.realm_done.size() != g.N1 * R: g.realm_done.resize(g.N1 * R)
	for i in R:
		var m: PackedInt32Array = _members[i]
		if m.size() < 6: continue
		var cnt := {}
		for p in m:
			var o := g.owner[p]
			if o != 0: cnt[o] = cnt.get(o, 0) + 1
		for o in cnt:
			if o == g.rebel or g.alive[o] == 0 or g.realm_done[o * R + i] != 0: continue
			if float(cnt[o]) / m.size() >= NEED:
				g.realm_done[o * R + i] = 1
				g.gold[o] += 100.0
				for p in g.owned(o): g.stab[p] = mini(100, g.stab[p] + 5); g.touch(p)
				g.log.append({"turn": g.turn, "kind": "realm", "a": o, "id": LIST[i][0]})
