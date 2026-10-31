## "How many?" for Recruit and Hire: a chip beside the province with the troop picker, the live price and the two buttons (docs/WAR_DESIGN.md section 2).
## The card only asks; `confirmed(amount)` carries the number and the owner sends the command. The price line is read from the game's own `can` so it can never disagree with the command.
class_name TBRecruitCard
extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")
const CC = preload("res://src/ui/cmd_card.gd")
static var T: Callable = TBI18n.T

signal confirmed(amount: int)
signal cancelled

var g: TBGame
var p := -1
var kind := "recruit"                 # "recruit" | "hire"
var picker: TBTroopPicker
var _cap: TBBz.TLabel
var _name: TBBz.TLabel
var _price: Label
var _why: Label
var _ok: Button
var _cancel: Button
var _box: VBoxContainer

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 30
	custom_minimum_size = Vector2(340, 0)
	add_theme_stylebox_override("panel", TBBz.plate_box(8.0, true))
	var pad := MarginContainer.new()
	for side in ["left", "right"]: pad.add_theme_constant_override("margin_" + side, 17)
	for side in ["top", "bottom"]: pad.add_theme_constant_override("margin_" + side, 15)
	add_child(pad)
	_box = VBoxContainer.new(); _box.add_theme_constant_override("separation", 8); pad.add_child(_box)
	_cap = K.caps("", 10) as TBBz.TLabel; _box.add_child(_cap)
	_name = K.title("", 19, Color.TRANSPARENT, 0.06, 19.0 * 1.1) as TBBz.TLabel; _box.add_child(_name)
	picker = TBTroopPicker.new(); _box.add_child(picker)
	_price = K.label("", 14); _price.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _box.add_child(_price)
	_why = K.label("", 13, TBTokens.c("neg")); _why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _why.visible = false; _box.add_child(_why)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); _box.add_child(row)
	_ok = K.button(T.call("recruit"), func(): _confirm(), true, false, "recruit"); _ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_ok)
	_cancel = K.button(T.call("pv_cancel"), func(): cancelled.emit()); row.add_child(_cancel)

## range and first value come from the game; the numbers the command accepts are the card's range
func open(game: TBGame, province: int, what: String = "recruit") -> void:
	g = game; p = province; kind = what
	var r := TBRecruitCard.range_for(g, p, kind)
	_cap.text = T.call("recruit") if kind == "recruit" else T.call("cc_hire"); _cap.refit()
	_name.text = TBI18n.place(g.world.name[p]); _name.refit()
	picker.setup(r.x, r.y, clampi(r.z, r.x, r.y), T.call("recruit") if kind == "recruit" else T.call("cc_hire"), true)
	if not picker.changed.is_connected(_on_amount): picker.changed.connect(_on_amount)
	_on_amount(picker.value)
	visible = true
	reset_size()

## (lowest, highest, first) number of men the card offers: the command's own limits; the first is what the old one-press button raised
static func range_for(game: TBGame, province: int, what: String) -> Vector3i:
	if what == "hire": return Vector3i(10, 60, 40)
	return game.recruit_range(province)

func _cmd(n: int) -> Dictionary: return {"cmd": kind, "p": p, "amount": n}

func _on_amount(n: int) -> void:
	if g == null: return
	var c := g.can(_cmd(n))
	var parts := PackedStringArray()
	if int(c.get("gold", 0)) > 0: parts.append(CC.gold(int(c["gold"])))
	if int(c.get("men", 0)) > 0: parts.append(CC.unit(int(c["men"]), "u_man"))
	_price.text = T.call("rc_price", {"p": " · ".join(parts)})
	var ok: bool = bool(c.get("ok", false))
	_ok.disabled = not ok
	_why.visible = not ok
	if not ok: _why.text = String(T.call("err_" + String(c.get("reason", "")))) if TBI18n.has_key("err_" + String(c.get("reason", ""))) else String(c.get("reason", ""))
	reset_size()

func _confirm() -> void:
	if g == null or not bool(g.can(_cmd(picker.value)).get("ok", false)): return
	confirmed.emit(picker.value)

## beside the province, flipped to its left when it does not fit (the order chip's rule)
func place(map: TBMapView, host: Control) -> void:
	if g == null or p < 0 or not visible: return
	var pt := map.project(g.world.lon[p], g.world.lat[p])
	reset_size()
	var sz := size
	var x: float = pt.x + 70.0
	if x + sz.x > host.size.x - 28.0: x = pt.x - 70.0 - sz.x
	var y: float = clampf(pt.y - sz.y * 0.5, 150.0, maxf(150.0, host.size.y - sz.y - 120.0))
	position = Vector2(x, y).floor()
