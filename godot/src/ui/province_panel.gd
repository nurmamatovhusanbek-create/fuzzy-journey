## The command card (design/ux/command-card.md): replaces the long right-hand province panel. Docked bottom-centre on desktop,
## a handed strip on landscape phones, a bottom sheet in portrait. Header, <= 4 info chips, send-share + live cost line, 3-5 verbs
## in stable slots, a Details drawer with the ledger. It only emits command dictionaries; orders on the map run through TBOrderFlow.
## Public API kept from the old panel: signals command / move_requested / closed / nation_requested, layout_for(vp), rebuild(),
## show_province(g, p), send_frac, visible, get_global_rect().
class_name TBProvincePanel
extends PanelContainer

signal command(cmd: Dictionary)
signal move_requested(p: int)
signal closed
signal nation_requested(n: int)
signal share_changed(frac: float)
signal select_requested(p: int)

const CC = preload("res://src/ui/cmd_card.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T
static var _title_font: Font

const HOT := {"move": "M", "attack": "M", "recruit": "R", "hire": "H", "general": "G", "build": "B", "colonize": "C", "diplo": "D", "ult": "U", "war": "W", "peace": "P", "terms": "T"}
const HOT_KEY := {KEY_M: "move", KEY_R: "recruit", KEY_H: "hire", KEY_G: "general", KEY_B: "build", KEY_C: "colonize", KEY_D: "diplo", KEY_U: "ult", KEY_W: "war", KEY_P: "peace", KEY_T: "terms"}

var g: TBGame
var p := -1
var send_frac := 1.0                      # share of the stack a move sends (25 / 50 / 75 / 100 %)
var flow: TBOrderFlow
var busy_fn: Callable                     # () -> bool : the turn is resolving on the worker thread
var blocked_fn: Callable                  # () -> bool : a modal / text field owns the keyboard, or no game is running
var profile := "D"                        # D desktop card | L landscape-phone strip | P portrait sheet
var drawer_open := false
var reserve := 12.0                       # px kept free below the card (dock / seal in portrait)
var band_fn: Callable                     # () -> Vector2 : the horizontal band (x0, x1) free of the rail and the End Turn seal (hud.card_band)
var reserve_fn: Callable                  # () -> float : px kept free below the sheet in portrait (hud.bottom_reserve)
var confirm_fn: Callable                  # () -> String : "smart" | "always" | "never" (hud.confirm_mode) for declare war / break pact

var _col: VBoxContainer
var _box: CC.PlateBox
var _vp := Vector2(1280, 720)
var _verbs: Array = []                    # [{id, btn, can, parts, why, hot}]
var _focus_verb := 0
var _cost: CC.CostLine
var _share: CC.ShareSeg
var _count: Label
var _popover: Popover
var _war_target := -1
var _head2: HBoxContainer                 # second header row at large text sizes
var _brk_target := -1                     # a nation whose pact the player is about to break (confirm row)
var _card_w := 480.0
var _atk_src := -1                        # attacker chosen for an enemy province by tapping an own army
var _flash_v := 0
var _busy := false
var _case := {}
var _rise := 0.0
var _hotkeys := {}
var _handle: Control
var _drag_y := 0.0
var _name_label: Label
var _px0 := 0.0
var _act_node: Control                    # the idle verb row: AoC action buttons floating above the minimap (top level)

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = CC.plate("paper_0", "rule", TBTokens.CUT_PANEL, 1)
	_box.fill_a = 0.8
	add_theme_stylebox_override("panel", _box)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 2)
	add_child(_col)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	minimum_size_changed.connect(_refit)
	set_process(true)

# ---------------------------------------------------------------- layout (call on resize)
func layout_for(vp: Vector2) -> void:
	_vp = vp
	CC.sync_settings()
	var prev := profile
	profile = "P" if vp.y > vp.x else ("L" if vp.y <= 480.0 else "D")
	CC.show_hotkeys = profile != "P" and not (OS.get_name() in ["Android", "iOS"])
	# the band the card may use: right of the rail, left of the End Turn seal and its chip with a 16 u gap (never over End Turn)
	var band := Vector2(8.0, vp.x - 8.0)
	if band_fn.is_valid(): band = band_fn.call()
	# AoC layout: the minimap owns the bottom-left corner, the information bar sits right of it, the Next Turn plate bottom-right
	var R := TBHudParts.R
	var x0: float = band.x if profile != "P" else 8.0
	var w: float = minf(R.call(620.0), maxf(240.0, band.y - x0)) if profile != "P" else vp.x - 16.0
	var side_pad := 1.0
	reserve = 0.0
	_box.content_margin_top = 1; _box.content_margin_bottom = 1
	if profile == "P":
		reserve = 12.0
		if reserve_fn.is_valid(): reserve = float(reserve_fn.call())
	var pw := _card_w
	_card_w = w
	_box.content_margin_left = side_pad; _box.content_margin_right = side_pad
	_box.force_rebuild()
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	var left: float = x0
	_px0 = x0
	offset_left = left - vp.x * 0.5; offset_right = left + w - vp.x * 0.5
	_refit()
	if prev != profile and visible: rebuild()
	elif visible and profile == "L" and (pw >= 480.0) != (w >= 480.0) and false: rebuild()

## the card is bottom-anchored and grows upward: its top edge follows its content height (a container resize would grow it downward)
func _refit() -> void:
	var h := get_combined_minimum_size().y
	offset_bottom = -reserve + _rise
	offset_top = offset_bottom - h
	if _act_node != null and is_instance_valid(_act_node):
		var ah: float = _act_node.get_combined_minimum_size().y
		var top_y: float = _vp.y + offset_top
		if profile == "P": _act_node.position = Vector2(8.0, top_y - ah - 4.0)
		else:
			var ax: float = _px0 - TBHudParts.R(295.0) if _px0 <= TBHudParts.R(301.0) else _px0
			_act_node.position = Vector2(ax, minf(_vp.y - TBHudParts.R(145.0), top_y) - ah)
		_act_node.size = _act_node.get_combined_minimum_size()

## the radius of space the card must keep clear of the selected province (the map pans if it would cover it)
func card_rect() -> Rect2: return get_global_rect()

# ---------------------------------------------------------------- public state
func show_province(game: TBGame, province: int) -> void:
	g = game
	var changed := province != p
	p = province
	if p < 0:
		_close_popover(); _war_target = -1; _brk_target = -1; _atk_src = -1
		visible = false; return
	if changed: _war_target = -1; _brk_target = -1; _atk_src = -1; _close_popover()
	var was := visible
	visible = true
	rebuild()
	if not was and not TBHudParts.reduced_motion():        # rises 16 px and fades in (160 ms); instant with reduced motion
		modulate.a = 0.0
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.16)
		tw.tween_method(_set_rise, 16.0, 0.0, 0.16)
	_keep_province_visible()

func _set_rise(v: float) -> void:
	_rise = v
	_refit()

func set_attacker(q: int) -> void:
	_atk_src = q
	rebuild()

## back one layer; true when something was consumed (popover -> war confirm -> preview -> armed -> drawer -> card)
func back() -> bool:
	if _popover != null and is_instance_valid(_popover) and _popover.visible: _close_popover(); return true
	if _war_target >= 0 or _brk_target >= 0: _war_target = -1; _brk_target = -1; rebuild(); return true
	if flow != null and flow.mode == TBOrderFlow.Mode.PREVIEW: flow.cancel(); return true
	if flow != null and flow.explicit: flow.disarm(); return true
	if drawer_open: set_drawer(false); return true
	if visible: closed.emit(); return true
	return false

func set_drawer(on: bool) -> void:
	if drawer_open == on: return
	drawer_open = on
	rebuild()

## a rejected command: the cost line turns into a 3 s reason with a warning glyph and the outline flashes (no shake)
func reject(why: String) -> void:
	var key := "err_" + why
	var text: String = T.call(key) if TBI18n.has_key(key) else why
	flash(text)

