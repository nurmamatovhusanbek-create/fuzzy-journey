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
var cfg := {"perf": false, "seal_seen": false, "sound": true, "quality": "auto", "lang": "en", "view": "flat", "difficulty": "normal", "aggression": 1, "tutorial": false, "theme": "standard", "ui": "normal", "honours": {}, "era": "modern", "players": 1, "text_scale": 1.0, "readable": false, "reduce_motion": false, "touch_large": false, "hc": "off", "cvd": "off", "tts": false, "confirm": "risky", "mirror": false, "vis_alerts": false, "vol_master": 80, "vol_music": 80, "vol_sfx": 80, "vol_ui": 80, "comfort_seen": false, "navpad": "auto", "fx": "full", "win": {}}
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
	hud = TBHud.new(); hud.map_view = map; add_child(hud); hud.visible = false; TBBake.watch(hud)
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
	panel.blocked_fn = func() -> bool: return mode != "game" or _modal_open()
	panel.command.connect(func(c: Dictionary): _on_command(c, true)); panel.move_requested.connect(_on_move_requested); panel.closed.connect(func(): _select(-1))
	panel.insp_fn = hud.inspector_rect; panel.sheet_fn = hud.sheet_mode; TBPanel.drawer_rect_fn = hud.drawer_rect
	TBPanel.drawer_opened_fn = func() -> void:
		if hud.exclusive_panels() and panel != null: panel.show_province(g, -1)
	panel.select_requested.connect(func(q: int): _select(q))
	ring = TBMapRing.new(); ring.map = map; add_child(ring)
	ring.avoid_fn = func() -> Array:
		var r: Array = hud.keepouts()
		if panel.visible: r.append(panel.get_global_rect())
		return r
	panel.verbs_ready.connect(func(sp: int, vs: Array): ring.g = g; ring.show_verbs(sp, vs))
	panel.visibility_changed.connect(func(): if not panel.visible: ring.clear())
	ring.pressed.connect(func(i: int): panel._press(i))
	ring.dossier_requested.connect(func(q: int): _open_dossier(q))
	ring.nation_requested.connect(func(n: int): _open_nations(n))
	ring.hovered.connect(func(i: int): panel._set_focus_verb(i))
	tip = TBMapTip.new(); add_child(tip)
	TBMapCursor.install(self)                       # keyboard map cursor + on-screen nav pad (accessibility)
	_overlay = Control.new(); _overlay.set_anchors_preset(Control.PRESET_FULL_RECT); _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.child_entered_tree.connect(func(_c: Node): if hud != null: hud.dismiss_floating())      # a screen or dialog opens: the HUD tooltip / popover goes
	mp = TBMpController.new(); add_child(mp); mp.setup(self)
	hud.end_turn_pressed.connect(func():
		sfx.play("turn"); end_turn()
		if not cfg.get("seal_seen", false): cfg["seal_seen"] = true; _save_cfg(); hud.set_seal_pulse(false))
	hud.tapped.connect(func(): sfx.play("tap"))
	hud.lens_selected.connect(func(n): map.set_lens(n); hud.set_lens_legend(n))
	hud.nations_pressed.connect(func(): if not _toggle_window("nations"): _open_nations())
	hud.goals_pressed.connect(func(): if not _toggle_window("council"): _open_council("goals"))
	hud.decisions_pressed.connect(func(): if not _toggle_window("decrees"): _open_decisions())
	hud.chronicle_pressed.connect(func(): if not _toggle_window("annals"): _open_annals())
	hud.advisor_pressed.connect(func(): if not _toggle_window("council"): _open_council("advice"))
	hud.wars_pressed.connect(func(): _open_nations(-1, "war"))
	panel.nation_requested.connect(_open_nation)
	panel.terms_requested.connect(func(e: int): TBTermsScreen.open(_overlay, g, e, {"on_cmd": func(c: Dictionary): _on_command(c, false)}))
	hud.budget_pressed.connect(func(): if not _toggle_window("treasury"): _open_budget())
	hud.save_pressed.connect(func(): _open_menu_hub("saves"))
	hud.settings_pressed.connect(func(): _open_menu_hub("settings"))
	hud.exit_pressed.connect(show_menu)
	hud.input_blocked_fn = func() -> bool: return mode != "game" or _modal_open()
	hud.mp_waiting_fn = func() -> bool: return mp.in_game
	hud.goto_province.connect(_goto_province)
	hud.nation_pressed.connect(_open_nation)
	hud.realm_pressed.connect(func(): if not _toggle_window("realm"): _open_realm_page())
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

## The UI is laid out in the Bezel demo's design units: a stage 1180 units tall on a desktop (390 on a phone held in landscape), scaled to the window.
## So a number in the demo (a 46 unit medallion, a 22 unit title) is the same number here. cfg "ui" is the demo's S / M / L (taller stage = smaller UI).
func _update_ui_scale() -> void:
	var w := get_window()
	var s := w.size
	var k: float = {"small": 1.18, "normal": 1.0, "large": 0.86}.get(cfg.get("ui", "normal"), 1.0)
	var ppu: float = _px_per_unit(s, k)
	w.content_scale_size = Vector2i(maxi(320, int(round(s.x / ppu))), maxi(240, int(round(s.y / ppu))))
	_apply_safe_area()

