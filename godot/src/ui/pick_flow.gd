## Nation pick on the map (nation-pick.md stages 2-3): the map is the hero. Top: Back, the instruction slip with the three step pips, List.
## Bottom: tier segmented + shortlist rail (Random first). A non-modal confirm card (ruler, size rank, army, tech, start difficulty) with the
## primary "Play as X"; tapping another nation swaps the card in place. The map stays live; Android Back closes the card first.
class_name TBPickFlow
extends Control

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
const HOT_COLORS := [0xC63A4A, 0x3A7AC6, 0x3AA66A, 0xC6A23A]

signal play(n: int)
signal back_requested
signal list_requested

var g: TBGame
var map: TBMapView
var st := {}
var hot_n := 0
var hot_list := PackedInt32Array()
var sel := -1
var tier := "powers"
var _slip: PanelContainer
var _slip_label: Label
var _card: PanelContainer
var _card_sc: ScrollContainer          # the card body scrolls inside the viewport; the primary below it is pinned
var _card_v: VBoxContainer
var _card_go: VBoxContainer            # pinned footer of the card: "Play as X" (+ seat line)
var _rail: PanelContainer
var _rail_row: HBoxContainer
var _tier_seg: Control
var _back_btn: Button
var _list_btn: Button
var _shown_at := 0
var _hint_override := ""

func setup(game: TBGame, map_view: TBMapView, hot_count: int, picked: PackedInt32Array) -> TBPickFlow:
	g = game; map = map_view; hot_n = hot_count; hot_list = picked
	st = TBNationsScreen.compute(g)
	set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_btn = K.button(T.call("back"), func(): back_requested.emit())
	_back_btn.icon = null
	add_child(_back_btn)
	K.a11y(_back_btn, T.call("back"), "button")
	_list_btn = K.button(T.call("nations"), func(): list_requested.emit())
	add_child(_list_btn)
	# slip
	_slip = PanelContainer.new(); _slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slip.add_theme_stylebox_override("panel", _aoc_box(14, 8))
	var sv := K.vbox(4); sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slip.add_child(sv)
	_slip_label = K.title("", 17); _slip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; _slip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _slip_label.custom_minimum_size.x = 120
	sv.add_child(_slip_label)
	var steps := TBMenuParts.Steps.new(1, false); steps.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sv.add_child(steps)
	add_child(_slip)
	# rail
	_rail = PanelContainer.new()
	_rail.add_theme_stylebox_override("panel", _aoc_box(10, 8))
	var rv := K.vbox(8); _rail.add_child(rv)
	_tier_seg = TBPanel.seg([["powers", T.call("tier_powers")], ["regional", T.call("tier_regional")], ["minor", T.call("tier_minor")]], tier, func(id: String): tier = id; _fill_rail())
	rv.add_child(_tier_seg)
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 68); sc.follow_focus = true
	_rail_row = K.hbox(8); sc.add_child(_rail_row)
	rv.add_child(sc)
	add_child(_rail)
	# card (non-modal)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", _aoc_box(14, 10))
	var cov := K.vbox(8); _card.add_child(cov)
	_card_sc = ScrollContainer.new(); _card_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; _card_sc.follow_focus = true; _card_sc.scroll_deadzone = 12
	_card_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; _card_sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cov.add_child(_card_sc)
	_card_v = K.vbox(8); _card_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; _card_sc.add_child(_card_v)
	_card_go = K.vbox(4); cov.add_child(_card_go)
	_card.visible = false
	add_child(_card)
	_card_v.minimum_size_changed.connect(_card_changed)
	_card_go.minimum_size_changed.connect(_card_changed)
	refresh_hint()
	_fill_rail()
	resized.connect(_layout)
	_layout.call_deferred()
	(func(): await get_tree().process_frame; _layout()).call_deferred()
	return self

func hot_seat() -> bool: return hot_n > 1