func flash(text: String) -> void:
	if _cost == null: return
	_cost.set_parts([{"t": text, "short": false}], true)
	_flash_v += 1
	var v := _flash_v
	if get_tree() != null:
		get_tree().create_timer(3.0).timeout.connect(func(): if v == _flash_v: _update_cost_line())
	# a rejected order flashes the card outline for 120 ms; the card never shakes (A11Y-MOT-002)
	_box.outline = "neg"; _box.force_rebuild(); queue_redraw()
	if get_tree() != null:
		get_tree().create_timer(0.12).timeout.connect(func(): _box.outline = ""; _box.force_rebuild(); queue_redraw())

func _process(_dt: float) -> void:
	var b: bool = busy_fn.is_valid() and bool(busy_fn.call())
	if b != _busy:
		_busy = b
		modulate.a = 0.6 if b else 1.0
		for v in _verbs: (v["btn"] as CC.VerbBtn).set_blocked(b or not bool(v["can"]["ok"]))
		if b and _cost != null: _cost.set_parts([{"t": T.call("cc_resolving"), "short": false}])
		elif _cost != null: _update_cost_line()

# ---------------------------------------------------------------- rebuild
func _subject() -> int:
	if flow != null and flow.mode == TBOrderFlow.Mode.PREVIEW and flow.tgt >= 0: return flow.tgt
	return p

func _classify(s: int) -> Dictionary:
	var me := g.human_id
	var o := g.owner[s]; var ctrl := g.controller(s)
	var cs := {"p": s, "o": o, "ctrl": ctrl, "me": me, "held": false, "retake": false, "enemy": 0}
	if o == me and ctrl == me:
		cs["kind"] = 1 if g.army[s] > 1 else 2
	elif ctrl == me:
		cs["kind"] = 1 if g.army[s] > 1 else 2; cs["held"] = true
	elif o == 0:
		cs["kind"] = 5
	else:
		var eff := ctrl if ctrl != 0 else o
		if eff != me and g.get_rel(me, eff) == D.REL_WAR:
			cs["kind"] = 4; cs["enemy"] = eff; cs["retake"] = o == me
		else:
			cs["kind"] = 3
	cs["rel"] = g.get_rel(me, o) if (o != 0 and o != me) else -1
	return cs

func _clear_col() -> void:
	for c in _col.get_children():
		_col.remove_child(c); c.queue_free()
	if _act_node != null and is_instance_valid(_act_node):
		remove_child(_act_node); _act_node.queue_free()
	_act_node = null
	_verbs.clear(); _hotkeys.clear(); _cost = null; _share = null; _count = null; _handle = null

func rebuild() -> void:
	if p < 0 or g == null: return
	CC.sync_settings()
	var prev_focus := _focus_verb
	var prev_id := ""
	if prev_focus >= 0 and prev_focus < _verbs.size(): prev_id = _verbs[prev_focus]["id"]
	_clear_col()
	var subj := _subject()
	var cs := _classify(subj)
	_case = cs
	if drawer_open: _col.add_child(_build_drawer(subj, cs))
	var bar := TBInfoBar.new()
	bar.tag = _tag_for(cs)
	bar.setup(g, subj, cs, drawer_open)
	bar.closed.connect(func(): closed.emit())
	bar.owner_pressed.connect(func(n: int): nation_requested.emit(n))
	bar.details_pressed.connect(func(): set_drawer(not drawer_open))
	_col.add_child(bar)
	_head2 = null; _name_label = null
	var chips := _build_chips(subj, cs)
	if chips.get_child_count() > 0: _col.add_child(chips)
	var order_mode := _order_mode()
	var src := _source_for(cs) if order_mode != "war" else -1
	var verbs_row: Control
	match order_mode:
		"preview", "war": verbs_row = _build_order_row(cs, src, order_mode)
		"armed": verbs_row = _build_armed_row()
		_: verbs_row = _build_verb_row(subj, cs, src)
	var share_row: Control = _build_share_row(subj, cs, src)
	# AoC: the information bar is the whole card; the send share, the cost line and the action buttons float above the minimap
	var act := VBoxContainer.new()
	act.add_theme_constant_override("separation", int(TBHudParts.R(4.0)))
	if share_row.get_child_count() > 0 or _share_holder != null:
		var strip := PanelContainer.new()
		strip.add_theme_stylebox_override("panel", TBHudParts.sbox(TBHudParts.al(TBHudParts.tk("bar_0"), 0.9), TBHudParts.tk("rule"), TBHudParts.R(5.0), 1))
		strip.mouse_filter = Control.MOUSE_FILTER_STOP
		strip.add_child(share_row)
		if _share_holder != null: share_row.add_child(_share_holder)
		act.add_child(strip)
	if _cost_holder != null: act.add_child(_cost_holder)
	act.add_child(verbs_row)
	act.custom_minimum_size.x = _card_w
	_act_node = act
	_act_node.top_level = true
	add_child(_act_node)
	# keep the focused slot across rebuilds (stale state: the same verb stays focused if it is still there)
	_focus_verb = 0
	for i in _verbs.size():
		if _verbs[i]["id"] == prev_id: _focus_verb = i
	_update_cost_line()
	_busy = false
	_process(0.0)
	if _name_label != null: _name_label.queue_redraw()
	_refit.call_deferred()

func _order_mode() -> String:
	if _war_target >= 0 or _brk_target >= 0: return "war"
	if flow == null: return "idle"
	if flow.mode == TBOrderFlow.Mode.PREVIEW: return "preview"
	if flow.explicit and flow.src >= 0: return "armed"
	return "idle"

## the army whose men a share applies to: the selected own army, the chosen attacker, or the strongest neighbour that could attack
func _source_for(cs: Dictionary) -> int:
	var k: int = cs["kind"]
	if flow != null and flow.mode == TBOrderFlow.Mode.PREVIEW: return flow.src
	if k == 1: return int(cs["p"])
	if k == 4:
		if _atk_src >= 0 and g.controller(_atk_src) == g.human_id and g.army[_atk_src] > 1 and flow != null and flow.check(int(cs["p"]), _atk_src)["valid"]: return _atk_src
		return flow.best_source(int(cs["p"])) if flow != null else -1
	return -1

# ---------------------------------------------------------------- header
static func _font_title() -> Font:
	if _title_font == null: _title_font = TBKit.tracked(TBKit.display_hi(), 1)
	return _title_font

## the sheet's drag handle: a 4 px bar, but a 48 x 48 hit area (it reaches up over the sheet's top edge)
class _Handle extends Control:
	func _has_point(p: Vector2) -> bool:
		var t: float = TBCmdCard.touch()
		return Rect2(Vector2(0.0, size.y - t), Vector2(size.x, t)).has_point(p)

func _build_handle() -> Control:
	var h := _Handle.new()
	h.custom_minimum_size = Vector2(0, 20); h.mouse_filter = Control.MOUSE_FILTER_STOP
	h.draw.connect(func(): h.draw_rect(Rect2(h.size.x * 0.5 - 24.0, 8.0, 48.0, 4.0), CC.tk("ink_off")))
	h.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: _drag_y = e.position.y
			else:
				var dy: float = e.position.y - _drag_y
				if dy < -18.0: set_drawer(true)
				elif dy > 18.0: (set_drawer(false) if drawer_open else closed.emit())
				else: set_drawer(not drawer_open))
	_handle = h
	return h

func _tag_for(cs: Dictionary) -> Array:        # [glyph, text, token]
	var k: int = cs["kind"]
	var o: int = cs["o"]
	if k == 5: return ["", T.call("cc_tag_unclaimed"), "ink_1"]
	if o == cs["me"] or cs["retake"]: return ["", T.call("cc_tag_own"), "brass_ink"]
	if cs["held"]: return ["", T.call("cc_tag_held"), "brass_ink"]
	var rel: int = cs["rel"]
	if rel == D.REL_WAR: return ["swords", T.call("cc_tag_war"), "neg"]
	if rel == D.REL_ALLY: return ["link", T.call("ally"), "info"]
	if rel == D.REL_NAP: return ["link", T.call("nap"), "info"]
	if rel == D.REL_MARRIAGE: return ["crown", T.call("marriage"), "info"]
	if g.overlord[o] != 0: return ["crown", T.call("vassal"), "foreign"]
	return ["dove", T.call("peace"), "foreign"]

