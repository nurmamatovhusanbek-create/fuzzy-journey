## Menu hub: Saves (Save / Load), Settings, How to play (Codex + tutorial replay) and Honours in ONE panel with a tab row; in a running game the footer
## carries [Main menu] (confirmed, with "Save and exit") and [Resume]. Opened from the title (Load / Settings / How to play / Honours tools) and from
## the HUD Menu entry. Every setting applies live; ctx.on_change(key) lets main apply it.
class_name TBMenuHub
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
const CODEX := ["infamy", "cb", "ultimatum", "generals", "battle", "supply", "rulers", "doctrine", "trade", "realms", "victory"]
const SAVE_SLOTS := ["1", "2", "3", "4", "5"]
static var mem := {"tab": "saves", "mode": "save", "topic": "infamy"}

## ctx: cfg, in_game (bool), g (TBGame or null), tab, on_change(key), on_save(slot), on_load(slot), on_menu(), on_diag(), on_tutorial()
static func open(parent: Control, ctx: Dictionary) -> TBPanel.Handle:
	var in_game: bool = bool(ctx.get("in_game", false))
	var cfg: Dictionary = ctx["cfg"]
	var tab: String = String(ctx.get("tab", mem["tab"]))
	if not tab in ["saves", "settings", "howto", "honours"]: tab = "saves"
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var portrait := TBPanel.is_portrait(vs)
	var S := {"tab": tab, "topic_open": false}
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("menu"), "gear", {"scroll": true})
	var ui := {}
	var titles := {"saves": T.call("saves"), "settings": T.call("settings"), "howto": T.call("tut_help"), "honours": T.call("honours")}
	# ---- tabs
	var items: Array = [["saves", titles["saves"]], ["settings", titles["settings"]], ["howto", titles["howto"]], ["honours", titles["honours"]]]
	var rebuild := func() -> void:
		var nctx: Dictionary = ctx.duplicate(); nctx["tab"] = S["tab"]
		h.close()
		open(parent, nctx)
	var render := func() -> void:
		for c in h.body.get_children(): c.queue_free()
		S["topic_open"] = false
		mem["tab"] = S["tab"]
		h.set_title(titles[S["tab"]] if not in_game else T.call("menu"))
		match String(S["tab"]):
			"saves": _saves(h, ctx, parent, in_game)
			"settings": _settings(h, ctx, parent, rebuild, portrait)
			"howto": _howto(h, ctx, parent, S, portrait)
			"honours": _honours(h, ctx, portrait)
		h.scroll.scroll_vertical = 0
	var tabs := K.tabs(items, tab, func(id: String): S["tab"] = id; render.call())
	h.set_tabs(tabs)
	# ---- footer (running game only)
	if in_game:
		var leave := K.button(T.call("main_menu"), func(): _leave_confirm(parent, ctx, h))
		var back := K.button(T.call("resume"), func(): h.close(), true)
		h.actions(leave, back)
	h.on_back = func() -> bool:
		if bool(S["topic_open"]) and portrait:
			S["topic_open"] = false; render.call(); return true
		return false
	render.call()
	if ctx.has("on_open"): (ctx["on_open"] as Callable).call(h)
	return h

# ---- Saves ----------------------------------------------------------------------------------------------------------------------------------
static func _slot_title(slot: String) -> String:
	return T.call("autosave") if slot == "auto" else T.call("slot_n", {"n": slot})

static func _saved_at(slot: String) -> String:
	var p: String = TBSave.path_for(slot)
	if not FileAccess.file_exists(p): return ""
	var t: int = int(FileAccess.get_modified_time(p))
	if t <= 0: return ""
	return Time.get_datetime_string_from_unix_time(t, true).substr(0, 16)

static func _meta_line(meta: Dictionary) -> String:
	var y: int = int(meta.get("year", 0))
	var ys: String = ("%d BC" % -y) if y < 0 else ("%d AD" % y)
	return "%s · %s %d%s" % [String(meta.get("nation", "")), T.call("turn"), int(meta.get("turn", 0)), (" · " + ys) if y != 0 else ""]

