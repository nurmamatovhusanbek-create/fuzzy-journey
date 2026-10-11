## Where a nation's capital stands. The table (data/capitals.json: nation id -> [lon, lat] of its historical capital) gives the point; the capital province is the one the nation owns
## nearest to it, if that is within CAP_REACH km. A nation the table does not know, or one that has lost every province near its capital, keeps the old pick (the province with most neighbours).
class_name TBCapitals
extends RefCounted

const CAP_REACH := 700.0                       # km: farther than this from the historical capital, the point is not "where it stood" any more
static var _tab: Dictionary = {}
static var _loaded := false

static func _load() -> void:
	_loaded = true
	var f := FileAccess.open("res://data/capitals.json", FileAccess.READ)
	if f == null: return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary: _tab = d

## the province for nation n, or -1 (the caller falls back)
static func pick(g: TBGame, n: int) -> int:
	if g.rules < 1: return -1
	if not _loaded: _load()
	var id: String = g.nat_code[n]
	if not _tab.has(id): return -1
	var pt: Array = _tab[id]
	var best := -1; var bd := 1e9
	for p in g.owned(n):
		var d: float = TBGame.gc_dist(g.world.lon[p], g.world.lat[p], float(pt[0]), float(pt[1])) * 6371.0       # gc_dist is an angle in radians (see game.gd)
		if d < bd: bd = d; best = p
	return best if (best >= 0 and bd <= CAP_REACH) else -1
