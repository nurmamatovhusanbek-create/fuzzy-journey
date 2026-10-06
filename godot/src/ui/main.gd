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
var cfg := {"perf": false, "seal_seen": false, "sound": true, "quality": "auto", "lang": "en", "view": "globe", "difficulty": "normal", "tutorial": false, "theme": "standard", "ui": "normal", "honours": {}}
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
	map.keepout_fn = func() -> Array:
		var r: Array = hud.keepouts()
		if panel.visible: r.append(panel.get_global_rect())
		return r
	panel.command.connect(_on_command); panel.move_requested.connect(_on_move_requested); panel.closed.connect(func(): _select(-1))
	_overlay = Control.new(); _overlay.set_anchors_preset(Control.PRESET_FULL_RECT); _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	mp = TBMpController.new(); add_child(mp); mp.setup(self)
	hud.end_turn_pressed.connect(func():
		sfx.play("turn"); end_turn()
		if not cfg.get("seal_seen", false): cfg["seal_seen"] = true; _save_cfg(); hud.set_seal_pulse(false))
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
	var card := PanelContainer.new()                       # the title cartouche: a laid sheet over the turning globe
	card.add_theme_stylebox_override("panel", TBFrame.sheet(40, 30))
	holder.add_child(card)
	var v := K.vbox(2)
	v.custom_minimum_size = Vector2(380, 0)
	card.add_child(v)
	var portrait := size.y > size.x
	var t := K.label(T.call("title"), 54 if not portrait else 38, K.GOLD2)
	t.add_theme_font_override("font", K.tracked(K.display_hi(), 4 if not portrait else 2))
	t.add_theme_color_override("font_shadow_color", Color(1, 0.96, 0.82, 0.55)); t.add_theme_constant_override("shadow_offset_y", 2); t.add_theme_constant_override("shadow_offset_x", 0)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	v.add_child(K.ornament())
	var tag := K.caps(T.call("tagline"), 11, K.TEXT); tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(tag)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 18); v.add_child(gap)
	v.add_child(MP_.Entry.new(T.call("new_game"), true, func(): _hot_n = 0; _hot_list = PackedInt32Array(); _open_era_picker()))
	v.add_child(MP_.Entry.new(T.call("hotseat"), false, func(): TBModals.hotseat_setup(_overlay, func(k: int): _hot_n = k; _hot_list = PackedInt32Array(); _open_era_picker())))
	if not TBSave.meta("auto").is_empty(): v.add_child(MP_.Entry.new(T.call("continue"), false, func(): _load_slot("auto")))
	v.add_child(MP_.Entry.new(T.call("load"), false, func(): TBModals.save_load(_overlay, false, _save_slot, _load_slot)))
	v.add_child(MP_.Entry.new(T.call("multiplayer"), false, func(): mp.open_menu()))
	v.add_child(MP_.Entry.new("%s  %d/%d" % [T.call("honours"), TBHonours.count(cfg), TBHonours.LIST.size()], false, func(): TBModals.honours(_overlay, cfg)))
	v.add_child(MP_.Entry.new(T.call("settings"), false, _open_settings))
	var gap2 := Control.new(); gap2.custom_minimum_size = Vector2(0, 10); v.add_child(gap2)
	var ver := K.caps("terra bellum · godot build", 10, K.DIM); ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ver)

func _open_settings() -> void:
	var prev_lang: String = TBI18n.lang
	TBModals.settings(_overlay, cfg, func():
		_save_cfg(); TBI18n.load_lang(cfg["lang"]); _apply_quality(); _update_ui_scale(); sfx.enabled = cfg.get("sound", true)
		map.set_mode(0 if cfg["view"] == "globe" else 1)
		if TBI18n.lang != prev_lang:          # re-create already-built screens in the new language
			prev_lang = TBI18n.lang
			if mode == "game": hud.build(); hud.refresh(); if selected >= 0: panel.rebuild()
			elif mode == "menu": show_menu(), func(): show_menu() if mode == "game" else Callable(), _copy_diagnostics)

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
	_clear_overlay(); _spin = false
	TBModals.era_picker(_overlay, cfg["difficulty"], _begin_pick, show_menu)

