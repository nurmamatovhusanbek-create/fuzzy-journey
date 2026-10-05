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
var cfg := {"quality": "medium", "lang": "en", "view": "globe", "difficulty": "normal", "tutorial": false}
var _overlay: Control          # screens/modals live here
var _turn_thread: Thread
var _busy := false
var _log_idx := 0
var _spin := true
var mp: TBMpController

func _ready() -> void:
	theme = K.theme()
	_load_cfg()
	TBI18n.load_lang(cfg["lang"])
	world = TBWorld.load_from("res://data")
	map = TBMapView.new()
	map.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(map)
	map.province_picked.connect(_on_pick)
	hud = TBHud.new(); add_child(hud); hud.visible = false
	panel = TBProvincePanel.new(); add_child(panel)
	panel.command.connect(_on_command); panel.move_requested.connect(_on_move_requested); panel.closed.connect(func(): _select(-1))
	_overlay = Control.new(); _overlay.set_anchors_preset(Control.PRESET_FULL_RECT); _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	mp = TBMpController.new(); add_child(mp); mp.setup(self)
	hud.end_turn_pressed.connect(end_turn)
	hud.lens_selected.connect(func(n): map.set_lens(n))
	hud.nations_pressed.connect(func(): TBModals.nations(_overlay, g, _open_nation))
	hud.wars_pressed.connect(func(): TBModals.nations(_overlay, g, _open_nation, true))
	panel.nation_requested.connect(_open_nation)
	hud.budget_pressed.connect(func(): TBModals.budget(_overlay, g, func(): hud.refresh()))
	hud.save_pressed.connect(func(): TBModals.save_load(_overlay, true, _save_slot, _load_slot))
	hud.settings_pressed.connect(_open_settings)
	resized.connect(func(): panel.layout_for(size))
	get_window().size_changed.connect(_update_ui_scale); _update_ui_scale()
	_apply_quality()
	_new_demo_game()
	show_menu()
	panel.layout_for(size)

## phones in portrait need a different logical base size, otherwise the landscape 1280x720 base shrinks the UI to a few px
func _update_ui_scale() -> void:
	var w := get_window()
	var s := w.size
	w.content_scale_size = Vector2i(540, 960) if s.y > s.x else Vector2i(1280, 720)
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

func _guess_quality() -> String:
	if OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS": return "medium"
	return "high"

func _apply_quality() -> void:
	var q: int = {"low": 0, "medium": 1, "high": 2}.get(cfg["quality"], 1)
	map.quality = q
	map.render_scale = [0.6, 0.85, 1.0][q]      # fraction of logical resolution the map shader renders at
	map._push_view()

# ---------------------------------------------------------------- screens
func _new_demo_game() -> void:
	g = TBGame.new(world, {}, {"seed": 1})
	map.setup(g)
	map.set_mode(0 if cfg["view"] == "globe" else 1)

func _clear_overlay() -> void:
	for c in _overlay.get_children(): c.queue_free()

func show_menu() -> void:
	mode = "menu"; _spin = true
	hud.visible = false; panel.visible = false; _clear_overlay()
	var m := K.modal(_overlay, "")
	m[0].color = Color(0, 0, 0, 0)
	var v: VBoxContainer = m[1]
	v.custom_minimum_size = Vector2(320, 0)
	var t := K.label(T.call("title"), 34, K.GOLD2); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var tag := K.label(T.call("tagline"), 14, K.DIM); tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tag)
	v.add_child(K.button(T.call("new_game"), _open_era_picker, true))
	var cont := K.button(T.call("continue"), func(): _load_slot("auto"))
	cont.visible = not TBSave.meta("auto").is_empty(); v.add_child(cont)
	v.add_child(K.button(T.call("load"), func(): TBModals.save_load(_overlay, false, _save_slot, _load_slot)))
	v.add_child(K.button(T.call("multiplayer"), func(): mp.open_menu()))
	v.add_child(K.button(T.call("settings"), _open_settings))

