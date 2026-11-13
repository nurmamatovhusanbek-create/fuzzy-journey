## "How many?" for Recruit and Hire: a bar docked at the bottom of the map, in the way of AoC2's army slider (docs/WAR_DESIGN.md section 2).
## [province, cost, army after] [-] slider with its preset marks [+] number [confirm] [cancel]  -- all in one row, every plate and glyph centred (tests/recruit_grid.gd measures it).
## The bar only asks; `confirmed(amount)` carries the number and the owner sends the command. The cost is read from the game's own `can`, so it can never disagree with the command.
class_name TBRecruitCard
extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")
const CC = preload("res://src/ui/cmd_card.gd")
static var T: Callable = TBI18n.T

signal confirmed(amount: int)
signal cancelled

var g: TBGame
var p := -1
var kind := "recruit"                 # "recruit" | "hire" | "raise" (rules 5: the levy pool first, the rest hired) | "disband" (rules 5: men go home, half back to the levy pool)
var picker: TBTroopPicker
var _name: TBBz.TLabel
var _price: Label
var _split: Label
var _army: Label
var _ok: Button
var _cancel: Button

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30
	add_theme_stylebox_override("panel", TBBz.plate_box(8.0, true))
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 16)
	for side in ["top", "bottom"]: pad.add_theme_constant_override("margin_" + side, 10)
	add_child(pad)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); row.alignment = BoxContainer.ALIGNMENT_CENTER; pad.add_child(row)
	var left := VBoxContainer.new(); left.add_theme_constant_override("separation", 1); left.custom_minimum_size.x = 118; left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name = K.title("", 14, TBTokens.c("ink_0"), 0.12, 14.0 * 1.1) as TBBz.TLabel; _name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_name)
	_price = K.label("", 14, TBTokens.c("brass_lt")); _price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_price)
	_split = K.label("", 12.5, TBTokens.c("ink_1")); _split.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_split)
	_army = K.label("", 12.5, K.DIM); _army.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; left.add_child(_army)
	row.add_child(left)
	picker = TBTroopPicker.new(); picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL; picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(picker)
	_ok = _plate("check", true, func(): _confirm())
	_cancel = _plate("close", false, func(): cancelled.emit())
	for b in [_ok, _cancel]: (b as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_ok); row.add_child(_cancel)

## an icon-only notched plate (the kit's button would turn to its text-wrapping mode at large text and lose the icon): the same width for both, the glyph in the middle
func _plate(glyph: String, primary: bool, cb: Callable) -> Button:
	return TBRecruitCard.plate(glyph, TBBz.V.PRI if primary else TBBz.V.SEC, cb)

static func plate(glyph: String, variant: int, cb: Callable) -> Button:
	var b := TBBz.Btn.new("", variant, false)
	b.glyph = glyph
	b.pressed.connect(cb)
	return b

## range and first value come from the game; the numbers the command accepts are the bar's range
func open(game: TBGame, province: int, what: String = "recruit") -> void:
	g = game; p = province; kind = what
	var r := TBRecruitCard.range_for(g, p, kind)
	var verb: String = T.call("recruit") if kind == "recruit" else (T.call("cc_raise") if kind == "raise" else (T.call("cc_disband") if kind == "disband" else T.call("cc_hire")))
	_name.text = TBI18n.place(g.pname(p)); _name.refit()
	picker.setup(r.x, r.y, clampi(r.z, r.x, r.y), verb, false, true)
	if not picker.changed.is_connected(_on_amount): picker.changed.connect(_on_amount)
	TBKit.a11y(_ok, verb, "button"); TBKit.a11y(_cancel, T.call("pv_cancel"), "button")
	_ok.tooltip_text = verb; _cancel.tooltip_text = T.call("pv_cancel")
	picker.tooltip_text = T.call("rc_ready", {"k": g.levy[p], "c": g.levy_cap(p)}) if (g.rules >= 4 and kind in ["recruit", "raise"]) else ""
	_on_amount(picker.value)
	visible = true
	reset_size()

## (lowest, highest, first) number of men the bar offers: the command's own limits; the first is what the old one-press button raised
static func range_for(game: TBGame, province: int, what: String) -> Vector3i:
	if what == "hire": return Vector3i(10, 60, 40)
	if what == "disband":
		var dh: int = TBRaise.disband_max(game, province)
		return Vector3i(mini(1, dh), maxi(1, dh), clampi(dh / 2, 1, maxi(1, dh)))
	if what == "raise":
		var hi: int = TBRaise.max_amount(game, province)
		return Vector3i(mini(1, hi), maxi(1, hi), clampi(TBRaise.default_amount(game, province), 1, maxi(1, hi)))
	return game.recruit_range(province)

func _cmd(n: int) -> Dictionary: return {"cmd": kind, "p": p, "amount": n}

func _on_amount(n: int) -> void:
	if g == null: return
	var c := g.can(_cmd(n))
	var parts := PackedStringArray()
	if int(c.get("gold", 0)) > 0: parts.append(CC.gold(int(c["gold"])))
	if int(c.get("men", 0)) > 0: parts.append(CC.unit(int(c["men"]), "u_man"))
	_price.text = " · ".join(parts)
	_split.text = ""
	if kind == "raise" and c.has("levy"):                                   # where the men come from, and what the mix saves against hiring them all
		_split.text = String(T.call("rc_split", {"l": TBKit.fmt(int(c["levy"])), "h": TBKit.fmt(int(c["hired"]))})) if int(c["hired"]) > 0 else String(T.call("rc_split_levy"))
		if int(c.get("saved", 0)) > 0 and int(c["levy"]) > 0: _split.text += "  ·  " + String(T.call("rc_saved", {"g": CC.gold(int(c["saved"]))}))
	if kind == "disband": _split.text = String(T.call("rc_disband_back", {"n": TBKit.fmt(int(c.get("levy", 0)))}))
	var ok: bool = bool(c.get("ok", false))
	_ok.disabled = not ok
	if ok:
		_army.text = T.call("rc_army", {"a": g.army[p], "b": (g.army[p] - n) if kind == "disband" else mini(TBGame.ARMY_CAP, g.army[p] + n)})
		_army.add_theme_color_override("font_color", K.DIM)
	else:
		var rk := "err_" + String(c.get("reason", ""))
		_army.text = String(T.call(rk)) if TBI18n.has_key(rk) else String(c.get("reason", ""))
		_army.add_theme_color_override("font_color", TBTokens.c("neg"))
	reset_size()

func _confirm() -> void:
	if g == null or not bool(g.can(_cmd(picker.value)).get("ok", false)): return
	confirmed.emit(picker.value)

## docked at the bottom of the map, centred, above the lens bar (the map is free above it: the province stays in view)
func place(_map: TBMapView, host: Control) -> void:
	if g == null or p < 0 or not visible: return
	custom_minimum_size.x = clampf(host.size.x - 48.0, 520.0, 920.0 if TBKit.text_scale < 1.4 else 1240.0)
	reset_size()
	var sz := size
	position = Vector2(floorf((host.size.x - sz.x) * 0.5), floorf(host.size.y - sz.y - 84.0))
