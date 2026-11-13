## "Before you end the turn": the loose ends (TBLoose) in one card. Handle them takes you to the first; End turn anyway goes on, and the card does not come back this turn.
class_name TBLooseCard
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
static var ICON := {"spread_army": "spread", "idle_gold": "treasury", "idle_men": "recruit", "no_general": "general"}

static func open(parent: Control, items: Array, on_handle: Callable, on_end: Callable) -> TBPanel.Handle:
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("lc_title"), "turn", {"w": 520.0})
	h.body.add_child(TBPanel.para(T.call("lc_sub", {"n": items.size()}), 15, K.DIM))
	for it in items:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
		var ic := TBLooseIcon.new(String(ICON.get(String(it["id"]), "info")))
		row.add_child(ic)
		var tx := TBPanel.para(T.call("lc_" + String(it["id"]), {"k": K.fmt(float(it["k"]))}), 16, TBTokens.c("ink_0"))
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tx)
		h.body.add_child(row)
	var btns := HBoxContainer.new(); btns.add_theme_constant_override("separation", 10); btns.alignment = BoxContainer.ALIGNMENT_END
	var go := K.button(T.call("lc_handle"), func(): h.close(); on_handle.call(items[0]), true)
	var end := K.button(T.call("lc_end"), func(): h.close(); on_end.call())
	btns.add_child(end); btns.add_child(go)
	h.body.add_child(btns)
	return h

class TBLooseIcon extends Control:
	var glyph := ""
	func _init(g: String) -> void:
		glyph = g; custom_minimum_size = Vector2(30, 30); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		TBBzIcons.draw(self, glyph, size * 0.5, 26.0, TBTokens.c("brass_lt"))