func _build_header(s: int, cs: Dictionary) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.custom_minimum_size = Vector2(0, 36 if profile != "P" else int(CC.touch()))
	_head2 = null
	var split := CC.text_scale >= 1.4                  # large text: identity + close on row 1, relation tag / owner link / Details on row 2
	if split:
		_head2 = HBoxContainer.new(); _head2.add_theme_constant_override("separation", 6)
		_head2.custom_minimum_size = Vector2(0, int(CC.touch()))
	var r2: HBoxContainer = _head2 if split else h
	var o: int = cs["o"]
	if o != 0:
		var fl := TBFlags.chip(g, o, 0.5)
		fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(fl)
	var nm := CC.label(TBI18n.place(g.world.name[s]), 18 if profile == "D" else 17, "oxblood", _font_title())
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.max_lines_visible = 2
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_FILL
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var nlh: float = ceilf(_font_title().get_height(CC.fs(18 if profile == "D" else 17)))
	nm.custom_minimum_size = Vector2(70, nlh)
	h.custom_minimum_size.y = maxf(h.custom_minimum_size.y, nlh + 6.0)
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nm)
	_name_label = nm
	if g.capital[s] != 0:
		var cap := Control.new()
		cap.custom_minimum_size = Vector2(18, 18); cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER; cap.mouse_filter = Control.MOUSE_FILTER_PASS
		cap.tooltip_text = T.call("capital")
		cap.draw.connect(func(): CC.glyph(cap, "capital", cap.size * 0.5, 14.0, CC.tk("brass_ink"), 1.6))
		h.add_child(cap)
	if o != 0 and o != cs["me"] and profile != "L":
		var nb := _link_button("%s ›" % g.dname(o), func(): nation_requested.emit(o))
		r2.add_child(nb)
	var tg := _tag_for(cs)
	r2.add_child(_RelTag.new(tg[0], tg[1], tg[2]))
	# Details + close
	var det := _text_button(T.call("cc_details"), "tri_up" if not drawer_open else "tri_down", func(): set_drawer(not drawer_open))
	det.tooltip_text = T.call("cc_details") + " (I)"
	if split:
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE; r2.add_child(sp)
	r2.add_child(det)
	var cl := _CloseBtn.new(48.0 if profile == "P" else 36.0)
	cl.pressed.connect(func(): closed.emit())
	cl.tooltip_text = T.call("cc_close")
	TBKit.a11y(cl, T.call("cc_close"), "button")
	h.add_child(cl)
	return h

func _link_button(text: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = text; b.flat = true; b.focus_mode = Control.FOCUS_ALL
	for st in ["normal", "hover", "pressed", "focus", "disabled"]: b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_font_override("font", TBKit.body_b())
	b.add_theme_font_size_override("font_size", CC.fs(14))
	b.add_theme_color_override("font_color", CC.tk("ink_0")); b.add_theme_color_override("font_hover_color", CC.tk("oxblood")); b.add_theme_color_override("font_pressed_color", CC.tk("oxblood"))
	b.custom_minimum_size = Vector2(0, 36 if profile != "P" else int(CC.touch()))
	b.pressed.connect(cb)
	return b

func _text_button(text: String, glyph_id: String, cb: Callable) -> Button:
	var b := _GlyphText.new(text, glyph_id)
	b.pressed.connect(cb)
	return b

## relation tag: glyph + word, in the semantic colour (never colour alone)
class _RelTag extends Control:
	var gl := ""
	var text := ""
	var token := "ink_1"
	func _init(g_: String, t_: String, tk_: String) -> void:
		gl = g_; text = t_; token = tk_
		mouse_filter = Control.MOUSE_FILTER_PASS; tooltip_text = t_
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _label() -> String: return text.to_upper() if TBI18n.lang != "ru" else text
	func _get_minimum_size() -> Vector2:
		var w := TBKit.body_b().get_string_size(_label(), HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(12)).x + 2.0 + (18.0 if gl != "" else 0.0)
		return Vector2(w, 24.0)
	func _draw() -> void:
		var x := 0.0
		var c := TBCmdCard.tk(token)
		if gl != "":
			TBCmdCard.glyph(self, gl, Vector2(8.0, size.y * 0.5), 14.0, c, 1.5); x = 18.0
		draw_string(TBKit.body_b(), Vector2(x, size.y * 0.5 + 4.5), _label(), HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(12), c)

## the card's close button: a drawn X with a 48 x 48 hit area whatever its visual size
class _CloseBtn extends Button:
	func _init(px: float) -> void:
		flat = true; focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
		custom_minimum_size = Vector2(px, px)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _has_point(p: Vector2) -> bool:
		var t: float = TBCmdCard.touch()
		var ex := Vector2(maxf(0.0, (t - size.x) * 0.5), maxf(0.0, (t - size.y) * 0.5))
		return Rect2(-ex, size + ex * 2.0).has_point(p)
	func _draw() -> void:
		var hot := is_hovered() or button_pressed
		if hot: draw_colored_polygon(TBCmdCard.chamfer(Rect2(Vector2.ZERO, size), 4.0), TBCmdCard.tk("paper_hover"))
		TBCmdCard.glyph(self, "close", size * 0.5, 16.0, TBCmdCard.tk("oxblood") if hot else TBCmdCard.tk("ink_0"), 1.8)
		if has_focus(): draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), TBCmdCard.tk("ink_0"), false, 2.0)

## "Details ⌃": a text button with a drawn glyph (32 px high, 48 on touch via hit-slop)
class _GlyphText extends Button:
	var gl := ""
	func _init(t_: String, g_: String) -> void:
		text = ""; gl = g_; focus_mode = Control.FOCUS_ALL; flat = true
		for st in ["normal", "hover", "pressed", "focus", "disabled"]: add_theme_stylebox_override(st, StyleBoxEmpty.new())
		custom_minimum_size = Vector2(maxf(TBCmdCard.touch() - 8.0, TBKit.body_b().get_string_size(t_, HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(14)).x + 30.0), 36.0)
		tooltip_text = t_
		set_meta("label", t_)
	func _has_point(p: Vector2) -> bool:               # a 48 x 48 hit area around the 36 px text button
		var t: float = TBCmdCard.touch()
		var ex := Vector2(maxf(0.0, (t - size.x) * 0.5), maxf(0.0, (t - size.y) * 0.5))
		return Rect2(-ex, size + ex * 2.0).has_point(p)
	func _draw() -> void:
		var hot := is_hovered() or button_pressed
		var c := TBCmdCard.tk("oxblood") if hot else TBCmdCard.tk("ink_0")
		TBCmdCard.glyph(self, gl, Vector2(9.0, size.y * 0.5), 10.0, c, 1.4)
		draw_string(TBKit.body_b(), Vector2(20.0, size.y * 0.5 + 5.0), String(get_meta("label")), HORIZONTAL_ALIGNMENT_LEFT, -1, TBCmdCard.fs(14), c)
		if has_focus(): draw_rect(Rect2(Vector2.ZERO, size).grow(-1.0), TBCmdCard.tk("ink_0"), false, 2.0)