## the demo's rule: a phone in landscape (css height < 560 and width < 1300) uses a 390 unit stage, everything else 1180.
## On Android the css size is the window in dp (dpi / 160). TB_UI_SCALE (px per unit) overrides it for tests that emulate a density.
func _px_per_unit(s: Vector2i, k: float = 1.0) -> float:
	var env := OS.get_environment("TB_UI_SCALE")
	if env != "": return clampf(float(env), 0.3, 4.0) / k
	var dpr: float = 1.0
	if OS.get_name() in ["Android", "iOS"]: dpr = clampf(DisplayServer.screen_get_dpi() / 160.0, 1.0, 4.0)
	var vw: float = s.x / dpr; var vh: float = s.y / dpr
	if s.y > s.x: return clampf(s.x / 360.0, 1.0, 3.0) / k                    # portrait: 360 unit wide column
	var phone: bool = vh < 560.0 and vw < 1300.0
	var dh: float = (390.0 if phone else 1180.0) * k
	return s.y / dh

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

## a modal (dialog, menu, pick screen...) is up: the map, the rail and the hotkeys wait. The movable windows (Nations, Budget...) are not modal.
func _modal_open() -> bool:
	for c in _overlay.get_children():
		if c.is_queued_for_deletion() or c.has_meta("tb_closing"): continue
		if c.has_meta("tb_handle") and not (c.get_meta("tb_handle") as TBPanel.Handle).modal: continue
		return true
	return false

## the open Nations window (a non-modal window whose screen key is "nations"), or null
## a rail tab pressed while its window is open closes it (the same press opens and closes); true when it closed one
func _toggle_window(key: String) -> bool:
	for c in _overlay.get_children():
		if c.is_queued_for_deletion() or not c.has_meta("tb_handle"): continue
		var h: TBPanel.Handle = c.get_meta("tb_handle")
		if h.mem_key == key and h.is_open():
			h.close(); return true
	return false

func _nations_window() -> TBPanel.Handle:
	for c in _overlay.get_children():
		if c.is_queued_for_deletion() or not c.has_meta("tb_handle"): continue
		var h: TBPanel.Handle = c.get_meta("tb_handle")
		if h.mem_key == "nations" and h.is_open(): return h
	return null

func _load_cfg() -> void:
	var f := ConfigFile.new()
	if f.load("user://settings.cfg") == OK:
		for k in cfg: cfg[k] = f.get_value("tb", k, cfg[k])
		if bool(f.get_value("tb", "contrast", false)) and cfg["hc"] == "off": cfg["hc"] = "light"          # the old boolean became hc off / light / dark
		if not f.has_section_key("tb", "reduce_motion"): cfg["reduce_motion"] = K.os_prefers_reduced_motion()
		if cfg["win"] is Dictionary: TBPanel.win_mem = cfg["win"]
	else:
		cfg["quality"] = _guess_quality()
		cfg["fx"] = TBFx.default_for(cfg["quality"])
		cfg["reduce_motion"] = K.os_prefers_reduced_motion()

func _save_cfg() -> void:
	cfg["win"] = TBPanel.win_mem
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

## the map's first quality tier by what the machine is: software renderers start low; integrated GPUs and CPUs with four threads or fewer start medium (the auto tier steps
## down further on its own when frames stay slow); phones medium; everything else high
func _guess_quality() -> String:
	if OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS": return "medium"
	var gpu: String = (RenderingServer.get_video_adapter_name() + " " + RenderingServer.get_video_adapter_vendor()).to_lower()
	for soft in ["llvmpipe", "swiftshader", "software", "basic render", "microsoft basic", "softpipe", "vmware", "virtualbox"]:
		if gpu.contains(soft): return "low"
	var integrated: bool = (gpu.contains("intel") and not gpu.contains("arc")) or gpu.contains("uhd") or gpu.contains("iris") or gpu.contains("vega 3") or gpu.contains("vega 6") or gpu.contains("vega 8") or gpu.contains("radeon graphics")
	if integrated or OS.get_processor_count() <= 4: return "medium"
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
var ring: TBMapRing

## everything the game interface needs before it is shown: sans fonts, the Atlas Ledger palette with the player's accent, darker land colours
func _enter_game_visuals() -> void:
	map.grid_k = 1.0
	K.serif = true; TBTokens.legacy = false; TBFrame.rounded = false; TBFrame.bezel = true; TBLenses.dark_land = true
	if g != null and g.human_id > 0: TBTokens.set_accent(g.color[g.human_id])
	theme = K.theme()

## the title's globe: whole inside its ring, sized so the ring clears the tools row (and fits the width in portrait). Also after the view setting changes on the title,
## which must not blow the globe up past the ring. Wide layout: a smaller globe in the middle, the menu beside it
func _fit_title_globe() -> void:
	var vs: Vector2 = size if size.x > 2.0 else get_viewport_rect().size
	var portrait := vs.y > vs.x
	var short: bool = vs.y < 480.0 and not portrait
	var tools_h: float = float(K.touch())
	map.set_mode(0)
	map._fly = {}
	var base: float = minf(vs.x, vs.y) * 0.44
	var r_max: float = ((vs.y * 0.5 - tools_h - 10.0) / 1.103) if not portrait else minf((vs.x - 28.0) * 0.5 / 1.103, (vs.y - tools_h * 2.0 - 30.0) * 0.5 / 1.103)
	if short: r_max = maxf(r_max, 120.0)
	if _title_wide: r_max = vs.y * 0.264
	map.zoom = clampf(r_max / base, 0.3, 1.0); map._push_view()

