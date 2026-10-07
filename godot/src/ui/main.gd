## App root: screen flow (menu -> era -> pick nation -> game), input routing, async end-turn, persistence.
extends Control

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

var world: TBWorld
var g: TBGame
var map: TBMapView
var hud: TBHud
var panel: TBProvincePanel
var flow: TBOrderFlow          # orders on the map (select -> targets -> preview -> confirm)
var tip: TBMapTip
var mode := "boot"             # menu | pick | game
var selected := -1
var move_from := -1
var cfg := {"perf": false, "seal_seen": false, "sound": true, "quality": "auto", "lang": "en", "view": "globe", "difficulty": "normal", "tutorial": false, "theme": "standard", "ui": "normal", "honours": {}, "era": "modern", "players": 1, "text_scale": 1.0, "readable": false, "reduce_motion": false, "touch_large": false, "hc": "off", "cvd": "off", "tts": false, "confirm": "risky", "mirror": false, "vis_alerts": false, "vol_master": 80, "vol_music": 80, "vol_sfx": 80, "vol_ui": 80, "comfort_seen": false, "navpad": "auto"}
var _overlay: Control          # screens/modals live here
var _turn_thread: Thread
var _busy := false
var _log_idx := 0
var _spin := true
var mp: TBMpController
var sfx: TBAudio
var _perf_label: Label
var _perf_t := 0.0
var _turn_ms := 0
var _turn_t0 := 0

func _ready() -> void:
	theme = K.theme()
	_load_cfg()
	TBI18n.load_lang(cfg["lang"])
	_apply_a11y()
	world = TBWorld.load_from("res://data")
	map = TBMapView.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	map.province_picked.connect(_on_pick)
	map.province_hovered.connect(_on_hover)
	map.province_peeked.connect(_on_peek)
	map.performance_low.connect(_on_perf_low)
	sfx = TBAudio.new(); add_child(sfx); sfx.enabled = cfg.get("sound", true)
	hud = TBHud.new(); add_child(hud); hud.visible = false
	panel = TBProvincePanel.new(); add_child(panel)
	map.keepout_fn = func() -> Array:
		var r: Array = hud.keepouts()
		if panel.visible: r.append(panel.get_global_rect())
		return r
	flow = TBOrderFlow.new(); flow.map = map; flow.panel = panel; flow.host = self
	flow.do_move = func(from: int, to: int): _do_move(from, to)
	flow.is_busy = func() -> bool: return _busy
	panel.flow = flow
	panel.busy_fn = func() -> bool: return _busy
	panel.blocked_fn = func() -> bool: return mode != "game" or _overlay.get_child_count() > 0
	panel.command.connect(func(c: Dictionary): _on_command(c, true)); panel.move_requested.connect(_on_move_requested); panel.closed.connect(func(): _select(-1))
	panel.select_requested.connect(func(q: int): _select(q))
	tip = TBMapTip.new(); add_child(tip)
	TBMapCursor.install(self)                       # keyboard map cursor + on-screen nav pad (accessibility)
	_overlay = Control.new(); _overlay.set_anchors_preset(Control.PRESET_FULL_RECT); _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	mp = TBMpController.new(); add_child(mp); mp.setup(self)
	hud.end_turn_pressed.connect(func():
		sfx.play("turn"); end_turn()
		if not cfg.get("seal_seen", false): cfg["seal_seen"] = true; _save_cfg(); hud.set_seal_pulse(false))
	hud.tapped.connect(func(): sfx.play("tap"))
	hud.lens_selected.connect(func(n): map.set_lens(n); hud.set_lens_legend(n))
	hud.nations_pressed.connect(func(): _open_nations())
	hud.goals_pressed.connect(func(): _open_council("goals"))
	hud.decisions_pressed.connect(func(): _open_decisions())
	hud.chronicle_pressed.connect(func(): _open_annals())
	hud.advisor_pressed.connect(func(): _open_council("advice"))
	hud.wars_pressed.connect(func(): _open_nations(-1, "war"))
	panel.nation_requested.connect(_open_nation)
	hud.budget_pressed.connect(func(): _open_budget())
	hud.save_pressed.connect(func(): _open_menu_hub("saves"))
	hud.settings_pressed.connect(_open_settings)
	hud.input_blocked_fn = func() -> bool: return mode != "game" or _overlay.get_child_count() > 0
	hud.mp_waiting_fn = func() -> bool: return mp.in_game
	hud.goto_province.connect(_goto_province)
	hud.nation_pressed.connect(_open_nation)
	hud.offer_answered.connect(func(uid: int, i: int): _on_command({"cmd": "eventChoice", "uid": uid, "i": i}))
	hud.event_requested.connect(func(uid: int): _shown_events.erase(uid); show_events())
	panel.band_fn = hud.card_band; panel.reserve_fn = hud.bottom_reserve; panel.confirm_fn = func() -> String: return _confirm_mode()
	resized.connect(func(): hud.layout_for(size); panel.layout_for(size))        # the HUD first: the card fits the band the End Turn seal leaves
	hud.layout_changed.connect(func(): panel.layout_for(size))
	get_window().size_changed.connect(_update_ui_scale); _update_ui_scale()
	_apply_quality()
	_new_demo_game()
	show_menu()
	panel.layout_for(size)
	_offer_comfort.call_deferred()