## AoC panel: dark translucent body, thin rule, 4 px corners
static func _aoc_box(px: int, py: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TBTokens.ca("paper_0", 0.93); sb.border_color = TBTokens.c("rule"); sb.set_border_width_all(1); sb.set_corner_radius_all(4)
	sb.content_margin_left = px; sb.content_margin_right = px; sb.content_margin_top = py; sb.content_margin_bottom = py
	return sb

func refresh_hint() -> void:
	var t: String = _hint_override
	if t == "":
		t = T.call("hot_pick", {"k": hot_list.size() + 1, "n": hot_n}) if hot_seat() else T.call("pick_nation")
	_slip_label.text = t

## map tap (province p): light the whole nation and show its card; sea / unclaimed land says so
func on_map_pick(p: int) -> void:
	if p < 0 or g.owner[p] == 0:
		_hint_override = T.call("unclaimed"); refresh_hint()
		get_tree().create_timer(2.0).timeout.connect(func(): _hint_override = ""; if is_instance_valid(self): refresh_hint())
		return
	select_nation(g.owner[p], false)

func select_nation(n: int, fly: bool) -> void:
	sel = n
	var cap: int = g.capital_of[n]
	if cap < 0:
		var own := g.owned(n)
		cap = own[0] if own.size() > 0 else -1
	if map.has_method("highlight_nation"): map.call("highlight_nation", n)        # whole nation lit, the rest dimmed (map agent API)
	elif cap >= 0: map.select(cap)
	if cap >= 0 and fly: map.fly_to(g.world.lon[cap], g.world.lat[cap], 2.4 if map.mode == 0 else maxf(map.zoom, 3.0))
	_build_card(n)
	_card.visible = true
	_shown_at = Time.get_ticks_msec()
	_layout()
	(func(): await get_tree().process_frame; if is_instance_valid(self): _layout()).call_deferred()
	# keep the rail's selection honest
	for c in _rail_row.get_children():
		if c is RailChip:
			(c as RailChip).selected = (c as RailChip).n == n
			if (c as RailChip).n == n: ((c.get_parent().get_parent()) as ScrollContainer).ensure_control_visible.call_deferred(c)

## Back: dismiss the card first; returns true when it consumed the press
func pop() -> bool:
	if _card != null and _card.visible:
		_card.visible = false; sel = -1
		_clear_map_highlight()
		for c in _rail_row.get_children():
			if c is RailChip: (c as RailChip).selected = false
		return true
	return false

func _card_changed() -> void:
	if _card != null and _card.visible: _layout.call_deferred()

func _clear_map_highlight() -> void:
	if map != null and is_instance_valid(map):
		if map.has_method("clear_highlight"): map.call("clear_highlight")

func _exit_tree() -> void:
	_clear_map_highlight()

func _unhandled_key_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_R and not TBPanel.any_open(get_parent()):
		_random(); get_viewport().set_input_as_handled()

func _members() -> Array:
	var out: Array = []
	for n in st["by_p"]:
		if TBNationsScreen.tier_of(int(st["rank_p"][n])) == tier: out.append(n)
	return out

func _random() -> void:
	var cand: Array = []
	for n in _members():
		if not hot_list.has(n): cand.append(n)
	if cand.is_empty(): return
	select_nation(cand[randi() % cand.size()], true)

class RailChip extends Button:
	var n := 0
	var title_text := ""
	var sub := ""
	var tex: Texture2D
	var selected := false:
		set(v): selected = v; queue_redraw()
	var badge := ""
	func _init(nation: int, ttl: String, subline: String, flag: Texture2D, cb: Callable) -> void:
		n = nation; title_text = ttl; sub = subline; tex = flag
		text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(maxf(132.0, TBKit.body_b().get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(14)).x + 56.0), 64)
		for s in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(s, TBKit._empty)
		pressed.connect(cb)
		TBKit.a11y(self, "%s, %s" % [ttl, subline], "button")
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		var hot := is_hovered()
		var fill: String = "paper_2" if selected else ("paper_hover" if hot else "paper_0")
		draw_style_box(TBFrame.plate(TBTokens.c(fill), TBTokens.c("ink_1") if selected else TBTokens.c("rule"), 4, 0, 0, 0), Rect2(0, 0, size.x, size.y))
		if selected: draw_rect(Rect2(4, size.y - 3, size.x - 8, 3), TBTokens.c("oxblood"))
		var ink: Color = TBTokens.c("ink_0")
		var dim: Color = TBTokens.c("ink_1")
		var x := 10.0
		if tex != null: draw_texture_rect(tex, Rect2(x, 10, 30, 20), false); x += 38.0
		else: TBGlyph.draw(self, "globe", Vector2(x + 12, 20), 22.0, ink); x += 38.0
		var f := TBKit.body_b()
		draw_string(f, Vector2(x, 25), title_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 8.0, TBKit.fs(14), ink)
		var fm := TBKit.mono()
		draw_string(fm, Vector2(10, 52), sub, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, TBKit.fs(12), dim)
		if badge != "":
			var bw: float = TBKit.mono_b().get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(12)).x
			draw_rect(Rect2(size.x - bw - 14.0, 4, bw + 8.0, 16), TBTokens.c("warn_bar"))
			draw_string(TBKit.mono_b(), Vector2(size.x - bw - 10.0, 17), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(12), TBTokens.c("ink_0"))
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(false, 4, 0), Rect2(0, 0, size.x, size.y))

