## Negotiation instruments (Bezel): the dial that plays out a request to an AI court, and the disposition meter on the nation card.
## Both draw the real sums from TBDipView (the engine's own acceptance rule), so what the needle shows is what the court decides.
class_name TBNegotiate
extends Control

const K = preload("res://src/ui/ui_kit.gd")
const BZ = preload("res://src/ui/bezel.gd")
const P = preload("res://src/ui/hud_parts.gd")
static var T: Callable = TBI18n.T

## the last meter value drawn per nation (the meter slides from it to the new one after a command)
static var last_meter: Dictionary = {}
## true while a dial is on screen: the panel behind must not react to keys, and a second dial must not open
static var active := false
static var skip_fn: Callable = Callable()

static func _ang(v: float) -> float: return deg_to_rad(-135.0 + 270.0 * clampf(v, 0.0, 100.0) / 100.0) - PI * 0.5

# ================================================================== the dial
class Dial extends Control:
	signal finished
	var need_v := 50.0
	var score_v := 50.0
	var blocked := false
	var ok := false
	var t := 0.0
	var dur := 1.7
	var done := false
	var stamp_t := 0.0
	var score_text := ""
	var need_text := ""
	func _init() -> void:
		custom_minimum_size = Vector2(196, 196); size_flags_horizontal = Control.SIZE_SHRINK_CENTER; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func needle_v() -> float:
		if done: return 2.0 if blocked else score_v
		var k: float = clampf(t / dur, 0.0, 1.0)
		var a: float = 1.0 - exp(-5.0 * k) * cos(14.0 * k)
		return 2.0 + 2.0 * sin(t * 9.0) * (1.0 - k) if blocked else clampf(a * score_v, -4.0, 104.0)
	func _process(d: float) -> void:
		t += d
		if t >= dur and not done:
			done = true; finished.emit()
		if done: stamp_t += d
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		var R: float = minf(size.x, size.y) * 0.5 - 2.0
		var fr: float = BZ.ring(self, c, R, 60, TBTokens.c("bar_0"))
		var ar: float = fr - 14.0
		var a_need: float = TBNegotiate._ang(need_v)
		draw_arc(c, ar, TBNegotiate._ang(0.0), a_need, 36, TBTokens.c("neg_bar"), 9.0, true)
		draw_arc(c, ar, a_need, TBNegotiate._ang(100.0), 36, TBTokens.c("pos_bar"), 9.0, true)
		var nd := Vector2(cos(a_need), sin(a_need))
		draw_line(c + nd * (ar - 8.0), c + nd * (ar + 8.0), TBTokens.c("cream"), 2.0, true)
		var nv: float = needle_v()
		var na: float = TBNegotiate._ang(nv)
		var dv := Vector2(cos(na), sin(na))
		draw_line(c - dv * 8.0, c + dv * (ar - 6.0), TBTokens.c("cream"), 3.0, true)
		draw_circle(c, 6.5, TBTokens.c("brass_lt"))
		draw_circle(c, 2.5, TBTokens.c("bar_0"))
		var f: Font = K.tracked(K.display(), 1)
		var z: int = P.fs(12.0)
		var s1: String = need_text
		draw_string(f, Vector2(c.x - P.tw(f, s1, z) * 0.5, c.y + fr * 0.52), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, z, TBTokens.c("smoke"))
		var fb: Font = K.body_b()
		var z2: int = P.fs(18.0)
		draw_string(fb, Vector2(c.x - P.tw(fb, score_text, z2) * 0.5, c.y + fr * 0.52 + z2 + 2.0), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, z2, TBTokens.c("cream"))

## score x 100 for display; within one and a half points of the bar the decimal is shown (the engine's test is strict: 45.0 is not above 45)
static func _fmt(v: float, near: float = -1.0) -> String:
	if near >= 0.0 and absf(v - near) < 0.015 and absf(v - near) > 0.0000001: return "%.1f" % (v * 100.0)
	return "%d" % int(roundf(v * 100.0))

