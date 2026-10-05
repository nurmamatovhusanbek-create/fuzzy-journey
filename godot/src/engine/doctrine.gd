## National doctrine (rules >= 1): one exclusive strategic stance per nation. Adopting is cheap, switching costs diplomacy points.
## 0 none, 1 martial (+6 % combat, +10 % manpower), 2 mercantile (+6 % gold), 3 administrative (-12 % administration, +5 % research).
class_name TBDoctrine
extends RefCounted

const IDS := ["none", "martial", "mercantile", "administrative"]
const ADOPT_DP := 2
const SWITCH_DP := 4

static func combat_mul(g: TBGame, n: int) -> float: return 1.06 if _is(g, n, 1) else 1.0
static func manpower_mul(g: TBGame, n: int) -> float: return 1.10 if _is(g, n, 1) else 1.0
static func gold_mul(g: TBGame, n: int) -> float: return 1.06 if _is(g, n, 2) else 1.0
static func admin_mul(g: TBGame, n: int) -> float: return 0.88 if _is(g, n, 3) else 1.0
static func research_mul(g: TBGame, n: int) -> float: return 1.05 if _is(g, n, 3) else 1.0

static func _is(g: TBGame, n: int, d: int) -> bool:
	return g.rules >= 1 and g.doctrine[n] == d

static func cost(g: TBGame, n: int) -> int: return ADOPT_DP if g.doctrine[n] == 0 else SWITCH_DP

static func adopt(g: TBGame, n: int, id: String) -> Dictionary:
	if g.rules < 1: return {"ok": false, "err": "rules"}
	var d := IDS.find(id)
	if d < 1: return {"ok": false, "err": "decision"}
	if g.doctrine[n] == d: return {"ok": false, "err": "active"}
	var c := cost(g, n)
	if g.dp[n] < c: return {"ok": false, "err": "dp"}
	g.dp[n] -= c
	g.doctrine[n] = d
	g.log.append({"turn": g.turn, "kind": "doctrine", "a": n, "id": id})
	return {"ok": true}

## AI nations settle on a doctrine that suits their temperament the first time they can afford it (no RNG)
static func ai_step(g: TBGame, n: int) -> void:
	if g.rules < 1 or g.doctrine[n] != 0 or g.dp[n] < ADOPT_DP + 1: return
	var pid: String = TBData.PERSONALITIES[g.personality[n]]["id"]
	var want := "martial"
	match pid:
		"merchant": want = "mercantile"
		"diplomat", "guardian": want = "administrative"
	adopt(g, n, want)
