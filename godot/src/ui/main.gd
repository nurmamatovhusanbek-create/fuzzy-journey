## App root: screen flow (menu -> era -> pick nation -> game), input routing, async end-turn, persistence.
extends Control

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

var world: TBWorld
var g: TBGame
var map: TBMapView
var hud: TBHud
var panel: TBProvincePanel
var mode := "boot"             # menu | pick | game
var selected := -1
var move_from := -1
var cfg := {"sound": true, "quality": "auto", "lang": "en", "view": "globe", "difficulty": "normal", "tutorial": false, "theme": "standard", "ui": "normal"}
var _overlay: Control          # screens/modals live here
var _turn_thread: Thread
var _busy := false
var _log_idx := 0
var _spin := true
var mp: TBMpController
var sfx: TBAudio

func _ready() -> void:
	theme = K.theme()
	_load_cfg()
	TBI18n.load_lang(cfg["lang"])
	world = TBWorld.load_from("res://data")
	map = TBMapView.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	map.province_picked.connect(_on_pick)
	map.province_hovered.connect(_on_hover)
	map.performance_low.connect(_on_perf_low)
	sfx = TBAudio.new(); add_child(sfx); sfx.enabled = cfg.get("sound", true)
	hud = TBHud.new(); add_child(hud); hud.visible = false
	panel = TBProvincePanel.new(); add_child(panel)
	panel.command.connect(_on_command); panel.move_requested.connect(_on_move_requested); panel.closed.connect(func(): _select(-1))
	_overlay = Control.new(); _overlay.set_anchors_preset(Control.PRESET_FULL_RECT); _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	mp = TBMpController.new(); add_child(mp); mp.setup(self)
	hud.end_turn_pressed.connect(func(): sfx.play("turn"); end_turn())
	hud.tapped.connect(func(): sfx.play("tap"))
	hud.lens_selected.connect(func(n): map.set_lens(n); hud.set_lens_legend(n))
	hud.nations_pressed.connect(func(): TBModals.nations(_overlay, g, _open_nation))
	hud.goals_pressed.connect(func(): TBModals.goals(_overlay, g))
	hud.decisions_pressed.connect(func(): TBModals.decisions(_overlay, g, _on_command))
	hud.chronicle_pressed.connect(func(): TBModals.chronicle(_overlay, g, _goto_province))
	hud.advisor_pressed.connect(func(): TBModals.advisor(_overlay, g, _goto_province))
	hud.wars_pressed.connect(func(): TBModals.nations(_overlay, g, _open_nation, true))
	panel.nation_requested.connect(_open_nation)
	hud.budget_pressed.connect(func(): TBModals.budget(_overlay, g, func(): hud.refresh()))
	hud.save_pressed.connect(func(): TBModals.save_load(_overlay, true, _save_slot, _load_slot))
	hud.settings_pressed.connect(_open_settings)
	resized.connect(func(): panel.layout_for(size); hud.layout_for(size))
	get_window().size_changed.connect(_update_ui_scale); _update_ui_scale()
	_apply_quality()
	_new_demo_game()
	show_menu()
	panel.layout_for(size)

## phones in portrait need a different logical base size, otherwise the landscape 1280x720 base shrinks the UI to a few px
func _update_ui_scale() -> void:
	var w := get_window()
	var s := w.size
	var k: float = {"small": 1.18, "normal": 1.0, "large": 0.84}.get(cfg.get("ui", "normal"), 1.0)      # bigger logical size = smaller UI
	var base := Vector2(540, 960) if s.y > s.x else Vector2(1280, 720)
	w.content_scale_size = Vector2i(int(base.x * k), int(base.y * k))
	_apply_safe_area()

