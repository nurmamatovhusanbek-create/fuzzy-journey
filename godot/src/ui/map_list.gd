## Provinces / Armies list (A11Y-GES-002): a non-spatial route to every map verb. Searchable; picking a row flies the map there and selects the
## province (the command card then offers the verbs). Data helpers are static so a menu screen can embed the same rows; `open()` builds a
## minimal popover from the kit (K.modal) so it works on its own.
class_name TBMapList
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
const LIMIT := 60

## rows for the list: [{p, name, owner, army, mine}] sorted by name (provinces) or by army size (armies)
static func rows(g: TBGame, query: String = "", armies: bool = false) -> Array:
	var q := query.strip_edges().to_lower()
	var out: Array = []
	var me := g.human_id
	for p in g.P:
		var o := g.owner[p]
		if armies and (g.controller(p) != me or g.army[p] <= 0): continue
		var nm: String = TBI18n.place(g.world.name[p])
		if q != "" and not (nm.to_lower().contains(q) or (o != 0 and g.dname(o).to_lower().contains(q))): continue
		if not armies and q == "" and o != me: continue                 # no query: just the realm; searching reaches every province
		out.append({"p": p, "name": nm, "owner": o, "army": g.army[p], "mine": o == me})
	if armies: out.sort_custom(func(a, b): return a["army"] > b["army"] if a["army"] != b["army"] else a["name"] < b["name"])
	else: out.sort_custom(func(a, b): return a["name"] < b["name"])
	return out

## move the map to a province and select it through the same path as a tap (main._goto_province)
static func focus_province(map: TBMapView, p: int) -> void:
	map.focus_on(p)

static func open(host: Control, g: TBGame, map: TBMapView, on_pick: Callable, armies_first: bool = false) -> void:
	var m := K.modal(host, T.call("ml_title"), 520, "pin")
	var back: Control = m[0]; var body: VBoxContainer = m[1]
	var state := {"armies": armies_first, "q": ""}
	var search := LineEdit.new(); search.placeholder_text = T.call("search"); search.clear_button_enabled = true
	search.custom_minimum_size = Vector2(0, K.touch())
	K.a11y(search, T.call("search"), "searchbox")
	var seg := K.segmented([["prov", T.call("ml_provinces")], ["army", T.call("ml_armies")]], "army" if armies_first else "prov", func(id): state["armies"] = id == "army"; _fill(body, g, state, on_pick, back, 0))
	var scroll: Node = body.get_parent()                           # the search controls stay pinned above the scrolling rows
	var top := K.vbox(8)
	top.add_child(seg); top.add_child(search)
	scroll.get_parent().add_child(top)
	scroll.get_parent().move_child(top, scroll.get_index())
	search.text_changed.connect(func(t: String): state["q"] = t; _fill(body, g, state, on_pick, back, 0))
	_fill(body, g, state, on_pick, back, 0)
	if TBFrame.kbd_nav or not DisplayServer.is_touchscreen_available(): search.grab_focus.call_deferred()

## rebuild the rows under the first `keep` children (segmented + search field)
static func _fill(body: VBoxContainer, g: TBGame, state: Dictionary, on_pick: Callable, back: Control, keep: int) -> void:
	while body.get_child_count() > keep:
		var c := body.get_child(body.get_child_count() - 1)
		body.remove_child(c); c.queue_free()
	var list := rows(g, state["q"], state["armies"])
	if list.is_empty():
		body.add_child(K.label(T.call("none"), 14, TBTokens.c("ink_1")))
		return
	var shown := 0
	for r in list:
		if shown >= LIMIT: break
		shown += 1
		var p: int = r["p"]
		var right := "%s %s" % [T.call("army"), TBKit.fmt(r["army"])] if (state["armies"] or int(r["army"]) > 0) else ""
		if not r["mine"] and int(r["owner"]) != 0: right = ("%s · %s" % [g.dname(r["owner"]), right]) if right != "" else g.dname(r["owner"])
		var row := K.list_row(String(r["name"]), right, func():
			if is_instance_valid(back): back.queue_free()
			on_pick.call(p))
		K.a11y(row, "%s, %s" % [r["name"], right] if right != "" else String(r["name"]), "button")
		body.add_child(row)
	if list.size() > shown: body.add_child(K.label(T.call("ml_more", {"n": list.size() - shown}), 12, TBTokens.c("ink_1")))