const TP_ = preload("res://src/ui/title_parts.gd")
var _title_wide := false
var _sel: TP_.SelFrame
var _title_cur: Control

func _title_layout(vs: Vector2) -> bool:
	return vs.y <= vs.x and vs.y >= 640.0 and vs.x >= vs.y * 1.5

## the title: layout B "Orrery" (docs/screens/title_mocks): the globe in its instrument ring, the wordmark and menu at the left, your campaign at the right.
## Portrait and short windows keep the old composition (everything inside the ring) with the same parts.
func show_menu() -> void:
	mode = "menu"; _spin = true; _pick_flow = null; K.serif = true; TBTokens.legacy = false; TBFrame.rounded = false; TBFrame.bezel = true; theme = K.theme()
	TBFx.apply(cfg)
	map.outline_nation(-1)
	map.set_mode(0)                                           # the title is always the globe inside its ring, whatever view the game uses
	if not TBLenses.dark_land:
		TBLenses.dark_land = true
		if map.lenses != null: map.lenses.refresh_nations(); map.repaint_all()
	var vs: Vector2 = size if size.x > 2.0 else get_viewport_rect().size
	var portrait := vs.y > vs.x
	var short: bool = vs.y < 480.0 and not portrait
	var wide: bool = _title_layout(vs)
	_title_wide = wide
	var u: float = vs.y / 720.0 if wide else clampf(minf(vs.y / 800.0, (vs.x - 40.0) / 300.0), 0.7, 1.4)
	map.grid_k = 0.38 if wide else 1.0
	_fit_title_globe()
	hud.visible = false; panel.visible = false; _clear_overlay(); map.labels.visible = false
	var am := TBSave.meta("auto")
	var has_save: bool = not am.is_empty()
	var orr := TP_.Orrery.new(); orr.map = map; orr.wide = wide
	var order: Array = TBNewGame.ERAS.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return TBNewGame.ERA_YEAR[a] < TBNewGame.ERA_YEAR[b])
	for id in order:
		var yy: int = TBNewGame.ERA_YEAR[id]
		orr.eras.append([id, ("%d BC" % -yy) if yy < 0 else str(yy)])
	orr.cur_era = String(am.get("era", cfg.get("era", "modern"))) if has_save else String(cfg.get("era", "modern"))
	_overlay.add_child(orr); _bezel = orr
	# layout: [ scrolling column (wordmark + menu) ] over [ tools row ]; the column scrolls instead of covering anything
	var frame := VBoxContainer.new(); frame.set_anchors_preset(Control.PRESET_FULL_RECT); frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("separation", 0)
	frame.offset_left = 12; frame.offset_right = -12; frame.offset_top = 6; frame.offset_bottom = -6
	_overlay.add_child(frame)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.follow_focus = true; sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(sc)
	var holder: Container
	if wide:
		var mc := MarginContainer.new(); mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mc.add_theme_constant_override("margin_left", int(44.0 * u)); mc.add_theme_constant_override("margin_top", int(56.0 * u))
		holder = mc
	else:
		holder = CenterContainer.new(); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sc.resized.connect(_sync_title_holder.bind(sc, holder))      # centre vertically while it fits, scroll when it does not
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(holder)
	var colw: float = 270.0 * u
	var v := K.vbox(int(2 * u) if short else int(8 * u))
	if wide: v.custom_minimum_size.x = colw; v.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	holder.add_child(v)
	# wordmark: two lines at the left (wide), one centred line otherwise
	var wm: String = T.call("title")
	var wm_font: Font = K.tracked(K.wordmark(), 6 if wide else (2 if (portrait or short) else 4))
	var wm_avail: float = colw * 1.25 if wide else minf(vs.x - 32.0, maxf(220.0, map.radius_px() * 1.56))
	var lines: PackedStringArray = wm.split(" ", false, 1) if wide else PackedStringArray([wm])
	var wm_max: int = int(46.0 * u) if wide else (30 if short else (54 if not portrait else 40))
	var wm_size: int = wm_max
	for ln in lines:
		while wm_size > 14 and wm_font.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, K.fs(wm_size)).x > wm_avail: wm_size -= 1
	var wm_box := VBoxContainer.new(); wm_box.add_theme_constant_override("separation", int(-6.0 * u) if wide else 0); wm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ln in lines:
		var t := K.label(ln, wm_size, TBTokens.c("brass_lt"))
		t.add_theme_font_override("font", wm_font)
		t.add_theme_constant_override("outline_size", 4); t.add_theme_color_override("font_outline_color", TBTokens.ca("table", 0.9))
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER
		t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_SHRINK_CENTER
		wm_box.add_child(t)
	wm_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_SHRINK_CENTER
	v.add_child(wm_box)
	if not short:
		var orn := K.ornament(); orn.col = TBTokens.ca("brass_lt", 0.7); v.add_child(orn)
		var tag := K.caps(T.call("tagline"), int(11.0 * u) if wide else 12, TBTokens.c("smoke")); tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if wide else HORIZONTAL_ALIGNMENT_CENTER; tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.custom_minimum_size.x = 40; tag.add_theme_constant_override("outline_size", 3); tag.add_theme_color_override("font_outline_color", TBTokens.ca("table", 0.9)); v.add_child(tag)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, (88.0 if wide else 14.0) * u); v.add_child(gap)
	# the menu: one big card (Continue, or New game when there is no save) and quiet rows
	var items: Array = []
	var flash := func(cb: Callable) -> Callable:
		return func():
			if _sel != null: _sel.flash()
			cb.call()
	var unreadable: bool = not has_save and FileAccess.file_exists(TBSave.path_for("auto"))
	var card: Control
	if has_save:
		var yr: int = int(am.get("year", 0))
		var era_id: String = String(am.get("era", ""))
		var sub := "%s · %s %d%s" % [String(am.get("nation", "")), T.call("turn"), int(am.get("turn", 0)), (" · " + (("%d BC" % -yr) if yr < 0 else ("%d AD" % yr))) if yr != 0 else ""]
		var flag_tex: Texture2D = null
		if am.has("code"): flag_tex = TBFlags.medal(String(am["code"]), era_id) if TBFlags.medal(String(am["code"]), era_id) != null else TBFlags.texture(String(am["code"]), int(am.get("color", 0x808080)), era_id)
		card = TP_.CardBtn.new(T.call("continue"), sub, flag_tex, "globe", u, flash.call(_title_continue))
	else:
		card = TP_.CardBtn.new(T.call("new_game"), T.call("title_new_sub"), null, "globe", u, flash.call(func(): _open_era_picker()))
	items.append(card)
	v.add_child(card)
	var cg := Control.new(); cg.custom_minimum_size = Vector2(0, 14.0 * u); v.add_child(cg)
	var saves := 0
	for sl in ["auto", "1", "2", "3", "4", "5"]:
		if not TBSave.meta(sl).is_empty(): saves += 1
	var rows: Array = []
	if has_save: rows.append(TP_.RowBtn.new(T.call("new_game"), u, flash.call(func(): _open_era_picker())))
	elif unreadable: rows.append(TP_.RowBtn.new(T.call("continue"), u, Callable(), T.call("autosave_unreadable")))
	var ld := TP_.RowBtn.new(T.call("load"), u, flash.call(func(): _open_menu_hub("saves")), T.call("no_saves_yet") if saves == 0 else "")
	if saves > 0: ld.tooltip_text = T.call("n_saves", {"n": saves})
	rows.append(ld)
	rows.append(TP_.RowBtn.new(T.call("multiplayer"), u, flash.call(func(): mp.open_menu())))
	for r in rows: items.append(r); v.add_child(r)
	for it in items:
		it.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_SHRINK_CENTER
		(it as Control).custom_minimum_size.x = colw
	# the selection bracket, above the menu
	_sel = TP_.SelFrame.new(u); _overlay.add_child(_sel)
	for it in items:
		it.chosen.connect(func(b: Control): _title_cur = b; _sel.go_to(Rect2(b.global_position, b.size)))
	_title_cur = null
	for it in items:
		if not (it as Button).disabled: _title_cur = it; break
	_title_sel_start.call_deferred()
	# your campaign (wide layout, with a save)
	if wide and has_save:
		var era_id2: String = String(am.get("era", ""))
		var ft: Texture2D = null
		if am.has("code"): ft = TBFlags.medal(String(am["code"]), era_id2) if TBFlags.medal(String(am["code"]), era_id2) != null else TBFlags.texture(String(am["code"]), int(am.get("color", 0x808080)), era_id2)
		var yr2: int = int(am.get("year", 0))
		var rname := ""
		if am.has("rk") and String(am.get("rn", "")) != "": rname = "%s %s" % [T.call(String(am["rk"])), TBRulers.name_of(String(am["rn"]), int(am.get("rnum", 0)))]
		var l1: String = ("%s · %s %d" % [rname, T.call("turn"), int(am.get("turn", 0))]) if rname != "" else "%s %d" % [T.call("turn"), int(am.get("turn", 0))]
		var l2: String = ((("%d BC" % -yr2) if yr2 < 0 else ("%d AD" % yr2)) if yr2 != 0 else "") + ((" · " + T.call("era_" + era_id2)) if era_id2 != "" and TBI18n.has_key("era_" + era_id2) else "")
		var cp := TP_.Campaign.new(u, ft, String(am.get("nation", "")), l1, l2, T.call("title_cont_cap"), T.call("title_campaign"))
		cp.position = Vector2(vs.x - 268.0 * u - 52.0 * u, vs.y * 0.40); cp.size = cp.custom_minimum_size
		_overlay.add_child(cp)
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
	if TBPanel.wants_focus() and _title_cur != null:         # keyboard / gamepad cold start: the first enabled entry has focus (Up / Down / Enter / Space)
		_title_cur.grab_focus.call_deferred()