func _begin_pick(era_id: String, difficulty: String) -> void:
	cfg["difficulty"] = difficulty; _save_cfg()
	var era := TBWorld.load_era("res://data", era_id) if era_id != "modern" else {}
	g = TBGame.new(world, era, {"seed": int(Time.get_unix_time_from_system()) & 0x7fffffff | 1, "difficulty": difficulty})
	map.setup(g)
	mode = "pick"; _spin = false; _clear_overlay()
	_pick_hint(T.call("pick_nation") if _hot_n == 0 else T.call("hot_pick", {"k": _hot_list.size() + 1, "n": _hot_n}))
	_add_pick_buttons()

## the instruction slip at the top of the nation-pick screen: ink on paper, readable over any backdrop
func _pick_hint(text: String) -> void:
	var hint_box := PanelContainer.new(); hint_box.set_anchors_preset(Control.PRESET_CENTER_TOP); hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.add_theme_stylebox_override("panel", TBFrame.chit(TBFrame.PAPER, 26, 9))
	hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH; hint_box.offset_top = 12
	var hint := K.title(text, 17); hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint_box.add_child(hint)
	_overlay.add_child(hint_box)

func _add_pick_buttons() -> void:
	_overlay.add_child(_back_btn())
	var lb := K.button(T.call("nations"), func(): TBModals.nations(_overlay, g, func(n: int): _pick_nation_from_list(n), false, false))
	lb.anchor_left = 1.0; lb.anchor_right = 1.0; lb.offset_left = -150; lb.offset_right = -10; lb.offset_top = 10
	_overlay.add_child(lb)

## hot-seat: every player picks in turn, then the game starts
func _confirm_pick(n: int) -> void:
	if _hot_n <= 1: _start_game(n); return
	_hot_list.append(n)
	if _hot_list.size() >= _hot_n: _start_game(n); return
	_clear_overlay()
	_pick_hint(T.call("hot_pick", {"k": _hot_list.size() + 1, "n": _hot_n}))
	_add_pick_buttons()

func _pick_nation_from_list(n: int) -> void:
	var cap := g.capital_of[n]
	if cap < 0: cap = g.owned(n)[0]
	map.fly_to(world.lon[cap], world.lat[cap], 2.4 if map.mode == 0 else maxf(map.zoom, 3.0))
	_on_pick(cap, false)

func _back_btn() -> Button:
	var b := K.button(T.call("back"), func(): show_menu()); b.position = Vector2(10, 10); return b

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
	mode = "game"; _clear_overlay(); _log_idx = g.log.size()
	map.lenses.refresh_nations(); map.repaint_all()
	var cap := g.capital_of[n]
	if cap >= 0: map.fly_to(world.lon[cap], world.lat[cap], 2.2 if map.mode == 0 else maxf(map.zoom, 3.0))
	hud.g = g; hud.visible = true; hud.build(); hud.refresh()
	hud.set_seal_pulse(not cfg.get("seal_seen", false))
	_select(-1)
	_autosave()
	if not cfg.get("tutorial", false):
		cfg["tutorial"] = true; _save_cfg()
		TBModals.tutorial(_overlay, func(): TBModals.briefing(_overlay, g, func(): pass))
	else:
		TBModals.briefing(_overlay, g, func(): pass)

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
		var army := 0
		var rank := 1
		for q in g.P:
			if g.owner[q] == n: army += g.army[q]
		for o in range(1, g.N1):
			if o != n and g.alive[o] != 0 and g.own_count(o) > g.own_count(n): rank += 1
		var facts := K.hbox(12); m[1].add_child(facts)
		if g.rules >= 1 and g.r_name[n] != "":
			facts.add_child(TBPortrait.new().setup(g, n, 64))
		var fv := K.vbox(2); fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; fv.size_flags_vertical = Control.SIZE_SHRINK_CENTER; facts.add_child(fv)
		if g.rules >= 1 and g.r_name[n] != "":
			fv.add_child(K.label("%s %s" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)], 15, K.GOLD2))
		fv.add_child(K.label("%d %s · %s" % [g.own_count(n), T.call("lands").to_lower(), T.call("rank_size", {"n": rank})], 14, K.TEXT))
		fv.add_child(K.label("%s %s · %s %.1f" % [T.call("total_army"), K.fmt(army), T.call("era_name_%d" % g.era[n]), g.tech_level[n]], 13, K.DIM))
		fv.add_child(K.label("%s · %s" % [T.call("g_" + TBData.REGIME_ID[g.regime[n]]), T.call("pers_" + TBData.PERSONALITIES[g.personality[n]]["id"])], 13, K.DIM))
		var row := K.hbox(8); m[1].add_child(row)
		row.add_child(K.button(T.call("back"), func(): m[0].queue_free()))
		var taken: bool = _hot_list.has(n)
		var go := K.button(T.call("play_as", {"nation": g.dname(n)}), func(): _confirm_pick(n), true); go.size_flags_horizontal = Control.SIZE_EXPAND_FILL; go.disabled = taken; row.add_child(go)
		return
	if mode != "game" or _busy: return
	if p < 0: _select(-1); return
	if secondary and selected >= 0 and g.controller(selected) == g.human_id: _do_move(selected, p); return
	if move_from >= 0:
		_try_move(move_from, p); return
	_select(p)

