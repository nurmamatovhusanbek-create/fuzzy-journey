## New Game page (nation-pick.md stage 1): chronology rail on the left; the selected era (year, name, blurb, great powers as flag chips, nation count),
## difficulty and the Players selector (1 solo, 2-4 hot-seat) on the right. Wide panel on landscape, page on portrait (list first, detail pushed).
class_name TBNewGame
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
const ERAS := ["modern", "ancient", "roman", "medieval", "mongol", "timurid", "discovery", "gunpowder", "napoleonic", "victorian", "ww1", "ww2", "coldwar"]
const ERA_YEAR := {"ancient": -218, "roman": 117, "medieval": 1096, "mongol": 1300, "timurid": 1400, "discovery": 1492, "gunpowder": 1700, "napoleonic": 1804, "victorian": 1850, "ww1": 1914, "ww2": 1939, "coldwar": 1947, "modern": 2024}
static var _cache := {}

static func year_text(id: String) -> String:
	var y: int = ERA_YEAR[id]
	return ("%d BC" % -y) if y < 0 else ("%d AD" % y)

## great powers and nation count of an era: {"powers": [{name, code, n, prov}], "count": int}; `world` is needed for the modern map only
static func facts(id: String, world: TBWorld) -> Dictionary:
	if _cache.has(id): return _cache[id]
	var out := {"powers": [], "count": 0}
	var counts := {}
	var names: Array = []                   # index k -> [name, code]
	if id != "modern":
		var era := TBWorld.load_era("res://data", id)
		if era.is_empty(): return out
		for o in era["owner"]:
			if int(o) > 0: counts[int(o)] = int(counts.get(int(o), 0)) + 1
		names.append(["", ""])
		for nn in era["nations"]: names.append([String(nn["name"]), String(nn["id"])])
	elif world != null:
		for i in world.P:
			var k: int = world.prov_nat[i]
			if k > 0 and world.nat_code[k] != "": counts[k] = int(counts.get(k, 0)) + 1
		for k in world.nat_code.size(): names.append([String(world.nat_name[k]), String(world.nat_code[k])])
	var ks := counts.keys()
	ks.sort_custom(func(a: int, b: int) -> bool: return counts[a] > counts[b] if counts[a] != counts[b] else a < b)
	var powers: Array = []
	for k in ks:
		var kk: int = k
		if kk >= names.size(): continue
		var nm: String = names[kk][0]
		var low := nm.to_lower()
		if low.contains("hunter") or low.contains("farmers") or low.contains("pastoral") or low.contains("cultures") or low.contains("minor"): continue
		powers.append({"name": nm, "code": names[kk][1], "n": kk, "prov": counts[kk]})
		if powers.size() >= 3: break
	out["powers"] = powers
	out["count"] = counts.size()
	_cache[id] = out
	return out