## the bracket takes its place once the menu has been laid out (no glide on the first placement)
func _title_sel_start() -> void:
	await get_tree().process_frame
	if mode == "menu" and _title_cur != null and is_instance_valid(_title_cur) and is_instance_valid(_sel):
		_sel.go_to(Rect2(_title_cur.global_position, _title_cur.size))

## Continue: the autosave opens. With effects on the title dissolves, its ring opens and the globe dives to your capital before the game takes over (any key or click skips);
## with Effects Off it is a plain load.
var _dive: Tween
var _dive_ng: TBGame
var _dive_thread: Thread
var _dive_block: Control

## One continuous move: the menu dissolves while the camera already turns; the ring opens; near the end the game is built underneath a still of the globe, which keeps zooming
## with the camera while it dissolves and the interface fades in. The save is read on a thread meanwhile. The end framing is the game's own (capital at 2.2, or the matching globe zoom).
func _title_continue() -> void:
	var am := TBSave.meta("auto")
	if not TBFx.on(TBFx.LIGHT) or mode != "menu" or _dive != null or not am.has("cap"): _load_slot("auto"); return
	var cap: int = int(am["cap"])
	if cap < 0 or cap >= world.P: _load_slot("auto"); return
	_spin = false
	_dive_thread = Thread.new(); _dive_thread.start(func() -> TBGame: return TBSave.load_game(world, "auto"))
	_dive_block = Control.new(); _dive_block.set_anchors_preset(Control.PRESET_FULL_RECT); _dive_block.mouse_filter = Control.MOUSE_FILTER_STOP; _dive_block.focus_mode = Control.FOCUS_ALL
	_dive_block.gui_input.connect(func(e: InputEvent): if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed): _dive_skip())
	_overlay.add_child(_dive_block); _dive_block.grab_focus()
	var full: bool = TBFx.on(TBFx.FULL)
	var lon_t: float = deg_to_rad(world.lon[cap]); var lat_t: float = clampf(deg_to_rad(world.lat[cap]), -1.45, 1.45)
	var lon_0: float = map.lon0; var lat_0: float = map.lat0; var z_0: float = map.zoom; var gk_0: float = map.grid_k
	# the globe zoom whose scale at the capital equals the flat game's (Mercator stretches by 1/cos(lat))
	var flat_z := 2.2
	var z_end: float = 2.2
	if cfg["view"] != "globe":
		z_end = (map.size.x / TAU * flat_z / maxf(cos(lat_t), 0.3)) / (0.44 * minf(map.size.x, map.size.y))
	var fade_nodes: Array = []
	for c in _overlay.get_children():
		if c != _bezel and c != _dive_block: fade_nodes.append(c)
	var T_SWAP: float = 0.72 if full else 0.55            # fraction of the move at which the game takes over underneath the still
	var st := {"swapped": false, "still": null, "z_s": 1.0, "full": full}
	var zoom_at := func(t: float) -> float:
		var e: float = TBFx.smooth((t - 0.04) / 0.96)
		return z_0 * pow(z_end / z_0, e)
	var secs: float = 1.9 if full else 0.8
	_dive = TBFx.run(self, secs, func(t: float):
		var a: float = 1.0 - TBFx.smooth(t / (0.26 if full else 0.6))
		for n in fade_nodes: if is_instance_valid(n): (n as CanvasItem).modulate.a = a
		if is_instance_valid(_bezel):
			(_bezel as TP_.Orrery).open = TBFx.smooth((t - 0.04) / (0.5 if full else 0.7)); _bezel.queue_redraw()
		var z: float = zoom_at.call(t) if full else 1.0
		if not st["swapped"]:
			if full:
				var e: float = TBFx.smooth((t - 0.04) / 0.96)
				map.lon0 = lon_0 + wrapf(lon_t - lon_0, -PI, PI) * e
				map.lat0 = lerpf(lat_0, lat_t, e)
				map.zoom = z
				map.grid_k = lerpf(gk_0, 1.0, e)
				map._push_view()
			if t >= T_SWAP: st["z_s"] = z; _dive_swap(st)
		else:
			var still: TextureRect = st["still"]
			var k: float = z / float(st["z_s"])
			if is_instance_valid(still):
				still.pivot_offset = still.size * 0.5; still.scale = Vector2(k, k)
				still.modulate.a = 1.0 - TBFx.smooth((t - T_SWAP) / (1.0 - T_SWAP))
			if full:
				if cfg["view"] == "globe": map.zoom = z; map._push_view()
				else: map.jump_to(world.lon[cap], world.lat[cap], flat_z * z / z_end)
			if hud != null: hud.modulate.a = TBFx.smooth((t - T_SWAP - 0.08) / (1.0 - T_SWAP - 0.08)),
		_dive_end.bind(st), TBFx.LIGHT)

