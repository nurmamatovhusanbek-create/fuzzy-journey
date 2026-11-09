## Rules 5: what an AI state is fighting FOR. When it declares war it picks an aim and keeps to it (it fights for it, refuses a cheap peace while it is winning, and makes peace
## when the aim is met or the war has dragged on); so a war changes the map instead of trading a province or two.
##   NATION  take the whole land of the enemy       REGION  take the provinces next to its own land (at least four)
##   VASSAL  make the enemy its vassal              HUMBLE  win a victory in the field and a white peace
class_name TBAims
extends RefCounted

const NONE := 0
const NATION := 1
const REGION := 2
const VASSAL := 3
const HUMBLE := 4
const PATIENCE := 70                  # turns of war after which an unmet aim is dropped
static var IDS: Array = ["none", "nation", "region", "vassal", "humble"]

static func kind_of(g: TBGame, n: int, t: int) -> int:
	if g.rules < 5 or n <= 0 or g.aim_kind.size() != g.N1: return NONE
	return g.aim_kind[n] if g.aim_t[n] == t else NONE

## the aim a state declares war with
static func pick(g: TBGame, n: int, t: int) -> int:
	var mine := 0; var theirs := 0
	for p in g.owned(n): mine += g.army[p]
	for p in g.owned(t): theirs += g.army[p]
	var r: float = float(mine) / maxf(1.0, float(theirs))
	var share: float = float(g.own_count(t)) / maxf(1.0, float(g.own_count(n)))
	var bent: float = float(TBData.PERSONALITIES[g.personality[n]]["aggr"])
	if r >= 1.5 and share <= 1.0: return NATION
	if r >= 1.0: return REGION
	if r >= 0.8 and bent >= 0.5 and g.overlord[t] == 0 and g.overlord[n] == 0: return VASSAL
	return HUMBLE

static func set_aim(g: TBGame, n: int, t: int, kind: int) -> void:
	if g.rules < 5 or g.aim_kind.size() != g.N1: return
	g.aim_kind[n] = kind; g.aim_t[n] = t; g.aim_since[n] = g.turn

static func clear(g: TBGame, n: int) -> void:
	if g.aim_kind.size() == g.N1: g.aim_kind[n] = NONE; g.aim_t[n] = 0

## provinces of t next to n's land (the region n wants)
static func region(g: TBGame, n: int, t: int) -> Array:
	var out: Array = []
	for p in g.owned(t):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			if g.nb_sea[i] == 0 and g.owner[g.nb[i]] == n: out.append(p); break
	return out

static func is_wanted(g: TBGame, n: int, t: int, p: int) -> bool:
	match kind_of(g, n, t):
		NATION: return g.owner[p] == t
		REGION: return g.owner[p] == t and region(g, n, t).has(p)
	return false

## is the aim met: n holds (as occupier) enough of what it wanted, or its war score is high enough
static func met(g: TBGame, n: int, t: int) -> bool:
	var ws: int = g.war_score[n * g.N1 + t]
	var occ := 0; var total := 0
	for p in g.owned(t):
		total += 1
		if g.occupier[p] == n: occ += 1
	match kind_of(g, n, t):
		NATION: return total == 0 or float(occ) >= 0.8 * float(total) or ws >= 90
		REGION: return occ >= mini(4, maxi(1, total / 2)) and ws >= 25
		VASSAL: return ws >= 50
		HUMBLE: return ws >= 35
	return true

## "" or the translation key of the aim n has against t (what the interface says)
static func key(g: TBGame, n: int, t: int) -> String:
	var k := kind_of(g, n, t)
	return "" if k == NONE else "aim_" + String(IDS[k])