func _open_settings() -> void:
	TBModals.settings(_overlay, cfg, func():
		_save_cfg(); TBI18n.load_lang(cfg["lang"]); _apply_quality()
		map.set_mode(0 if cfg["view"] == "globe" else 1), func(): show_menu() if mode == "game" else Callable())

func _open_era_picker() -> void:
	_clear_overlay(); _spin = false
	TBModals.era_picker(_overlay, cfg["difficulty"], _begin_pick, show_menu)

func _begin_pick(era_id: String, difficulty: String) -> void:
	cfg["difficulty"] = difficulty; _save_cfg()
	var era := TBWorld.load_era("res://data", era_id) if era_id != "modern" else {}
	g = TBGame.new(world, era, {"seed": int(Time.get_unix_time_from_system()) & 0x7fffffff | 1, "difficulty": difficulty})
	map.setup(g)
	mode = "pick"; _spin = false; _clear_overlay()
	var hint := K.label(T.call("pick_nation"), 16, K.GOLD2)
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP); hint.position.y = 14
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(hint)
	_overlay.add_child(_back_btn())

func _back_btn() -> Button:
	var b := K.button(T.call("back"), func(): show_menu()); b.position = Vector2(10, 10); return b

func _start_game(n: int) -> void:
	g.set_human(n); g.color[n] = 0xE63946
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
		_overlay.add_child(_back_btn())
		var m := K.modal(_overlay, g.nat_name[n], 380)
		m[0].color = Color(0, 0, 0, 0)
		m[1].add_child(K.label("%d %s" % [g.own_count(n), T.call("lands").to_lower()], 14, K.DIM))
		var row := K.hbox(8); m[1].add_child(row)
		row.add_child(K.button(T.call("back"), func(): m[0].queue_free()))
		var go := K.button(T.call("play_as", {"nation": g.nat_name[n]}), func(): _start_game(n), true); go.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(go)
		return
	if mode != "game" or _busy: return
	if p < 0: _select(-1); return
	if secondary and selected >= 0 and g.controller(selected) == g.human_id: _do_move(selected, p); return
	if move_from >= 0:
		var f := move_from; move_from = -1; _do_move(f, p); return
	_select(p)

func _select(p: int) -> void:
	selected = p
	map.select(p)
	panel.show_province(g, p) if p >= 0 else panel.show_province(g, -1)

func _on_move_requested(p: int) -> void:
	move_from = p
	hud.toast(T.call("move") + " ▸")

func _open_nation(n: int) -> void:
	TBModals.nation_detail(_overlay, g, n, _on_command, _goto_nation)

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
	_busy = true; hud.set_busy(true); move_from = -1
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
	if g.over: TBModals.game_over(_overlay, g, show_menu)
	else: _autosave()

func _flush_log() -> void:
	var me := g.human_id
	while _log_idx < g.log.size():
		var e: Dictionary = g.log[_log_idx]; _log_idx += 1
		var a := String(g.nat_name[e["a"]]); var b := String(g.nat_name[e["b"]]) if e.has("b") else ""
		var rel: bool = e["a"] == me or e.get("b", -1) == me
		match e["kind"]:
			"war": if rel: hud.toast(T.call("e_war", {"a": a, "b": b}), true)
			"peace": if rel: hud.toast(T.call("e_peace", {"a": a, "b": b}))
			"ally": if rel: hud.toast(T.call("e_ally", {"a": a, "b": b}))
			"eliminated": hud.toast(T.call("e_elim", {"a": a}))
			"spy": if e.get("b", -1) == me: hud.toast(T.call("e_spy_hit", {"a": a, "op": T.call("spy_" + String(e["op"]))}) if e["ok"] else T.call("e_spy_caught", {"a": a}), e["ok"])
			"rebels": if e["a"] == me: hud.toast(T.call("e_rebels", {"a": a}), true)
	if g.log.size() > 400:
		g.log = g.log.slice(g.log.size() - 200); _log_idx = g.log.size()

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
	if mode == "menu" and _spin:
		map.lon0 += delta * 0.12
		map._push_view()

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