## first run: one "Comfort and access" page (text size, contrast, motion), offered once. Not in script runs (tests) unless TB_COMFORT=1.
func _offer_comfort() -> void:
	if bool(cfg.get("comfort_seen", false)): return
	var scripted: bool = ("-s" in OS.get_cmdline_args() or "--script" in OS.get_cmdline_args()) and OS.get_environment("TB_COMFORT") == ""
	if scripted: return
	TBMenuHub.comfort(_overlay, cfg, _on_setting_changed)

## phones in portrait need a different logical base size, otherwise the landscape 1280x720 base shrinks the UI to a few px
func _update_ui_scale() -> void:
	var w := get_window()
	var s := w.size
	var k: float = {"small": 1.18, "normal": 1.0, "large": 0.84}.get(cfg.get("ui", "normal"), 1.0)      # bigger logical size = smaller UI
	var ppu: float = _px_per_unit(s) / k
	w.content_scale_size = Vector2i(maxi(320, int(round(s.x / ppu))), maxi(240, int(round(s.y / ppu))))
	_apply_safe_area()

## physical pixels per logical unit "u" (design/ux/hud.md Q1): ~1 dp on phones (DPI based), 1.5 px/u on a 1080p desktop,
## and never below 1.0 so an 800x360 window is 800x360u. TB_UI_SCALE overrides it (tests emulating a phone's density).
func _px_per_unit(s: Vector2i) -> float:
	var env := OS.get_environment("TB_UI_SCALE")
	if env != "": return clampf(float(env), 0.5, 4.0)
	if OS.get_name() in ["Android", "iOS"]:
		return clampf(DisplayServer.screen_get_dpi() / 160.0, 1.0, 4.0)
	if s.y > s.x: return clampf(s.x / 360.0, 1.0, 3.0)         # portrait window: 540 px = 360u
	return clampf(s.y / 720.0, 1.0, 3.0)

## keep UI clear of notches / rounded corners / gesture bars on phones
func _apply_safe_area() -> void:
	var emu := OS.get_environment("TB_SAFE")          # "left,top,right,bottom" in logical units: cutout emulation for screenshots / tests
	if emu != "":
		var p := emu.split_floats(",")
		if p.size() == 4:
			offset_left = p[0]; offset_top = p[1]; offset_right = -p[2]; offset_bottom = -p[3]; return
	if not (OS.get_name() in ["Android", "iOS"]):
		offset_left = 0; offset_top = 0; offset_right = 0; offset_bottom = 0; return
	var w := get_window()
	var safe := DisplayServer.get_display_safe_area()
	var scr := DisplayServer.screen_get_size()
	if safe.size == Vector2i.ZERO or scr.x == 0: return
	var k := minf(float(w.size.x) / w.content_scale_size.x, float(w.size.y) / w.content_scale_size.y)   # physical px per logical px
	offset_left = safe.position.x / k; offset_top = safe.position.y / k
	offset_right = -(scr.x - safe.end.x) / k; offset_bottom = -(scr.y - safe.end.y) / k

func _load_cfg() -> void:
	var f := ConfigFile.new()
	if f.load("user://settings.cfg") == OK:
		for k in cfg: cfg[k] = f.get_value("tb", k, cfg[k])
		if bool(f.get_value("tb", "contrast", false)) and cfg["hc"] == "off": cfg["hc"] = "light"          # the old boolean became hc off / light / dark
		if not f.has_section_key("tb", "reduce_motion"): cfg["reduce_motion"] = K.os_prefers_reduced_motion()
	else:
		cfg["quality"] = _guess_quality()
		cfg["reduce_motion"] = K.os_prefers_reduced_motion()

func _save_cfg() -> void:
	var f := ConfigFile.new()
	for k in cfg: f.set_value("tb", k, cfg[k])
	f.save("user://settings.cfg")

var _auto_tier := -1

## the map reports sustained slow frames: step the auto tier down once per ~30 interactions
func _on_perf_low() -> void:
	if cfg["quality"] != "auto" or _auto_tier <= 0: return
	_auto_tier -= 1
	_apply_quality()
	if hud != null and hud.visible: hud.toast(T.call("q_auto_down"))

func _guess_quality() -> String:
	if OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS": return "medium"
	return "high"

func _apply_quality() -> void:
	if cfg["quality"] == "auto" and _auto_tier < 0: _auto_tier = {"low": 0, "medium": 1, "high": 2}.get(_guess_quality(), 1)
	var q: int = _auto_tier if cfg["quality"] == "auto" else {"low": 0, "medium": 1, "high": 2}.get(cfg["quality"], 1)
	map.quality = q
	map.map_theme = {"parchment": 1, "hc": 2}.get(cfg.get("theme", "standard"), 0)
	map.render_scale = [0.6, 0.85, 1.0][q]      # fraction of logical resolution the map shader renders at
	map.apply_a11y(cfg)

# ---------------------------------------------------------------- screens
func _new_demo_game() -> void:
	g = TBGame.new(world, {}, {"seed": 1})
	map.setup(g)
	map.set_mode(0 if cfg["view"] == "globe" else 1)

func _clear_overlay() -> void:
	for c in _overlay.get_children(): c.queue_free()

const MP_ = preload("res://src/ui/menu_parts.gd")
var _bezel: Control