## the dial, then `then`. With reduced motion (or in tests) the verdict is applied at once.
## view: a TBDipView result. what: "dv_pact_nap"... a sentence key (the title reads "<what> with <nation>").
static func run(parent: Control, what_key: String, nation: String, view: Dictionary, then: Callable) -> void:
	if not K.motion_ok() or parent == null or not is_instance_valid(parent):
		then.call(); return
	if active: return
	var back := ColorRect.new()
	back.color = TBTokens.ca("table", 0.72); back.set_anchors_preset(Control.PRESET_FULL_RECT); back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.z_index = 90
	var holder := CenterContainer.new(); holder.set_anchors_preset(Control.PRESET_FULL_RECT); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(holder)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_0"), TBTokens.c("rule"), TBTokens.CUT_PANEL, 2, 30, 20))
	holder.add_child(card)
	var col := K.vbox(8); col.alignment = BoxContainer.ALIGNMENT_CENTER; card.add_child(col)
	var title := K.caps(T.call("nego_with", {"what": T.call(what_key), "a": nation}), 13, TBTokens.c("brass_lt"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var dial := Dial.new()
	dial.need_v = TBDipView.meter({"score": float(view["need"]), "need": float(view["need"])})
	dial.score_v = TBDipView.meter(view)
	dial.blocked = String(view["blocked"]) != ""
	dial.ok = bool(view["ok"])
	dial.need_text = T.call("dv_needs", {"n": _fmt(float(view["need"]))})
	dial.score_text = "—" if dial.blocked else T.call("dv_score", {"s": _fmt(float(view["score"]), float(view["need"]))})
	col.add_child(dial)
	var verdict := K.title("", 22, TBTokens.c("cream"))
	verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; verdict.custom_minimum_size = Vector2(0, 30)
	col.add_child(verdict)
	var why := K.label(T.call("dvb_" + String(view["blocked"])) if dial.blocked else "", 14, TBTokens.c("neg"))
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(why)
	var skip := K.label(T.call("nego_skip"), 12, TBTokens.c("ink_off")); skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(skip)
	parent.add_child(back)
	var fired := [false]
	active = true
	var finish := func():
		if fired[0] or not is_instance_valid(back): return
		fired[0] = true
		active = false; skip_fn = Callable()
		back.queue_free(); then.call()
	skip_fn = func(): finish.call()
	back.tree_exiting.connect(func(): active = false; skip_fn = Callable())
	dial.finished.connect(func():
		verdict.text = T.call("nego_accept") if dial.ok else T.call("nego_refuse")
		verdict.add_theme_color_override("font_color", TBTokens.c("pos_bar") if dial.ok else TBTokens.c("neg_bar"))
		if K.motion_ok():
			verdict.pivot_offset = verdict.size * 0.5
			var tw := verdict.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(verdict, "scale", Vector2.ONE, 0.3).from(Vector2(1.9, 1.9))
		back.get_tree().create_timer(1.0).timeout.connect(finish))
	back.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed: finish.call())
	dial.set_process(true)

# ================================================================== the disposition meter
## 0..100 bar with graduated marks, a notch at what the court needs, a needle at where it stands; slides from its last value
class Meter extends Control:
	var value := 50.0
	var shown := 50.0
	var need := 50.0
	var good := false
	var key := 0
	var need_label := ""
	var float_txt := ""
	var float_t := 0.0
	var _from := 50.0
	var _t := 1.0
	func _init() -> void:
		custom_minimum_size = Vector2(0, 54); size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func setup(v: float, need_v: float, nation_key: int) -> Meter:
		value = v; need = need_v; key = nation_key
		var prev: float = float(TBNegotiate.last_meter.get(key, v))
		TBNegotiate.last_meter[key] = v
		if absf(prev - v) > 0.5 and K.motion_ok():
			_from = prev; shown = prev; _t = 0.0
			float_txt = ("+%d" if v > prev else "−%d") % int(roundf(absf(v - prev))); float_t = 1.4
			set_process(true)
		else:
			shown = v; set_process(false)
		return self
	func _process(d: float) -> void:
		if _t < 1.0:
			_t = minf(1.0, _t + d / 0.9)
			shown = lerpf(_from, value, 1.0 - pow(1.0 - _t, 3.0))
		if float_t > 0.0: float_t -= d
		queue_redraw()
		if _t >= 1.0 and float_t <= 0.0: set_process(false)
	func _draw() -> void:
		var x0 := 8.0; var x1 := size.x - 8.0
		var y := 24.0
		var w: float = x1 - x0
		draw_rect(Rect2(x0, y - 5.0, w, 10.0), TBTokens.c("paper_1"))
		draw_rect(Rect2(x0, y - 5.0, w, 10.0), TBTokens.ca("rule", 0.6), false, 1.0)
		var fillc: Color = TBTokens.c("pos_bar") if (good and shown >= need - 0.01) else TBTokens.c("neg_bar")
		draw_rect(Rect2(x0 + 1.0, y - 4.0, (w - 2.0) * clampf(shown / 100.0, 0.0, 1.0), 8.0), fillc)
		var nx: float = x0 + w * need / 100.0
		draw_line(Vector2(nx, y - 9.0), Vector2(nx, y + 9.0), TBTokens.c("cream"), 2.0)
		BZ.ruler_h(self, x0, x1, y + 12.0, w / 20.0, 5, TBTokens.ca("rule", 0.9), 3.0)
		var cx: float = x0 + w * clampf(shown / 100.0, 0.0, 1.0)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 6.0, y - 18.0), Vector2(cx + 6.0, y - 18.0), Vector2(cx, y - 8.0)]), TBTokens.c("cream"))
		var f: Font = K.body_b()
		var z: int = P.fs(14.0)
		if float_t > 0.0:
			var a: float = clampf(float_t / 0.6, 0.0, 1.0)
			var fy: float = y - 24.0 - (1.4 - float_t) * 8.0
			var fc: Color = TBTokens.c("pos_bar") if float_txt.begins_with("+") else TBTokens.c("neg_bar")
			draw_string_outline(f, Vector2(cx + 10.0, fy), float_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, z + 4, 4, TBTokens.with_a(TBTokens.HALO, a))
			draw_string(f, Vector2(cx + 10.0, fy), float_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, z + 4, TBTokens.with_a(fc, a))
		var cf: Font = K.tracked(K.display(), 1)
		var zc: int = P.fs(12.0)
		draw_string(cf, Vector2(x0, size.y - 2.0), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, zc, TBTokens.c("ink_off"))
		draw_string(cf, Vector2(x1 - P.tw(cf, "100", zc), size.y - 2.0), "100", HORIZONTAL_ALIGNMENT_LEFT, -1, zc, TBTokens.c("ink_off"))
		var lw: float = P.tw(cf, need_label, zc)
		draw_string(cf, Vector2(clampf(nx - lw * 0.5, x0 + 20.0, x1 - lw - 30.0), size.y - 2.0), need_label, HORIZONTAL_ALIGNMENT_LEFT, -1, zc, TBTokens.c("smoke"))