func _dive_skip() -> void:
	if _dive == null: return
	_dive.kill(); _dive = null
	_dive_end({"swapped": false})

## the game is built under a still of the title's last frame
func _dive_swap(st: Dictionary) -> void:
	st["swapped"] = true
	var ng: TBGame = _dive_thread.wait_to_finish() if _dive_thread != null else null
	_dive_thread = null
	if ng == null: ng = TBSave.load_game(world, "auto")
	if ng == null: return
	_dive_ng = ng
	var img := get_viewport().get_texture().get_image()
	var tr := TextureRect.new(); tr.texture = ImageTexture.create_from_image(img); tr.set_anchors_preset(Control.PRESET_FULL_RECT); tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_SCALE; tr.z_index = 50
	var cam := Vector3(map.lon0, map.lat0, map.zoom)
	_enter_loaded(ng, false)
	if st.get("full", false):
		if cfg["view"] == "globe": map.lon0 = cam.x; map.lat0 = cam.y; map.zoom = cam.z; map._push_view()
	else: _fly_to_capital(ng)
	add_child(tr); st["still"] = tr
	if hud != null: hud.modulate.a = 0.0

## the move is over (or skipped): make sure the game is up, the camera final and nothing is left over
func _dive_end(st: Dictionary) -> void:
	_dive = null
	if _dive_ng == null:
		var ng: TBGame = _dive_thread.wait_to_finish() if _dive_thread != null else null
		_dive_thread = null
		if ng == null: ng = TBSave.load_game(world, "auto")
		if ng == null: return
		_enter_loaded(ng, true)
	else:
		_fly_to_capital(_dive_ng)
	_dive_ng = null
	for c in get_children():
		if c is TextureRect and c.z_index == 50: c.queue_free()
	if hud != null: hud.modulate.a = 1.0
	if map.grid_k != 1.0: map.grid_k = 1.0; map._push_view()

