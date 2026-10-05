## Honours: persistent, cross-game achievements. A view-layer helper: reads game state and log, never mutates the game.
## Unlocked ids live in cfg["honours"] as {id: "year"}; the caller saves cfg when scan() reports something new.
class_name TBHonours
extends RefCounted

const D = preload("res://src/engine/data.gd")

## id, glyph
const LIST := [
	["first_blood", "swords"], ["empire_30", "flag"], ["empire_60", "flag"], ["empire_100", "flag"],
	["treasure", "coins"], ["heir", "crown"], ["infamous", "skull"], ["decreed", "scroll"],
	["merchant", "coins"], ["matchmaker", "crown"], ["suzerain", "flag"], ["ultimatum_win", "scroll"],
	["never_kneel", "swords"], ["five_star", "swords"], ["modern_age", "flask"], ["unifier", "flag"],
	["veteran", "book"], ["alliances", "dove"], ["victor", "trophy"],
]

static func has(cfg: Dictionary, id: String) -> bool:
	return (cfg.get("honours", {}) as Dictionary).has(id)

static func count(cfg: Dictionary) -> int:
	return (cfg.get("honours", {}) as Dictionary).size()

## returns the ids newly earned by this log entry (the caller records them)
static func on_log(g: TBGame, e: Dictionary) -> PackedStringArray:
	var me := g.human_id
	var out := PackedStringArray()
	var a: int = e.get("a", -1); var b: int = e.get("b", -1)
	match String(e["kind"]):
		"occupied": if a == me: out.append("first_blood")
		"ruler": if a == me and String(e["k"]) != "elected": out.append("heir")
		"marriage": if a == me or b == me: out.append("matchmaker")
		"realm": if a == me: out.append("unifier")
		"ultimatum":
			if a == me and e["k"] == "yield": out.append("ultimatum_win")
			if b == me and e["k"] == "refuse": out.append("never_kneel")
		"victory": if a == me: out.append("victor")
	return out

## state-based honours
static func on_state(g: TBGame) -> PackedStringArray:
	var me := g.human_id
	var out := PackedStringArray()
	if me <= 0 or g.alive[me] == 0: return out
	var n := g.own_count(me)
	if n >= 30: out.append("empire_30")
	if n >= 60: out.append("empire_60")
	if n >= 100: out.append("empire_100")
	if g.gold[me] >= 5000.0: out.append("treasure")
	if g.rules >= 1:
		if g.coalition[me] != 0: out.append("infamous")
		if g.trade_cnt[me] >= 3: out.append("merchant")
		for p in g.owned(me):
			if g.gen[p] != 0 and TBGenerals.skill(g, p) >= TBGenerals.MAX_SKILL: out.append("five_star"); break
	if g.era[me] >= 4: out.append("modern_age")
	if g.turn >= 100: out.append("veteran")
	var allies := 0; var vassals := 0
	for o in range(1, g.N1):
		if o == me or g.alive[o] == 0: continue
		if g.get_rel(me, o) == D.REL_ALLY: allies += 1
		if g.overlord[o] == me: vassals += 1
	if allies >= 3: out.append("alliances")
	if vassals >= 1: out.append("suzerain")
	if g.rules >= 1 and TBDecisions.active_count(g, me) >= 1: out.append("decreed")
	if g.over and g.winner == me: out.append("victor")
	return out

## records new ids in cfg; returns only the ones that were not yet unlocked
static func record(g: TBGame, cfg: Dictionary, ids: PackedStringArray) -> PackedStringArray:
	var fresh := PackedStringArray()
	var d: Dictionary = cfg.get("honours", {})
	for id in ids:
		if d.has(id): continue
		d[id] = str(g.year)
		fresh.append(id)
	cfg["honours"] = d
	return fresh