func show_menu() -> void:
	mode = "menu"; _spin = true; _pick_flow = null; K.serif = true
	var vs: Vector2 = size if size.x > 2.0 else get_viewport_rect().size
	var portrait := vs.y > vs.x
	var short: bool = vs.y < 480.0 and not portrait
	var tools_h: float = float(K.touch())
	if map.mode == 0:                                       # whole globe inside the ring, sized so the ring clears the tools row (and fits the width in portrait)
		map.set_mode(0)
		var base: float = minf(vs.x, vs.y) * 0.44
		var r_max: float = ((vs.y * 0.5 - tools_h - 10.0) / 1.103) if not portrait else minf((vs.x - 28.0) * 0.5 / 1.103, (vs.y - tools_h * 2.0 - 30.0) * 0.5 / 1.103)
		if short: r_max = maxf(r_max, 120.0)
		map.zoom = clampf(r_max / base, 0.55, 1.0); map._push_view()
	hud.visible = false; panel.visible = false; _clear_overlay(); map.labels.visible = false
	var bez := MP_.Bezel.new(); bez.map = map; _overlay.add_child(bez); _bezel = bez
	# layout: [ scrolling centre column (wordmark + text rows) ] over [ tools row ]; the column scrolls instead of covering anything
	var frame := VBoxContainer.new(); frame.set_anchors_preset(Control.PRESET_FULL_RECT); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("separation", 0)
	frame.offset_left = 12; frame.offset_right = -12; frame.offset_top = 6; frame.offset_bottom = -6
	_overlay.add_child(frame)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.follow_focus = true; sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sc)
	var holder := CenterContainer.new(); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(holder)
	sc.resized.connect(_sync_title_holder.bind(sc, holder))      # centre vertically while it fits, scroll when it does not
	var colw: float = clampf(vs.x - 40.0, 240.0, 380.0)
	var v := K.vbox(2 if short else 8)
	holder.add_child(v)
	var wm: String = T.call("title")
	var wm_max: int = 30 if short else (54 if not portrait else 40)
	var wm_font: Font = K.tracked(K.wordmark(), 2 if (portrait or short) else 4)
	var wm_avail: float = minf(vs.x - 32.0, maxf(220.0, map.radius_px() * 1.56))      # the wordmark stays inside the ring's chord
	var wm_size: int = wm_max
	while wm_size > 14 and wm_font.get_string_size(wm, HORIZONTAL_ALIGNMENT_LEFT, -1, K.fs(wm_size)).x > wm_avail: wm_size -= 1        # fits at every text size
	var t := K.label(wm, wm_size, TBTokens.c("brass_lt"))
	t.add_theme_font_override("font", wm_font)
	t.add_theme_constant_override("outline_size", 4); t.add_theme_color_override("font_outline_color", TBTokens.ca("table", 0.9))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(t)
	if not short:
		var orn := K.ornament(); orn.col = TBTokens.ca("brass_lt", 0.7); v.add_child(orn)
		var tag := K.caps(T.call("tagline"), 12, TBTokens.c("smoke")); tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.custom_minimum_size.x = 40; tag.add_theme_constant_override("outline_size", 3); tag.add_theme_color_override("font_outline_color", TBTokens.ca("table", 0.9)); v.add_child(tag)
		var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 6); v.add_child(gap)
	var am := TBSave.meta("auto")
	var plates: Array = []
	var cmp: bool = short
	if not am.is_empty():
		var yr: int = int(am.get("year", 0))
		var sub := "%s · %s %d%s" % [String(am.get("nation", "")), T.call("turn"), int(am.get("turn", 0)), (" · " + (("%d BC" % -yr) if yr < 0 else ("%d AD" % yr))) if yr != 0 else ""]
		plates.append(MP_.Plate.new(T.call("continue"), sub, true, func(): _load_slot("auto"), "", cmp))
	elif FileAccess.file_exists(TBSave.path_for("auto")):
		plates.append(MP_.Plate.new(T.call("continue"), "", false, Callable(), T.call("autosave_unreadable"), cmp))
	plates.append(MP_.Plate.new(T.call("new_game"), "", am.is_empty() and not FileAccess.file_exists(TBSave.path_for("auto")), func(): _open_era_picker(), "", cmp))
	var saves := 0
	for sl in ["auto", "1", "2", "3", "4", "5"]:
		if not TBSave.meta(sl).is_empty(): saves += 1
	plates.append(MP_.Plate.new(T.call("load"), T.call("n_saves", {"n": saves}) if saves > 0 else "", false, func(): _open_menu_hub("saves"), T.call("no_saves_yet") if saves == 0 else "", cmp))
	plates.append(MP_.Plate.new(T.call("multiplayer"), "", false, func(): mp.open_menu(), "", cmp))
	for pl in plates: pl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; (pl as Control).custom_minimum_size.x = minf(colw, 340.0); v.add_child(pl)
	# tools row: Honours n/19, Settings, How to play, EN | RU | UZ (small text buttons, wraps in portrait)
	var tools := HFlowContainer.new(); tools.alignment = FlowContainer.ALIGNMENT_CENTER; tools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tools.add_theme_constant_override("h_separation", 6); tools.add_theme_constant_override("v_separation", 0)
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(MP_.ToolChip.new("trophy", "%s %d/%d" % [T.call("honours"), TBHonours.count(cfg), TBHonours.LIST.size()], func(): _open_menu_hub("honours")))
	tools.add_child(MP_.ToolChip.new("gear", T.call("settings"), func(): _open_menu_hub("settings")))
	tools.add_child(MP_.ToolChip.new("book", T.call("tut_help"), func(): _open_menu_hub("howto")))
	var ls := MP_.LangSwitch.new(String(cfg["lang"]))
	ls.chosen.connect(func(code: String):
		cfg["lang"] = code; _save_cfg(); TBI18n.load_lang(code); show_menu())
	tools.add_child(ls)
	frame.add_child(tools)
	var vtxt := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges().trim_prefix("v")
	var ver := K.label("v" + (vtxt if vtxt != "" else "dev"), 12, TBTokens.c("smoke"))
	ver.set_anchors_preset(Control.PRESET_TOP_RIGHT); ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -10; ver.offset_top = 6; ver.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ver.add_theme_constant_override("outline_size", 3); ver.add_theme_color_override("font_outline_color", TBTokens.ca("table", 0.9))
	_overlay.add_child(ver)
	if TBPanel.wants_focus():                                # keyboard / gamepad cold start: the first enabled entry has focus (Up / Down / Enter / Space)
		for pl in plates:
			if not (pl as Button).disabled: (pl as Control).grab_focus.call_deferred(); break