## opts: world, era, difficulty, players, mp (bool: no players selector), on_next(era, diff, players), on_back, next_label
static func open(parent: Control, opts: Dictionary) -> TBPanel.Handle:
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var portrait := TBPanel.is_portrait(vs)
	var mp: bool = bool(opts.get("mp", false))
	var S := {"era": String(opts.get("era", "modern")), "diff": String(opts.get("difficulty", "normal")), "players": int(opts.get("players", 1)), "detail": false}
	if not ERA_YEAR.has(S["era"]): S["era"] = "modern"
	var on_back: Callable = opts.get("on_back", Callable())
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("new_game_t"), "hourglass", {"scroll": false, "padded": false, "dismissable": true})
	if not mp:
		var steps := TBMenuParts.Steps.new(0, portrait)
		h.set_chip(steps)
	var world: TBWorld = opts.get("world", null)
	# ---- columns
	var split := BoxContainer.new(); split.vertical = false
	split.add_theme_constant_override("separation", 0)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL; split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(split)
	var rail_sc := ScrollContainer.new(); rail_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; rail_sc.follow_focus = true; rail_sc.scroll_deadzone = 12
	rail_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rail_m := MarginContainer.new()
	rail_m.add_theme_constant_override("margin_left", h.pad); rail_m.add_theme_constant_override("margin_right", 12 if not portrait else h.pad)
	rail_m.add_theme_constant_override("margin_top", 8); rail_m.add_theme_constant_override("margin_bottom", 8)
	rail_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rail := K.vbox(0); rail_m.add_child(rail); rail_sc.add_child(rail_m)
	if portrait: rail_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else: rail_sc.custom_minimum_size = Vector2(340, 0)
	split.add_child(rail_sc)
	var det_sc := ScrollContainer.new(); det_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; det_sc.follow_focus = true; det_sc.scroll_deadzone = 12
	det_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; det_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var det_m := MarginContainer.new()
	det_m.add_theme_constant_override("margin_left", 16 if not portrait else h.pad); det_m.add_theme_constant_override("margin_right", h.pad)
	det_m.add_theme_constant_override("margin_top", 14); det_m.add_theme_constant_override("margin_bottom", 14)
	det_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var det := K.vbox(10); det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det_m.add_child(det); det_sc.add_child(det_m)
	if not portrait:
		var vr := ColorRect.new(); vr.color = TBTokens.c("hair") if not TBTokens.is_hc() else TBTokens.c("rule"); vr.custom_minimum_size = Vector2(1, 0); vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		split.add_child(vr)
	split.add_child(det_sc)
	# ---- rail rows
	var order: Array = ERAS.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return ERA_YEAR[a] < ERA_YEAR[b])
	var rows := {}
	var show := func(id: String, push: bool) -> void:
		S["era"] = id
		for k in rows: (rows[k] as TBMenuParts.EraRow).selected = (k == id)
		for c in det.get_children(): c.queue_free()
		var yl := K.num(year_text(id), 15, K.DIM); det.add_child(yl)
		var nl := K.title(T.call("era_" + id), 26); nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nl.custom_minimum_size.x = 40
		det.add_child(nl)
		det.add_child(TBPanel.para(T.call("blurb_" + id), 15, K.TEXT))
		det.add_child(K.section(T.call("great_powers")))
		var f := facts(id, world)
		var fw := TBPanel.flow(6); det.add_child(fw)
		for p in f["powers"]:
			var code: String = p["code"]
			fw.add_child(TBPanel.flag_tag(TBFlags.texture(code, TBGame.gen_wash(int(p["n"]))), TBI18n.nation(String(p["name"])), str(int(p["prov"]))))
		fw.add_child(K.chip(T.call("n_nations", {"n": f["count"] if int(f["count"]) > 0 else 250}), "globe", "neutral"))
		det.add_child(K.hair())
		det.add_child(K.section(T.call("difficulty")))
		det.add_child(K.segmented([["easy", T.call("easy")], ["normal", T.call("normal")], ["hard", T.call("hard")]], String(S["diff"]), func(v: String): S["diff"] = v))
		if not mp:
			det.add_child(K.section(T.call("hot_players")))
			var hint := TBPanel.para(T.call("players_hint_1") if int(S["players"]) <= 1 else T.call("players_hint_n", {"n": S["players"]}), 13, K.DIM)
			det.add_child(K.segmented([["1", "1"], ["2", "2"], ["3", "3"], ["4", "4"]], str(S["players"]), func(v: String):
				S["players"] = int(v)
				hint.text = T.call("players_hint_1") if int(S["players"]) <= 1 else T.call("players_hint_n", {"n": S["players"]})))
			det.add_child(hint)
		if portrait and push:
			S["detail"] = true
			rail_sc.visible = false; det_sc.visible = true
			h.set_title(T.call("era_" + id))
	for i in order.size():
		var id: String = order[i]
		var r := TBMenuParts.EraRow.new(year_text(id), T.call("era_" + id))
		r.first = i == 0; r.last = i == order.size() - 1
		r.pressed.connect(func(): show.call(id, true))
		rail.add_child(r); rows[id] = r
	if portrait: det_sc.visible = false
	show.call(String(S["era"]), false)
	# ---- footer: the verb, not "New Game"
	var go := K.button(String(opts.get("next_label", T.call("pick_nation_btn"))), func():
		h.close()
		(opts["on_next"] as Callable).call(String(S["era"]), String(S["diff"]), int(S["players"])), true)
	h.actions(null, go)
	h.on_back = func() -> bool:
		if portrait and bool(S["detail"]):
			S["detail"] = false; rail_sc.visible = true; det_sc.visible = false; h.set_title(T.call("new_game_t"))
			return true
		return false
	h.on_dismiss = on_back
	return h
