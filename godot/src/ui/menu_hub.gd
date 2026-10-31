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
	d.lead(T.call("leave_b", {"n": g.turn if g != null else 0}))
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
## defaults of everything "Reset accessibility" restores (also read by main.gd for a fresh cfg)
const ACCESS_DEFAULTS := {"text_scale": 1.0, "hc": "off", "cvd": "off", "navpad": "auto", "reduce_motion": false, "touch_large": false, "readable": false, "confirm": "risky",
	"tts": false, "mirror": false, "vis_alerts": false, "vol_master": 80, "vol_music": 80, "vol_sfx": 80, "vol_ui": 80, "sound": true}

static func _seg(col: VBoxContainer, title: String, items: Array, cur: String, cb: Callable, compact: bool = false) -> void:
	col.add_child(K.section(title))
	col.add_child(K.segmented(items, cur, cb, compact))

## a group: caption + its rows; returns the VBox so the jump chips can scroll to it
static func _group(title: String) -> VBoxContainer:
	var g := K.vbox(8); g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_child(K.caps(title, 12, K.GOLD))
	return g

## the categories of the Settings tab (a rail on the left, or a row of chips on a narrow or large-text window); one category at a time keeps the page calm
const SET_CATS := [["display", "set_display"], ["map", "set_cat_map"], ["comfort", "set_cat_comfort"], ["sound", "set_audio"], ["language", "language"], ["advanced", "set_advanced"]]

## one row: the name on the left, its control on the right (stacked, name above control, on a narrow window)
static func _srow(title: String, ctl: Control, stacked: bool, hint: String = "") -> Control:
	var box: BoxContainer = VBoxContainer.new() if stacked else HBoxContainer.new()
	box.add_theme_constant_override("separation", 6 if stacked else 14)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lb := K.vbox(0); lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := K.label(title, 16); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.custom_minimum_size.x = 60
	lb.add_child(l)
	if hint != "":
		var hl := K.label(hint, 13, K.DIM); hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hl.custom_minimum_size.x = 60
		lb.add_child(hl)
	ctl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if stacked else Control.SIZE_SHRINK_END
	ctl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(lb); box.add_child(ctl)
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", 4); m.add_theme_constant_override("margin_bottom", 6); m.add_child(box)
	return m

## a choice of more than three options: a drop-down (a pill showing the current choice); three or fewer stay a segmented control
static func _choice(items: Array, cur: String, cb: Callable) -> Control:
	if items.size() <= 3: return K.segmented(items, cur, cb, true)
	var ob := OptionButton.new()
	ob.focus_mode = Control.FOCUS_ALL; ob.fit_to_longest_item = true
	ob.custom_minimum_size = Vector2(150.0, float(K.touch()))
	var sel := 0
	for i in items.size():
		ob.add_item(String(items[i][1]), i)
		if String(items[i][0]) == cur: sel = i
	ob.select(sel)
	ob.item_selected.connect(func(i: int): cb.call(String(items[i][0])))
	return ob