func _sync_title_holder(sc: Control, holder: Control) -> void:
	if is_instance_valid(holder) and is_instance_valid(sc): holder.custom_minimum_size = Vector2(0, sc.size.y)

## a panel over the title: the globe stops, the ring dims; both come back when the last panel closes
func _title_panel_opened(h: TBPanel.Handle) -> void:
	if mode != "menu" or h == null: return
	_spin = false
	if is_instance_valid(_bezel): _bezel.dim = 0.35; _bezel.queue_redraw()
	h.root.tree_exited.connect(func(): _title_restore.call_deferred())

func _title_restore() -> void:
	if mode != "menu" or TBPanel.any_open(_overlay): return
	_spin = true
	if is_instance_valid(_bezel): _bezel.dim = 1.0

# ================================================================================================================================
# UI ENTRY POINTS (modals): the HUD dock, ribbon chips and shortcuts call these. Everything below this marker up to the
# "end of UI entry points" marker belongs to the modal system; keep HUD wiring to one-line calls.
# ================================================================================================================================
func _open_nations(select: int = -1, filter: String = "", tab: String = "") -> void:
	if g == null: return
	var o := {"on_cmd": _on_command, "on_goto": _goto_nation}
	if select > 0: o["select"] = select
	if filter != "": o["filter"] = filter
	if tab != "": o["tab"] = tab
	TBModals.nations_screen(_overlay, g, o)

func _open_nation(n: int) -> void: _open_nations(n)

func _open_council(tab: String = "") -> void:
	if g != null: TBModals.council(_overlay, g, _goto_province, tab)

func _open_budget() -> void:
	if g != null: TBModals.budget(_overlay, g, func(): hud.refresh())

func _open_decisions() -> void:
	if g != null: TBModals.decisions(_overlay, g, _on_command)

func _open_annals() -> void:
	if g != null: TBModals.chronicle(_overlay, g, _goto_province, hud.feed_lines(8))

## Saves / Settings / How to play / Honours in one panel; tab = "saves" | "settings" | "howto" | "honours"
func _open_menu_hub(tab: String = "") -> void:
	var ctx := {"cfg": cfg, "in_game": mode == "game", "g": g if mode == "game" else null, "on_change": _on_setting_changed, "on_save": _save_slot, "on_load": _load_slot,
		"on_menu": show_menu, "on_diag": _copy_diagnostics, "on_tutorial": func(): TBModals.tutorial(_overlay, func(): pass), "on_open": _title_panel_opened}
	if tab != "": ctx["tab"] = tab
	TBModals.menu_hub(_overlay, ctx)

func _open_settings() -> void: _open_menu_hub("settings")

## kit setting (off | risky | all) -> HUD / card wording (never | smart | always)
func _confirm_mode() -> String:
	return {"off": "never", "risky": "smart", "all": "always"}.get(K.confirm, "smart")

## apply the accessibility settings to the kit (text size, fonts, contrast, motion, targets) and refresh the theme
func _apply_a11y() -> void:
	theme = K.apply_settings(cfg)         # sets K.text_scale / reduce_motion / touch / hc / cvd / tts / confirm, rebuilds the theme, emits K.settings_changed
	TBAudio.apply_volumes(cfg)
	if hud != null:
		hud.set_text_scale(K.text_scale)
		hud.confirm_mode = _confirm_mode()
	TBNavPad.setting = String(cfg.get("navpad", "auto"))
	if map != null: map.apply_a11y(cfg)                     # colour-vision palette + high-contrast map

func _on_setting_changed(key: String) -> void:
	_save_cfg()
	match key:
		"lang":
			TBI18n.load_lang(cfg["lang"]); _rebuild_screens()
		"quality", "view", "theme", "ui":
			_apply_quality(); _update_ui_scale(); map.set_mode(0 if cfg["view"] == "globe" else 1)
		"sound": sfx.enabled = cfg.get("sound", true); _apply_a11y()
		"vol_master", "vol_music", "vol_sfx", "vol_ui": TBAudio.apply_volumes(cfg)
		"text_scale", "readable", "touch_large", "hc", "contrast", "reduce_motion", "cvd", "tts", "confirm", "mirror", "vis_alerts", "navpad":
			_apply_a11y(); _rebuild_screens()
		"reset_access":
			sfx.enabled = cfg.get("sound", true); _apply_a11y(); _rebuild_screens()