func _fly_to_capital(ng: TBGame) -> void:
	var cap: int = ng.capital_of[ng.human_id]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2)

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
	var o := {"on_cmd": _on_command, "on_goto": _goto_nation, "on_fly": _fly_to_nation}
	if select > 0: o["select"] = select
	if filter != "": o["filter"] = filter
	if tab != "": o["tab"] = tab
	TBModals.nations_screen(_overlay, g, o)

func _open_nation(n: int) -> void:
	_open_nations(n)
	_fly_to_nation(n)

## a country's name was pressed (a list, a card, a notice): the map turns to it and lights its border, without picking a district
func _fly_to_nation(n: int) -> void:
	if g == null or n <= 0 or n >= g.N1 or mode != "game": return
	var cp: int = g.capital_of[n]
	if cp < 0: return
	map.outline_nation(n)
	map.fly_to(world.lon[cp], world.lat[cp])

func _open_council(tab: String = "") -> void:
	if g != null: TBModals.council(_overlay, g, _goto_province, tab, _open_screen)

## the council's buttons open the other screens by name
func _open_screen(k: String) -> void:
	match k:
		"nations": _open_nations()
		"budget": _open_budget()
		"decrees": _open_decisions()

func _open_dossier(p: int) -> void:
	if g != null: TBDossier.open(_overlay, g, p, func(c: Dictionary): _on_command(c, false))

## the crest: your own country's page (standing, treasury, court, treaties)
func _open_realm_page() -> void:
	if g != null: TBRealmScreen.open(_overlay, g, {"on_nation": _open_nation})

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

var _game_menu: TBGameMenu
## the gear: the demo's popover (resume / save / load / settings / main menu / interface size); the full screens open from it
func _open_game_menu() -> void:
	if is_instance_valid(_game_menu):
		_game_menu.queue_free(); _game_menu = null; return
	var ver := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges().trim_prefix("v")
	var vs := get_viewport_rect().size
	_game_menu = TBGameMenu.new()
	_overlay.add_child(_game_menu)
	_game_menu.setup(String(cfg.get("ui", "normal")), "build %s · %s %d×%d" % [ver if ver != "" else "10", "phone" if K.is_phone(self) else "desktop", int(vs.x), int(vs.y)])
	_game_menu.picked.connect(_on_game_menu_pick)
	_game_menu.size_picked.connect(func(k: String):
		cfg["ui"] = k; _save_cfg(); _on_setting_changed("ui")
		if is_instance_valid(_game_menu): _game_menu.queue_free(); _game_menu = null
		_open_game_menu.call_deferred())

func _on_game_menu_pick(id: String) -> void:
	if is_instance_valid(_game_menu): _game_menu.queue_free()
	_game_menu = null
	if id == "save" or id == "load": _open_menu_hub("saves")
	elif id == "settings": _open_menu_hub("settings")
	elif id == "main": show_menu()

## kit setting (off | risky | all) -> HUD / card wording (never | smart | always)
func _confirm_mode() -> String:
	return {"off": "never", "risky": "smart", "all": "always"}.get(K.confirm, "smart")

## apply the accessibility settings to the kit (text size, fonts, contrast, motion, targets) and refresh the theme
func _apply_a11y() -> void:
	TBFx.apply(cfg)
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
			_apply_quality(); _update_ui_scale()
			if mode == "menu": _fit_title_globe()                      # the title is always the globe in its ring: the view setting only counts in a game
			else: map.set_mode(0 if cfg["view"] == "globe" else 1)
		"sound": sfx.enabled = cfg.get("sound", true); _apply_a11y()
		"vol_master", "vol_music", "vol_sfx", "vol_ui": TBAudio.apply_volumes(cfg)
		"fx": TBFx.apply(cfg)
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
	lines.append("lang=%s view=%s theme=%s ui=%s fx=%s reduce_motion=%s" % [cfg.get("lang", ""), cfg.get("view", ""), cfg.get("theme", ""), cfg.get("ui", ""), cfg.get("fx", ""), cfg.get("reduce_motion", false)])
	_store_diagnostics(lines)
	if mode == "game" and map != null and map.is_visible_in_tree(): _diag_bench(lines)       # a few seconds later the same text is copied again with the measurements

func _store_diagnostics(lines: PackedStringArray) -> void:
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	var f := FileAccess.open("user://diagnostics.txt", FileAccess.WRITE)
	if f != null: f.store_string(text); f.close()

