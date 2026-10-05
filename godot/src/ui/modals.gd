## Modal dialogs: era picker, nations list, budget, settings, save/load, game over.
class_name TBModals
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
const ERAS := ["modern", "ancient", "roman", "medieval", "mongol", "timurid", "discovery", "gunpowder", "napoleonic", "victorian", "ww1", "ww2", "coldwar"]
const ERA_YEAR := {"ancient": -218, "roman": 117, "medieval": 1096, "mongol": 1300, "timurid": 1400, "discovery": 1492, "gunpowder": 1700, "napoleonic": 1804, "victorian": 1850, "ww1": 1914, "ww2": 1939, "coldwar": 1947, "modern": 2024}

static func close(m: Control) -> void:
	if is_instance_valid(m): m.queue_free()

static func era_picker(parent: Control, difficulty: String, on_start: Callable, on_back: Callable) -> void:
	var st := {"era": "modern", "diff": difficulty}
	var m := K.modal(parent, T.call("choose_era"), 640)
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8)
	m[1].add_child(grid)
	var era_btns := {}
	for id in ERAS:
		var y: int = ERA_YEAR[id]
		var b := K.button("%s\n%s" % [T.call("era_" + id), ("%d BC" % -y) if y < 0 else ("%d AD" % y)])
		b.custom_minimum_size = Vector2(190, 58)
		b.pressed.connect(func():
			st["era"] = id
			for k in era_btns: era_btns[k].add_theme_color_override("font_color", K.GOLD2 if k == id else K.TEXT))
		grid.add_child(b); era_btns[id] = b
	era_btns["modern"].add_theme_color_override("font_color", K.GOLD2)
	m[1].add_child(K.label(T.call("difficulty"), 13, K.DIM))
	var seg := K.hbox(6); m[1].add_child(seg)
	var d_btns := {}
	for d in ["easy", "normal", "hard"]:
		var b := K.button(T.call(d)); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			st["diff"] = d
			for k in d_btns: d_btns[k].add_theme_color_override("font_color", K.GOLD2 if k == d else K.TEXT))
		seg.add_child(b); d_btns[d] = b
	d_btns[difficulty].add_theme_color_override("font_color", K.GOLD2)
	var row := K.hbox(8); m[1].add_child(row)
	row.add_child(K.button(T.call("back"), func(): close(m[0]); on_back.call()))
	var go := K.button(T.call("new_game"), func(): close(m[0]); on_start.call(st["era"], st["diff"]), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(go)

static func nations(parent: Control, g: TBGame, on_pick: Callable) -> void:
	var m := K.modal(parent, T.call("nations"), 480)
	var search := LineEdit.new(); search.placeholder_text = T.call("search"); search.custom_minimum_size = Vector2(0, K.MIN_TOUCH)
	m[1].add_child(search)
	var list := K.vbox(2); m[1].add_child(list)
	var rows: Array = []
	for n in range(1, g.N1):
		if g.alive[n] != 0: rows.append(n)
	rows.sort_custom(func(a, b): return g.own_count(a) > g.own_count(b) if g.own_count(a) != g.own_count(b) else a < b)
	var draw := func(q: String):
		for c in list.get_children(): c.queue_free()
		var shown := 0
		for n in rows:
			if q != "" and not g.nat_name[n].to_lower().contains(q.to_lower()): continue
			var rel := g.get_rel(g.human_id, n)
			var b := K.button("%s%s    %d" % [g.nat_name[n], "  ⚔" if rel == 1 else ("  🤝" if rel == 3 else ""), g.own_count(n)])
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT; b.custom_minimum_size = Vector2(0, 38)
			b.pressed.connect(func(): close(m[0]); on_pick.call(n))
			list.add_child(b)
			shown += 1
			if shown >= 60: break
	search.text_changed.connect(draw)
	draw.call("")
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

static func budget(parent: Control, g: TBGame, on_change: Callable) -> void:
	var m := K.modal(parent, T.call("budget"), 460)
	var n := g.human_id
	var keys := ["tax", "goods", "research", "invest"]
	var sliders := []
	var labels := []
	var sync := func():
		for i in 4:
			sliders[i].set_value_no_signal(g.budget[n * 4 + i]); labels[i].text = "%s  %d%%" % [T.call(keys[i]), g.budget[n * 4 + i]]
	for i in 4:
		var l := K.label("", 15); m[1].add_child(l); labels.append(l)
		var s := HSlider.new(); s.min_value = 0; s.max_value = 100; s.step = 1; s.custom_minimum_size = Vector2(0, 30)
		var idx := i
		s.value_changed.connect(func(v: float):
			g.apply({"cmd": "budget", "n": n, "key": keys[idx], "val": int(v)}); sync.call(); on_change.call())
		m[1].add_child(s); sliders.append(s)
	sync.call()
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

static func settings(parent: Control, cfg: Dictionary, on_change: Callable, on_menu: Callable) -> void:
	var m := K.modal(parent, T.call("settings"), 440)
	_segment(m[1], T.call("quality"), [["low", T.call("q_low")], ["medium", T.call("q_medium")], ["high", T.call("q_high")]], cfg["quality"], func(v): cfg["quality"] = v; on_change.call())
	_segment(m[1], T.call("language"), [["en", "English"], ["ru", "Русский"]], cfg["lang"], func(v): cfg["lang"] = v; on_change.call())
	_segment(m[1], T.call("map_view"), [["globe", T.call("globe")], ["flat", T.call("flat")]], cfg["view"], func(v): cfg["view"] = v; on_change.call())
	var row := K.hbox(8); m[1].add_child(row)
	if on_menu.is_valid(): row.add_child(K.button(T.call("title"), func(): close(m[0]); on_menu.call()))
	var bk := K.button(T.call("back"), func(): close(m[0]), true); bk.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(bk)

static func _segment(parent: Control, title: String, items: Array, current: String, cb: Callable) -> void:
	parent.add_child(K.label(title, 13, K.DIM))
	var row := K.hbox(6); parent.add_child(row)
	var btns := {}
	for it in items:
		var b := K.button(it[1]); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = it[0]
		b.pressed.connect(func():
			cb.call(id)
			for k in btns: btns[k].add_theme_color_override("font_color", K.GOLD2 if k == id else K.TEXT))
		row.add_child(b); btns[id] = b
	btns[current].add_theme_color_override("font_color", K.GOLD2)

static func save_load(parent: Control, saving: bool, on_save: Callable, on_load: Callable) -> void:
	var m := K.modal(parent, T.call("save") if saving else T.call("load"), 460)
	for slot in ["auto", "1", "2", "3"]:
		var meta := TBSave.meta(slot)
		var row := K.hbox(6); m[1].add_child(row)
		var name: String = T.call("autosave") if slot == "auto" else "#" + slot
		var info: String = name + " · " + (("%s · %s %d" % [meta["nation"], T.call("turn"), meta["turn"]]) if not meta.is_empty() else T.call("empty_slot"))
		var l := K.label(info, 14); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		if saving and slot != "auto": row.add_child(K.button(T.call("save"), func(): on_save.call(slot); close(m[0])))
		if not saving and not meta.is_empty(): row.add_child(K.button(T.call("load"), func(): close(m[0]); on_load.call(slot)))
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

static func game_over(parent: Control, text: String, on_menu: Callable) -> void:
	var m := K.modal(parent, text, 420)
	m[1].add_child(K.button(T.call("title"), func(): close(m[0]); on_menu.call(), true))