## re-create the already-built screens after a language / text / contrast change (the open hub rebuilds itself)
func _rebuild_screens() -> void:
	if mode == "game":
		hud.build(); hud.refresh()
		if selected >= 0: panel.rebuild()
	elif mode == "menu":
		var keep := TBPanel.top(_overlay)
		if keep == null: show_menu()
		else:
			# title behind an open panel: rebuild the title parts only, keep the panel
			var panels: Array = []
			for c in _overlay.get_children():
				if c.has_meta("tb_handle"): panels.append(c)
			for c in panels: _overlay.remove_child(c)
			show_menu()
			for c in panels: _overlay.add_child(c)
			_bezel.dim = 0.35

# ---------------------------------------------------------------- end of UI entry points

## everything needed to judge performance on a device, copied to the clipboard (and saved to user://diagnostics.txt)
func _copy_diagnostics() -> void:
	var lines := PackedStringArray()
	lines.append("Terra Bellum diagnostics")
	lines.append("os=%s %s model=%s" % [OS.get_name(), OS.get_version(), OS.get_model_name()])
	lines.append("cpu=%s x%d  ram_static=%d MB" % [OS.get_processor_name(), OS.get_processor_count(), OS.get_static_memory_usage() / 1048576])
	lines.append("gpu=%s | %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	lines.append("screen=%s window=%s scale=%.2f touch=%s" % [DisplayServer.screen_get_size(), DisplayServer.window_get_size(), DisplayServer.screen_get_scale(), DisplayServer.is_touchscreen_available()])
	lines.append("fps=%d frame_ms=%.1f quality=%s tier=%d render_scale=%.2f last_turn_ms=%d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, cfg.get("quality", "auto"), map.quality, map.render_scale, _turn_ms])
	if g != null:
		lines.append("game: era=%s turn=%d seed=%d rules=%d provinces=%d nations_alive=%d" % [g.era_id, g.turn, g.seed_value, g.rules, g.P, _alive_count()])
	lines.append("lang=%s view=%s theme=%s ui=%s" % [cfg.get("lang", ""), cfg.get("view", ""), cfg.get("theme", ""), cfg.get("ui", "")])
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	var f := FileAccess.open("user://diagnostics.txt", FileAccess.WRITE)
	if f != null: f.store_string(text); f.close()

func _alive_count() -> int:
	var c := 0
	for n in range(1, g.N1):
		if g.alive[n] != 0 and n != g.rebel: c += 1
	return c

func _open_era_picker() -> void:
	if mode != "menu": show_menu()
	TBModals.new_game(_overlay, {"world": world, "era": cfg.get("era", "modern"), "difficulty": cfg["difficulty"], "players": int(cfg.get("players", 1)),
		"on_next": func(era: String, diff: String, players: int):
			cfg["era"] = era; cfg["players"] = players; _hot_n = players if players > 1 else 0; _hot_list = PackedInt32Array()
			_begin_pick(era, diff),
		"on_back": show_menu})
	_title_panel_opened(TBPanel.top(_overlay))

func _begin_pick(era_id: String, difficulty: String) -> void:
	cfg["difficulty"] = difficulty; _save_cfg()
	var era := TBWorld.load_era("res://data", era_id) if era_id != "modern" else {}
	g = TBGame.new(world, era, {"seed": int(Time.get_unix_time_from_system()) & 0x7fffffff | 1, "difficulty": difficulty})
	map.setup(g)
	mode = "pick"; _spin = false; K.serif = false
	_show_pick()

var _pick_flow: TBPickFlow

## the nation-pick overlay (back, instruction slip, shortlist rail, confirm card); rebuilt after every hot-seat pick
func _show_pick() -> void:
	_clear_overlay()
	_pick_flow = TBPickFlow.new().setup(g, map, _hot_n, _hot_list)
	_pick_flow.play.connect(_confirm_pick)
	_pick_flow.back_requested.connect(_open_era_picker)
	_pick_flow.list_requested.connect(_open_pick_list)
	_overlay.add_child(_pick_flow)

func _open_pick_list() -> void:
	var seats := {}
	for i in _hot_list.size(): seats[_hot_list[i]] = "P%d" % (i + 1)
	TBModals.nations_screen(_overlay, g, {"pick": true, "taken": Array(_hot_list), "seats": seats, "on_play": _confirm_pick, "on_goto": _pick_nation_from_list})

## hot-seat: every player picks in turn, then the game starts
func _confirm_pick(n: int) -> void:
	if _hot_n <= 1: _start_game(n); return
	_hot_list.append(n)
	if _hot_list.size() >= _hot_n: _start_game(n); return
	_show_pick()

func _pick_nation_from_list(n: int) -> void:
	if _pick_flow != null and is_instance_valid(_pick_flow): _pick_flow.select_nation(n, true)

const HOT_COLORS := [0xC63A4A, 0x3A7AC6, 0x3AA66A, 0xC6A23A]

func _start_game(n: int) -> void:
	hud.seat_tag = ""
	if _hot_n > 1:
		g.set_human(_hot_list[0])
		for k in range(1, _hot_list.size()): g.add_human(_hot_list[k])
		for k in _hot_list.size(): g.color[_hot_list[k]] = HOT_COLORS[k]
		n = _hot_list[0]
		_hot_n = 0
	else:
		g.set_human(n); g.color[n] = 0xC63A4A
	mode = "game"; K.serif = false; _clear_overlay(); _log_idx = g.log.size()
	map.lenses.refresh_nations(); map.repaint_all()
	var cap := g.capital_of[n]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2 if map.mode == 0 else maxf(map.zoom, 3.0))
	hud.g = g; hud.visible = true; hud.build(); hud.refresh()
	hud.set_seal_pulse(not cfg.get("seal_seen", false))
	_select(-1)
	_autosave()
	var first_run: bool = not cfg.get("tutorial", false)
	if first_run: cfg["tutorial"] = true; _save_cfg()
	TBModals.first_turn(_overlay, g, first_run)                  # tutorial (first game) + briefing; Skip on the tutorial skips both in one tap

# ---------------------------------------------------------------- input
func _on_pick(p: int, secondary: bool) -> void:
	if mode == "mp_lobby":
		mp.pick_province(p); return
	if mode == "pick":
		if _pick_flow != null and is_instance_valid(_pick_flow): _pick_flow.on_map_pick(p)
		return
	if mode != "game" or _busy: return
	flow.g = g
	if p < 0:
		if flow.mode == TBOrderFlow.Mode.PREVIEW: flow.cancel()
		else: _select(-1)
		return
	if flow.pick(p, secondary, map.last_pick_touch): return
	if not secondary: _select(p)

## touch long-press: the same tooltip content as the desktop hover, shown above the finger, released with it
func _on_peek(p: int) -> void:
	if mode != "game" or g == null or p < 0:
		if tip != null: tip.visible = false
		return
	flow.g = g
	tip.show_for(g, p, flow)
	tip.position = (get_local_mouse_position() + Vector2(-tip.size.x * 0.5, -tip.size.y - 40.0)).clamp(Vector2.ZERO, size - tip.size)

## desktop-only hover card (dark plate): flag + place, owner and relation, army and terrain, and in an armed state the attack outcome
func _on_hover(p: int) -> void:
	if mode != "game" or p < 0 or OS.has_feature("mobile") or g == null:
		if tip != null: tip.visible = false
		if flow != null: flow.hover(-1)
		return
	flow.g = g
	flow.hover(p)
	tip.show_for(g, p, flow)
	_place_tip()

func _place_tip() -> void:
	if tip == null or not tip.visible: return
	tip.position = (get_local_mouse_position() + Vector2(18, 20)).clamp(Vector2.ZERO, size - tip.size)

func _select(p: int) -> void:
	selected = p
	map.select(p)
	flow.g = g
	flow.on_select(p)
	panel.show_province(g, p) if p >= 0 else panel.show_province(g, -1)

## the Move verb / M: arm the selected army (own armies become targets too)
func _on_move_requested(p: int) -> void:
	flow.g = g
	flow.arm(p)

## kept for older callers: forget any armed / previewed order
func _set_move_from(p: int) -> void:
	move_from = p
	if p < 0:
		if flow != null: flow.clear()
		hud.hide_preview(); _pv_to = -1

func _goto_province(p: int) -> void:
	map.fly_to(world.lon[p], world.lat[p])
	_select(p)

func _goto_nation(n: int) -> void:
	var cp := g.capital_of[n]
	if cp >= 0:
		map.fly_to(world.lon[cp], world.lat[cp])
		_select(cp)

# ---------------------------------------------------------------- commands
func _on_command(c: Dictionary, from_card: bool = false) -> void:
	if mp.in_game:
		mp.send_command(c); return
	var cmd := c.duplicate(); cmd["n"] = g.human_id
	var res := g.apply(cmd)
	if not res["ok"]:
		if from_card and panel.visible: panel.reject(String(res["err"]))      # the card's reason line replaces the toast
		else:
			var key := "err_" + String(res["err"])
			hud.toast(T.call(key) if TBI18n.has_key(key) else String(res["err"]), true)
	elif String(cmd.get("cmd", "")) in ["decide", "trade", "build", "develop", "hire", "recruit"]:
		sfx.play("coin")
	elif res.has("success"):
		hud.toast(T.call("spy_ok") if res["success"] else T.call("spy_fail"), not res["success"])
	_after_change()

var _pv_to := -1
## how many men a move sends from `from`, following the 25/50/75/100 % choice on the command card
func _troops_for(from: int) -> int:
	return flow.troops_for(from)

## compatibility entry (tests, monkey): order from -> to as the flow would after the source was selected
func _try_move(from: int, to: int) -> void:
	flow.g = g
	flow.src = from
	flow.mode = TBOrderFlow.Mode.ARMED
	var c := flow.check(to)
	if not c["valid"]: _set_move_from(-1); return
	if c["preview"]: flow.preview_to(to)
	else: _do_move(from, to)

func _commit_move(from: int, to: int) -> void:
	flow.clear()
	_do_move(from, to)

func _do_move(from: int, to: int) -> void:
	var tr := _troops_for(from)
	flow.clear()
	if mp.in_game:
		mp.send_command({"cmd": "move", "from": from, "to": to, "troops": tr}); _select(to); return
	var res := g.apply({"cmd": "move", "n": g.human_id, "from": from, "to": to, "troops": tr})
	if not res["ok"]:
		panel.reject(String(res["err"]))
		if g.controller(from) == g.human_id: _select(from)
	else:
		var rs: String = res.get("result", "")
		if rs == "move":
			map.labels.add_fx("march", from, to, TBTokens.c("brass_lt"))
		else:
			var win: bool = rs == "win"
			map.labels.add_fx("atk", from, to, TBTokens.c("pos_bar") if win else TBTokens.c("neg_bar"))
			map.labels.add_fx("cap", from, to, TBTokens.c("pos_bar") if win else TBTokens.c("neg_bar"), 450)
		_select(to)
	_after_change()

var _shown_events := {}
var _hot_n := 0                          # hot-seat: players to pick (0 = not setting one up)
var _hot_list := PackedInt32Array()

func _is_hotseat() -> bool: return g != null and not mp.in_game and g.humans().size() > 1

## prompt the human for any pending event choice addressed to them (SP and MP share this)
func show_events() -> void:
	if g == null or g.human_id == 0: return
	for e in g.pending:
		if int(e["n"]) != g.human_id or _shown_events.has(e["uid"]): continue
		_shown_events[e["uid"]] = true
		sfx.play("event")
		var uid: int = e["uid"]
		TBModals.event_prompt(_overlay, e, func(i: int): _on_command({"cmd": "eventChoice", "uid": uid, "i": i}), g, func(): _defer_event(uid))
		return                      # one at a time; the next shows after this one is answered

## "Decide later": the prompt closes, the event stays pending and waits as an Event chip in the ticker (HUD API defer_event); without it, a toast and a re-prompt after End Turn
func _defer_event(uid: int) -> void:
	if hud.has_method("defer_event"): hud.call("defer_event", uid)
	else:
		hud.toast(T.call("decide_later_toast"))
		hud.end_turn_pressed.connect(func(): _shown_events.erase(uid), CONNECT_ONE_SHOT)
	hud.refresh()
	show_events()

func _after_change() -> void:
	show_events()
	map.repaint(g.take_dirty())
	hud.refresh()
	if selected >= 0: flow.refresh(); panel.rebuild()

# ---------------------------------------------------------------- end turn (worker thread so the UI never freezes)
func end_turn() -> void:
	if mp.in_game:
		mp.end_turn(); return
	if _busy or mode != "game": return
	if _is_hotseat():
		var hs := g.humans()
		var nxt := _next_human(hs)
		if nxt != 0:
			_set_move_from(-1)
			_hot_switch(nxt, false); return
	_busy = true; hud.set_busy(true); _set_move_from(-1); hud.hide_preview(); _pv_to = -1
	if tip != null: tip.visible = false
	_turn_t0 = Time.get_ticks_msec()
	_turn_thread = Thread.new()
	_turn_thread.start(_turn_worker)

## the next living human after the current one in this round (0 = everybody has moved)
func _next_human(hs: PackedInt32Array) -> int:
	var i := hs.find(g.human_id)
	for k in range(i + 1, hs.size()):
		if g.alive[hs[k]] != 0: return hs[k]
	return 0

## hand the device to player n: state changes behind an opaque curtain, revealed on tap
func _hot_switch(n: int, new_round: bool) -> void:
	g.human_id = n
	hud.seat_tag = "P%d" % (g.humans().find(n) + 1)
	_select(-1); _set_move_from(-1)
	map.lenses.refresh_nations(); map.repaint_all()
	var cap := g.capital_of[n]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2 if map.mode == 0 else maxf(map.zoom, 3.0))
	hud.refresh()
	TBModals.pass_device(_overlay, g, n, func(): show_events())