static func _saves(h: TBPanel.Handle, ctx: Dictionary, parent: Control, in_game: bool) -> void:
	var v: VBoxContainer = h.body
	var saving: bool = in_game and String(mem["mode"]) == "save"
	if in_game:
		v.add_child(K.segmented([["save", T.call("save")], ["load", T.call("load")]], "save" if saving else "load", func(id: String):
			mem["mode"] = id
			for c in v.get_children(): c.queue_free()
			_saves(h, ctx, parent, in_game)))
	var slots: Array = ["auto"] + SAVE_SLOTS
	var any := false
	var grid := GridContainer.new(); grid.columns = 2 if (h.card.size.x >= 720.0 and h.form == "panel") else 1
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 8); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(grid)
	for slot in slots:
		var sl: String = slot
		var meta := TBSave.meta(sl)
		var exists := FileAccess.file_exists(TBSave.path_for(sl))
		var title: String = _slot_title(sl)
		var detail := ""
		var reason := ""
		var chips: Array = []
		var cb := Callable()
		if not meta.is_empty():
			any = true
			detail = _meta_line(meta)
			var when := _saved_at(sl)
			if when != "": chips.append([when, "", "neutral"])
			if saving:
				if sl == "auto": reason = T.call("autosave_hint")
				else: cb = func(): _overwrite(parent, ctx, h, sl, meta)
			else:
				cb = func(): _load(parent, ctx, h, sl, in_game)
		elif exists:
			detail = T.call("unreadable"); reason = T.call("unreadable_why")
		else:
			detail = T.call("empty_slot")
			if saving and sl != "auto": cb = func(): (ctx["on_save"] as Callable).call(sl); h.close()
			elif sl == "auto": detail = T.call("autosave_none")
			else: reason = ""
		var c: TBPanel.Card
		if saving and meta.is_empty() and sl != "auto" and not exists:
			c = TBPanel.card("save", title, T.call("save_here"), [], cb, "", false, false)
		elif not saving and meta.is_empty():
			c = TBPanel.card("save", title, detail, [], Callable(), T.call("no_save_to_load") if not exists else reason, false, false)
		else:
			c = TBPanel.card("save" if sl != "auto" else "hourglass", title, detail, chips, cb, reason, false, false)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(c)
		if exists and meta.is_empty() and sl != "auto":
			var del := K.button(T.call("delete"), func():
				TBPanel.confirm(parent, T.call("delete_confirm_t", {"s": title}), T.call("delete_confirm_b"), T.call("delete"), func():
					TBSave.delete(sl)
					for ch in v.get_children(): ch.queue_free()
					_saves(h, ctx, parent, in_game)))
			del.size_flags_horizontal = Control.SIZE_SHRINK_END
			grid.add_child(del)
	if not saving and not any:
		v.add_child(TBPanel.empty_state("save", T.call("no_saves"), T.call("no_saves_why")))

static func _overwrite(parent: Control, ctx: Dictionary, h: TBPanel.Handle, slot: String, meta: Dictionary) -> void:
	var g: TBGame = ctx.get("g", null)
	var now := ""
	if g != null: now = "%s · %s %d" % [g.dname(g.human_id), T.call("turn"), g.turn]
	var body: String = T.call("overwrite_b", {"old": _meta_line(meta), "new": now})
	TBPanel.confirm(parent, T.call("overwrite_t", {"s": _slot_title(slot)}), body, T.call("overwrite_do", {"s": _slot_title(slot)}), func():
		(ctx["on_save"] as Callable).call(slot); h.close())

static func _load(parent: Control, ctx: Dictionary, h: TBPanel.Handle, slot: String, in_game: bool) -> void:
	if not in_game:
		h.close(); (ctx["on_load"] as Callable).call(slot); return
	TBPanel.confirm(parent, T.call("load_t", {"s": _slot_title(slot)}), T.call("load_b"), T.call("load"), func():
		h.close(); (ctx["on_load"] as Callable).call(slot), true, "warning")