var _tip: PanelContainer
var _tip_label: Label
## desktop-only hover card: province, owner and relation, army, terrain; in move mode the outcome of an attack
var _tip_name: Label
var _tip_sub: Label
var _tip_note: Label
var _tip_flag: TextureRect
func _on_hover(p: int) -> void:
	if mode != "game" or p < 0 or OS.has_feature("mobile") or g == null:
		if _tip != null: _tip.visible = false
		return
	if _tip == null:
		_tip = PanelContainer.new(); _tip.mouse_filter = Control.MOUSE_FILTER_IGNORE; _tip.z_index = 50
		_tip.add_theme_stylebox_override("panel", TBFrame.make(Color(0.035, 0.055, 0.11, 0.95), Color(K.GOLD.r, K.GOLD.g, K.GOLD.b, 0.6), 7, false, 11, 7))
		var v := K.vbox(1); _tip.add_child(v)
		var top := K.hbox(7); v.add_child(top)
		_tip_flag = TextureRect.new(); _tip_flag.custom_minimum_size = Vector2(22, 15); _tip_flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _tip_flag.stretch_mode = TextureRect.STRETCH_SCALE; _tip_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(_tip_flag)
		_tip_name = K.title("", 15); top.add_child(_tip_name)
		_tip_sub = K.label("", 12, K.DIM); v.add_child(_tip_sub)
		_tip_note = K.label("", 12, K.TEXT); v.add_child(_tip_note)
		add_child(_tip)
	var o := g.owner[p]
	var me := g.human_id
	_tip_name.text = TBI18n.place(world.name[p])
	_tip_flag.visible = o != 0
	if o != 0: _tip_flag.texture = TBFlags.texture(g.nat_code[o], g.color[o])
	var rel_txt := ""
	if o == 0: rel_txt = T.call("neutral")
	elif o == me: rel_txt = g.dname(o)
	else:
		var r := g.get_rel(me, o)
		rel_txt = "%s · %s" % [g.dname(o), T.call(["rel_peace", "rel_war", "rel_nap", "rel_ally", "rel_marriage"][clampi(r, 0, 4)])]
	_tip_sub.text = "%s  ·  %s %s  ·  %s" % [rel_txt, T.call("army"), K.fmt(g.army[p]), T.call("t_" + TBData.TERRAIN_ID[g.terrain[p]])]
	_tip_note.visible = false
	if move_from >= 0 and g.rules >= 1 and g.move_check(me, move_from, p) == "attack":
		var pv := g.combat_preview(me, move_from, p, _troops_for(move_from))
		_tip_note.visible = true
		_tip_note.text = T.call("pv_win_short", {"k": int(pv["hold"])}) if pv["win"] else T.call("pv_lose_short", {"a": int(pv["lost"])})
		_tip_note.add_theme_color_override("font_color", K.GREEN if pv["win"] else K.RED)
	if not _tip.visible and TBMapView.animate:
		_tip.modulate.a = 0.0
		_tip.create_tween().tween_property(_tip, "modulate:a", 1.0, 0.1)
	_tip.visible = true
	_tip.reset_size()
	_place_tip()

func _place_tip() -> void:
	if _tip == null or not _tip.visible: return
	_tip.position = (get_local_mouse_position() + Vector2(18, 20)).clamp(Vector2.ZERO, size - _tip.size)

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
	if p < 0: hud.hide_preview(); _pv_to = -1
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