func _turn_worker() -> void:
	var dirty := g.end_turn()
	_turn_done.call_deferred(dirty)

func _turn_done(dirty: PackedInt32Array) -> void:
	_turn_thread.wait_to_finish()
	_busy = false; hud.set_busy(false)
	_turn_ms = Time.get_ticks_msec() - _turn_t0
	var lens := map.lenses.mode
	map.repaint(dirty, lens != "political")
	var hot := _is_hotseat()
	if hot:
		g.human_id = g.humans()[0]
		for h in g.humans():
			if g.alive[h] != 0: g.human_id = h; break
	_flush_log()
	_replay_battles()
	hud.refresh()
	if selected >= 0: flow.refresh(); panel.rebuild()
	if hot and not g.over: _hot_switch(g.human_id, true)
	else: show_events()
	if g.over: sfx.play("win" if g.winner == g.human_id else "alert")
	if g.over: TBModals.game_over(_overlay, g, show_menu)
	else: _autosave()

## replay this turn's battles that involved the player, so AI attacks on (or defences by) the realm are visible
func _replay_battles() -> void:
	var me := g.human_id
	var i := 0
	for b in g.battle_fx:
		if int(b[4]) != me and int(b[3]) != me: continue
		if int(b[3]) == me: continue                      # own attacks already play when ordered; AI-run turns of other humans skip
		var held: bool = int(b[2]) == 0
		var col: Color = TBTokens.c("pos_bar") if held else TBTokens.c("neg_bar")
		map.labels.add_fx("atk", int(b[0]), int(b[1]), col, i * 220)
		map.labels.add_fx("cap", int(b[0]), int(b[1]), col, i * 220 + 250)
		i += 1
		if i >= 8: break
	g.battle_fx.clear()