# ---------------------------------------------------------------- chips (<= 4, priority order)
func _build_chips(s: int, cs: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(0, 28)
	var me: int = cs["me"]
	var list: Array = []
	var terr: String = T.call("t_" + D.TERRAIN_ID[g.terrain[s]])
	match int(cs["kind"]):
		1, 2:
			if g.rules >= 1 and g.gen[s] != 0:
				list.append(CC.InfoChip.new("",  "", "%s %s" % ["★".repeat(mini(5, TBGenerals.skill(g, s))), TBGenerals.display_name(g, s)], "", "%s: %s" % [T.call("general"), TBGenerals.display_name(g, s)]))
			var outside: bool = g.owner[s] != me
			var attr := g.attrition(s)
			if g.rules >= 1 and g.army[s] > 1 and (outside or attr > 0):
				var cap_txt: String = T.call("supply") if attr == 0 else T.call("attrition")
				list.append(CC.InfoChip.new("supply", T.call("cc_supply") if attr == 0 else T.call("attrition"), "%d" % g.supply_limit(s) if attr == 0 else "−%d" % attr, "neg" if attr > 0 else "", T.call("supply_hint")))
			if g.occupier[s] != 0 and g.occupier[s] != me:
				list.append(CC.InfoChip.new("warning", "", T.call("occupied_by", {"nation": g.dname(g.occupier[s])}), "neg"))
		3:
			var o: int = cs["o"]
			if g.rules >= 1:
				var ratio := TBDiplo.ult_ratio(g, me, o)
				list.append(CC.InfoChip.new("scales", T.call("cc_ratio"), "%.1f×" % ratio, "", T.call("ultimatum_hint", {"r": "%.1f" % ratio})))
			if g.has_truce(me, o):
				list.append(CC.InfoChip.new("hourglass", "", T.call("truce_left", {"n": g.truce[me * g.N1 + o] - g.turn}), "", T.call("truce_left", {"n": g.truce[me * g.N1 + o] - g.turn})))
			elif int(cs["rel"]) == D.REL_NAP:
				var ex: int = int(g.nap_expiry.get(mini(me, o) * g.N1 + maxi(me, o), 0)) - g.turn
				if ex > 0: list.append(CC.InfoChip.new("hourglass", "", T.call("cc_pact_left", {"n": ex}), "", T.call("cc_pact_left", {"n": ex})))
		4:
			var src := _source_for(cs)
			if src >= 0: list.append(CC.InfoChip.new("men", "", T.call("cc_from", {"p": TBI18n.place(g.world.name[src]), "n": TBKit.fmt(g.army[src])}), "", T.call("cc_from_tip")))
			var en: int = cs["enemy"]
			list.append(CC.InfoChip.new("swords", T.call("war_score"), "%d" % g.war_score[me * g.N1 + en]))
			if cs["retake"] and g.occupier[s] != 0:
				list.insert(0, CC.InfoChip.new("warning", "", T.call("occupied_by", {"nation": g.dname(g.occupier[s])}), "neg"))
		5:
			var reach := _reach(s)
			list.append(CC.InfoChip.new("arrowhead", "", T.call(reach), "" if reach == "cc_reach_adj" or reach == "cc_reach_port" else "warn"))
			var cn := g.can({"cmd": "colonize", "p": s})
			if int(cn["gold"]) > 0: list.append(CC.InfoChip.new("coin", "", CC.gold(int(cn["gold"])), "neg" if cn["short"].has("gold") else ""))
	while list.size() > 4: list.pop_back()
	for c in list: row.add_child(c)
	row.custom_minimum_size = Vector2(0, 28 if row.get_child_count() > 0 else 0)
	# a narrow card drops the captions (icon + value stay; the tooltip carries the words), then the lowest-priority chips
	if profile != "L": row.resized.connect(func(): _fit_chip_row(row, row.size.x))
	return row

## chips of a row fit `avail`: captions off when too wide, then hide trailing (lowest-priority) chips; the first two always stay
func _fit_chip_row(row: HBoxContainer, avail: float) -> void:
	if avail <= 0.0: return
	var kids: Array = []
	for c0 in row.get_children():
		if c0 is CC.InfoChip: kids.append(c0)
	for c in kids: (c as CC.InfoChip).visible = true
	var need := 0.0
	for c in kids:
		(c as CC.InfoChip).set_compact(false)
		need += (c as CC.InfoChip).get_combined_minimum_size().x + 4.0
	var compact := need > avail + 0.5 or profile == "L"
	for c in kids: (c as CC.InfoChip).set_compact(compact)
	var i := kids.size() - 1
	while i >= 1 and _row_need(kids) > avail - 90.0:
		(kids[i] as Control).visible = false; i -= 1

func _row_need(kids: Array) -> float:
	var need := 0.0
	for c in kids:
		if (c as Control).visible: need += (c as Control).get_combined_minimum_size().x + 4.0
	return need - 4.0

## landscape strip: the chips share the header row with name, tag, Details and close; fit them to what is left
func _fit_header_chips(head: HBoxContainer, chips: HBoxContainer) -> void:
	if not is_instance_valid(head) or not is_instance_valid(chips): return
	var others := 0.0
	var n := 0
	for c in head.get_children():
		if c == chips or not (c as Control).visible: continue
		others += (c as Control).get_combined_minimum_size().x; n += 1
	var avail := head.size.x - others - 6.0 * (n + 1) - 8.0
	_fit_chip_row(chips, avail)

func _reach(s: int) -> String:
	var me := g.human_id
	var adj := false; var port := false
	for e in range(g.nb_off[s], g.nb_off[s + 1]):
		var q: int = g.nb[e]
		if g.owner[q] != me: continue
		if g.nb_sea[e] == 0: adj = true
		elif g.building[q] == D.B_PORT: port = true
	if adj: return "cc_reach_adj"
	if port: return "cc_reach_port"
	for e in range(g.nb_off[s], g.nb_off[s + 1]):
		if g.owner[g.nb[e]] == me: return "cc_reach_sea"
	return "cc_reach_none"

# ---------------------------------------------------------------- share + cost line
var _share_holder: Control
var _cost_holder: Control

func _build_share_row(s: int, cs: Dictionary, src: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var tall := 36 if profile == "D" else int(CC.touch())
	row.custom_minimum_size = Vector2(0, tall)
	_share_holder = null; _cost_holder = null
	_cost = CC.CostLine.new()
	_cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count = null; _share = null
	if src >= 0:
		var cap := CC.label(T.call("send_share"), 12, "ink_1", TBKit.body_b())
		cap.text = cap.text.to_upper() if TBI18n.lang != "ru" else cap.text
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_share = CC.ShareSeg.new()
		_share.cell_h = tall
		_share.cell_w = 40.0 if profile == "D" else maxf(48.0, CC.touch())      # touch cells are >= 48 wide and high
		_share.set_current(send_frac)
		var army := g.army[src] - 1
		for i in 4:                                    # duplicate presets of a small army are disabled
			var a := maxi(1, int(floor(army * CC.ShareSeg.FRACS[i]))) if i < 3 else army
			_share.off[i] = i > 0 and a == (maxi(1, int(floor(army * CC.ShareSeg.FRACS[i - 1]))) if i - 1 < 3 else army)
		_share.chosen.connect(func(f: float):
			send_frac = f
			share_changed.emit(f)
			if flow != null: flow.share_changed()
			_refresh_count())
		_count = CC.label("", 14, "ink_0", TBKit.mono_b())
		_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if profile != "L":
			row.add_child(cap)
		var holder := HBoxContainer.new(); holder.add_theme_constant_override("separation", 6)
		holder.add_child(_share)
		if profile != "L": row.add_child(holder); row.add_child(_count)
		else: holder.add_child(_count); _share_holder = holder
		_refresh_count()
	elif int(cs["kind"]) == 2 or (int(cs["kind"]) == 1):
		var hint := CC.label(T.call("cc_raise_hint"), 13, "ink_1")
		hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if int(cs["kind"]) == 2 and profile != "L": row.add_child(hint)
	if profile == "D":
		row.add_child(_cost)
	else:                                              # touch layouts: the cost line gets its own full-width row and wraps
		_cost_holder = _cost
		_cost.size_flags_vertical = Control.SIZE_FILL
	return row

func _refresh_count() -> void:
	if _count == null: return
	var src := _source_for(_case)
	if src < 0: return
	var n := flow.troops_for(src) if flow != null else maxi(1, g.army[src] - 1)
	_count.text = "→ %d" % n

# ---------------------------------------------------------------- verbs
func _amount(key: String, n: int) -> String:
	match key:
		"gold": return CC.gold(n)
		"moves": return CC.unit(n, "u_move")
		"men": return CC.unit(n, "u_man")
		"dp": return "%d %s" % [n, T.call("u_dp")]
	return str(n)

## "Not enough gold, needs 20 g": the engine's reason plus every missing amount
func reason_text(cn: Dictionary) -> String:
	var r: String = cn["reason"]
	var key := "err_" + r
	var base: String = T.call(key) if TBI18n.has_key(key) else r
	var parts: Array = []
	var sh: Dictionary = cn["short"]
	for k in ["gold", "moves", "men", "dp"]:
		if sh.has(k): parts.append(_amount(k, int(sh[k])))
	if parts.is_empty(): return base
	return "%s, %s" % [base, T.call("cc_needs", {"x": ", ".join(parts)})]

func _cost_parts(head: String, cn: Dictionary, skip: Array = []) -> Array:
	var out: Array = [{"t": head, "short": false}]
	var sh: Dictionary = cn["short"]
	if int(cn["moves"]) > 0 and not skip.has("moves"): out.append({"t": " · " + CC.unit(int(cn["moves"]), "u_move"), "short": sh.has("moves")})
	if int(cn["gold"]) > 0 and not skip.has("gold"): out.append({"t": " · " + CC.gold(int(cn["gold"])), "short": sh.has("gold")})
	if int(cn["men"]) > 0: out.append({"t": " · " + CC.unit(int(cn["men"]), "u_man"), "short": sh.has("men")})
	if int(cn["dp"]) > 0: out.append({"t": " · %d %s" % [int(cn["dp"]), T.call("u_dp")], "short": sh.has("dp")})
	return out

func _mk(id: String, glyph_id: String, label_key: String, cn: Dictionary, parts: Array, primary: bool = false, danger: bool = false, extra: Dictionary = {}) -> Dictionary:
	var v := {"id": id, "glyph": glyph_id, "label": T.call(label_key), "can": cn, "parts": parts, "primary": primary, "danger": danger, "hot": HOT.get(id, "")}
	v["why"] = "" if cn["ok"] else reason_text(cn)
	for k in extra: v[k] = extra[k]
	return v

func _verb_specs(s: int, cs: Dictionary, src: int) -> Array:
	var me: int = cs["me"]
	var out: Array = []
	var busy_now: bool = busy_fn.is_valid() and bool(busy_fn.call())
	match int(cs["kind"]):
		1, 2:
			var held: bool = cs["held"]
			var k: int = cs["kind"]
			var rc := g.can({"cmd": "recruit", "p": s, "amount": 15})
			var hc := g.can({"cmd": "hire", "p": s, "amount": 40})
			if k == 1:
				var targets_n := flow.compute_targets().size() if (flow != null and flow.src == s) else 0
				var mv := {"ok": true, "reason": "", "gold": 0, "moves": 1, "men": 0, "dp": 0, "short": {}}
				if g.mp[me] < 1: mv["ok"] = false; mv["reason"] = "mp"; mv["short"] = {"moves": 1}
				elif flow != null and targets_n == 0 and not _has_explicit_targets(s): mv["ok"] = false; mv["reason"] = "notargets"
				out.append(_mk("move", "arrowhead", "move", mv, [{"t": T.call("cc_move_hint"), "short": false}, {"t": " · " + CC.unit(1, "u_move"), "short": mv["short"].has("moves")}], true))
				out.append(_mk("recruit", "men", "recruit", rc, _cost_parts("%s +%d" % [T.call("recruit"), int(rc["gain"])], rc), false))
			else:
				out.append(_mk("recruit", "men", "recruit", rc, _cost_parts("%s +%d" % [T.call("recruit"), int(rc["gain"])], rc), true))
			out.append(_mk("hire", "coin", "cc_hire", hc, _cost_parts("%s +%d" % [T.call("cc_hire"), int(hc["gain"])], hc)))
			if k == 1 and g.rules >= 1 and not held and g.gen[s] == 0 and g.army[s] >= TBGenerals.MIN_ARMY:
				var gc := g.can({"cmd": "appoint", "p": s})
				if gc["reason"] != "cap" or true:
					var gparts := _cost_parts(T.call("appoint_general"), gc) + [{"t": " · " + T.call("gen_slots", {"n": TBGenerals.count(g, me), "c": TBGenerals.cap(g, me)}), "short": gc["reason"] == "cap"}]
					out.append(_mk("general", "general_star", "cc_general", gc, gparts))
			var bi := _build_items(s)
			if not bi["items"].is_empty() or bi["busy"] or held or g.occupier[s] != 0:
				var bcan: Dictionary
				if held or g.occupier[s] != 0 or g.owner[s] != me: bcan = g.can({"cmd": "build", "p": s, "b": 1})
				elif bi["busy"]: bcan = g.can({"cmd": "build", "p": s, "b": 1})
				else:
					bcan = bi["best"]
				var cheapest: Dictionary = bi["best"] if bi["best"] != null else bcan
				var parts: Array = [{"t": T.call("build"), "short": false}]
				if not bi["items"].is_empty(): parts.append({"t": " · " + T.call("cc_from_gold", {"n": int(bi["min_gold"])}), "short": false})
				out.append(_mk("build", "hammer", "build", bcan, parts, false, false, {"items": bi["items"]}))
		3:
			var o: int = cs["o"]
			var rel: int = cs["rel"]
			var dl := _diplo_items(o)
			var any_ok := false
			var first_bad: Dictionary = {}
			for it in dl:
				if it["can"]["ok"]: any_ok = true
				elif first_bad.is_empty(): first_bad = it["can"]
			var dcan: Dictionary = {"ok": true, "reason": "", "gold": 0, "moves": 0, "men": 0, "dp": 0, "short": {}}
			if not any_ok and not dl.is_empty(): dcan = first_bad
			if not dl.is_empty():
				var pp: Array = [{"t": T.call("cc_diplomacy"), "short": false}]
				var mn := 99
				for it in dl: if it["can"]["dp"] > 0: mn = mini(mn, int(it["can"]["dp"]))
				if mn < 99: pp.append({"t": " · " + T.call("cc_from_dp", {"n": mn}), "short": false})
				out.append(_mk("diplo", "scroll", "cc_diplomacy", dcan, pp, true, false, {"items": dl}))
			if g.rules >= 1 and rel == D.REL_PEACE:
				var uc := g.can({"cmd": "ultimatum", "t": o, "p": s})
				if not (uc["reason"] in ["vassal", "target", "capital"]):
					var ratio := TBDiplo.ult_ratio(g, me, o)
					out.append(_mk("ult", "scales", "ultimatum", uc, _cost_parts(T.call("ultimatum"), uc) + [{"t": " · " + T.call("cc_ratio_of", {"r": "%.1f" % ratio, "n": "%.1f" % TBDiplo.ULT_RATIO}), "short": false}]))
			if rel == D.REL_PEACE or (g.overlord[o] == 0 and g.overlord[me] != o and rel != D.REL_NAP and rel != D.REL_ALLY and rel != D.REL_MARRIAGE):
				var wc := g.can({"cmd": "declareWar", "t": o})
				if wc["reason"] != "vassal":
					var wp := _cost_parts(T.call("declare_war"), wc)
					if float(wc["infamy"]) > 0.0: wp.append({"t": " · " + T.call("cc_infamy", {"n": int(wc["infamy"])}), "short": false})
					out.append(_mk("war", "swords", "cc_war", wc, wp, false, true, {"gap": true}))
		4:
			var en: int = cs["enemy"]
			var ac: Dictionary
			if src >= 0: ac = g.can({"cmd": "move", "from": src, "to": s, "troops": flow.troops_for(src)})
			else: ac = {"ok": false, "reason": "nosource", "gold": 0, "moves": 2, "men": 0, "dp": 0, "short": {}}
			var ap := _cost_parts(T.call("cc_attack"), ac)
			out.append(_mk("attack", "swords", "cc_attack", ac, ap, true))
			var pc := g.can({"cmd": "peace", "t": en, "kind": "white"})
			out.append(_mk("peace", "dove", "cc_peace", pc, _cost_parts(T.call("white_peace"), pc)))
			var tc := g.can({"cmd": "peace", "t": en, "kind": "cede"})
			if g.rules >= 1: out.append(_mk("terms", "scales", "cc_terms", tc, _cost_parts(T.call("demand_land"), tc) + [{"t": " · %s %d/25" % [T.call("war_score"), g.war_score[me * g.N1 + en]], "short": tc["reason"] == "warscore"}]))
		5:
			var cc := g.can({"cmd": "colonize", "p": s})
			out.append(_mk("colonize", "flag", "colonize", cc, _cost_parts(T.call("colonize"), cc), true))
	if busy_now:
		for v in out:
			v["can"] = {"ok": false, "reason": "busy_turn", "gold": 0, "moves": 0, "men": 0, "dp": 0, "short": {}}
			v["why"] = T.call("cc_resolving")
	return out

func _has_explicit_targets(s: int) -> bool:
	if flow == null: return true
	for q in flow._candidates(s):
		if flow.check(q, s)["valid"]: return true
	return false

## building picker content: affordable-or-not items of the province, cheapest first; permanently impossible ones are left out
func _build_items(s: int) -> Dictionary:
	var me := g.human_id
	var items: Array = []
	var best: Variant = null
	var busy: bool = g.b_building[s] != 0
	var min_gold := 0
	if g.owner[s] == me and g.occupier[s] == 0 and not busy:
		for i in D.BUILDINGS.size():
			var b: Dictionary = D.BUILDINGS[i]
			var cn := g.can({"cmd": "build", "p": s, "b": i + 1})
			if cn["reason"] in ["occupied", "max", "type", "busy", "notyours"]: continue
			var lvl: int = int(cn.get("levels", 1))
			var cur := lvl - 1
			items.append({"b": i + 1, "can": cn, "label": "%s %s" % [T.call("b_" + b["id"]), "L%d" % lvl if int(b["maxLevel"]) > 1 else ""], "turns": int(b["buildTime"][cur]), "gold": int(cn["gold"])})
		items.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return int(a["gold"]) < int(c["gold"]))
		if not items.is_empty():
			min_gold = int(items[0]["gold"])
			for it in items: if it["can"]["ok"]: best = it["can"]; break
			if best == null: best = items[0]["can"]
	return {"items": items, "busy": busy, "best": best, "min_gold": min_gold}

func _diplo_items(o: int) -> Array:
	var me := g.human_id
	var rel := g.get_rel(me, o)
	var out: Array = []
	if rel == D.REL_PEACE:
		out.append({"label": T.call("propose_nap"), "can": g.can({"cmd": "nap", "t": o}), "cmd": {"cmd": "nap", "t": o}})
		out.append({"label": T.call("propose_ally"), "can": g.can({"cmd": "ally", "t": o}), "cmd": {"cmd": "ally", "t": o}})
	if rel == D.REL_NAP:
		out.append({"label": T.call("propose_ally"), "can": g.can({"cmd": "ally", "t": o}), "cmd": {"cmd": "ally", "t": o}})
	if g.rules >= 1:
		if rel != D.REL_WAR and not TBTrade.has(g, me, o):
			out.append({"label": T.call("cc_trade"), "can": g.can({"cmd": "trade", "t": o}), "cmd": {"cmd": "trade", "t": o}})
		if TBDiplo.can_marry(g, me, o):
			out.append({"label": T.call("cc_marry"), "can": g.can({"cmd": "marry", "t": o}), "cmd": {"cmd": "marry", "t": o}})
	if rel == D.REL_NAP or rel == D.REL_ALLY:
		out.append({"label": T.call("break_pact"), "can": g.can({"cmd": "breakPact", "t": o}), "cmd": {"cmd": "breakPact", "t": o}, "danger": true})
	return out

func _build_verb_row(s: int, cs: Dictionary, src: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var specs := _verb_specs(s, cs, src)
	var h := int(maxf(TBHudParts.R(68.0), 44.0))
	row.add_theme_constant_override("separation", int(TBHudParts.R(5.0)))
	row.custom_minimum_size = Vector2(0, h)
	_verbs.clear(); _hotkeys.clear()
	for i in specs.size():
		var v: Dictionary = specs[i]
		if bool(v.get("gap", false)):
			var gp := Control.new(); gp.custom_minimum_size = Vector2(12, 0); gp.mouse_filter = Control.MOUSE_FILTER_IGNORE; row.add_child(gp)
		var b := CC.VerbBtn.new().setup(v["id"], v["glyph"], v["label"], v["hot"], bool(v["primary"]), bool(v["danger"]))
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.custom_minimum_size = Vector2(maxf(TBHudParts.R(92.0), 56.0), h)
		b.aoc = true
		b.set_blocked(not bool(v["can"]["ok"]))
		var tip: String = "%s. %s" % [v["label"], _plain(v["parts"])] if v["why"] == "" else "%s. %s: %s" % [v["label"], T.call("cc_unavailable"), v["why"]]
		b.tooltip_text = tip
		var idx := _verbs.size()
		b.pressed.connect(func(): _press(idx))
		b.mouse_entered.connect(func(): _set_focus_verb(idx))
		b.focus_entered.connect(func(): _set_focus_verb(idx))
		b.mouse_exited.connect(func(): _set_focus_verb(0))
		row.add_child(b)
		v["btn"] = b
		_verbs.append(v)
		var key: int = -1
		for kc in HOT_KEY: if HOT_KEY[kc] == v["id"] or (v["id"] == "attack" and HOT_KEY[kc] == "move"): key = kc
		if key >= 0: _hotkeys[key] = idx
	return row

func _plain(parts: Array) -> String:
	var s := ""
	for q in parts: s += String(q["t"])
	return s

func _set_focus_verb(i: int) -> void:
	_focus_verb = i
	_update_cost_line()

func _update_cost_line() -> void:
	if _cost == null: return
	if _busy: _cost.set_parts([{"t": T.call("cc_resolving"), "short": false}]); return
	var mode := _order_mode()
	if mode == "war" and _brk_target >= 0:
		_cost.set_parts([{"t": T.call("cc_break_ask", {"n": g.dname(_brk_target)}), "short": false}]); return
	if mode == "war":
		var cn := g.can({"cmd": "declareWar", "t": _war_target})
		var parts: Array = [{"t": T.call("cc_war_ask", {"n": g.dname(_war_target)}), "short": false}]
		if float(cn["infamy"]) > 0.0: parts.append({"t": " · " + T.call("cc_infamy_nocb", {"n": int(cn["infamy"])}), "short": false})
		_cost.set_parts(parts); return
	if mode == "preview" and flow != null and flow.src >= 0:
		var cn2 := g.can({"cmd": "move", "from": flow.src, "to": flow.tgt, "troops": flow.troops_for(flow.src)})
		if not cn2["ok"]: _cost.set_parts([{"t": reason_text(cn2), "short": false}], true)
		else:
			var head: String = T.call("cc_attack") if cn2["kind"] == "attack" else T.call("move")
			_cost.set_parts(_cost_parts(head, cn2))
		return
	if mode == "armed":
		_cost.set_parts([{"t": T.call("cc_move_hint") + " · " + CC.unit(1, "u_move"), "short": false}]); return
	if _verbs.is_empty():
		_cost.set_parts([]); return
	var v: Dictionary = _verbs[clampi(_focus_verb, 0, _verbs.size() - 1)]
	if v["why"] != "": _cost.set_parts([{"t": String(v["why"]), "short": false}], true)
	else: _cost.set_parts(v["parts"])

# ---------------------------------------------------------------- order rows (replace the verb row)
func _build_armed_row() -> HBoxContainer:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, CC.touch())
	var cb := CC.VerbBtn.new().setup("cancel", "close", T.call("pv_cancel"), "Esc", false, false)
	cb.custom_minimum_size = Vector2(104, CC.touch()); cb.pressed.connect(func(): if flow != null: flow.disarm())
	row.add_child(cb)
	var hint := CC.label(T.call("cc_pick_target_kb"), 13, "ink_1")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)
	return row

