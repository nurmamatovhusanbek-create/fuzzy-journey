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
var _date: Label
var _turn: Label
var _lens: OptionButton
var _advisor_btn: P.DockButton
var _portrait := false

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
		var b := P.DockButton.new().setup(spec[0], T.call(spec[1]), func(): sig.emit())
		_dock.add_child(b)
		if spec[0] == "lamp": _advisor_btn = b
	# ---- toasts (dispatch slips)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 5)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_toasts)
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
	_name.text = g.nat_name[n]
	var rl := ""
	if g.rules >= 1 and g.r_name[n] != "":
		rl = "%s %s" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)]
	_ruler.text = rl
	_ruler.visible = rl != ""
	_date.text = _year(g.year)
	_turn.text = "%s %d · %s" % [T.call("turn"), g.turn, T.call("month_%d" % g.month_idx) if TBI18n.has_key("month_%d" % g.month_idx) else TBData.MONTHS[g.month_idx]]
	var net: int = inc["net"]
	_r["gold"].set_value("%s" % K.fmt(g.gold[n]), K.GOLD2)
	_r["gold"].caption.text = "%s%d" % ["+" if net >= 0 else "", net]
	_r["gold"].caption.add_theme_color_override("font_color", K.GREEN if net >= 0 else K.RED)
	_r["man"].set_value("%s" % K.fmt(g.manpower[n])); _r["man"].caption.text = "/ %s" % K.fmt(inc["manCap"])
	_r["mp"].set_value("%d" % int(g.mp[n])); _r["dp"].set_value("%d" % int(g.dp[n]))
	_r["intel"].set_value("%d" % int(g.intel[n])); _r["intel"].visible = g.rules >= 1
	_r["lands"].set_value("%d" % inc["lands"])
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
	get_tree().create_timer(5.5).timeout.connect(func(): if is_instance_valid(l): l.queue_free())

func set_busy(b: bool) -> void:
	if _seal: _seal.set_busy(b); _seal.disabled = b