static func _settings(h: TBPanel.Handle, ctx: Dictionary, parent: Control, rebuild: Callable, portrait: bool) -> void:
	var cfg: Dictionary = ctx["cfg"]
	var on_change: Callable = ctx["on_change"]
	var wide: bool = not portrait and h.card.size.x >= 720.0 and K.text_scale < 1.4
	var stacked: bool = not wide and (portrait or h.card.size.x < 520.0 or K.text_scale >= 1.4)
	var keep_scroll := func() -> void: mem["scroll"] = h.scroll.scroll_vertical
	var set := func(key: String, value: Variant, needs_rebuild: bool = false) -> void:
		cfg[key] = value
		keep_scroll.call()
		on_change.call(key)
		if needs_rebuild: rebuild.call()
	var cat: String = String(mem.get("set_cat", "display"))
	var page := K.vbox(4); page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(K.caps(T.call(String(SET_CATS[_cat_index(cat)][1])), 12, K.GOLD))
	match cat:
		"display":
			page.add_child(_srow(T.call("quality"), _choice([["auto", T.call("q_auto_s")], ["low", T.call("q_low")], ["medium", T.call("q_medium")], ["high", T.call("q_high")]], String(cfg["quality"]), func(v): set.call("quality", v)), stacked, T.call("q_auto")))
			page.add_child(_srow(T.call("fx_title"), _choice([["off", T.call("fx_off")], ["light", T.call("fx_light")], ["full", T.call("fx_full")]], String(cfg.get("fx", "full")), func(v): set.call("fx", v)), stacked))
			page.add_child(_srow(T.call("ui_size"), _choice([["small", T.call("ui_small")], ["normal", T.call("ui_normal")], ["large", T.call("ui_large")]], String(cfg.get("ui", "normal")), func(v): set.call("ui", v)), stacked))
			page.add_child(_srow(T.call("phone_layout"), _choice([["desktop", T.call("phone_desktop")], ["compact", T.call("phone_compact")]], String(cfg.get("phone_ui", "desktop")), func(v): set.call("phone_ui", v)), stacked))
			page.add_child(_srow(T.call("era_ui_title"), _choice([["ring", T.call("era_ui_ring")], ["classic", T.call("era_ui_classic")]], String(cfg.get("era_ui", "ring")), func(v): set.call("era_ui", v)), stacked))
			page.add_child(K.toggle(T.call("tips_title"), bool(cfg.get("tips", true)), func(v): set.call("tips", v)))
		"map":
			page.add_child(_srow(T.call("map_view"), _choice([["globe", T.call("globe")], ["flat", T.call("flat")]], String(cfg["view"]), func(v): set.call("view", v)), stacked))
			page.add_child(_srow(T.call("map_style"), _choice([["standard", T.call("style_standard")], ["parchment", T.call("style_parchment")], ["hc", T.call("style_hc")]], String(cfg.get("theme", "standard")), func(v): set.call("theme", v)), stacked))
			page.add_child(_srow(T.call("navpad_title"), _choice([["auto", T.call("navpad_auto")], ["on", T.call("navpad_on")], ["off", T.call("navpad_off")]], String(cfg.get("navpad", "auto")), func(v): set.call("navpad", v)), stacked))
			page.add_child(_srow(T.call("cvd_title"), _choice([["off", T.call("cvd_off")], ["deuter", T.call("cvd_deuter")], ["protan", T.call("cvd_protan")], ["tritan", T.call("cvd_tritan")]], String(cfg.get("cvd", "off")), func(v): set.call("cvd", v)), stacked))
		"comfort":
			page.add_child(_srow(T.call("text_size"), _choice([["1.0", "100%"], ["1.25", "125%"], ["1.5", "150%"], ["2.0", "200%"]], _scale_id(float(cfg.get("text_scale", 1.0))), func(v): set.call("text_scale", float(v), true)), stacked))
			page.add_child(TBPanel.para(T.call("text_preview"), 15, K.DIM))
			page.add_child(_srow(T.call("high_contrast"), _choice([["off", T.call("hc_off")], ["light", T.call("hc_light")], ["dark", T.call("hc_dark")]], _hc_id(cfg), func(v): cfg.erase("contrast"); set.call("hc", v, true)), stacked))
			page.add_child(K.toggle(T.call("reduce_motion"), bool(cfg.get("reduce_motion", false)), func(v): set.call("reduce_motion", v)))
			page.add_child(K.toggle(T.call("large_targets"), bool(cfg.get("touch_large", false)), func(v): set.call("touch_large", v, true)))
			page.add_child(K.toggle(T.call("readable_fonts"), bool(cfg.get("readable", false)), func(v): set.call("readable", v, true)))
			page.add_child(_srow(T.call("set_confirm"), _choice([["off", T.call("confirm_off")], ["risky", T.call("confirm_risky")], ["all", T.call("confirm_all")]], String(cfg.get("confirm", "risky")), func(v): set.call("confirm", v)), stacked))
			var warn := K.label("", 13, K.DIM); warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; warn.visible = false
			page.add_child(K.toggle(T.call("set_tts"), bool(cfg.get("tts", false)), func(v): set.call("tts", v)))
			var tb := K.button(T.call("tts_test"), func():
				K.tts_test()
				warn.text = K.tts_warning; warn.visible = K.tts_warning != "")
			tb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			page.add_child(tb); page.add_child(warn)
			page.add_child(K.toggle(T.call("set_mirror"), bool(cfg.get("mirror", false)), func(v): set.call("mirror", v)))
		"sound":
			page.add_child(K.toggle(T.call("sound"), bool(cfg.get("sound", true)), func(v): set.call("sound", v)))
			for it in [["vol_master", "vol_master"], ["vol_music", "vol_music"], ["vol_sfx", "vol_sfx"], ["vol_ui", "vol_ui"]]:
				var key: String = it[0]
				var sr := K.slider_row(T.call(String(it[1])), 0, 100, 5, float(cfg.get(key, 80)), func(v: float): set.call(key, int(v)))
				sr.custom_minimum_size.x = 250.0
				page.add_child(_srow(T.call(String(it[1])), sr, stacked))
			page.add_child(K.toggle(T.call("set_vis_alerts"), bool(cfg.get("vis_alerts", false)) or not bool(cfg.get("sound", true)), func(v): set.call("vis_alerts", v)))
			if not bool(cfg.get("sound", true)): page.add_child(TBPanel.para(T.call("vis_alerts_muted"), 13, K.DIM))
		"language":
			page.add_child(_srow(T.call("language"), _choice([["en", "English"], ["ru", "Русский"], ["uz", "O‘zbekcha"]], String(cfg["lang"]), func(v): set.call("lang", v, true)), stacked))
		"advanced":
			page.add_child(K.toggle(T.call("perf_overlay"), bool(cfg.get("perf", false)), func(v): set.call("perf", v)))
			if ctx.has("on_diag") and (ctx["on_diag"] as Callable).is_valid():
				var db := K.button(T.call("copy_diag"), Callable())
				db.pressed.connect(func(): (ctx["on_diag"] as Callable).call(); db.text = T.call("diag_copied"))
				db.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				page.add_child(db)
			var reset := K.button(T.call("reset_access"), func():
				TBPanel.confirm(parent, T.call("reset_confirm_t"), T.call("reset_confirm_b"), T.call("reset_do"), func():
					for k in ACCESS_DEFAULTS: cfg[k] = ACCESS_DEFAULTS[k]
					cfg.erase("contrast")
					on_change.call("reset_access"); rebuild.call(), false, "info"))
			reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			page.add_child(reset)
	# ---- the rail (wide window) or a row of chips (narrow): one tap to another category
	var pick := func(id: String) -> void:
		if id == String(mem.get("set_cat", "display")): return
		mem["set_cat"] = id; mem["scroll"] = 0
		rebuild.call()
	var nav: Control
	if wide:
		var rail := K.vbox(4); rail.custom_minimum_size.x = 176.0
		for c in SET_CATS:
			var id: String = c[0]
			var b := K.button(T.call(String(c[1])), func(): pick.call(id), id == cat)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			K.a11y(b, T.call(String(c[1])), "tab")
			rail.add_child(b)
		nav = rail
		var host := HBoxContainer.new(); host.add_theme_constant_override("separation", 22); host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.add_child(nav); host.add_child(VSeparator.new()); host.add_child(page)
		h.body.add_child(host)
	else:
		var chips := HFlowContainer.new(); chips.add_theme_constant_override("h_separation", 6); chips.add_theme_constant_override("v_separation", 6)
		for c in SET_CATS:
			var id2: String = c[0]
			var b2 := K.button(T.call(String(c[1])), func(): pick.call(id2), id2 == cat, true)
			K.a11y(b2, T.call(String(c[1])), "tab")
			chips.add_child(b2)
		h.body.add_child(chips)
		var gap := Control.new(); gap.custom_minimum_size.y = 8.0; h.body.add_child(gap)
		h.body.add_child(page)
	if mem.has("scroll"):
		var sv: int = int(mem["scroll"])
		(func(): if is_instance_valid(h.scroll): h.scroll.scroll_vertical = sv).call_deferred()