func _build_order_row(cs: Dictionary, src: int, mode: String) -> HBoxContainer:
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, CC.touch())
	if mode == "preview" and flow != null and flow.has_method("summary"):
		# the preview chip beside the target owns Cancel / Attack; the card only restates the order (Enter and Esc still work)
		var sm: Dictionary = flow.summary()
		var atk: bool = String(sm.get("kind", "")) == "attack"
		var line := "%s · %s" % [T.call("cc_attack") if atk else T.call("move"), CC.unit(int(sm.get("moves", 1)), "u_move")]
		if atk and int(sm.get("lost", 0)) > 0: line += " · −%s" % CC.unit(int(sm["lost"]), "u_man")
		var hint: Label = TBKit.label("%s   —   %s" % [line, T.call("pv_confirm_hint")], CC.fs(13), TBTokens.c("ink_1"))
		hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(hint)
		_verbs.clear()
		return row
	var cancel := CC.VerbBtn.new().setup("cancel", "close", T.call("pv_cancel"), "Esc", false, false)
	cancel.custom_minimum_size = Vector2(104, CC.touch())
	var ok: CC.VerbBtn
	if mode == "war" and _brk_target >= 0:
		cancel.pressed.connect(func(): _brk_target = -1; rebuild())
		var bt := _brk_target
		var bcn := g.can({"cmd": "breakPact", "t": bt})
		ok = CC.VerbBtn.new().setup("brk_ok", "swords", T.call("break_pact"), "", false, true)
		ok.set_blocked(not bcn["ok"])
		ok.pressed.connect(func():
			if not bcn["ok"]: reject_can(bcn); return
			_brk_target = -1
			command.emit({"cmd": "breakPact", "t": bt}))
	elif mode == "war":
		cancel.pressed.connect(func(): _war_target = -1; rebuild())
		var cn := g.can({"cmd": "declareWar", "t": _war_target})
		ok = CC.VerbBtn.new().setup("war_ok", "swords", "%s · %d %s" % [T.call("cc_war"), int(cn["dp"]), T.call("u_dp")], "", false, true)
		ok.set_blocked(not cn["ok"])
		ok.pressed.connect(func():
			var t := _war_target
			if not cn["ok"]: reject_can(cn); return
			_war_target = -1
			command.emit({"cmd": "declareWar", "t": t}))
	else:
		cancel.pressed.connect(func(): if flow != null: flow.cancel())
		var cn2 := g.can({"cmd": "move", "from": src, "to": flow.tgt, "troops": flow.troops_for(src)}) if (flow != null and src >= 0) else {"ok": false, "kind": "attack", "moves": 2, "men": 0, "short": {}, "reason": "notadjacent", "gain": 0, "gold": 0, "dp": 0}
		var attack: bool = cn2["kind"] == "attack"
		var label := ""
		var lost := 0
		if attack and flow != null and src >= 0:
			var pv := g.combat_preview(g.human_id, src, flow.tgt, flow.troops_for(src))
			lost = int(pv["lost"])
		label = "%s · %s" % [T.call("cc_attack") if attack else T.call("move"), CC.unit(int(cn2["moves"]), "u_move")]
		if attack and lost > 0: label += " · −%s" % CC.unit(lost, "u_man")
		ok = CC.VerbBtn.new().setup("confirm", "swords" if attack else "arrowhead", label, "↵", not attack, attack)
		ok.set_blocked(not cn2["ok"])
		ok.pressed.connect(func(): if cn2["ok"]: flow.confirm() else: reject_can(cn2))
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.custom_minimum_size = Vector2(120, CC.touch())
	row.add_child(cancel); row.add_child(ok)
	_verbs.clear()
	_verbs.append({"id": "confirm", "btn": ok, "can": {"ok": true}, "parts": [], "why": ""})
	return row

