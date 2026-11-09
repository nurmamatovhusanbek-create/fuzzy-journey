## The Outliner: one list of what is under way in the realm (projects and buildings, armies and marches, wars) and the provinces the player pinned; every row flies to its province.
class_name TBOutliner
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
const MAX_PINS := 16

static func pins(cfg: Dictionary) -> Array:
	var out: Array = []
	for s in (cfg.get("pins", []) as Array):
		if str(s).is_valid_int(): out.append(int(str(s)))
	return out

static func toggle_pin(cfg: Dictionary, p: int) -> void:
	var list: Array = (cfg.get("pins", []) as Array).duplicate()
	var key := str(p)
	if key in list: list.erase(key)
	elif list.size() < MAX_PINS: list.append(key)
	cfg["pins"] = list

## [[text, province]] sections as data (so a test can read them without a screen)
static func rows(g: TBGame, me: int, cfg: Dictionary) -> Dictionary:
	var out := {"projects": [], "armies": [], "wars": [], "pins": []}
	for p in g.owned(me):
		var pn: String = TBI18n.place(g.pname(p))
		if g.rules >= 4 and g.proj_kind[p] != 0:
			out["projects"].append([T.call("ol_project_row", {"p": pn, "k": T.call("pj_" + TBInvest.project_id(g.proj_kind[p])), "t": g.proj_left[p]}), p])
		if g.b_building[p] != 0:
			out["projects"].append([T.call("ol_build_row", {"p": pn, "b": T.call("b_" + TBData.BUILDINGS[g.b_building[p] - 1]["id"]), "t": g.b_turns[p]}), p])
	var armies: Array = []
	for p in g.P:
		if g.controller(p) == me and g.army[p] > 0: armies.append(p)
	armies.sort_custom(func(a: int, b: int) -> bool: return g.army[a] > g.army[b] if g.army[a] != g.army[b] else a < b)
	for p in armies.slice(0, 8): out["armies"].append([T.call("ol_army_row", {"p": TBI18n.place(g.pname(p)), "m": K.fmt(float(g.army[p]))}), p])
	for m in g.marches:
		if int(m["n"]) == me: out["armies"].append([T.call("ol_march_row", {"k": K.fmt(float(m["k"])), "p": TBI18n.place(g.pname(int(m["to"])))}), int(m["to"])])
	for o in range(1, g.N1):
		if o != me and g.alive[o] != 0 and g.get_rel(me, o) == TBData.REL_WAR:
			var cap_o: int = g.capital_of[o]
			out["wars"].append([T.call("ol_war_row", {"n": g.dname(o), "s": int(g.war_score[me * g.N1 + o])}), cap_o])
	for p in pins(cfg):
		if p >= 0 and p < g.P: out["pins"].append([TBI18n.place(g.pname(p)) + ("" if g.owner[p] == me else " · " + (g.dname(g.owner[p]) if g.owner[p] > 0 else "")), p])
	return out

static func open(parent: Control, g: TBGame, cfg: Dictionary, selected: int, on_goto: Callable, on_change: Callable) -> TBPanel.Handle:
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("dk_outliner"), "outliner", {"w": 520, "h": 560, "sub": T.call("outliner_sub")})
	var me := g.human_id
	var data := rows(g, me, cfg)
	for sec in [["projects", "ol_projects"], ["armies", "ol_armies"], ["wars", "ol_wars"], ["pins", "ol_pins"]]:
		h.body.add_child(TBPanel.section(T.call(String(sec[1]))))
		var list: Array = data[String(sec[0])]
		if list.is_empty() and String(sec[0]) != "pins": h.body.add_child(TBPanel.para(T.call("ol_none"), 14, K.DIM)); continue
		for r in list:
			var pv: int = int(r[1])
			var row := K.ListRow.new(String(r[0]), "›", func(): h.close(); on_goto.call(pv))
			h.body.add_child(row)
	if selected >= 0 and selected < g.P:
		var pin_btn := K.button(T.call("ol_pin_sel"), func(): toggle_pin(cfg, selected); on_change.call(); h.close(); open(parent, g, cfg, selected, on_goto, on_change))
		h.body.add_child(pin_btn)
	return h