## keep UI clear of notches / rounded corners / gesture bars on phones
func _apply_safe_area() -> void:
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
	else:
		cfg["quality"] = _guess_quality()

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
	map.map_theme = 1 if cfg.get("theme", "standard") == "parchment" else 0
	map.render_scale = [0.6, 0.85, 1.0][q]      # fraction of logical resolution the map shader renders at
	map._push_view()

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
	mode = "menu"; _spin = true
	hud.visible = false; panel.visible = false; _clear_overlay(); map.labels.visible = false
	var bez := MP_.Bezel.new(); bez.map = map; _overlay.add_child(bez); _bezel = bez
	var holder := CenterContainer.new(); holder.set_anchors_preset(Control.PRESET_FULL_RECT); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(holder)
	var v := K.vbox(2)
	v.custom_minimum_size = Vector2(380, 0)
	holder.add_child(v)
	var portrait := size.y > size.x
	var t := K.label(T.call("title"), 54 if not portrait else 38, K.GOLD2)
	t.add_theme_font_override("font", K.tracked(K.display_hi(), 4 if not portrait else 2))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75)); t.add_theme_constant_override("shadow_offset_y", 2); t.add_theme_constant_override("shadow_offset_x", 0); t.add_theme_constant_override("shadow_outline_size", 5)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	v.add_child(K.ornament())
	var tag := K.caps(T.call("tagline"), 11, K.TEXT); tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tag)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 18); v.add_child(gap)
	v.add_child(MP_.Entry.new(T.call("new_game"), true, _open_era_picker))
	if not TBSave.meta("auto").is_empty(): v.add_child(MP_.Entry.new(T.call("continue"), false, func(): _load_slot("auto")))
	v.add_child(MP_.Entry.new(T.call("load"), false, func(): TBModals.save_load(_overlay, false, _save_slot, _load_slot)))
	v.add_child(MP_.Entry.new(T.call("multiplayer"), false, func(): mp.open_menu()))
	v.add_child(MP_.Entry.new(T.call("settings"), false, _open_settings))
	var gap2 := Control.new(); gap2.custom_minimum_size = Vector2(0, 10); v.add_child(gap2)
	var ver := K.caps("terra bellum · godot build", 9, K.DIM); ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ver)

func _open_settings() -> void:
	var prev_lang: String = TBI18n.lang
	TBModals.settings(_overlay, cfg, func():
		_save_cfg(); TBI18n.load_lang(cfg["lang"]); _apply_quality(); _update_ui_scale(); sfx.enabled = cfg.get("sound", true)
		map.set_mode(0 if cfg["view"] == "globe" else 1)
		if TBI18n.lang != prev_lang:          # re-create already-built screens in the new language
			prev_lang = TBI18n.lang
			if mode == "game": hud.build(); hud.refresh(); if selected >= 0: panel.rebuild()
			elif mode == "menu": show_menu(), func(): show_menu() if mode == "game" else Callable())

func _open_era_picker() -> void:
	_clear_overlay(); _spin = false
	TBModals.era_picker(_overlay, cfg["difficulty"], _begin_pick, show_menu)

func _begin_pick(era_id: String, difficulty: String) -> void:
	cfg["difficulty"] = difficulty; _save_cfg()
	var era := TBWorld.load_era("res://data", era_id) if era_id != "modern" else {}
	g = TBGame.new(world, era, {"seed": int(Time.get_unix_time_from_system()) & 0x7fffffff | 1, "difficulty": difficulty})
	map.setup(g)
	mode = "pick"; _spin = false; _clear_overlay()
	var hint_box := VBoxContainer.new(); hint_box.set_anchors_preset(Control.PRESET_CENTER_TOP); hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.custom_minimum_size = Vector2(360, 0); hint_box.offset_left = -180; hint_box.offset_right = 180; hint_box.offset_top = 16
	var hint := K.title(T.call("pick_nation"), 17); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint_box.add_child(hint); hint_box.add_child(K.ornament())
	_overlay.add_child(hint_box)
	_add_pick_buttons()

func _add_pick_buttons() -> void:
	_overlay.add_child(_back_btn())
	var lb := K.button(T.call("nations"), func(): TBModals.nations(_overlay, g, func(n: int): _pick_nation_from_list(n), false, false))
	lb.anchor_left = 1.0; lb.anchor_right = 1.0; lb.offset_left = -150; lb.offset_right = -10; lb.offset_top = 10
	_overlay.add_child(lb)

func _pick_nation_from_list(n: int) -> void:
	var cap := g.capital_of[n]
	if cap < 0: cap = g.owned(n)[0]
	map.fly_to(world.lon[cap], world.lat[cap], 2.4 if map.mode == 0 else maxf(map.zoom, 3.0))
	_on_pick(cap, false)

func _back_btn() -> Button:
	var b := K.button(T.call("back"), func(): show_menu()); b.position = Vector2(10, 10); return b

func _start_game(n: int) -> void:
	g.set_human(n); g.color[n] = 0xC63A4A
	mode = "game"; _clear_overlay(); _log_idx = g.log.size()
	map.lenses.refresh_nations(); map.repaint_all()
	var cap := g.capital_of[n]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2 if map.mode == 0 else maxf(map.zoom, 3.0))
	hud.g = g; hud.visible = true; hud.build(); hud.refresh()
	_select(-1)
	_autosave()
	if not cfg.get("tutorial", false):
		cfg["tutorial"] = true; _save_cfg()
		TBModals.tutorial(_overlay, func(): pass)