## what this machine does with the map: the time of a frame that redraws nothing new, of one that redraws the whole map, and of one that redraws a hover-sized part of it
func _diag_bench(lines: PackedStringArray) -> void:
	lines.append("bench: measuring (about 3 seconds, the map flickers once)")
	_store_diagnostics(lines)
	lines.remove_at(lines.size() - 1)
	await get_tree().process_frame
	var base: Array = []; var full: Array = []; var part: Array = []
	for round_i in 3:
		for kind in 3:
			for i in 8:
				if kind == 1:
					map._rend_sig = []; map._push_view()
				elif kind == 2:
					map._pend_full = false
					map._partial_redraw(Rect2(map.size * 0.4, map.size * 0.2))
				else:
					queue_redraw()
				var t0 := Time.get_ticks_usec()
				await RenderingServer.frame_post_draw
				RenderingServer.force_sync()
				var ms := float(Time.get_ticks_usec() - t0) / 1000.0
				if i >= 2: [base, full, part][kind].append(ms)
	for a in [base, full, part]: (a as Array).sort()
	lines.append("bench (ms, median of %d): frame with no map change %.1f | whole map redrawn %.1f | a hover-sized part redrawn %.1f | map redraws so far: %d whole, %d partial" % [base.size(), base[base.size() / 2], full[full.size() / 2], part[part.size() / 2], map.full_redraws, map.partial_redraws])
	map._rend_sig = []; map._push_view()
	_store_diagnostics(lines)

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
	TBFlags.cur_era = String(era.get("id", ""))
	g = TBGame.new(world, era, {"seed": (int(OS.get_environment("TB_SEED")) if OS.get_environment("TB_SEED") != "" else int(Time.get_unix_time_from_system()) & 0x7fffffff | 1), "difficulty": difficulty, "aggression": int(cfg.get("aggression", 1))})
	TBLenses.dark_land = true
	map.setup(g)
	mode = "pick"; _spin = false; _enter_game_visuals()
	TBLenses.dark_land = true
	map.set_mode(0 if cfg["view"] == "globe" else 1)
	_show_pick()

var _pick_flow: TBPickFlow

## the nation-pick overlay (back, instruction slip, shortlist rail, confirm card); rebuilt after every hot-seat pick
func _show_pick() -> void:
	_clear_overlay()
	_pick_flow = TBPickFlow.new().setup(g, map, _hot_n, _hot_list)
	_pick_flow.play.connect(_confirm_pick)
	_pick_flow.aggression_changed.connect(func(l: int): cfg["aggression"] = l; _save_cfg())
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

static func g_era(game: TBGame) -> String: return game.era_id if game != null and game.era_id != "modern" else ""

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
	mode = "game"; _enter_game_visuals(); _clear_overlay(); _log_idx = g.log.size()
	TBLenses.dark_land = true
	map.set_mode(0 if cfg["view"] == "globe" else 1)
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
	if p >= 0 and not secondary and flow.mode == TBOrderFlow.Mode.IDLE and _nations_window() != null and g.owner[p] > 0:   # the Nations window is open: a country on the map shows its card
		_open_nations(g.owner[p]); return
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
	tip.show_for(g, p, flow, flow.mode == TBOrderFlow.Mode.IDLE and not map.district_zoom())
	tip.position = (get_local_mouse_position() + Vector2(-tip.size.x * 0.5, -tip.size.y - 40.0)).clamp(Vector2.ZERO, size - tip.size)

## desktop-only hover card (dark plate): flag + place, owner and relation, army and terrain, and in an armed state the attack outcome
func _on_hover(p: int) -> void:
	if mode != "game" or p < 0 or OS.has_feature("mobile") or g == null:
		if tip != null: tip.visible = false
		if flow != null: flow.hover(-1)
		return
	flow.g = g
	flow.hover(p)
	tip.show_for(g, p, flow, flow.mode == TBOrderFlow.Mode.IDLE and not map.district_zoom())
	_place_tip()

func _place_tip() -> void:
	if tip == null or not tip.visible: return
	tip.position = (get_local_mouse_position() + Vector2(18, 20)).clamp(Vector2.ZERO, size - tip.size)

