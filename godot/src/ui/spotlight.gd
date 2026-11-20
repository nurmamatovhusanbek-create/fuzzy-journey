## The tutorial's pointer: a brass ring and a faint glow around the real controls a step talks about, drawn above the dialog (the dialog's own dim stays under it). Ignores the mouse.
class_name TBSpotlight
extends Control

var rects: Array = []                       # global rects of what to ring

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_level = true
	z_index = 5                              # above the dialog it belongs to

func point_at(list: Array) -> void:
	rects = list
	var vp := get_viewport()
	if vp != null: size = vp.get_visible_rect().size
	position = Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	for r in rects:
		var rc: Rect2 = (r as Rect2).grow(6.0)
		draw_rect(rc.grow(5.0), TBTokens.with_a(TBTokens.c("brass_lt"), 0.10), true)
		draw_rect(rc, TBTokens.with_a(TBTokens.c("brass_lt"), 0.95), false, 2.0)
		draw_rect(rc.grow(4.0), TBTokens.with_a(TBTokens.c("brass_lt"), 0.35), false, 1.0)