# ---------------------------------------------------------------- input
func _on_pick(p: int, secondary: bool) -> void:
	if mode == "mp_lobby":
		mp.pick_province(p); return
	if mode == "pick":
		if p < 0 or g.owner[p] == 0: return
		var n := g.owner[p]
		map.select(p)
		_clear_overlay()
		_add_pick_buttons()
		var m := K.modal(_overlay, g.dname(n), 380, "flag")
		m[0].color = Color(0, 0, 0, 0)
		m[1].add_child(K.label("%d %s" % [g.own_count(n), T.call("lands").to_lower()], 14, K.DIM))
		var row := K.hbox(8); m[1].add_child(row)
		row.add_child(K.button(T.call("back"), func(): m[0].queue_free()))
		var go := K.button(T.call("play_as", {"nation": g.dname(n)}), func(): _start_game(n), true); go.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(go)
		return
	if mode != "game" or _busy: return
	if p < 0: _select(-1); return
	if secondary and selected >= 0 and g.controller(selected) == g.human_id: _do_move(selected, p); return
	if move_from >= 0:
		var f := move_from; _set_move_from(-1); _do_move(f, p); return
	_select(p)

var _tip: PanelContainer
var _tip_label: Label
## desktop-only hover tooltip: province, owner, army
func _on_hover(p: int) -> void:
	if mode != "game" or p < 0 or OS.has_feature("mobile"):
		if _tip != null: _tip.visible = false
		return
	if _tip == null:
		_tip = PanelContainer.new(); _tip.mouse_filter = Control.MOUSE_FILTER_IGNORE; _tip.z_index = 50
		_tip_label = K.label("", 13); _tip.add_child(_tip_label); add_child(_tip)
	var o := g.owner[p]
	_tip_label.text = "%s — %s  (%s %s)" % [world.name[p], g.dname(o) if o != 0 else T.call("neutral"), T.call("army"), K.fmt(g.army[p])]
	_tip.visible = true
	_tip.reset_size()
	_tip.position = (get_local_mouse_position() + Vector2(16, 18)).clamp(Vector2.ZERO, size - _tip.size)

func _select(p: int) -> void:
	selected = p
	map.select(p)
	panel.show_province(g, p) if p >= 0 else panel.show_province(g, -1)

func _on_move_requested(p: int) -> void:
	_set_move_from(p)
	hud.toast(T.call("move") + " ▸")

## highlight where the selected army may go (adjacent land, or sea hops from ports)
func _set_move_from(p: int) -> void:
	move_from = p
	var t := PackedInt32Array()
	if p >= 0:
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			if g.nb_sea[e] != 0 and g.building[p] != TBData.B_PORT: continue
			t.append(g.nb[e])
	map.set_targets(t)

func _open_nation(n: int) -> void:
	TBModals.nation_detail(_overlay, g, n, _on_command, _goto_nation)

func _goto_province(p: int) -> void:
	map.fly_to(world.lon[p], world.lat[p])
	_select(p)

func _goto_nation(n: int) -> void:
	var cp := g.capital_of[n]
	if cp >= 0:
		map.fly_to(world.lon[cp], world.lat[cp])
		_select(cp)

# ---------------------------------------------------------------- commands
func _on_command(c: Dictionary) -> void:
	if mp.in_game:
		mp.send_command(c); return
	var cmd := c.duplicate(); cmd["n"] = g.human_id
	var res := g.apply(cmd)
	if not res["ok"]:
		var key := "err_" + String(res["err"])
		hud.toast(T.call(key) if TBI18n.has_key(key) else String(res["err"]), true)
	elif String(cmd.get("cmd", "")) in ["decide", "trade", "build", "develop", "hire", "recruit"]:
		sfx.play("coin")
	elif res.has("success"):
		hud.toast(T.call("spy_ok") if res["success"] else T.call("spy_fail"), not res["success"])
	_after_change()