var _crisis := PackedStringArray()

func _flush_log() -> void:
	var me := g.human_id
	var earned := PackedStringArray()
	while _log_idx < g.log.size():
		var e: Dictionary = g.log[_log_idx]; _log_idx += 1
		earned.append_array(TBHonours.on_log(g, e))
		if not TBChron.toast_worthy(g, e, me): continue
		var tx := TBChron.text(g, e)
		if tx != "":
			hud.report_line(tx, TBChron.is_bad(e, me), TBChron.category(e))
			if String(e["kind"]) == "war" and TBChron.involves(e, me): sfx.play("war")
			elif String(e["kind"]) in ["event", "ruler"]: sfx.play("event")
	earned.append_array(TBHonours.on_state(g))
	if _is_hotseat(): earned.clear()
	for id in TBHonours.record(g, cfg, earned):
		hud.toast("%s: %s" % [T.call("honour_earned"), T.call("honour_" + id)], false)
		sfx.play("event"); _save_cfg()
	hud.report_flush(g.battle_fx.size())            # one Turn report chip instead of a toast per line; crises are alert chips (state-based)
	if g.log.size() > 900:
		g.log = g.log.slice(g.log.size() - 600); _log_idx = g.log.size()

# ---------------------------------------------------------------- persistence
func _save_slot(slot: String) -> void:
	if TBSave.save(g, slot): hud.toast(T.call("saved"))