func _select(p: int) -> void:
	selected = p
	map.select(p)
	map.outline_nation(g.owner[p] if (p >= 0 and g != null and g.human_id != 0 and g.owner[p] != 0) else -1)       # AoC: the owner's border lights up in brass
	flow.g = g
	flow.on_select(p)
	if p >= 0 and hud.exclusive_panels() and not hud.sheet_mode(): TBPanel.close_drawers(_overlay)       # 700-1099 px: the drawer and the inspector never share the width
	panel.show_province(g, p) if p >= 0 else panel.show_province(g, -1)
	ring.g = g; ring.set_selection(p)

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
		mp.send_command(TBAsks.wrap(g, c)); return
	var cmd := TBAsks.wrap(g, c.duplicate()); cmd["n"] = g.human_id
	var res := g.apply(cmd)
	if not res["ok"]:
		if from_card and panel.visible: panel.reject(String(res["err"]))      # the card's reason line replaces the toast
		else:
			var key := "err_" + String(res["err"])
			hud.toast(T.call(key) if TBI18n.has_key(key) else String(res["err"]), true)
	elif String(cmd.get("cmd", "")) in ["hire", "recruit"]:                          # the men stand in the district where they were raised: say which, ready to be marched where you need them
		sfx.play("coin")
		var rp: int = int(cmd.get("p", -1))
		if rp >= 0 and rp < g.P:
			hud.toast(T.call("recruit_done", {"k": int(cmd.get("amount", 15)), "p": TBI18n.place(g.world.name[rp])}))
			map.labels.add_fx("cap", rp, rp, TBTokens.c("pos_bar"))
	elif String(cmd.get("cmd", "")) in ["decide", "trade", "build", "develop", "demolish"]:
		sfx.play("coin")
	elif String(cmd.get("cmd", "")) == "ask":
		hud.toast(T.call("ask_sent", {"a": g.dname(int(cmd["t"]))}))
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
	var a0: int = g.army[from]; var d0: int = g.army[to]
	var res := g.apply({"cmd": "move", "n": g.human_id, "from": from, "to": to, "troops": tr})
	if not res["ok"]:
		panel.reject(String(res["err"]))
		if g.controller(from) == g.human_id: _select(from)
	else:
		var rs: String = res.get("result", "")
		var at: int = int(res.get("at", -1))
		if rs == "march":                                                     # a long march: the army has taken its first stride, the rest is a standing order
			var step_to: int = at if at >= 0 else to
			map.labels.add_fx("march", from, step_to, TBTokens.c("brass_lt"))
			_select(step_to)
			_after_change()
			return
		if rs == "move":
			map.labels.add_fx("march", from, to, TBTokens.c("brass_lt"))
		else:
			var win: bool = rs == "win"
			map.labels.add_fx("atk", from, to, TBTokens.c("pos_bar") if win else TBTokens.c("neg_bar"))
			map.labels.add_fx("cap", from, to, TBTokens.c("pos_bar") if win else TBTokens.c("neg_bar"), 450)
			var send: int = maxi(1, mini(tr if tr != 0 else a0 - 1, a0 - 1))
			TBModals.battle_report(_overlay, {"win": win, "name": TBI18n.place(world.name[to]), "claimed": win and g.owner[to] == g.human_id,
				"my_loss": (send - g.army[to]) if win else (a0 - g.army[from]), "foe_loss": d0 if win else d0 - g.army[to], "left": g.army[to]})
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
	else: _autosave_soon()

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
	# the strides of your own standing march orders: a march arrow for each, and the fight where one reached an enemy
	var si := 0
	for m in g.march_fx:
		if int(m[3]) != me or si >= 10: continue
		var rs2: String = m[2]
		if rs2 == "march" or rs2 == "move":
			map.labels.add_fx("march", int(m[0]), int(m[1]), TBTokens.c("brass_lt"), si * 120)
		elif not rs2.begins_with("!"):
			var won: bool = rs2 == "win"
			map.labels.add_fx("atk", int(m[0]), int(m[1]), TBTokens.c("pos_bar") if won else TBTokens.c("neg_bar"), si * 220)
			map.labels.add_fx("cap", int(m[0]), int(m[1]), TBTokens.c("pos_bar") if won else TBTokens.c("neg_bar"), si * 220 + 250)
		si += 1
	g.march_fx.clear()
	# the marches of other nations that are in sight (fog of war): a faint arrow for each, so you see an army coming before it arrives
	var k := 0
	TBVision.sync(g)
	for m in g.move_fx:
		if int(m[2]) == me or k >= 14: continue
		if not (TBVision.sees_fast(g, int(m[0])) or TBVision.sees_fast(g, int(m[1]))): continue
		var c := Color.hex((g.color[int(m[2])] << 8) | 0xFF).lightened(0.25)
		map.labels.add_fx("march", int(m[0]), int(m[1]), c, k * 90)
		k += 1
	g.move_fx.clear()

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

## the autosave (serialising the whole game and writing the file) waits a few frames so the new turn appears first; skipped when another turn already started
func _autosave_soon() -> void:
	var t := g.turn
	get_tree().create_timer(0.35).timeout.connect(func(): if g != null and not _busy and mode == "game" and g.turn == t: _autosave())

func _autosave() -> void:
	TBSave.save(g, "auto")

func _load_slot(slot: String) -> void:
	var ng := TBSave.load_game(world, slot)
	if ng == null: return
	_enter_loaded(ng, true)

## put a loaded game on screen (the title's Continue dive passes fly = false and steers the camera itself)
func _enter_loaded(ng: TBGame, fly: bool) -> void:
	if _dive_block != null and is_instance_valid(_dive_block): _dive_block.queue_free()
	_dive_block = null
	TBFlags.cur_era = g_era(ng)
	g = ng; mode = "game"; _enter_game_visuals(); _spin = false; _clear_overlay(); _log_idx = g.log.size()
	TBLenses.dark_land = true
	map.set_mode(0 if cfg["view"] == "globe" else 1)
	TBLenses.dark_land = true
	map.setup(g); map.repaint_all()
	hud.seat_tag = ""
	hud.g = g; hud.visible = true; hud.build(); hud.refresh()
	if fly: _fly_to_capital(g)
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
			else: _open_game_menu()

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
	TBFlags.cur_era = g_era(game)
	g = game; mode = "game"; _enter_game_visuals(); _spin = false; _clear_overlay(); _log_idx = g.log.size()
	TBLenses.dark_land = true
	map.set_mode(0 if cfg["view"] == "globe" else 1)
	g.human_id = nation
	TBLenses.dark_land = true
	map.setup(g); map.repaint_all()
	var cap := g.capital_of[nation]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2)
	hud.g = g; hud.visible = true; hud.build(); hud.refresh(); _select(-1)

func leave_mp() -> void:
	mp.leave()