static func meter(view: Dictionary, nation_key: int) -> Meter:      # nation_key: one meter memory per nation AND request (n * 8 + lead)
	var nv: float = TBDipView.meter({"score": float(view["need"]), "need": float(view["need"])})
	var vv: float = TBDipView.meter(view)
	if String(view["blocked"]) != "": vv = minf(vv, nv * 0.6)           # a blocked request never sits above the bar
	var m := Meter.new().setup(vv, nv, nation_key)
	m.good = bool(view["ok"])
	m.need_label = T.call("dv_needs", {"n": _fmt(float(view["need"]))})
	return m

## "Why they feel this way": the terms of the sum as a leader list (label ..... +value), then the total against what is needed
static func why_list(view: Dictionary) -> Control:
	var v := K.vbox(0)
	var cum := 0.0; var shown_cum := 0                      # each line is the change in the running rounded total: the lines always add up to the total
	for term in view["terms"]:
		var val: float = float(term[1])
		cum += val
		var cur: int = int(roundf(cum * 100.0))
		var step: int = cur - shown_cum; shown_cum = cur
		if step == 0: continue
		var col: Color = TBTokens.c("pos") if step > 0 else TBTokens.c("neg")
		v.add_child(K.row(T.call(String(term[0])), "%s%d" % ["+" if step > 0 else "−", absi(step)], col))
	if String(view["blocked"]) != "":
		v.add_child(K.row(T.call("dvb_" + String(view["blocked"])), "✕", TBTokens.c("neg")))
	var total := K.row(T.call("dv_total"), "%s / %s" % [_fmt(float(view["score"]), float(view["need"])), _fmt(float(view["need"]))], TBTokens.c("pos") if bool(view["ok"]) else TBTokens.c("neg"))
	v.add_child(total)
	return v