func reject_can(cn: Dictionary) -> void:
	flash(reason_text(cn))

# ---------------------------------------------------------------- verb actions
func _press(i: int) -> void:
	if i < 0 or i >= _verbs.size(): return
	var v: Dictionary = _verbs[i]
	_set_focus_verb(i)
	if _busy: flash(T.call("cc_resolving")); return
	var cn: Dictionary = v["can"]
	if not cn["ok"]: flash(String(v["why"])); return
	var s := _subject()
	match String(v["id"]):
		"move": move_requested.emit(s)
		"attack": if flow != null: flow.preview_to(s, _source_for(_case))
		"build": _open_list(v["btn"], _build_rows(v["items"]), s)
		"diplo": _open_list(v["btn"], _diplo_rows(v["items"]), s)
		"war":
			if _confirm_mode() == "never": command.emit({"cmd": "declareWar", "t": int(_case["o"])})
			else: _war_target = int(_case["o"]); rebuild()
		"ult": command.emit({"cmd": "ultimatum", "t": int(_case["o"]), "p": s})
		"recruit": command.emit({"cmd": "recruit", "p": s, "amount": 15})
		"hire": command.emit({"cmd": "hire", "p": s, "amount": 40})
		"general": command.emit({"cmd": "appoint", "p": s})
		"colonize": command.emit({"cmd": "colonize", "p": s})
		"peace": command.emit({"cmd": "peace", "t": int(_case["enemy"]), "kind": "white"})
		"terms": command.emit({"cmd": "peace", "t": int(_case["enemy"]), "kind": "cede"})