static func _leave_confirm(parent: Control, ctx: Dictionary, h: TBPanel.Handle) -> void:
	var g: TBGame = ctx.get("g", null)
	var d := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("leave_t"), "warning", {"width": 440})
	d.body.add_child(TBPanel.para(T.call("leave_b", {"n": g.turn if g != null else 0}), 15))
	var sx := K.button(T.call("save_exit"), func():
		(ctx["on_save"] as Callable).call("auto"); d.close(); h.close(); (ctx["on_menu"] as Callable).call())
	sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.body.add_child(sx)
	var cancel := K.button(T.call("cancel"), func(): d.close())
	var leave := K.danger(T.call("main_menu"), func(): d.close(); h.close(); (ctx["on_menu"] as Callable).call(), "warning")
	d.actions(cancel, leave)
	d.focus_target = cancel
	if TBFrame.kbd_nav: cancel.grab_focus.call_deferred()

# ---- Settings -------------------------------------------------------------------------------------------------------------------------------
static func _seg(col: VBoxContainer, title: String, items: Array, cur: String, cb: Callable) -> void:
	col.add_child(K.section(title))
	col.add_child(K.segmented(items, cur, cb))

static func _settings(h: TBPanel.Handle, ctx: Dictionary, parent: Control, rebuild: Callable, portrait: bool) -> void:
	var cfg: Dictionary = ctx["cfg"]
	var on_change: Callable = ctx["on_change"]
	var wide: bool = not portrait and h.card.size.x >= 720.0 and K.text_scale < 1.4
	var host: BoxContainer = BoxContainer.new(); host.vertical = not wide
	host.add_theme_constant_override("separation", 28 if wide else 16)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(host)
	var c1 := K.vbox(8); c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c2 := K.vbox(8); c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(c1); host.add_child(c2)
	var set := func(key: String, value: Variant, needs_rebuild: bool = false) -> void:
		cfg[key] = value
		on_change.call(key)
		if needs_rebuild: rebuild.call()
	# Display
	c1.add_child(K.caps(T.call("set_display"), 12, K.GOLD))
	_seg(c1, T.call("quality"), [["auto", T.call("q_auto_s")], ["low", T.call("q_low")], ["medium", T.call("q_medium")], ["high", T.call("q_high")]], String(cfg["quality"]), func(v): set.call("quality", v))
	_seg(c1, T.call("map_view"), [["globe", T.call("globe")], ["flat", T.call("flat")]], String(cfg["view"]), func(v): set.call("view", v))
	_seg(c1, T.call("map_style"), [["standard", T.call("style_standard")], ["parchment", T.call("style_parchment")]], String(cfg.get("theme", "standard")), func(v): set.call("theme", v))
	# Interface
	c1.add_child(K.hair())
	c1.add_child(K.caps(T.call("set_interface"), 12, K.GOLD))
	_seg(c1, T.call("ui_size"), [["small", T.call("ui_small")], ["normal", T.call("ui_normal")], ["large", T.call("ui_large")]], String(cfg.get("ui", "normal")), func(v): set.call("ui", v))
	_seg(c1, T.call("text_size"), [["1.0", "100%"], ["1.25", "125%"], ["1.5", "150%"]], _scale_id(float(cfg.get("text_scale", 1.0))), func(v): set.call("text_scale", float(v), true))
	# Language
	c1.add_child(K.hair())
	c1.add_child(K.caps(T.call("language"), 12, K.GOLD))
	c1.add_child(K.segmented([["en", "English"], ["ru", "Русский"], ["uz", "O‘zbekcha"]], String(cfg["lang"]), func(v): set.call("lang", v, true)))
	# Audio
	c2.add_child(K.caps(T.call("set_audio"), 12, K.GOLD))
	c2.add_child(TBPanel.toggle(T.call("sound"), bool(cfg.get("sound", true)), func(v): set.call("sound", v)))
	# Accessibility
	c2.add_child(K.hair())
	c2.add_child(K.caps(T.call("set_access"), 12, K.GOLD))
	c2.add_child(TBPanel.toggle(T.call("high_contrast"), bool(cfg.get("contrast", false)), func(v): set.call("contrast", v, true)))
	c2.add_child(TBPanel.toggle(T.call("reduce_motion"), bool(cfg.get("reduce_motion", false)), func(v): set.call("reduce_motion", v)))
	c2.add_child(TBPanel.toggle(T.call("large_targets"), bool(cfg.get("touch_large", false)), func(v): set.call("touch_large", v, true)))
	c2.add_child(TBPanel.toggle(T.call("readable_fonts"), bool(cfg.get("readable", false)), func(v): set.call("readable", v, true)))
	# Advanced
	c2.add_child(K.hair())
	c2.add_child(K.caps(T.call("set_advanced"), 12, K.GOLD))
	c2.add_child(TBPanel.toggle(T.call("perf_overlay"), bool(cfg.get("perf", false)), func(v): set.call("perf", v)))
	if ctx.has("on_diag") and (ctx["on_diag"] as Callable).is_valid():
		var db := K.button(T.call("copy_diag"), Callable())
		db.pressed.connect(func(): (ctx["on_diag"] as Callable).call(); db.text = T.call("diag_copied"))
		c2.add_child(db)
	var reset := K.button(T.call("reset_access"), func():
		for k in ["contrast", "reduce_motion", "touch_large", "readable"]: cfg[k] = false
		cfg["text_scale"] = 1.0
		on_change.call("reset_access"); rebuild.call())
	c2.add_child(reset)

