## The war declaration (Path B3, docs/screens/popup_mocks/sheet_A_war_event.png): the face-off row (both flags, a war disc between them), the hold-to-declare **seal**
## (the existing hold rule: 0.6 s, or Enter twice) and the "War" moment that plays after the command is given. The look is permanent; the motion goes through TBFx.
class_name TBWarParts
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

static func rust() -> Color: return TBTokens.BZ_DNG_B
static func rust_hi() -> Color: return TBTokens.BZ_NOTICE_BAD

## "1815 AD" / "218 BC"
static func year_text(y: int) -> String:
	return ("%d BC" % -y) if y < 0 else ("%d AD" % y)

static func ruler_line(g: TBGame, n: int) -> String:
	if g.rules >= 1 and g.r_name[n] != "": return "%s %s" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)]
	return ""

# ================================================================================================================================ face-off row
class FaceOff extends Control:
	var g: TBGame
	var a := 0                      # you
	var b := 0                      # them
	func _init(game: TBGame, me: int, them: int) -> void:
		g = game; a = me; b = them
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 150)
	func _draw() -> void:
		var w := size.x
		var cy: float = 46.0
		var r: float = 36.0
		var ca := Vector2(w * 0.19, cy); var cb := Vector2(w * 0.81, cy); var cm := Vector2(w * 0.5, cy)
		var rustc: Color = TBWarParts.rust(); var hi: Color = TBWarParts.rust_hi()
		# the line between the two flags and the war disc
		for side in [-1, 1]:
			var x0: float = cm.x + side * 36.0
			var x1: float = (ca.x + r + 6.0) if side < 0 else (cb.x - r - 6.0)
			var steps := 10
			for i in steps:
				var t0: float = float(i) / steps; var t1: float = float(i + 1) / steps
				draw_line(Vector2(lerpf(x0, x1, t0), cy), Vector2(lerpf(x0, x1, t1), cy), TBTokens.with_a(rustc, 0.9 * (1.0 - t0)), 1.2)
		for k in 6:                                                               # soft glow behind the disc
			draw_circle(cm, 44.0 - k * 5.0, TBTokens.with_a(hi, 0.05 + 0.02 * k))
		draw_circle(cm, 27.0, TBTokens.BZ_FACE)
		draw_arc(cm, 27.0, 0.0, TAU, 48, hi, 1.6, true)
		TBBzIcons.draw(self, "war", cm, 28.0, TBTokens.with_a(hi, 1.0), 1.7)
		TBFlags.draw_flag_medal(self, TBFlags.medal_of(g, a), ca, r * 2.0)
		TBFlags.draw_flag_medal(self, TBFlags.medal_of(g, b), cb, r * 2.0)
		var f := TBKit.tracked(TBKit.wordmark(), 2)
		var fsz := TBKit.fs(15)
		var sf := TBKit.body_i()
		var ssz := TBKit.fs(14)
		for e in [[ca, a], [cb, b]]:
			var nm: String = g.dname(int(e[1])).to_upper()
			var tw: float = minf(f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x, w * 0.4)
			draw_string(f, Vector2(roundf((e[0] as Vector2).x - tw * 0.5), cy + r + 26.0), nm, HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, fsz, TBTokens.c("cream"))
			var rl: String = TBWarParts.ruler_line(g, int(e[1]))
			if rl != "":
				var rw: float = minf(sf.get_string_size(rl, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x, w * 0.42)
				draw_string(sf, Vector2(roundf((e[0] as Vector2).x - rw * 0.5), cy + r + 46.0), rl, HORIZONTAL_ALIGNMENT_LEFT, w * 0.42, ssz, TBTokens.c("smoke"))

# ================================================================================================================================ the seal
## Hold to declare: a wax seal with a progress ring and its caption to the left. `confirmed` fires after HOLD_T (or Enter twice); `progress(0..1)` while held.
class Seal extends Button:
	signal confirmed
	signal progress(f: float)
	const HOLD_T := 0.6
	var caption := ""
	var _hold := 0.0
	var _holding := false
	var _armed := false
	func _init(caption_text: String) -> void:
		caption = caption_text
		text = ""; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		var f := TBKit.tracked(TBKit.wordmark(), 2)
		var cw: float = f.get_string_size(caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(13)).x
		custom_minimum_size = Vector2(minf(cw, 260.0) + 24.0 + 84.0, maxf(84.0, float(TBKit.touch())))
		tooltip_text = TBI18n.T("hold_confirm")
		TBKit.a11y(self, caption, "button", TBI18n.T("hold_confirm"))
		set_process(false)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw); focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)
	func _gui_input(e: InputEvent) -> void:
		if disabled: return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if e.pressed: _holding = true; _hold = 0.0; set_process(true)
			else:
				if _holding and _hold < HOLD_T: _flash_hint()
				_reset()
		elif e is InputEventScreenTouch:
			accept_event()
		elif e.is_action_pressed("ui_accept") and not e.is_echo():
			accept_event()
			if _armed: _armed = false; caption = _cap0; confirmed.emit()
			else:
				_cap0 = caption; _armed = true; caption = TBI18n.T("press_again"); queue_redraw()
				get_tree().create_timer(3.0).timeout.connect(func():
					if is_instance_valid(self) and _armed: _armed = false; caption = _cap0; queue_redraw())
	var _cap0 := ""
	func _reset() -> void:
		_holding = false; _hold = 0.0; progress.emit(0.0); queue_redraw()
	func _flash_hint() -> void:
		_cap0 = caption; caption = TBI18n.T("hold_confirm"); queue_redraw()
		get_tree().create_timer(1.4).timeout.connect(func():
			if is_instance_valid(self) and not _armed: caption = _cap0; queue_redraw())
	func _process(delta: float) -> void:
		if not _holding: set_process(false); return
		_hold += delta
		progress.emit(clampf(_hold / HOLD_T, 0.0, 1.0))
		queue_redraw()
		if _hold >= HOLD_T:
			_holding = false; _hold = 0.0; set_process(false); progress.emit(0.0); queue_redraw(); confirmed.emit()
	func _draw() -> void:
		var w := size.x; var h := size.y
		var c := Vector2(w - 42.0, h * 0.5)
		var f_hold: float = clampf(_hold / HOLD_T, 0.0, 1.0)
		var hot: bool = (is_hovered() or has_focus()) and not disabled
		var rustc: Color = TBWarParts.rust(); var hi: Color = TBWarParts.rust_hi()
		# caption
		var f := TBKit.tracked(TBKit.wordmark(), 2)
		var fsz := TBKit.fs(13)
		var txt: String = caption.to_upper()
		var tw: float = minf(f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x, w - 100.0)
		draw_string(f, Vector2(w - 92.0 - tw, roundf(c.y + f.get_ascent(fsz) * 0.5 - 2.0)), txt, HORIZONTAL_ALIGNMENT_LEFT, w - 100.0, fsz, TBTokens.with_a(TBTokens.BZ_NOTICE_BAD.lerp(TBTokens.c("cream"), 0.25), 1.0))
		# ring: track, progress
		draw_arc(c, 39.0, 0.0, TAU, 64, TBTokens.with_a(rustc, 0.35), 3.0, true)
		if f_hold > 0.0: draw_arc(c, 39.0, -PI * 0.5, -PI * 0.5 + TAU * f_hold, 64, hi, 3.5, true)
		elif hot: draw_arc(c, 39.0, 0.0, TAU, 64, TBTokens.with_a(hi, 0.6), 1.5, true)
		# wax disc
		var down: float = 2.0 if f_hold > 0.0 else 0.0
		draw_circle(c + Vector2(0, 3.0), 31.0, TBTokens.with_a(TBTokens.BZ_SHADOW, 0.5))
		var base: Color = TBTokens.BZ_DNG_A.lerp(TBTokens.BZ_DNG_B, 0.55)
		for k in 8:
			var t: float = float(k) / 7.0
			draw_circle(c + Vector2(0, down) + Vector2(-1.0, -1.0) * (1.0 - t) * 4.0, 31.0 * (1.0 - t * 0.55), base.lerp(TBTokens.BZ_DNG_HA, (1.0 - t) * 0.35 + (0.12 if hot else 0.0)).darkened(0.18 * t if f_hold > 0.0 else 0.0))
		draw_arc(c + Vector2(0, down), 24.0, 0.0, TAU, 48, TBTokens.with_a(TBTokens.BZ_DNG_TX, 0.32), 1.4, true)
		TBBzIcons.draw(self, "war", c + Vector2(0, down), 28.0, TBTokens.BZ_DNG_TX, 1.8)
		if has_focus() and TBFrame.kbd_nav: draw_arc(c, 45.0, 0.0, TAU, 64, TBTokens.c("brass_lt"), 2.0, true)