## the player's confirm setting for destructive orders (declare war, break pact): smart / always ask, never does not
func _confirm_mode() -> String:
	return String(confirm_fn.call()) if confirm_fn.is_valid() else "smart"

func _build_rows(items: Array) -> Array:
	var rows: Array = []
	for it in items:
		var cn: Dictionary = it["can"]
		var det := "%s · %s · %s" % [CC.gold(int(cn["gold"])), CC.unit(int(cn["moves"]), "u_move"), CC.unit(int(it["turns"]), "u_turn")]
		rows.append({"label": String(it["label"]).strip_edges(), "detail": det, "ok": cn["ok"], "why": reason_text(cn) if not cn["ok"] else "", "cmd": {"cmd": "build", "p": _subject(), "b": it["b"]}, "danger": false})
	return rows

func _diplo_rows(items: Array) -> Array:
	var rows: Array = []
	for it in items:
		var cn: Dictionary = it["can"]
		var det := ("%d %s" % [int(cn["dp"]), T.call("u_dp")]) if int(cn["dp"]) > 0 else ""
		rows.append({"label": it["label"], "detail": det, "ok": cn["ok"], "why": reason_text(cn) if not cn["ok"] else "", "cmd": it["cmd"], "danger": bool(it.get("danger", false))})
	return rows

func _open_list(anchor: Control, rows: Array, _s: int) -> void:
	_close_popover()
	if rows.is_empty(): return
	_popover = Popover.new()
	add_child(_popover)
	_popover.setup(rows, anchor.get_global_rect(), _vp)
	_popover.picked.connect(func(i: int):
		var r: Dictionary = rows[i]
		if not r["ok"]: flash(String(r["why"])); return
		_close_popover()
		if bool(r.get("danger", false)) and String(r["cmd"].get("cmd", "")) == "breakPact" and _confirm_mode() != "never":
			_brk_target = int(r["cmd"]["t"]); rebuild(); return        # a destructive order asks first
		command.emit(r["cmd"]))
	_popover.closed.connect(func(): _popover = null)

func _close_popover() -> void:
	if _popover != null and is_instance_valid(_popover): _popover.queue_free()
	_popover = null