static func _scale_id(v: float) -> String:
	if v >= 1.4: return "1.5"
	if v >= 1.1: return "1.25"
	return "1.0"

# ---- How to play (Codex + tutorial replay) -------------------------------------------------------------------------------------------------------
static func _howto(h: TBPanel.Handle, ctx: Dictionary, parent: Control, S: Dictionary, portrait: bool) -> void:
	var v: VBoxContainer = h.body
	var wide: bool = not portrait and h.card.size.x >= 720.0 and K.text_scale < 1.4
	var replay := K.button(T.call("tut_replay"), func():
		h.close()
		if ctx.has("on_tutorial"): (ctx["on_tutorial"] as Callable).call())
	if portrait and bool(S["topic_open"]):
		_topic(v, String(mem["topic"]))
		return
	if wide:
		var split := K.hbox(24); split.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.add_child(split)
		var lv := K.vbox(0); lv.custom_minimum_size = Vector2(230, 0); split.add_child(lv)
		replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.add_child(replay)
		var sp0 := Control.new(); sp0.custom_minimum_size = Vector2(0, 8); lv.add_child(sp0)
		var rv := K.vbox(8); rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(rv)
		var rows := {}
		var show := func(id: String) -> void:
			mem["topic"] = id
			for k in rows: (rows[k] as K.ListRow).selected = (k == id)
			for c in rv.get_children(): c.queue_free()
			_topic(rv, id)
		for id in CODEX:
			var tid: String = id
			var row := K.ListRow.new(T.call("codex_" + tid + "_t"), "", func(): show.call(tid))
			lv.add_child(row); rows[tid] = row
		show.call(String(mem["topic"]))
	else:
		v.add_child(replay)
		v.add_child(K.section(T.call("codex")))
		for id in CODEX:
			var tid2: String = id
			v.add_child(K.ListRow.new(T.call("codex_" + tid2 + "_t"), "›", func():
				mem["topic"] = tid2; S["topic_open"] = true
				for c in v.get_children(): c.queue_free()
				_topic(v, tid2)))

static func _topic(v: Control, id: String) -> void:
	v.add_child(K.title(T.call("codex_" + id + "_t"), 20))
	v.add_child(TBPanel.para(T.call("codex_" + id + "_b"), 15, K.TEXT))

# ---- Honours ------------------------------------------------------------------------------------------------------------------------------------
## countable progress of an honour for the running game: [value, goal, unit] or []
static func _progress(g: TBGame, id: String) -> Array:
	if g == null or g.human_id <= 0: return []
	var me: int = g.human_id
	match id:
		"empire_30": return [g.own_count(me), 30, T.call("lands").to_lower()]
		"empire_60": return [g.own_count(me), 60, T.call("lands").to_lower()]
		"empire_100": return [g.own_count(me), 100, T.call("lands").to_lower()]
		"treasure": return [int(g.gold[me]), 5000, T.call("gold").to_lower()]
		"veteran": return [g.turn, 100, T.call("turn").to_lower()]
	return []