func _do_move(from: int, to: int) -> void:
	if mp.in_game:
		mp.send_command({"cmd": "move", "from": from, "to": to, "troops": g.army[from] - 1}); _select(to); return
	var res := g.apply({"cmd": "move", "n": g.human_id, "from": from, "to": to, "troops": g.army[from] - 1})
	if not res["ok"]:
		var key := "err_" + String(res["err"])
		hud.toast(T.call(key) if TBI18n.has_key(key) else String(res["err"]), true)
	else:
		var win: bool = res.get("result", "") == "win"
		map.labels.add_fx("atk", from, to, Color(0.5, 0.9, 0.55) if win else Color(1.0, 0.55, 0.5))
		if win: map.labels.add_fx("cap", from, to, Color(0.5, 0.9, 0.55))
		_select(to)
	_after_change()

var _shown_events := {}

## prompt the human for any pending event choice addressed to them (SP and MP share this)
func show_events() -> void:
	if g == null or g.human_id == 0: return
	for e in g.pending:
		if int(e["n"]) != g.human_id or _shown_events.has(e["uid"]): continue
		_shown_events[e["uid"]] = true
		sfx.play("event")
		var uid: int = e["uid"]
		TBModals.event_prompt(_overlay, e, func(i: int): _on_command({"cmd": "eventChoice", "uid": uid, "i": i}))
		return                      # one at a time; the next shows after this one is answered

func _after_change() -> void:
	show_events()
	map.repaint(g.take_dirty())
	hud.refresh()
	if selected >= 0: panel.rebuild()

# ---------------------------------------------------------------- end turn (worker thread so the UI never freezes)
func end_turn() -> void:
	if mp.in_game:
		mp.end_turn(); return
	if _busy or mode != "game": return
	_busy = true; hud.set_busy(true); _set_move_from(-1)
	_turn_thread = Thread.new()
	_turn_thread.start(_turn_worker)

func _turn_worker() -> void:
	var dirty := g.end_turn()
	_turn_done.call_deferred(dirty)

func _turn_done(dirty: PackedInt32Array) -> void:
	_turn_thread.wait_to_finish()
	_busy = false; hud.set_busy(false)
	var lens := map.lenses.mode
	map.repaint(dirty, lens != "political")
	_flush_log()
	hud.refresh()
	if selected >= 0: panel.rebuild()
	show_events()
	if g.over: sfx.play("win" if g.winner == g.human_id else "alert")
	if g.over: TBModals.game_over(_overlay, g, show_menu)
	else: _autosave()

var _crisis := PackedStringArray()

func _flush_log() -> void:
	var me := g.human_id
	while _log_idx < g.log.size():
		var e: Dictionary = g.log[_log_idx]; _log_idx += 1
		if not TBChron.toast_worthy(g, e, me): continue
		var tx := TBChron.text(g, e)
		if tx != "":
			hud.toast(tx, TBChron.is_bad(e, me))
			if String(e["kind"]) == "war" and TBChron.involves(e, me): sfx.play("war")
			elif String(e["kind"]) in ["event", "ruler"]: sfx.play("event")
	# new crises (since last turn) get an advisor toast
	var al := TBAdvisor.alerts(g, me)
	var now := TBAdvisor.crisis_ids(al)
	for a in al:
		if a["sev"] == 2 and not _crisis.has(a["id"]):
			hud.toast(T.call("al_" + String(a["id"]), {"k": int(a["k"]), "r": "%.1f" % (int(a["k"]) / 10.0)}), true)
	_crisis = now
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
	g = ng; mode = "game"; _spin = false; _clear_overlay(); _log_idx = g.log.size()
	map.setup(g); map.repaint_all()
	hud.g = g; hud.visible = true; hud.build(); hud.refresh()
	var cap := g.capital_of[g.human_id]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2)
	_select(-1)

## phones kill backgrounded apps: save when paused / losing focus
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if mode == "game" and g != null and not _busy and not mp.in_game:
			_autosave()

func _process(delta: float) -> void:
	if map.labels != null and map.labels.visible != (mode != "menu"): map.labels.visible = mode != "menu"
	if mode == "menu" and _spin:
		map.lon0 += delta * 0.12
		map._push_view()
		if is_instance_valid(_bezel): _bezel.queue_redraw()

# ---------------------------------------------------------------- multiplayer hooks (called by TBMpController)
func enter_mp_game(game: TBGame, nation: int) -> void:
	g = game; mode = "game"; _spin = false; _clear_overlay(); _log_idx = g.log.size()
	g.human_id = nation
	map.setup(g); map.repaint_all()
	var cap := g.capital_of[nation]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2)
	hud.g = g; hud.visible = true; hud.build(); hud.refresh(); _select(-1)

func leave_mp() -> void:
	mp.leave()