## pop-up list for the Build picker and the Diplomacy list: rows with a label, a cost detail and the reason when blocked
class Popover extends PanelContainer:
	signal picked(i: int)
	signal closed
	var _rows: Array = []
	var _btns: Array = []
	func setup(rows: Array, anchor: Rect2, vp: Vector2) -> void:
		_rows = rows
		top_level = true
		z_index = 60
		var box := TBCmdCard.plate("paper_0", "rule", TBTokens.CUT, 1)
		box.set_content_margin_all(6)
		add_theme_stylebox_override("panel", box)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4)
		add_child(v)
		for i in rows.size():
			var r: Dictionary = rows[i]
			var b := TBCmdCard.VerbBtn.new().setup("row", "", "%s   %s" % [r["label"], r["detail"]], str(i + 1) if i < 9 else "", false, bool(r["danger"]))
			b.set_blocked(not bool(r["ok"]))
			b.custom_minimum_size = Vector2(300, TBCmdCard.touch())
			b.tooltip_text = String(r["why"]) if not bool(r["ok"]) else String(r["detail"])
			var idx := i
			b.pressed.connect(func(): picked.emit(idx))
			v.add_child(b); _btns.append(b)
			if not bool(r["ok"]):
				var why := TBCmdCard.label(String(r["why"]), 12, "neg"); why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; why.custom_minimum_size = Vector2(300, 0)
				v.add_child(why)
		reset_size()
		var sz := get_combined_minimum_size()
		size = sz
		position = Vector2(clampf(anchor.position.x + anchor.size.x * 0.5 - sz.x * 0.5, 6.0, maxf(6.0, vp.x - sz.x - 6.0)), maxf(6.0, anchor.position.y - sz.y - 6.0))
	func _input(e: InputEvent) -> void:
		if not visible: return
		if e is InputEventMouseButton and e.pressed:
			if not get_global_rect().has_point(e.position):
				closed.emit(); queue_free()
		elif e is InputEventKey and e.pressed and not e.echo:
			if e.keycode == KEY_ESCAPE:
				closed.emit(); queue_free(); get_viewport().set_input_as_handled()
			elif e.keycode >= KEY_1 and e.keycode <= KEY_9 and e.keycode - KEY_1 < _rows.size():
				picked.emit(e.keycode - KEY_1); get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- Details drawer (the ledger)
func _build_drawer(s: int, cs: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2 if profile != "P" else 1
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 4)
	grid.custom_minimum_size = Vector2(0, 8)
	var dash := "—"
	var bname := dash
	if g.building[s] != 0: bname = "%s %d" % [T.call("b_" + D.BUILDINGS[g.building[s] - 1]["id"]), g.b_level[s]]
	elif g.b_building[s] != 0: bname = "%s · %s" % [T.call("b_" + D.BUILDINGS[g.b_building[s] - 1]["id"]), CC.unit(g.b_turns[s], "u_turn")]
	var gen_txt := dash
	if g.rules >= 1 and g.gen[s] != 0: gen_txt = "%s %s" % ["★".repeat(mini(5, TBGenerals.skill(g, s))), TBGenerals.display_name(g, s)]
	var occ := dash
	if g.occupier[s] != 0: occ = T.call("occupied_by", {"nation": g.dname(g.occupier[s])})
	var sup := dash
	if g.rules >= 1: sup = "%s %d · %s %d" % [T.call("cc_limit"), g.supply_limit(s), T.call("attrition").to_lower(), g.attrition(s)]
	grid.add_child(_ledger_row(T.call("pop"), TBKit.fmt(g.pop[s] * 1000), null))
	grid.add_child(_ledger_row(T.call("stability"), "%d" % g.stab[s], CC.Meter.new(g.stab[s])))
	grid.add_child(_ledger_row(T.call("dev"), "%d/5" % g.dev[s], CC.Pips.new(g.dev[s])))
	grid.add_child(_ledger_row(T.call("happiness"), "%d" % g.happy[s], CC.Meter.new(g.happy[s])))
	grid.add_child(_ledger_row(T.call("econ"), "%d/5" % g.econ[s], CC.Pips.new(g.econ[s])))
	grid.add_child(_ledger_row(T.call("supply"), sup, null))
	grid.add_child(_ledger_row(T.call("terrain"), T.call("t_" + D.TERRAIN_ID[g.terrain[s]]), null))
	grid.add_child(_ledger_row(T.call("general"), gen_txt, null))
	grid.add_child(_ledger_row(T.call("building"), bname, null))
	grid.add_child(_ledger_row(T.call("cc_occupation"), occ, null))
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)
	wrap.add_child(grid)
	var hl := Control.new(); hl.custom_minimum_size = Vector2(0, 1); hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.draw.connect(func(): hl.draw_line(Vector2(0, 0.5), Vector2(hl.size.x, 0.5), CC.tk("hair"), 1.0))
	wrap.add_child(hl)
	return wrap

func _ledger_row(caption: String, value: String, extra: Control) -> Control:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 6)
	h.custom_minimum_size = Vector2(0, 26)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c := CC.label(caption, 13, "ink_1"); c.custom_minimum_size = Vector2(88, 0); c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(c)
	if extra != null:
		extra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(extra)
	var v := CC.label(value, 14, "ink_0", TBKit.mono_b() if (value.length() < 10 and not value.contains(" ")) else TBKit.body_b())
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL if extra == null else Control.SIZE_SHRINK_END
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if extra != null: v.custom_minimum_size = Vector2(34, 0)
	h.add_child(v)
	return h

# ---------------------------------------------------------------- keyboard (hotkeys act only while the card is open and nothing else owns the keyboard)
func _input_blocked() -> bool:
	if blocked_fn.is_valid() and bool(blocked_fn.call()): return true
	var f := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	return f is LineEdit or f is TextEdit

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo: return
	if e.keycode != KEY_TAB or flow == null or g == null or _input_blocked(): return
	if e.ctrl_pressed or e.alt_pressed or e.meta_pressed: return
	if _popover != null and is_instance_valid(_popover): return
	flow.cycle(-1 if e.shift_pressed else 1)
	get_viewport().set_input_as_handled()

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or g == null or _input_blocked(): return
	if e.ctrl_pressed or e.alt_pressed or e.meta_pressed: return
	var k: int = e.keycode
	if k == KEY_ESCAPE:
		if visible and back(): get_viewport().set_input_as_handled()
		return
	if k == KEY_SPACE and flow != null and flow.focus_p >= 0 and (not visible or flow.focus_p != p):
		select_requested.emit(flow.focus_p); get_viewport().set_input_as_handled(); return
	if not visible: return
	if k == KEY_ENTER or k == KEY_KP_ENTER:
		if flow != null and flow.mode == TBOrderFlow.Mode.PREVIEW: flow.confirm(); get_viewport().set_input_as_handled()
		elif (_war_target >= 0 or _brk_target >= 0) and not _verbs.is_empty(): _press_confirm(); get_viewport().set_input_as_handled()
		return
	if k == KEY_I: set_drawer(not drawer_open); get_viewport().set_input_as_handled(); return
	if _share != null and not _busy:
		if k >= KEY_1 and k <= KEY_4 and _popover == null:
			_share._pick(k - KEY_1); get_viewport().set_input_as_handled(); return
		if k == KEY_BRACKETLEFT or k == KEY_BRACKETRIGHT:
			var i := CC.ShareSeg.FRACS.find(_share.current)
			_share._pick(clampi(i + (1 if k == KEY_BRACKETRIGHT else -1), 0, 3)); get_viewport().set_input_as_handled(); return
	if _hotkeys.has(k) and _war_target < 0 and _brk_target < 0 and _order_mode() != "preview":
		_press(int(_hotkeys[k])); get_viewport().set_input_as_handled()

func _press_confirm() -> void:
	if _verbs.is_empty(): return
	((_verbs[0]["btn"]) as Button).pressed.emit()

## the card must never cover the selected province: pan the map so it stays visible
func _keep_province_visible() -> void:
	if flow == null or flow.map == null or g == null or p < 0 or not visible: return
	await get_tree().process_frame
	if not visible or flow == null or flow.map == null: return
	var m := flow.map
	var pt := m.project(g.world.lon[p], g.world.lat[p])
	var r := get_global_rect()
	var origin := m.get_global_rect().position
	var gp := Vector2(pt.x, pt.y) + origin
	if pt.z <= 0.0 or not r.grow(14.0).has_point(gp): return
	var shift := (gp.y - (r.position.y - 70.0))                   # lift the province above the card top
	if m.mode == 1: m.lat0 -= shift / m.flat_scale(); m._clamp_flat()
	else: m.lat0 = clampf(m.lat0 - shift / m.radius_px(), -1.45, 1.45)
	m._push_view()