# ================================================================================================================================ the "War" moment
## Letterbox bars, a rust vignette, both flags with the war disc, "War" and "A declares war on B". Plays once after the command; any click or key ends it.
class Moment extends Control:
	var g: TBGame
	var a := 0
	var b := 0
	var t := 0.0                      # 0..1 over the whole moment
	var full := true
	var _tw: Tween
	func _init(game: TBGame, me: int, them: int, is_full: bool) -> void:
		g = game; a = me; b = them; full = is_full
		set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_STOP
		set_meta("tb_closing", true)                    # never counts as an open modal
		z_index = 90
		focus_mode = Control.FOCUS_ALL
	func play() -> void:
		var secs: float = 2.3 if full else 1.2
		_tw = TBFx.run(self, secs, func(v: float):
			t = v; queue_redraw(), func(): queue_free(), TBFx.LIGHT)
		grab_focus.call_deferred()
	func _gui_input(e: InputEvent) -> void:
		if (e is InputEventMouseButton and e.pressed) or (e is InputEventKey and e.pressed): _end()
	func _end() -> void:
		if _tw != null and _tw.is_valid(): _tw.kill()
		queue_free()
	static func _ease_out(x: float) -> float: return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)
	func _draw() -> void:
		var sz := size
		var env: float = TBFx.smooth(minf(t / 0.12, 1.0)) * (1.0 - TBFx.smooth((t - 0.86) / 0.14))         # everything fades in at the start and out at the end
		if env <= 0.001: return
		var cx: float = sz.x * 0.5
		var cy: float = sz.y * 0.5
		var rustc: Color = TBWarParts.rust(); var hi: Color = TBWarParts.rust_hi()
		# veil with a rust vignette
		draw_rect(Rect2(Vector2.ZERO, sz), TBTokens.with_a(TBTokens.BZ_SHADOW, 0.74 * env))
		for k in 7:
			draw_circle(Vector2(cx, cy), maxf(sz.x, sz.y) * (0.70 - k * 0.07), TBTokens.with_a(rustc, 0.035 * env))
		if full:                                                                                      # letterbox bars slide in
			var bh: float = sz.y * 0.13 * TBFx.smooth(minf(t / 0.16, 1.0)) * (1.0 - TBFx.smooth((t - 0.86) / 0.14))
			draw_rect(Rect2(0, 0, sz.x, bh), TBTokens.BZ_SHADOW); draw_rect(Rect2(0, sz.y - bh, sz.x, bh), TBTokens.BZ_SHADOW)
			draw_line(Vector2(0, bh), Vector2(sz.x, bh), TBTokens.with_a(rustc, 0.5 * env), 1.0); draw_line(Vector2(0, sz.y - bh), Vector2(sz.x, sz.y - bh), TBTokens.with_a(rustc, 0.5 * env), 1.0)
		var u: float = sz.y / 720.0
		var pop: float = _ease_out((t - 0.10) / 0.22)
		var r: float = 58.0 * u * (0.7 + 0.3 * pop)
		var ca := Vector2(cx - 190.0 * u, cy - 40.0 * u); var cb := Vector2(cx + 190.0 * u, cy - 40.0 * u); var cm := Vector2(cx, cy - 40.0 * u)
		var fa: float = env * pop
		for k in 8:
			draw_circle(cm, (70.0 - k * 7.0) * u, TBTokens.with_a(hi, (0.05 + 0.02 * k) * fa))
		draw_circle(cm, 38.0 * u, TBTokens.with_a(TBTokens.BZ_FACE, fa))
		draw_arc(cm, 38.0 * u, 0.0, TAU, 48, TBTokens.with_a(hi, fa), 2.0, true)
		TBBzIcons.draw(self, "war", cm, 40.0 * u, TBTokens.with_a(hi, fa), 1.8)
		draw_set_transform(ca, 0.0, Vector2.ONE)
		TBFlags.draw_flag_medal(self, TBFlags.medal_of(g, a), Vector2.ZERO, r * 2.0)
		draw_set_transform(cb, 0.0, Vector2.ONE)
		TBFlags.draw_flag_medal(self, TBFlags.medal_of(g, b), Vector2.ZERO, r * 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the word
		var tt: float = _ease_out((t - 0.26) / 0.24)
		var f := TBKit.tracked(TBKit.wordmark(), int(18.0 * u * (1.4 - 0.4 * tt)))
		var fsz := TBKit.fs(78.0 * u)
		var word: String = TBWarParts.T.call("war_moment_t").to_upper()
		var ww: float = f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var wc: Color = TBTokens.BZ_DNG_TX
		draw_string_outline(f, Vector2(roundf(cx - ww * 0.5), cy + 80.0 * u), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, 8, TBTokens.with_a(rustc.darkened(0.5), env * tt))
		draw_string(f, Vector2(roundf(cx - ww * 0.5), cy + 80.0 * u), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, TBTokens.with_a(wc, env * tt))
		var sub: String = TBWarParts.T.call("war_moment_sub", {"a": g.dname(a), "b": g.dname(b)})
		var sf := TBKit.body_i()
		var ssz := TBKit.fs(26.0 * u)
		var sw: float = minf(sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ssz).x, sz.x * 0.8)
		var st: float = _ease_out((t - 0.42) / 0.2)
		draw_string(sf, Vector2(roundf(cx - sw * 0.5), cy + 128.0 * u), sub, HORIZONTAL_ALIGNMENT_LEFT, sz.x * 0.8, ssz, TBTokens.with_a(TBTokens.c("cream").lerp(hi, 0.25), env * st))
		var date: String = "%s %d · %s" % [TBWarParts.T.call("turn"), g.turn, TBWarParts.year_text(g.year)]
		var df := TBKit.tracked(TBKit.wordmark(), 3)
		var dsz := TBKit.fs(14.0 * u)
		var dw: float = df.get_string_size(date.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, dsz).x
		draw_line(Vector2(cx - 280.0 * u * st, cy + 150.0 * u), Vector2(cx + 280.0 * u * st, cy + 150.0 * u), TBTokens.with_a(hi, 0.8 * env), 1.0)
		draw_string(df, Vector2(roundf(cx - dw * 0.5), cy + 178.0 * u), date.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, dsz, TBTokens.with_a(TBTokens.c("smoke"), env * st))