func _autosave() -> void:
	TBSave.save(g, "auto")

func _load_slot(slot: String) -> void:
	var ng := TBSave.load_game(world, slot)
	if ng == null: return
	g = ng; mode = "game"; K.serif = false; _spin = false; _clear_overlay(); _log_idx = g.log.size()
	map.setup(g); map.repaint_all()
	hud.seat_tag = ""
	hud.g = g; hud.visible = true; hud.build(); hud.refresh()
	var cap := g.capital_of[g.human_id]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2)
	_select(-1)
	if _is_hotseat(): _hot_switch(g.human_id, false)

## phones kill backgrounded apps: save when paused / losing focus
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "game" and g != null and not _busy and not mp.in_game:
			_autosave()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST: _on_back()

var _exit_armed := false

## Android Back / Esc / X share one stack (P-20): tooltip, order, the top panel or dialog, selection, then the menu; the title asks twice before quitting.
## An unanswered event, game over or pass-device curtain swallows Back. HUD / order code may define `_cancel_order_back() -> bool` to take step 2.
func _on_back() -> void:
	var res := TBPanel.pop(_overlay)
	if res == "locked":
		if hud != null and hud.visible: hud.toast(T.call("choose_option"), true)
		return
	if res != "none": return
	var legacy: Node = null                                  # multiplayer dialogs still use the old container
	for c in _overlay.get_children():
		if c is ColorRect and c.has_meta("tb_modal") and not c.is_queued_for_deletion(): legacy = c
	if legacy != null: legacy.queue_free(); return
	if has_method("_cancel_order_back") and bool(call("_cancel_order_back")): return
	match mode:
		"menu":
			if _exit_armed: get_tree().quit(); return
			_exit_armed = true
			_title_toast(T.call("press_back_again"))
			get_tree().create_timer(2.0).timeout.connect(func(): _exit_armed = false)
		"pick":
			if _pick_flow != null and is_instance_valid(_pick_flow) and _pick_flow.pop(): return
			_open_era_picker()
		"mp_lobby": show_menu()
		"game":
			if panel.visible: panel.back()
			else: _open_menu_hub()

func _unhandled_key_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel") and not e.is_echo():
		_on_back(); get_viewport().set_input_as_handled()

## a short slip over the title (the HUD toast is not available there)
func _title_toast(text: String) -> void:
	var pc := PanelContainer.new(); pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_theme_stylebox_override("panel", TBFrame.bar(14, 8))
	var l := K.label(text, 14, TBTokens.c("cream")); pc.add_child(l)
	pc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); pc.grow_horizontal = Control.GROW_DIRECTION_BOTH; pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pc.offset_bottom = -90
	_overlay.add_child(pc)
	get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(pc): pc.queue_free())

func _update_perf(delta: float) -> void:
	if not cfg.get("perf", false):
		if _perf_label != null: _perf_label.visible = false
		return
	if _perf_label == null:
		_perf_label = K.label("", 11, K.GOLD2); _perf_label.add_theme_font_override("font", K.mono())
		_perf_label.set_anchors_preset(Control.PRESET_TOP_RIGHT); _perf_label.offset_left = -620; _perf_label.offset_right = -8; _perf_label.offset_top = 100; _perf_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; _perf_label.z_index = 100
		add_child(_perf_label)
	_perf_label.visible = true
	_perf_t += delta
	if _perf_t < 0.5: return
	_perf_t = 0.0
	var ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	_perf_label.text = "%d fps · frame %.1f ms · map tier %d @%.0f%% · mem %d MB · turn %d ms" % [Engine.get_frames_per_second(), ms, map.quality, map.render_scale * 100.0, OS.get_static_memory_usage() / 1048576, _turn_ms]

func _process(delta: float) -> void:
	_update_perf(delta)
	_place_tip()
	if map.labels != null and map.labels.visible != (mode != "menu"): map.labels.visible = mode != "menu"
	if mode == "menu" and _spin and K.spin_ok():           # Reduce motion: the title globe stays still
		map.lon0 += delta * 0.12
		map._push_view()
		if is_instance_valid(_bezel): _bezel.queue_redraw()

# ---------------------------------------------------------------- multiplayer hooks (called by TBMpController)
func enter_mp_game(game: TBGame, nation: int) -> void:
	g = game; mode = "game"; K.serif = false; _spin = false; _clear_overlay(); _log_idx = g.log.size()
	g.human_id = nation
	map.setup(g); map.repaint_all()
	var cap := g.capital_of[nation]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2)
	hud.g = g; hud.visible = true; hud.build(); hud.refresh(); _select(-1)

func leave_mp() -> void:
	mp.leave()