func _fill_rail() -> void:
	for c in _rail_row.get_children(): c.queue_free()
	var rnd := RailChip.new(-1, T.call("random"), T.call("random_sub"), null, _random)
	_rail_row.add_child(rnd)
	var members := _members()
	for i in mini(members.size(), 40):
		var n: int = members[i]
		var chip := RailChip.new(n, g.dname(n), "#%d · %d" % [int(st["rank_p"][n]), int(st["prov"][n])], TBFlags.texture(g.nat_code[n], g.color[n]), func(): select_nation(n, true))
		if hot_list.has(n): chip.badge = "P%d" % (hot_list.find(n) + 1)
		chip.selected = n == sel
		_rail_row.add_child(chip)
	if members.size() > 40:
		var more := K.button(T.call("nations") + " ›", func(): list_requested.emit()); more.custom_minimum_size = Vector2(0, 64)
		_rail_row.add_child(more)

func _vp() -> Vector2:
	return size if size.x > 2.0 else get_viewport_rect().size

func _build_card(n: int) -> void:
	for c in _card_v.get_children(): c.queue_free()
	for c in _card_go.get_children(): c.queue_free()
	var vs := _vp()
	var compact: bool = TBPanel.stacked(vs)                     # portrait and short landscape: three rows, no facts grid
	var top := K.hbox(10); _card_v.add_child(top)
	top.add_child(TBFlags.chip(g, n, 1.0 if compact else 1.1))
	var nl := K.title(g.dname(n), 18 if compact else 20); nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nl.custom_minimum_size.x = 40
	top.add_child(nl)
	var x := K.IconBtn.new("close", func(): pop(), 40); K.a11y(x, T.call("close"), "button"); top.add_child(x)
	if g.rules >= 1 and g.r_name[n] != "":                       # ruler as one text line (the portrait lives in the Nation card only)
		var rl := TBPanel.para("%s %s · %s" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n), T.call("ruler_age", {"a": TBRulers.age(g, n)})], 14, TBTokens.c("oxblood"))
		_card_v.add_child(rl)
	var count: int = st["ids"].size()
	var rt := TBNationsScreen.start_rating(g, n, st)
	var cf := TBPanel.flow(6)
	if compact:
		cf.add_child(K.chip("%d · #%d" % [int(st["prov"][n]), int(st["rank_p"][n])], "flag", "own"))
		cf.add_child(K.chip("%s · #%d" % [K.fmt(float(st["army"][n])), int(st["rank_a"][n])], "swords", "neutral"))
		cf.add_child(K.chip("%s %.1f" % [T.call("era_name_%d" % g.era[n]), g.tech_level[n]], "flask", "neutral"))
		cf.add_child(TBNationsScreen.rating_chip(rt))
		_card_v.add_child(cf)
	else:
		var rows: Array = [
			[T.call("lands"), "%d · #%d / %d" % [int(st["prov"][n]), int(st["rank_p"][n]), count]],
			[T.call("total_army"), "%s · #%d" % [K.fmt(float(st["army"][n])), int(st["rank_a"][n])]],
			[T.call("tech"), "%s %.1f · #%d" % [T.call("era_name_%d" % g.era[n]), g.tech_level[n], int(st["rank_t"][n])]],
			[T.call("govt"), "%s · %s" % [T.call("g_" + TBData.REGIME_ID[g.regime[n]]), T.call("pers_" + TBData.PERSONALITIES[g.personality[n]]["id"])]]]
		_card_v.add_child(TBPanel.facts_grid(rows, 1))
		cf.add_child(TBNationsScreen.rating_chip(rt)); _card_v.add_child(cf)
	_card_v.add_child(TBPanel.para(TBNationsScreen.rating_reason(rt), 13, K.DIM))
	var taken := hot_list.has(n)
	if taken: cf.add_child(K.chip(T.call("taken_by_seat", {"p": "P%d" % (hot_list.find(n) + 1)}), "lock", "warn"))
	# pinned footer: the one primary of the card, always on screen
	var go := K.button(T.call("play_as", {"nation": g.dname(n)}), func():
		if Time.get_ticks_msec() - _shown_at < 300: return              # ignore the tap that opened the card
		play.emit(n), true)
	go.custom_minimum_size = Vector2(0, K.touch() if compact else maxi(56, K.touch()))
	go.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if taken: K.disable(go, T.call("taken_by_seat", {"p": "P%d" % (hot_list.find(n) + 1)}))
	_card_go.add_child(go)
	if hot_seat():
		var seat := K.hbox(6)
		seat.add_child(K.color_chip(HOT_COLORS[hot_list.size() % HOT_COLORS.size()]))
		seat.add_child(K.label(T.call("hot_seat_you", {"k": hot_list.size() + 1}), 13, K.DIM))
		_card_go.add_child(seat)
	if TBFrame.kbd_nav: go.grab_focus.call_deferred()

