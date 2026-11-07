## A country's standing (rules 4): one to five stars from what everyone can see of it, the total worth of its provinces, how many it holds, its technology and its income. Armies are not in it:
## they stay hidden until agents have looked (the stars take the place of the army figure on the map at country level). Rank-based, so a tenth of the world holds five stars.
class_name TBStanding
extends RefCounted

static var _turn := -1
static var _sig := -1
static var _stars := PackedInt32Array()
static var _worth := PackedFloat32Array()

static func _refresh(g: TBGame) -> void:
	var sig: int = g.get_instance_id() + g.turn * 7919 + g.P
	if _sig == sig and _stars.size() == g.N1: return
	_sig = sig
	var worth := PackedFloat32Array(); worth.resize(g.N1)
	var count := PackedInt32Array(); count.resize(g.N1)
	for p in g.P:
		var o: int = g.owner[p]
		if o > 0: worth[o] += g.province_value(p); count[o] += 1
	var ids: Array = []
	for n in range(1, g.N1):
		if g.alive[n] != 0 and n != g.rebel and count[n] > 0: ids.append(n)
	var gold := PackedFloat32Array(); gold.resize(g.N1)
	for n in ids: gold[n] = float(g.income(n)["gold"])
	var pct := PackedFloat32Array(); pct.resize(g.N1)
	var m: int = ids.size()
	for metric in 4:
		var by := ids.duplicate()
		by.sort_custom(func(a: int, b: int) -> bool:
			var va: float = worth[a] if metric == 0 else (float(count[a]) if metric == 1 else (g.tech_level[a] if metric == 2 else gold[a]))
			var vb: float = worth[b] if metric == 0 else (float(count[b]) if metric == 1 else (g.tech_level[b] if metric == 2 else gold[b]))
			return va > vb if va != vb else a < b)
		for i in by.size(): pct[by[i]] += (1.0 - float(i) / float(maxi(1, m - 1))) * 0.25
	_stars = PackedInt32Array(); _stars.resize(g.N1)
	for n in ids: _stars[n] = 5 if pct[n] >= 0.90 else (4 if pct[n] >= 0.70 else (3 if pct[n] >= 0.45 else (2 if pct[n] >= 0.20 else 1)))
	_worth = worth

## 1..5, 0 for a nation with no land
static func stars(g: TBGame, n: int) -> int:
	if g.rules < 4 or n <= 0 or n >= g.N1: return 0
	_refresh(g)
	return _stars[n]

## the total worth of n's provinces
static func total_worth(g: TBGame, n: int) -> float:
	_refresh(g)
	return _worth[n] if n > 0 and n < _worth.size() else 0.0