static func _cat_index(id: String) -> int:
	for i in SET_CATS.size():
		if String(SET_CATS[i][0]) == id: return i
	return 0

static func _scale_id(v: float) -> String:
	if v >= 1.75: return "2.0"
	if v >= 1.4: return "1.5"
	if v >= 1.1: return "1.25"
	return "1.0"

static func _hc_id(cfg: Dictionary) -> String:
	var hc: String = String(cfg.get("hc", "off"))
	if hc == "off" and bool(cfg.get("contrast", false)): return "light"
	return hc if hc in ["off", "light", "dark"] else "off"

## First-run "Comfort and access" page (A11Y-SET-002): text size, contrast, motion on one dialog with a live preview (each change applies at once).
## on_change(key) is main's setting handler; on_done runs after Continue or Skip. Built from kit helpers + TBPanel.
static func comfort(parent: Control, cfg: Dictionary, on_change: Callable, on_done: Callable = Callable()) -> TBPanel.Handle:
	var d := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("set_comfort_t"), "eye", {"width": 520, "dismissable": false})
	var apply := func(key: String, value: Variant) -> void:
		cfg[key] = value; on_change.call(key)
		if key in ["text_scale", "hc"]:                    # sizes and colours changed: rebuild the dialog so it is its own live preview
			d.close(); comfort(parent, cfg, on_change, on_done)
	d.lead(T.call("set_comfort_b"))
	_seg(d.body, T.call("text_size"), [["1.0", "100%"], ["1.25", "125%"], ["1.5", "150%"], ["2.0", "200%"]], _scale_id(float(cfg.get("text_scale", 1.0))), func(v): apply.call("text_scale", float(v)), true)
	d.body.add_child(TBPanel.para(T.call("text_preview"), 15, K.DIM))
	_seg(d.body, T.call("high_contrast"), [["off", T.call("hc_off")], ["light", T.call("hc_light")], ["dark", T.call("hc_dark")]], _hc_id(cfg), func(v): apply.call("hc", v), true)
	d.body.add_child(K.toggle(T.call("reduce_motion"), bool(cfg.get("reduce_motion", false)), func(v): apply.call("reduce_motion", v)))
	var finish := func() -> void:
		cfg["comfort_seen"] = true; on_change.call("comfort_seen")
		d.close()
		if on_done.is_valid(): on_done.call()
	var skip := K.button(T.call("set_comfort_skip"), func(): finish.call())
	var go := K.button(T.call("set_comfort_go"), func(): finish.call(), true)
	d.actions(skip, go)
	d.focus_target = go
	return d

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
