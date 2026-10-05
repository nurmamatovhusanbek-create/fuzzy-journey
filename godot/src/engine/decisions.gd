## National decisions (rules >= 1): costed projects that give timed (or permanent) modifiers or one-off effects.
class_name TBDecisions
extends RefCounted

const D = preload("res://src/engine/data.gd")
const FOREVER := 1000000
# id (<= 12 chars, sent over the network) -> definition. dur 0 = instant effect, -1 = permanent
const LIST := [
	{"id": "mil_reform", "gold": 220, "mp": 3, "dur": -1, "era": 1, "icon": "⚔"},
	{"id": "trade_fair", "gold": 120, "mp": 2, "dur": 20, "era": 0, "icon": "⚖"},
	{"id": "centralize", "gold": 160, "mp": 3, "dur": -1, "era": 1, "icon": "🏛"},
	{"id": "conscript", "gold": 100, "mp": 2, "dur": 12, "era": 1, "icon": "🪖"},
	{"id": "propaganda", "gold": 90, "mp": 2, "dur": 10, "era": 0, "icon": "📣"},
	{"id": "patronage", "gold": 160, "mp": 2, "dur": 20, "era": 1, "icon": "📚"},
	{"id": "fortify", "gold": 140, "mp": 3, "dur": 0, "era": 0, "icon": "🏰"},
	{"id": "amnesty", "gold": 120, "mp": 2, "dur": 0, "era": 0, "icon": "🕊"},
]

static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id: return i
	return -1

static func is_active(g: TBGame, n: int, i: int) -> bool:
	return g.dec_until[n * LIST.size() + i] > g.turn

static func turns_left(g: TBGame, n: int, i: int) -> int:
	return maxi(0, g.dec_until[n * LIST.size() + i] - g.turn)

## null (ok) or an error key; used by the command and the UI
static func why_not(g: TBGame, n: int, i: int) -> String:
	if g.rules < 1: return "rules"
	var d: Dictionary = LIST[i]
	if g.era[n] < int(d["era"]): return "era"
	if is_active(g, n, i): return "active"
	if g.gold[n] < float(d["gold"]): return "gold"
	if g.mp[n] < float(d["mp"]): return "mp"
	if d["id"] == "amnesty" and g.infamy[n] < 4.0: return "noinfamy"
	if d["id"] == "amnesty" and g.dec_until[n * LIST.size() + i] > g.turn - 20 and g.dec_until[n * LIST.size() + i] != 0: return "cooldown"
	return ""

static func apply(g: TBGame, n: int, id: String) -> Dictionary:
	var i := index_of(id)
	if i < 0: return {"ok": false, "err": "decision"}
	var why := why_not(g, n, i)
	if why != "": return {"ok": false, "err": why}
	var d: Dictionary = LIST[i]
	g.gold[n] -= float(d["gold"]); g.mp[n] -= float(d["mp"])
	var dur: int = d["dur"]
	var slot := n * LIST.size() + i
	match String(d["id"]):
		"fortify":
			for p in g.owned(n):
				if g.defense[p] < 50: g.defense[p] = mini(50, g.defense[p] + 15); g.touch(p)
			g.dec_until[slot] = g.turn          # instant; remembered only for the log
		"amnesty":
			g.infamy[n] = maxf(0.0, g.infamy[n] - 8.0)
			g.dec_until[slot] = g.turn
		_:
			g.dec_until[slot] = FOREVER if dur < 0 else g.turn + dur
	g.log.append({"turn": g.turn, "kind": "decision", "a": n, "id": d["id"]})
	return {"ok": true}

# ---------------------------------------------------------------- modifiers (multiplicative / additive, neutral when inactive)
static func _on(g: TBGame, n: int, id: String) -> bool:
	return g.dec_until[n * LIST.size() + index_of(id)] > g.turn

static func gold_mul(g: TBGame, n: int) -> float: return 1.0 + (0.15 if _on(g, n, "trade_fair") else 0.0)
static func combat_mul(g: TBGame, n: int) -> float: return 1.0 + (0.08 if _on(g, n, "mil_reform") else 0.0)
static func admin_mul(g: TBGame, n: int) -> float: return 0.85 if _on(g, n, "centralize") else 1.0
static func manpower_mul(g: TBGame, n: int) -> float: return 1.0 + (0.3 if _on(g, n, "conscript") else 0.0)
static func research_mul(g: TBGame, n: int) -> float: return 1.0 + (0.25 if _on(g, n, "patronage") else 0.0)
static func stab_add(g: TBGame, n: int) -> float: return 1.0 if _on(g, n, "propaganda") else 0.0
static func happy_add(g: TBGame, n: int) -> float: return (5.0 if _on(g, n, "propaganda") else 0.0) - (5.0 if _on(g, n, "conscript") else 0.0)

## AI: occasionally spends spare gold on a sensible decision
static func ai_pick(g: TBGame, n: int) -> void:
	if g.gold[n] < 260.0 or g.mp[n] < 3.0 or g.rng.next() > 0.12: return
	var at_war: bool = g.war_cnt[n] > 0
	var order := ["mil_reform", "centralize", "trade_fair", "patronage", "conscript", "amnesty", "fortify", "propaganda"]
	if at_war: order = ["mil_reform", "conscript", "fortify", "propaganda", "centralize", "trade_fair", "patronage", "amnesty"]
	for id in order:
		var i := index_of(id)
		if why_not(g, n, i) == "" and g.gold[n] >= float(LIST[i]["gold"]) + 100.0:
			apply(g, n, id); return
