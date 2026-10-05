## In-game HUD: ribbon (nation, date, ledger), dock, lens selector, dispatch slips, End-Turn seal. Pure view; emits signals.
class_name TBHud
extends Control

signal end_turn_pressed
signal lens_selected(name: String)
signal nations_pressed
signal wars_pressed
signal goals_pressed
signal decisions_pressed
signal chronicle_pressed
signal advisor_pressed
signal budget_pressed
signal save_pressed
signal settings_pressed
signal tapped

const K = preload("res://src/ui/ui_kit.gd")
const P = preload("res://src/ui/hud_parts.gd")
static var T: Callable = TBI18n.T

var g: TBGame
var _r := {}                       # readouts by key
var _toasts: VBoxContainer
var _dock: BoxContainer
var _dock_holder: Control
var _ribbon: PanelContainer
var _seal: P.Seal
var _flag: TextureRect
var _name: Label
var _ruler: Label
var _cameo: TBPortrait
var seat_tag := ""                      # hot-seat: "P2" etc., shown before the ruler's name
var _date: Label
var _turn: Label
var _lens: OptionButton
var _advisor_btn: P.DockButton
var _portrait := false
var _legend: P.Legend

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func build() -> void:
	for c in get_children(): c.queue_free()
	_r.clear()
	# ---- ribbon
	_ribbon = PanelContainer.new()
	_ribbon.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_ribbon.add_theme_stylebox_override("panel", P.Ribbon.new())
	add_child(_ribbon)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 18); row.add_theme_constant_override("v_separation", 4)
	_ribbon.add_child(row)
	var nat := K.hbox(9)
	_flag = TextureRect.new(); _flag.custom_minimum_size = Vector2(38, 26); _flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _flag.stretch_mode = TextureRect.STRETCH_SCALE; _flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nat.add_child(_flag)
	_cameo = TBPortrait.new(); _cameo.custom_minimum_size = Vector2(44, 44); _cameo.visible = false
	nat.add_child(_cameo)
	var nv := VBoxContainer.new(); nv.add_theme_constant_override("separation", -1)
	_name = K.title("", 19); nv.add_child(_name)
	_ruler = K.label("", 12, K.DIM); nv.add_child(_ruler)
	nat.add_child(nv)
	row.add_child(nat)
	var dv := VBoxContainer.new(); dv.add_theme_constant_override("separation", -1)
	_date = K.num("", 17, K.GOLD2); dv.add_child(_date)
	_turn = K.caps("", 9); dv.add_child(_turn)
	row.add_child(dv)
	for spec in [["gold", "coin", "gold"], ["man", "men", "hud_man"], ["mp", "swords", "hud_mp"], ["dp", "scroll", "hud_dp"], ["intel", "eye", "hud_intel"], ["lands", "flag", "hud_prov"], ["tech", "flask", "tech"]]:
		var ro := P.Readout.new().setup(spec[1], T.call(spec[2]))
		row.add_child(ro); _r[spec[0]] = ro
	var inf := P.Readout.new().setup("skull", T.call("infamy"), K.RED); row.add_child(inf); _r["infamy"] = inf
	var wr := P.Readout.new().setup("swords", T.call("hud_wars"), K.RED); row.add_child(wr); _r["wars"] = wr
	_lens = OptionButton.new()
	_lens.focus_mode = Control.FOCUS_NONE
	_lens.custom_minimum_size = Vector2(150, 34)
	for i in TBLenses.NAMES.size():
		_lens.add_item(T.call("lens_" + TBLenses.NAMES[i]), i)
	_lens.item_selected.connect(func(idx: int): lens_selected.emit(TBLenses.NAMES[_lens.get_item_id(idx)]))
	row.add_child(_lens)
	# ---- dock
	_dock_holder = Control.new(); _dock_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dock_holder)
	_dock = BoxContainer.new(); _dock.add_theme_constant_override("separation", 6)
	_dock_holder.add_child(_dock)
	for spec in [["globe", "dk_nations", nations_pressed], ["coins", "dk_budget", budget_pressed], ["scales", "dk_decisions", decisions_pressed], ["book", "dk_chronicle", chronicle_pressed], ["trophy", "dk_goals", goals_pressed], ["lamp", "dk_advisor", advisor_pressed], ["save", "dk_save", save_pressed], ["gear", "dk_settings", settings_pressed]]:
		var sig: Signal = spec[2]
		var b := P.DockButton.new().setup(spec[0], T.call(spec[1]), func(): tapped.emit(); sig.emit())
		_dock.add_child(b)
		if spec[0] == "lamp": _advisor_btn = b
	# ---- toasts (dispatch slips)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 5)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_toasts)
	_legend = P.Legend.new(); _legend.set_anchors_preset(Control.PRESET_CENTER_BOTTOM); add_child(_legend)
	# ---- end turn seal
	_seal = P.Seal.new()
	_seal.caption = T.call("end_turn").to_upper() if TBI18n.lang != "ru" else T.call("end_turn")
	_seal.pressed.connect(func(): end_turn_pressed.emit())
	add_child(_seal)
	_ribbon.resized.connect(_place_portrait_toasts)
	layout_for(get_viewport_rect().size)

