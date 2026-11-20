## One row of a "systems" list (government forms, institutions, estates): an icon, a title, a sentence under it that wraps, up to two meters with a caption, and an action on the right.
## Built from kit labels, so the text size setting and the type scale apply and nothing is clipped; the meters are drawn in token colours.
class_name TBInfoRow
extends HBoxContainer

const K = preload("res://src/ui/ui_kit.gd")

## meters: [{frac: 0..1, tone: token name, thick: bool, mark: 0..1 or -1}] drawn in order; caption: the small line under them
static func make(icon: String, icon_tone: String, title: String, desc: String, meters: Array, caption: String, action: Control) -> TBInfoRow:
	var r := TBInfoRow.new()
	r.add_theme_constant_override("separation", 12); r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ic := IconCell.new(icon, icon_tone); r.add_child(ic)
	var v := K.vbox(1); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.size_flags_vertical = Control.SIZE_SHRINK_CENTER; r.add_child(v)
	var t := K.label(title, 16, TBTokens.c("ink_0")); t.add_theme_font_override("font", K.body_b()); t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(t)
	if desc != "":
		var d := K.label(desc, 13, TBTokens.c("smoke")); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(d)
	if not meters.is_empty():
		v.add_child(Meters.new(meters))
		if caption != "":
			var c := K.label(caption, 12, TBTokens.c("smoke")); c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(c)
	if action != null:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER; r.add_child(action)
	return r

class IconCell extends Control:
	var icon := ""
	var tone := "brass_lt"
	func _init(i: String, t: String) -> void:
		icon = i; tone = t; custom_minimum_size = Vector2(32, 32); size_flags_vertical = Control.SIZE_SHRINK_BEGIN; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		TBBzIcons.draw(self, icon, Vector2(16, 18), 26.0, TBTokens.c(tone))

class Meters extends Control:
	var items: Array
	func _init(m: Array) -> void:
		items = m; mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var h := 3.0
		for it in items: h += (6.0 if bool(it.get("thick", false)) else 3.0) + 2.0
		custom_minimum_size = Vector2(300, h)
	func _draw() -> void:
		var y := 2.0
		for it in items:
			var th: float = 6.0 if bool(it.get("thick", false)) else 3.0
			draw_rect(Rect2(0, y, size.x, th), Color(TBTokens.c("hair")))
			draw_rect(Rect2(0, y, size.x * clampf(float(it["frac"]), 0.0, 1.0), th), Color(TBTokens.c(String(it.get("tone", "brass_lt"))), float(it.get("alpha", 1.0))))
			var mk: float = float(it.get("mark", -1.0))
			if mk >= 0.0: draw_rect(Rect2(size.x * mk - 0.75, y - 2.0, 1.5, th + 4.0), Color(TBTokens.c("smoke"), 0.85))
			y += th + 2.0