static func _honours(h: TBPanel.Handle, ctx: Dictionary, portrait: bool) -> void:
	var cfg: Dictionary = ctx["cfg"]
	var g: TBGame = ctx.get("g", null)
	var v: VBoxContainer = h.body
	var d: Dictionary = cfg.get("honours", {})
	var total: int = TBHonours.LIST.size()
	var got_n: int = TBHonours.count(cfg)
	var top := K.hbox(12); v.add_child(top)
	var pl := K.num("%d / %d" % [got_n, total], 18, K.GOLD2); top.add_child(pl)
	var mt := K.Meter.new(float(got_n) / float(total) * 100.0, TBTokens.c("brass_ink")); mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(mt)
	var S := {"f": "all"}
	var wide: bool = not portrait and h.card.size.x >= 720.0 and K.text_scale < 1.4
	var grid := GridContainer.new(); grid.columns = 2 if wide else 1
	grid.add_theme_constant_override("h_separation", 20); grid.add_theme_constant_override("v_separation", 10); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var empty := TBPanel.empty_state("trophy", T.call("honours_none"), T.call("honours_none_why")); empty.visible = false
	var chips := TBPanel.flow(6)
	var cbs := {}
	var draw := func() -> void:
		for c in grid.get_children(): c.queue_free()
		var shown := 0
		for it in TBHonours.LIST:
			var id: String = it[0]
			var got := d.has(id)
			if String(S["f"]) == "earned" and not got: continue
			if String(S["f"]) == "locked" and got: continue
			shown += 1
			grid.add_child(_tile(id, String(it[1]), got, String(d.get(id, "")), _progress(g, id)))
		empty.visible = shown == 0
	for f in [["all", T.call("f_all")], ["earned", T.call("f_earned")], ["locked", T.call("f_locked")]]:
		var fid: String = f[0]
		var cb := TBPanel.chip_button(String(f[1]), fid == "all", func():
			S["f"] = fid
			for k in cbs: (cbs[k] as TBPanel.ChipBtn).set_on(k == fid)
			draw.call())
		chips.add_child(cb); cbs[fid] = cb
	v.add_child(chips); v.add_child(grid); v.add_child(empty)
	draw.call()

static func _tile(id: String, glyph_id: String, got: bool, year: String, prog: Array) -> Control:
	var pc := PanelContainer.new(); pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_1"), TBTokens.c("brass_ink") if got else TBTokens.c("rule"), 4, 0, 12, 10, false, 2 if got else 1))
	var row := K.hbox(12); pc.add_child(row)
	var gl := K.glyph(glyph_id, 28, TBTokens.c("brass_ink") if got else TBTokens.c("ink_1"), got)
	gl.custom_minimum_size = Vector2(36, 36); gl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(gl)
	var col := K.vbox(3); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(col)
	var nm := K.title(T.call("honour_" + id), 15, TBTokens.c("oxblood") if got else TBTokens.c("ink_0"))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nm.custom_minimum_size.x = 40
	col.add_child(nm)
	col.add_child(TBPanel.para(T.call("honour_" + id + "_d"), 13, K.DIM))
	if got:
		var ec := K.chip(T.call("earned_year", {"y": year}), "check", "pos"); ec.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(ec)
	else:
		var lr := K.hbox(4); lr.add_child(K.glyph("lock", 14, TBTokens.c("ink_1")))
		lr.add_child(K.label(T.call("locked"), 12, K.DIM)); col.add_child(lr)
		if prog.size() == 3:
			var pr := K.hbox(8)
			var mt := K.Meter.new(clampf(float(prog[0]) / float(prog[1]) * 100.0, 0.0, 100.0), TBTokens.c("brass_ink")); mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pr.add_child(mt)
			pr.add_child(K.num("%d/%d" % [int(prog[0]), int(prog[1])], 12, K.DIM))
			col.add_child(pr)
	return pc