## landscape: dock runs down the left edge; portrait: along the bottom beside the seal
func layout_for(vp: Vector2) -> void:
	if _dock == null: return
	_portrait = vp.y > vp.x
	_dock.vertical = not _portrait
	_seal.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var sz := 84.0 if _portrait else 96.0
	_seal.custom_minimum_size = Vector2(sz, sz)
	_seal.offset_left = -sz - 10; _seal.offset_right = -10; _seal.offset_top = -sz - 10; _seal.offset_bottom = -10
	_toasts.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	for b in _dock.get_children(): b.custom_minimum_size = Vector2(46, 56) if _portrait else Vector2(54, 54)
	_dock.add_theme_constant_override("separation", 4 if _portrait else 6)
	if _portrait:
		_dock_holder.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_dock_holder.offset_left = 8; _dock_holder.offset_bottom = -10; _dock_holder.offset_top = -66; _dock_holder.offset_right = 8 + 8 * 46 + 7 * 4
		_toasts.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_toasts.offset_left = 10; _toasts.offset_right = 360
		_toasts.grow_vertical = Control.GROW_DIRECTION_END
		_toasts.offset_top = 140; _toasts.offset_bottom = 140
		_place_portrait_toasts.call_deferred()
	else:
		_dock_holder.set_anchors_preset(Control.PRESET_LEFT_WIDE)
		_dock_holder.offset_left = 8; _dock_holder.offset_right = 64; _dock_holder.offset_top = 92; _dock_holder.offset_bottom = -12
		_toasts.offset_left = 76; _toasts.offset_right = 420; _toasts.offset_bottom = -14; _toasts.offset_top = -14
		_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _place_portrait_toasts() -> void:
	if _toasts != null and _ribbon != null and _portrait:
		var h := maxf(_ribbon.size.y, _ribbon.get_combined_minimum_size().y)
		_toasts.offset_top = h + 10; _toasts.offset_bottom = h + 10

## vertical space the ribbon occupies (panels dock below it)
func ribbon_height() -> float:
	return _ribbon.size.y if _ribbon != null else 64.0

func refresh() -> void:
	if g == null or _r.is_empty(): return
	var n := g.human_id
	var inc := g.income(n)
	_flag.texture = TBFlags.texture(g.nat_code[n], g.color[n])
	_name.text = g.dname(n)
	var rl := ""
	if g.rules >= 1 and g.r_name[n] != "":
		rl = "%s %s" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)]
	if seat_tag != "" and rl != "": rl = "%s · %s" % [seat_tag, rl]
	_ruler.text = rl
	_ruler.visible = rl != ""
	_cameo.visible = rl != ""
	if rl != "": _cameo.setup(g, n, 44)
	_date.text = _year(g.year)
	_turn.text = "%s %d · %s" % [T.call("turn"), g.turn, T.call("month_%d" % g.month_idx) if TBI18n.has_key("month_%d" % g.month_idx) else TBData.MONTHS[g.month_idx]]
	var net: int = inc["net"]
	_r["gold"].set_num(g.gold[n], func(v: float): return K.fmt(int(round(v))), K.GOLD2)
	_r["gold"].caption.text = "%s%d" % ["+" if net >= 0 else "", net]
	_r["gold"].caption.add_theme_color_override("font_color", K.GREEN if net >= 0 else K.RED)
	_r["man"].set_num(g.manpower[n], func(v: float): return K.fmt(int(round(v)))); _r["man"].caption.text = "/ %s" % K.fmt(inc["manCap"])
	var ifmt := func(v: float): return "%d" % int(round(v))
	_r["mp"].set_num(floorf(g.mp[n]), ifmt); _r["dp"].set_num(floorf(g.dp[n]), ifmt)
	_r["intel"].set_num(floorf(g.intel[n]), ifmt); _r["intel"].visible = g.rules >= 1
	_r["lands"].set_num(float(inc["lands"]), ifmt)
	_r["tech"].set_value("%.1f" % g.tech_level[n]); _r["tech"].caption.text = T.call("era_name_%d" % g.era[n]).to_upper() if TBI18n.lang != "ru" else T.call("era_name_%d" % g.era[n])
	var wc := 0
	for o in range(1, g.N1):
		if g.alive[o] != 0 and g.get_rel(n, o) == 1: wc += 1
	_r["wars"].set_value("%d" % wc, K.RED); _r["wars"].visible = wc > 0
	_r["infamy"].set_value("%d" % int(g.infamy[n]), K.RED); _r["infamy"].visible = g.rules >= 1 and g.infamy[n] >= 5.0
	var al := TBAdvisor.alerts(g, n)
	var crit := 0
	for a in al: if a["sev"] == 2: crit += 1
	_advisor_btn.badge = al.size(); _advisor_btn.badge_col = K.RED if crit > 0 else K.GOLD2; _advisor_btn.queue_redraw()

