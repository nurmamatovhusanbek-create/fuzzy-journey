## The call to arms that reaches a human ally (rules 4, docs/WAR_DESIGN.md section 11), as the chosen mock D2: an announcement in the war dialog's language, the two flags face
## to face, the reasons as chips, how willing you are as a bar, and what refusing costs. The medallion carries the flag of the country you would fight instead of a glyph.
## Join / Decline answer the pending prompt (eventChoice 0 / 1); the cross keeps it waiting in the notice strip.
class_name TBCallPrompt
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

static func open(parent: Control, g: TBGame, e: Dictionary, on_choose: Callable, on_defer: Callable) -> TBPanel.Handle:
	var me: int = g.human_id
	var caller: int = int(e["from"]); var enemy: int = int(e["e"])
	var a: String = g.dname(caller); var en: String = g.dname(enemy)
	var chance: float = TBWar.call_chance(g, me, caller, enemy)
	var pct: int = int(roundf(chance * 100.0))
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("callp_title", {"a": a}), "war",
		{"w": 520.0, "medal": TBFlags.medal_of(g, enemy), "dismissable": on_defer.is_valid(), "on_dismiss": on_defer})
	h.lead(T.call("callp_lead", {"a": a, "e": en}))
	var col := K.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.body.add_child(col)
	col.add_child(TBWarParts.FaceOff.new(g, caller, enemy))
	var names := {"trust": "callp_trust", "threat": "callp_threat", "border": "callp_border", "distance": "callp_far", "weary": "callp_weary"}
	var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 8); row.add_theme_constant_override("v_separation", 8)
	row.alignment = FlowContainer.ALIGNMENT_CENTER; row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tm in TBWar.call_terms(g, me, caller, enemy):
		var v: float = float(tm[1])
		if absf(v) < 0.06: continue
		row.add_child(K.chip(T.call(names[String(tm[0])], {"a": a, "e": en}), "", "pos" if v > 0.0 else "info"))
	row.add_child(K.chip(T.call("callp_will", {"p": pct}), "", "neutral"))
	col.add_child(row)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 10); gap.mouse_filter = Control.MOUSE_FILTER_IGNORE; col.add_child(gap)
	col.add_child(Lean.new(pct))
	col.add_child(K.fxl([[T.call("callp_if"), T.call("callp_grudge", {"a": a, "g": TBWar.CALL_SNUB_GRUDGE}), -1]]))
	var join: Button = K.button(T.call("callp_join"), func() -> void: h.close(); on_choose.call(0), true, false, "war")
	var stay: Button = K.button(T.call("callp_stay"), func() -> void: h.close(); on_choose.call(1))
	join.custom_minimum_size.x = maxf(join.custom_minimum_size.x, 180.0); stay.custom_minimum_size.x = maxf(stay.custom_minimum_size.x, 150.0)
	h.actions(stay, join)
	h.focus_target = stay
	return h

## `.lk`: a notched gauge, the share that would stay out hatched in rust, the share that joins in gold, each with its figure
class Lean extends Control:
	var yes := 50
	func _init(p: int) -> void:
		yes = clampi(p, 0, 100)
		custom_minimum_size = Vector2(0, 30); size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
		TBKit.a11y(self, "%d %%" % yes, "image")
	func _draw() -> void:
		var w: float = size.x; var hh: float = 28.0; var y0: float = (size.y - hh) * 0.5
		draw_colored_polygon(_notch(0.0, y0, w, y0 + hh, 9.0), Color("7F6A33"))
		var x0 := 1.0; var x1: float = w - 1.0; var iy0: float = y0 + 1.0; var iy1: float = y0 + hh - 1.0
		draw_colored_polygon(_notch(x0, iy0, x1, iy1, 8.0), TBTokens.BZ_TRACK_BG)
		var cut: float = x0 + (x1 - x0) * float(100 - yes) / 100.0
		# the gold share (right), clipped to the notched inner shape
		var gold: Array = Geometry2D.intersect_polygons(_notch(x0, iy0, x1, iy1, 8.0), PackedVector2Array([Vector2(cut, iy0), Vector2(x1, iy0), Vector2(x1, iy1), Vector2(cut, iy1)]))
		for pg in gold: draw_colored_polygon(pg, TBTokens.BZ_SLIDER_FILL_A.lerp(TBTokens.BZ_SLIDER_FILL_B, 0.45))
		# the hatched share (left): 135 degree rust lines every 9 px
		var rust: Color = TBTokens.with_a(Color("D2603F"), 0.55)
		var x: float = x0 - (iy1 - iy0)
		while x < cut:
			var seg := PackedVector2Array([Vector2(x, iy0), Vector2(x + (iy1 - iy0), iy1)])
			var xa: float = clampf(seg[0].x, x0, cut); var xb: float = clampf(seg[1].x, x0, cut)
			if xb > xa:
				var ya: float = iy0 + (xa - x); var yb: float = iy0 + (xb - x)
				draw_line(Vector2(xa, ya), Vector2(xb, yb), rust, 1.5)
			x += 9.0
		var f := TBKit.body_b(); var fs: int = TBKit.fs(16)
		for pr in [[100 - yes, x0, cut, Color("F3B5A0")], [yes, cut, x1, Color("1B1408")]]:
			var txt: String = "%d%%" % int(pr[0])
			if float(pr[2]) - float(pr[1]) < 30.0: continue
			var ink: Rect2 = TBKit.ink_box(f, fs, txt)
			draw_string(f, Vector2((float(pr[1]) + float(pr[2])) * 0.5 - ink.get_center().x, size.y * 0.5 - ink.get_center().y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pr[3])
	func _notch(x0: float, y0: float, x1: float, y1: float, k: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(x0 + k, y0), Vector2(x1 - k, y0), Vector2(x1, y0 + k), Vector2(x1, y1 - k), Vector2(x1 - k, y1), Vector2(x0 + k, y1), Vector2(x0, y1 - k), Vector2(x0, y0 + k)])