var _pv_to := -1
## how many men a move sends from `from`, following the 25/50/75/100 % choice on the province panel
func _troops_for(from: int) -> int:
	var frac: float = panel.send_frac
	if frac >= 0.999: return g.army[from] - 1
	return maxi(1, int(floor((g.army[from] - 1) * frac)))

## attacks show the exact outcome first; a second tap on the same target (or Attack) commits
func _try_move(from: int, to: int) -> void:
	var tr := _troops_for(from)
	if mp.in_game or g.rules < 1 or g.move_check(g.human_id, from, to) != "attack":
		hud.hide_preview(); _pv_to = -1; _set_move_from(-1); _do_move(from, to); return
	if _pv_to == to: _commit_move(from, to); return
	_pv_to = to
	map.set_targets(PackedInt32Array([to]))
	hud.show_preview(g.combat_preview(g.human_id, from, to, tr), TBI18n.place(world.name[to]), func(): _commit_move(from, to), func(): _pv_to = -1; _set_move_from(from))

func _commit_move(from: int, to: int) -> void:
	hud.hide_preview(); _pv_to = -1
	_set_move_from(-1)
	_do_move(from, to)

func _do_move(from: int, to: int) -> void:
	var tr := _troops_for(from)
	if mp.in_game:
		mp.send_command({"cmd": "move", "from": from, "to": to, "troops": tr}); _select(to); return
	var res := g.apply({"cmd": "move", "n": g.human_id, "from": from, "to": to, "troops": tr})
	if not res["ok"]:
		var key := "err_" + String(res["err"])
		hud.toast(T.call(key) if TBI18n.has_key(key) else String(res["err"]), true)
	else:
		var rs: String = res.get("result", "")
		if rs == "move":
			map.labels.add_fx("march", from, to, Color(0.95, 0.8, 0.35))
		else:
			var win: bool = rs == "win"
			map.labels.add_fx("atk", from, to, Color(0.5, 0.9, 0.55) if win else Color(1.0, 0.55, 0.5))
			map.labels.add_fx("cap", from, to, Color(0.5, 0.9, 0.55) if win else Color(1.0, 0.55, 0.5), 450)
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
		TBModals.event_prompt(_overlay, e, func(i: int): _on_command({"cmd": "eventChoice", "uid": uid, "i": i}), g)
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
	if _is_hotseat():
		var hs := g.humans()
		var nxt := _next_human(hs)
		if nxt != 0:
			_set_move_from(-1)
			_hot_switch(nxt, false); return
	_busy = true; hud.set_busy(true); _set_move_from(-1); hud.hide_preview(); _pv_to = -1
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
	var m := K.modal(_overlay, g.dname(n), 420, "flag")
	m[0].color = Color(0.012, 0.02, 0.045, 1.0)
	var c := K.caps(T.call("hot_pass"), 11, K.GOLD); c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; m[1].add_child(c)
	var fl := TBFlags.chip(g, n, 1.6); fl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; m[1].add_child(fl)
	var tl := K.label("%s %d · %s" % [T.call("turn"), g.turn, TBChron.date(g, g.turn)], 14, K.DIM); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; m[1].add_child(tl)
	var rb := K.button(T.call("hot_ready"), func(): m[0].queue_free(); show_events(), true); rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m[2].add_child(rb)

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
	if selected >= 0: panel.rebuild()
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
		var col := Color(0.5, 0.9, 0.55) if held else Color(1.0, 0.55, 0.5)
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
			hud.toast(tx, TBChron.is_bad(e, me))
			if String(e["kind"]) == "war" and TBChron.involves(e, me): sfx.play("war")
			elif String(e["kind"]) in ["event", "ruler"]: sfx.play("event")
	earned.append_array(TBHonours.on_state(g))
	if _is_hotseat(): earned.clear()
	for id in TBHonours.record(g, cfg, earned):
		hud.toast("%s: %s" % [T.call("honour_earned"), T.call("honour_" + id)], false)
		sfx.play("event"); _save_cfg()
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

## Android back button: close the open dialog, then the province sheet, then offer the menu; quit only from the title screen
func _on_back() -> void:
	var top: Node = null
	for c in _overlay.get_children():
		if c is ColorRect: top = c
	if top != null and mode != "menu":
		top.queue_free(); return
	match mode:
		"menu":
			if top != null: show_menu()
			else: get_tree().quit()
		"pick", "mp_lobby": show_menu()
		"game":
			if panel.visible: _select(-1)
			else: _open_settings()

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