func _layout() -> void:
	if g == null: return
	var vs := _vp()
	var portrait := TBPanel.is_portrait(vs)
	var row_h: float = float(K.touch())
	_back_btn.position = Vector2(10, 10); _back_btn.size = Vector2(maxf(_back_btn.get_combined_minimum_size().x, 96.0), row_h)
	var lw: float = maxf(_list_btn.get_combined_minimum_size().x, 120.0)
	_list_btn.position = Vector2(vs.x - lw - 10.0, 10); _list_btn.size = Vector2(lw, row_h)
	_slip.reset_size()
	var sw: float = minf(maxf(_slip.get_combined_minimum_size().x, 300.0), vs.x - 24.0 - (0.0 if portrait else (2.0 * (maxf(96.0, lw) + 20.0))))
	_slip.custom_minimum_size = Vector2(sw, 0); _slip.reset_size()
	if portrait: _slip.position = Vector2(roundf((vs.x - _slip.size.x) * 0.5), 10.0 + row_h + 8.0)
	else: _slip.position = Vector2(roundf((vs.x - _slip.size.x) * 0.5), 10.0)
	_rail.reset_size()
	var rail_w: float = vs.x - 24.0 if portrait else vs.x - 24.0 - 356.0
	_rail.custom_minimum_size = Vector2(rail_w, 0); _rail.reset_size()
	_rail.position = Vector2(12.0, vs.y - _rail.size.y - 12.0)
	# the card is clamped to the viewport: the body scrolls, "Play as X" stays pinned. Portrait: between the slip and the rail, never over Back / Nations.
	var cw: float = vs.x - 24.0 if portrait else minf(340.0, vs.x - 24.0)
	var top_y: float = (_slip.position.y + _slip.size.y + 8.0) if portrait else (10.0 + row_h + 8.0)
	var bottom_y: float = (_rail.position.y - 8.0) if portrait else (vs.y - 12.0)
	var avail: float = maxf(bottom_y - top_y, 160.0)
	var chrome: float = 12.0 * 2.0 + 8.0 + _card_go.get_combined_minimum_size().y + 4.0           # card padding + gap + pinned footer
	var body_min: float = _card_v.get_combined_minimum_size().y
	_card_sc.custom_minimum_size = Vector2(0, clampf(body_min, 40.0, maxf(avail - chrome, 40.0)))
	_card.custom_minimum_size = Vector2(cw, 0); _card.reset_size()
	if _card.size.y > avail: _card.size.y = avail
	_card.size.x = cw
	if portrait: _card.position = Vector2(12.0, maxf(top_y, bottom_y - _card.size.y))
	else: _card.position = Vector2(vs.x - cw - 12.0, top_y)