static func _year(y: int) -> String:
	return "%d BC" % -y if y < 0 else "%d AD" % y

## dispatch slip: ruled paper-dark strip, crimson rule for bad news
## battle preview banner above the dock: strengths, the exact outcome, Attack / Cancel
var _preview: PanelContainer
func hide_preview() -> void:
	if is_instance_valid(_preview): _preview.queue_free()
	_preview = null

func show_preview(info: Dictionary, place: String, on_ok: Callable, on_cancel: Callable) -> void:
	hide_preview()
	var win: bool = info["win"]
	var edge := Color(0.55, 0.9, 0.6, 0.9) if win else Color(K.RED.r, K.RED.g, K.RED.b, 0.9)
	_preview = PanelContainer.new()
	_preview.add_theme_stylebox_override("panel", TBFrame.make(Color(0.035, 0.055, 0.11, 0.96), edge, 8, true, 14, 10))
	var v := K.vbox(6); _preview.add_child(v)
	var head := K.hbox(8); head.add_child(K.glyph_label_big("swords")); head.add_child(K.title(T.call("pv_title", {"p": place}), 17, K.GOLD2)); v.add_child(head)
	# strength bar: your force against the defenders
	var a: float = info["atk"]; var d: float = info["dfn"]
	var share := a / maxf(0.01, a + d)
	var bar := Control.new(); bar.custom_minimum_size = Vector2(320, 12)
	bar.draw.connect(func():
		var w := bar.size.x
		bar.draw_rect(Rect2(0, 2, w, 8), Color(0.8, 0.3, 0.28, 0.85))
		bar.draw_rect(Rect2(0, 2, w * share, 8), Color(0.45, 0.85, 0.55, 0.95))
		bar.draw_rect(Rect2(w * 0.5 - 1, 0, 2, 12), Color(1, 1, 1, 0.7)))
	v.add_child(bar)
	v.add_child(K.row(T.call("pv_force"), "%s  vs  %s" % [K.fmt(int(info["send"])), K.fmt(int(info["defenders"]))], K.TEXT))
	var res: String
	if win: res = T.call("pv_win", {"k": int(info["hold"]), "l": int(info["lost"])})
	else: res = T.call("pv_lose", {"a": int(info["lost"]), "d": int(info["enemy_lost"])})
	var rl := K.label(res, 14, Color(0.6, 0.95, 0.65) if win else K.RED.lightened(0.3)); rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rl.custom_minimum_size = Vector2(320, 0); v.add_child(rl)
	var row := K.hbox(8); v.add_child(row)
	row.add_child(K.button(T.call("pv_cancel"), func(): hide_preview(); on_cancel.call()))
	var ok := K.button(T.call("pv_attack"), func(): hide_preview(); on_ok.call(), true); ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(ok)
	_preview.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_preview.grow_horizontal = Control.GROW_DIRECTION_BOTH; _preview.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_preview.offset_bottom = -126 if _portrait else -110
	_preview.offset_left = -190 + (60 if not _portrait else 0); _preview.offset_right = 190 + (60 if not _portrait else 0)
	add_child(_preview)

func toast(msg: String, bad: bool = false) -> void:
	if _toasts == null: return
	var rule_c := Color(K.RED.r, K.RED.g, K.RED.b, 0.85) if bad else Color(K.GOLD.r, K.GOLD.g, K.GOLD.b, 0.55)
	var l := PanelContainer.new()
	l.add_theme_stylebox_override("panel", TBFrame.make(Color(0.035, 0.055, 0.11, 0.93), rule_c, 6, false, 12, 6))
	var t := K.label(msg, 14, K.RED.lightened(0.35) if bad else K.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; t.custom_minimum_size = Vector2(300, 0)
	l.add_child(t)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_child(l)
	while _toasts.get_child_count() > 5: _toasts.get_child(0).queue_free(); break
	get_tree().create_timer(5.5).timeout.connect(l.queue_free)      # a method callable: dropped automatically if the toast is gone

func set_lens_legend(lens: String) -> void:
	if _legend != null: _legend.setup(lens)
	_place_legend()

func _place_legend() -> void:
	if _legend == null: return
	var h := _legend.custom_minimum_size.y
	_legend.size = Vector2(340, h)
	_legend.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_legend.offset_left = -170 + (60 if not _portrait else 0); _legend.offset_right = 170 + (60 if not _portrait else 0)
	_legend.offset_bottom = -14 if not _portrait else -78; _legend.offset_top = _legend.offset_bottom - h

func set_seal_pulse(on: bool) -> void:
	if _seal: _seal.set_pulse(on)

func set_busy(b: bool) -> void:
	if _seal: _seal.set_busy(b); _seal.disabled = b
