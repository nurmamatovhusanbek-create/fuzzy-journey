## Shared UI kit (art bible 3, 7; accessibility A11Y-FOCUS / TXT / CON / TOUCH / MOT): flat chamfered plates, ink on paper, brass for the one primary.
## Colours come from TBTokens only (the old constant names remain as aliases); fonts per 7.2; every control that takes focus draws the focus ring.
## After changing TBTokens.mode, text_scale or touch_large call K.theme() again and rebuild the screen (the aliases refresh in theme()).
class_name TBKit
extends RefCounted

## ---- old colour names, now aliases of tokens (refreshed by sync_palette) ---------------------------------------------------
static var BG: Color
static var PANEL: Color
static var PANEL2: Color
static var LINE: Color
static var TEXT: Color
static var DIM: Color
static var GOLD: Color
static var GOLD2: Color
static var RED: Color
static var CRIMSON: Color
static var GREEN: Color
static var STEEL: Color
static var BRASS_LT: Color
static var BRASS: Color
static var CREAM: Color
static var SMOKE: Color
static var UMBER: Color
static var RED_LT: Color
static var GREEN_LT: Color
const MIN_TOUCH := 48                   # A11Y-TCH-001: unconditional (never gated on the platform); touch() returns 56 with Large targets

## ---- player-facing accessibility settings (set by apply_settings(cfg); then rebuild the screens) --------------------------------
static var text_scale: float = 1.0     # 1.0 / 1.25 / 1.5 / 2.0 (A11Y-TXT-001); independent of the layout scale (cfg "ui")
static var readable_fonts := false     # A11Y-TXT-004: no tracked capitals, Alegreya Bold instead of Cinzel
static var reduce_motion := false      # A11Y-MOT-001: ask motion_ok() before every tween / spin / pulse
static var large_targets := false      # A11Y-TCH-001: 56 instead of 48 (alias of touch_large)
static var touch_large := false
static var dp_scale := 1.0             # A11Y-TXT-005: logical px per dp
static var cvd := "off"                # A11Y-CVD: "off" | "deuter" | "protan" | "tritan" (palettes are the map / lens agents' job)
static var tts_on := false             # A11Y-SR-004: cfg["tts"]
static var confirm := "risky"          # "off" | "risky" | "all": cfg["confirm"]; the HUD / order flow asks need_confirm(risky)
static var mirror := false             # one-handed layout: HUD side controls swap sides (cfg["mirror"])
static var vis_alerts := false         # A11Y-AUD-006: show the visual alert strip (forced on while sound is muted)
static var sound_muted := false        # cfg["sound"] == false
static var allow_shake := false        # A11Y-MOT-002 bans shake; kept false, shake() is a no-op unless a test flips it

## settings bus: connect to K.settings_changed(cfg) to rebuild a screen after text size / contrast / motion / targets changed
class _Bus extends RefCounted:
	signal changed(cfg: Dictionary)
static var _bus: _Bus = _Bus.new()
static var settings_changed: Signal = _bus.changed

static func _static_init() -> void:
	sync_palette()

static func sync_palette() -> void:
	BG = TBTokens.c("table"); PANEL = TBTokens.c("paper_0"); PANEL2 = TBTokens.c("paper_1"); LINE = TBTokens.c("rule")
	TEXT = TBTokens.c("ink_0"); DIM = TBTokens.c("ink_1"); GOLD = TBTokens.c("brass_ink"); GOLD2 = TBTokens.c("oxblood")
	RED = TBTokens.c("neg"); CRIMSON = TBTokens.c("neg"); GREEN = TBTokens.c("pos"); STEEL = TBTokens.c("info")
	BRASS_LT = TBTokens.c("brass_lt"); BRASS = TBTokens.c("brass"); CREAM = TBTokens.c("cream"); SMOKE = TBTokens.c("smoke")
	UMBER = TBTokens.c("bar_1"); RED_LT = TBTokens.c("neg_bar"); GREEN_LT = TBTokens.c("pos_bar")

## Read every accessibility key of cfg into the statics, rebuild the theme and tell open screens (settings_changed).
## Returns the new Theme: `theme = K.apply_settings(cfg)` on the root Control. Missing keys fall back to defaults, "contrast": true migrates to hc "light".
static func apply_settings(cfg: Dictionary) -> Theme:
	text_scale = _snap_scale(float(cfg.get("text_scale", 1.0)))
	readable_fonts = bool(cfg.get("readable", false))
	reduce_motion = bool(cfg.get("reduce_motion", false))
	touch_large = bool(cfg.get("touch_large", false)); large_targets = touch_large
	var hc: String = String(cfg.get("hc", "off"))
	if hc == "off" and bool(cfg.get("contrast", false)): hc = "light"
	TBTokens.mode = TBTokens.mode_from_setting(hc)
	cvd = String(cfg.get("cvd", "off")) if String(cfg.get("cvd", "off")) in ["off", "deuter", "protan", "tritan"] else "off"
	tts_on = bool(cfg.get("tts", false))
	confirm = String(cfg.get("confirm", "risky")) if String(cfg.get("confirm", "risky")) in ["off", "risky", "all"] else "risky"
	mirror = bool(cfg.get("mirror", false))
	sound_muted = not bool(cfg.get("sound", true))
	vis_alerts = bool(cfg.get("vis_alerts", false))
	if tts_on: ensure_speaker()
	var t: Theme = theme()
	_bus.changed.emit(cfg)
	return t

static func _snap_scale(v: float) -> float:
	var best: float = 1.0
	for st in [1.0, 1.25, 1.5, 2.0]:
		if absf(v - st) < absf(v - best): best = st
	return best

## the OS "reduce motion" preference where Godot 4.4 can see it (no API: the TB_REDUCE_MOTION env var and Android's animator scale hint); else false
static func os_prefers_reduced_motion() -> bool:
	if OS.get_environment("TB_REDUCE_MOTION") != "": return OS.get_environment("TB_REDUCE_MOTION") != "0"
	return false

## true when the confirm setting wants a confirmation for this action ("risky" = irreversible / costly, "all" = every order)
static func need_confirm(risky: bool) -> bool:
	return confirm == "all" or (confirm == "risky" and risky)

static func fs(px: float) -> int:                       ## a font size through the text scale, never below the 12 px caption floor
	return maxi(roundi(px * text_scale), min_font())
static func min_font() -> int: return roundi(12.0 * dp_scale)
static func dp(n: float) -> int: return roundi(n * dp_scale)
static func touch() -> int: return TBTokens.TOUCH_LARGE if touch_large else TBTokens.TOUCH
static func contrast(a: Color, b: Color) -> float: return TBTokens.contrast(a, b)

# ---- motion (A11Y-MOT-001/002): every tween, spin, pulse and fade asks motion_ok() first --------------------------------------------------
## false when the player chose Reduce motion (or the TB_NOANIM test override is set): skip the tween, cut instantly
static func motion_ok() -> bool: return TBMapView.animate and not reduce_motion
## 1.0 or 0.0: multiply any looping / easing amount by it (shader `motion` uniform, title spin speed, pulse amplitude)
static func motion_factor() -> float: return 1.0 if motion_ok() else 0.0
## the title globe may auto-spin only when this is true
static func spin_ok() -> bool: return motion_ok()
## duration through the setting: 0.0 when motion is reduced (tweens of 0 s finish at once)
static func dur(seconds: float) -> float: return seconds if motion_ok() else 0.0
## a tween that does nothing visible when motion is reduced: `K.tween(node, "modulate:a", 1.0, 0.18)`; returns null when it cut instantly
static func tween(node: Node, prop: String, to: Variant, seconds: float, from: Variant = null) -> Tween:
	if not motion_ok() or not node.is_inside_tree():
		node.set_indexed(NodePath(prop), to); return null
	var tw := node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var tp := tw.tween_property(node, prop, to, minf(seconds, 0.25))
	if from != null: tp.from(from)
	return tw
## number roll helper (A11Y-MOT-002 allows none): sets the text at once; kept so callers have one place to ask
static func roll_number(set_text: Callable, _from: float, to: float, fmt_fn: Callable = Callable()) -> void:
	set_text.call(fmt_fn.call(to) if fmt_fn.is_valid() else str(int(round(to))))
## shake is banned (A11Y-MOT-002): a no-op unless allow_shake is flipped by a test. Show the reason inline instead.
static func shake(ctrl: Control, px: float = 4.0) -> void:
	if not allow_shake or not motion_ok() or not ctrl.is_inside_tree(): return
	var x0: float = ctrl.position.x
	var tw := ctrl.create_tween()
	tw.tween_property(ctrl, "position:x", x0 + px, 0.04); tw.tween_property(ctrl, "position:x", x0 - px, 0.08); tw.tween_property(ctrl, "position:x", x0, 0.04)

# ---- semantics and speech (A11Y-SR-001/004/005) ---------------------------------------------------------------------------------------
## accessible name / role / description: tooltip text plus meta for the later AccessKit binding. The tooltip is only set when empty or when it still
## shows the previous auto name, so a better name given later replaces a default one.
static func a11y(ctrl: Control, accessible_name: String, role: String = "", desc: String = "") -> void:
	var tip: String = accessible_name if desc == "" else "%s. %s" % [accessible_name, desc]
	var prev: Variant = ctrl.get_meta("a11y") if ctrl.has_meta("a11y") else null
	if ctrl.tooltip_text == "" or (prev is Dictionary and String((prev as Dictionary).get("tip", "")) == ctrl.tooltip_text): ctrl.tooltip_text = tip
	ctrl.set_meta("a11y", {"name": accessible_name, "role": role, "desc": desc, "tip": tip})

## what a control says when it receives focus: "Name, role, state"
static func a11y_text(ctrl: Control) -> String:
	if not ctrl.has_meta("a11y"): return ""
	var m: Variant = ctrl.get_meta("a11y")
	if not (m is Dictionary): return ""
	var d: Dictionary = m
	var parts: PackedStringArray = [String(d.get("name", ""))]
	var role: String = String(d.get("role", ""))
	if role != "":
		var rk := "a11y_" + role
		parts.append(TBI18n.T(rk) if TBI18n.has_key(rk) else role)
	if String(d.get("desc", "")) != "": parts.append(String(d["desc"]))
	return ", ".join(parts)

static var tts_warning := ""             # set when the current language has no installed voice (shown beside the Test voice button)
static var _utt := 0
static func tts_available() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH)

## voice id for the interface language: an exact language match, else the default voice (tts_warning says so; Uzbek often has none)
static func tts_voice() -> String:
	tts_warning = ""
	if not tts_available(): return ""
	var lang: String = TBI18n.lang
	var vs: PackedStringArray = DisplayServer.tts_get_voices_for_language(lang)
	if not vs.is_empty(): return vs[0]
	tts_warning = TBI18n.T("tts_no_voice", {"lang": {"en": "English", "ru": "Русский", "uz": "O‘zbekcha"}.get(lang, lang)})
	var all: Array[Dictionary] = DisplayServer.tts_get_voices()
	return String(all[0]["id"]) if not all.is_empty() else ""

## speak when "Speak alerts" is on (cfg["tts"]); interrupt = cut the current phrase. Safe on headless / unsupported platforms.
static func announce(text: String, interrupt: bool = true) -> void:
	if not tts_on or text.strip_edges() == "" or not tts_available(): return
	_speak(text, interrupt)

static func _speak(text: String, interrupt: bool) -> void:
	_utt += 1
	DisplayServer.tts_speak(text, tts_voice(), 80, 1.0, 1.0, _utt, interrupt)

## the Test voice button: speaks even when the setting is off; returns false (and sets tts_warning) when speech is unavailable
static func tts_test() -> bool:
	if not tts_available():
		tts_warning = TBI18n.T("tts_unavailable"); return false
	_speak(TBI18n.T("tts_test_phrase"), true)
	return true

static func tts_stop() -> void:
	if tts_available(): DisplayServer.tts_stop()

## speaks the semantic name of whatever receives focus and stops on Esc; installed once when speech is turned on
class Speaker extends Node:
	func _ready() -> void:
		name = "TBSpeaker"; process_mode = Node.PROCESS_MODE_ALWAYS
		get_viewport().gui_focus_changed.connect(func(c: Control):
			if TBKit.tts_on and c != null: TBKit.announce(TBKit.a11y_text(c)))
	func _input(e: InputEvent) -> void:
		if TBKit.tts_on and e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE: TBKit.tts_stop()

static func ensure_speaker() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null or tree.root.has_node("TBSpeaker"): return
	tree.root.add_child.call_deferred(Speaker.new())

## a disabled control always says why (art bible 7.5)
static func disable(ctrl: BaseButton, reason: String = "") -> void:
	ctrl.disabled = true
	if reason != "": ctrl.tooltip_text = reason

# ---- fonts ------------------------------------------------------------------------------------------------------------------
static var _fonts := {}
static var _trk := {}
static func _font(file: String, fallbacks: Array = []) -> FontFile:
	if _fonts.has(file): return _fonts[file]
	var f: FontFile = load("res://assets/fonts/%s.woff2" % file)
	if f != null:
		f = f.duplicate()
		for fb in fallbacks:
			var ff: Font = load("res://assets/fonts/%s.woff2" % fb)
			if ff != null: f.fallbacks.append(ff)
	_fonts[file] = f
	return f

## Alegreya: body 500, emphasis / buttons / rows 700, flavour 400 italic (Latin and Cyrillic)
## Typography. Atlas Ledger: Inter (400 body, 500 buttons, 600 titles and figures) with tabular numbers; Barlow Condensed 600 for map labels.
## The title screen keeps the Alegreya / Cinzel serif look (serif = true while it is shown).
static var serif := false
static func _inter(w: int) -> Font:
	return _font("inter-latin-%d-normal" % w, ["inter-cyrillic-%d-normal" % w])
static func body() -> Font: return _font("alegreya-latin-500-normal", ["alegreya-cyrillic-500-normal"]) if serif else _inter(400)
static func body_b() -> Font: return _font("alegreya-latin-700-normal", ["alegreya-cyrillic-700-normal"]) if serif else _inter(600)
static func body_m() -> Font: return _font("alegreya-latin-700-normal", ["alegreya-cyrillic-700-normal"]) if serif else _inter(500)
static func body_i() -> Font: return _font("alegreya-latin-400-italic", ["alegreya-cyrillic-400-italic"]) if serif else _inter(400)
## Inter 600 is the heavy face for titles and figures; Barlow Condensed 600 for the map (Cyrillic falls back to Inter)
static func heavy() -> Font: return _inter(600)
static func map_font() -> Font: return _font("barlow-condensed-latin-600-normal", ["inter-cyrillic-600-normal", "inter-latin-600-normal"])
## tabular figures: a variation of the font with the `tnum` feature on (columns of numbers align)
static var _tab := {}
static func tabular(base: Font) -> Font:
	var k := base.get_instance_id()
	if _tab.has(k): return _tab[k]
	var v := FontVariation.new(); v.base_font = base; v.opentype_features = {"tnum": 1}
	_tab[k] = v
	return v
static func display() -> Font:
	if readable_fonts or not serif: return body_b()
	return _font("cinzel-latin-700-normal", ["alegreya-sc-cyrillic-700-normal"])
static func display_hi() -> Font: return display()
static func display_lo() -> Font: return display()
static func wordmark() -> Font: return _font("cinzel-latin-900-normal", ["alegreya-sc-cyrillic-900-normal"])
## JetBrains Mono: figures 700, deltas 400
static func mono() -> Font: return _font("jetbrains-mono-latin-400-normal", ["jetbrains-mono-cyrillic-400-normal"]) if serif else tabular(body())
static func mono_b() -> Font: return _font("jetbrains-mono-latin-700-normal", ["jetbrains-mono-cyrillic-700-normal"]) if serif else tabular(body_b())
## letter-spaced face, created once per (font, spacing)
static func tracked(base: Font, spacing: float) -> Font:
	var key := "%d:%d" % [base.get_instance_id(), int(spacing)]
	if _trk.has(key): return _trk[key]
	var v := FontVariation.new(); v.base_font = base; v.spacing_glyph = int(spacing)
	_trk[key] = v
	return v

# ---- text builders --------------------------------------------------------------------------------------------------------------
static func label(text: String, size: int = 0, color: Color = Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = text
	if size > 0: l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", color if color.a > 0.0 else TEXT)
	return l

## panel / modal title: Cinzel 700, oxblood on paper (brass-lt on bar); Cyrillic falls back to Alegreya SC one px larger
static func title(text: String, size: int = 20, color: Color = Color.TRANSPARENT) -> Label:
	var l := label(text, size + (1 if TBI18n.lang == "ru" and not readable_fonts else 0), color if color.a > 0.0 else GOLD2)
	l.add_theme_font_override("font", display() if readable_fonts else tracked(display(), 1))
	return l

## figure in JetBrains Mono 700
static func num(text: String, size: int = 16, color: Color = Color.TRANSPARENT) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", mono_b())
	return l

## signed delta under a figure: Mono 400 12
static func delta(text: String, color: Color = Color.TRANSPARENT) -> Label:
	var l := label(text, 12, color if color.a > 0.0 else DIM)
	l.add_theme_font_override("font", mono())
	return l

## caption / unit / label: Alegreya 700 caps, 12 px floor (Cyrillic keeps sentence case and no tracking)
static func caps(text: String, size: int = 12, color: Color = Color.TRANSPARENT) -> Label:
	var up: bool = TBI18n.lang != "ru" and not readable_fonts
	var l := label(text.to_upper() if up else text, maxi(size, 12), color if color.a > 0.0 else DIM)
	l.add_theme_font_override("font", tracked(body_b(), 1) if up else body_b())
	return l

static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", sep); return h

static func vbox(sep: int = 6) -> VBoxContainer:
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", sep); return v

## 1 px hairline divider (grouping aid, never relied on alone; removed in high contrast)
static func hair() -> Control:
	var r := ColorRect.new(); r.color = TBTokens.c("hair") if not TBTokens.is_hc() else Color.TRANSPARENT
	r.custom_minimum_size = Vector2(0, 1); r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

## 12 x 12 colour square with a 1 px ink outline (nation colour in lens legends, art bible 5.4)
class ColorChip extends Control:
	var color := Color.WHITE
	func _init(c: Color = Color.WHITE, px: int = 12) -> void:
		color = c; custom_minimum_size = Vector2(px, px); mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TBTokens.c("ink_0"))
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), color)

static func color_chip(rgb: int) -> Control:
	return ColorChip.new(Color.hex((rgb << 8) | 0xFF))

## +608 / −42 (true minus), the sign always shown
static func signed(v: float) -> String:
	var n := int(round(v))
	return "+%d" % n if n > 0 else ("−%d" % -n if n < 0 else "0")

static func fmt(v: float) -> String:
	var a := absf(v)
	var s: String
	if a >= 1000000.0: s = "%.1fM" % (a / 1000000.0)
	elif a >= 10000.0: s = "%.1fk" % (a / 1000.0)
	else: s = str(int(round(a)))
	return ("−" + s) if v < 0.0 and s != "0" else s

# ---- vector textures for theme icons (no Image is ever allocated) ----------------------------------------------------------------
## a Texture2D that paints itself: slider thumb, slider tick, check box
class VecTex extends Texture2D:
	var kind := "thumb"
	var px := 24
	var c1 := Color.WHITE
	var c2 := Color.BLACK
	func _init(k: String, size_px: int, a: Color, b: Color) -> void:
		kind = k; px = size_px; c1 = a; c2 = b
	func _get_width() -> int: return px if kind != "tick" else 1
	func _get_height() -> int: return px
	func _has_alpha() -> bool: return true
	func _draw_rect(to_canvas_item: RID, rect: Rect2, _tile: bool, _modulate: Color, _transpose: bool) -> void:
		_draw(to_canvas_item, rect.position + ((rect.size - Vector2(_get_width(), _get_height())) * 0.5).floor(), _modulate, false)
	func _draw_rect_region(to_canvas_item: RID, rect: Rect2, _src: Rect2, _modulate: Color, _transpose: bool, _clip: bool) -> void:
		_draw(to_canvas_item, rect.position + ((rect.size - Vector2(_get_width(), _get_height())) * 0.5).floor(), _modulate, false)
	func _draw(to_canvas_item: RID, pos: Vector2, _modulate: Color, _transpose: bool) -> void:
		match kind:
			"thumb":
				var key := Vector2i(px, 24)
				var g: Variant = TBFrame._geo_get(key)
				if g == null:
					var c := Vector2(px * 0.5, px * 0.5)
					g = [TBFrame._circle(c, px * 0.5 - 0.5, 40), TBFrame._closed(TBFrame._circle(c, px * 0.5 - 1.0, 40))]
					TBFrame._geo_put(key, g)
				RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D(0.0, pos.round()))
				RenderingServer.canvas_item_add_polygon(to_canvas_item, g[0], TBFrame._pc(c1))
				RenderingServer.canvas_item_add_polyline(to_canvas_item, g[1], TBFrame._pc(c2), 2.0 if TBTokens.is_hc() else 1.0, true)
				RenderingServer.canvas_item_add_set_transform(to_canvas_item, Transform2D.IDENTITY)
			"tick":
				RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(pos.round(), Vector2(1, px)), c1)
			"box_on", "box_off":
				var r := Rect2(pos.round() + Vector2(2, 2), Vector2(px - 4, px - 4))
				RenderingServer.canvas_item_add_rect(to_canvas_item, r, c2)
				RenderingServer.canvas_item_add_rect(to_canvas_item, r.grow(-1), c1 if kind == "box_off" else c2)
				if kind == "box_on":
					var cx := r.position.x; var cy := r.position.y; var s := r.size.x
					RenderingServer.canvas_item_add_polyline(to_canvas_item, _tick_pts(cx, cy, s), TBFrame._pc(c1), 2.0, true)
	static func _tick_pts(cx: float, cy: float, s: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(cx + s * 0.22, cy + s * 0.52), Vector2(cx + s * 0.44, cy + s * 0.74), Vector2(cx + s * 0.80, cy + s * 0.28)])

# ---- theme -------------------------------------------------------------------------------------------------------------------------
static var _empty := StyleBoxEmpty.new()
static var _flat := {}
## borderless chamfered fill (hover / pressed squares of icon buttons), cached per colour
static func flat_plate(fill: Color, cut_px: int = 4) -> TBFrame:
	var key := "%s%d" % [fill.to_html(true), cut_px]
	if _flat.has(key): return _flat[key]
	var f := TBFrame.plate(fill, Color.TRANSPARENT, cut_px, 0, 0, 0, false, 0)
	_flat[key] = f
	return f

static func _pl(fill_tok: String, border_tok: String, cut_px: int = 4, elev: int = 0, px: float = 16.0, py: float = 10.0, pressed: bool = false, alpha: float = 1.0, mask: int = TBFrame.ALL, border_px: int = 1) -> TBFrame:
	var f := TBFrame.plate(TBTokens.ca(fill_tok, alpha) if fill_tok != "" else Color.TRANSPARENT, TBTokens.ca(border_tok, alpha) if border_tok != "" else Color.TRANSPARENT, cut_px, elev, px, py, pressed, border_px, mask)
	return f

static func _button_set(t: Theme, cls: String, fill: String, hover: String, press: String, border: String, text_tok: String, dis_alpha: float, ring_on_bar: bool, left_pad: float = 16.0, border_px: int = 1) -> void:
	var bw: int = border_px
	t.set_stylebox("normal", cls, _pl(fill, border, 4, 0, left_pad, 8, false, 1.0, TBFrame.ALL, bw))
	t.set_stylebox("hover", cls, _pl(hover, border, 4, 0, left_pad, 8, false, 1.0, TBFrame.ALL, bw))
	t.set_stylebox("pressed", cls, _pl(press, border, 4, 0, left_pad, 8, true, 1.0, TBFrame.ALL, bw))
	t.set_stylebox("hover_pressed", cls, _pl(press, border, 4, 0, left_pad, 8, true, 1.0, TBFrame.ALL, bw))
	if fill == "act":          # a disabled primary drops to the locked secondary look (the dark slab must never look available)
		t.set_stylebox("disabled", cls, _pl("paper_1", "ink_off", 4, 0, left_pad, 8, false, 1.0))
	else:
		t.set_stylebox("disabled", cls, _pl(fill, "ink_off" if fill.begins_with("paper") else border, 4, 0, left_pad, 8, false, dis_alpha, TBFrame.ALL, bw))
	t.set_stylebox("focus", cls, TBFrame.focus(ring_on_bar, 4, 0, "on_act", "act_rim") if fill == "act" else TBFrame.focus(ring_on_bar, 4, 0))
	t.set_color("font_color", cls, TBTokens.c(text_tok)); t.set_color("font_hover_color", cls, TBTokens.c(text_tok))
	t.set_color("font_pressed_color", cls, TBTokens.c(text_tok)); t.set_color("font_focus_color", cls, TBTokens.c(text_tok))
	t.set_color("font_hover_pressed_color", cls, TBTokens.c(text_tok))
	t.set_color("font_disabled_color", cls, TBTokens.c("ink_off") if (fill.begins_with("paper") or fill == "act") else TBTokens.ca(text_tok, 0.7))
	t.set_font("font", cls, body_b()); t.set_font_size("font_size", cls, fs(15))

static func theme() -> Theme:
	sync_palette()
	TBFrame.ensure_watch()
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = fs(15)
	t.set_color("font_color", "Label", TEXT)
	# native tooltips (guide 6.9): ink-700, hairline, radius 10, 13 px
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = TBTokens.c("bar_1"); tsb.border_color = TBTokens.c("rule"); tsb.set_border_width_all(1); tsb.set_corner_radius_all(10)
	tsb.content_margin_left = 12; tsb.content_margin_right = 12; tsb.content_margin_top = 8; tsb.content_margin_bottom = 8
	t.set_stylebox("panel", "TooltipPanel", tsb)
	t.set_font_size("font_size", "TooltipLabel", 13); t.set_color("font_color", "TooltipLabel", TBTokens.c("ink_0"))
	# secondary button: the default for everything that is not the one primary of its container
	for cls in ["Button", "OptionButton", "MenuButton"]:
		_button_set(t, cls, "paper_1", "paper_hover", "paper_2", "paper_1", "ink_0", 0.6, false)
	# primary (brass) and danger (flat wax) are theme variations: K.button(..., true), K.danger(...)
	t.set_type_variation("PrimaryButton", "Button")
	_button_set(t, "PrimaryButton", "act", "act_hover", "act_press", "act", "on_act", 0.4, false, 16.0, 1)       # Atlas: signal fill, ink text
	t.set_type_variation("DangerButton", "Button")
	_button_set(t, "DangerButton", "wax", "wax_hover", "wax_press", "wax", "on_wax", 0.4, true)
	t.set_type_variation("DangerGlyphButton", "Button")
	_button_set(t, "DangerGlyphButton", "wax", "wax_hover", "wax_press", "wax", "on_wax", 0.4, true, 44.0)
	# check box / switch: a square box with a tick, never colour alone
	for cls in ["CheckBox", "CheckButton"]:
		for st in ["normal", "hover", "pressed", "disabled", "hover_pressed"]: t.set_stylebox(st, cls, _empty)
		t.set_stylebox("focus", cls, TBFrame.focus(false, 2, 0))
		t.set_color("font_color", cls, TEXT); t.set_color("font_hover_color", cls, TEXT); t.set_color("font_pressed_color", cls, TEXT); t.set_color("font_hover_pressed_color", cls, TEXT)
		t.set_color("font_disabled_color", cls, TBTokens.c("ink_off")); t.set_color("font_focus_color", cls, TEXT)
		t.set_font("font", cls, body_b()); t.set_font_size("font_size", cls, fs(15))
		t.set_constant("h_separation", cls, 10)
		var on := VecTex.new("box_on", 24, TBTokens.c("cream"), TBTokens.c("ink_0")); var off := VecTex.new("box_off", 24, TBTokens.c("paper_1"), TBTokens.c("rule"))
		for ic in ["checked", "checked_mirrored", "radio_checked"]: t.set_icon(ic, cls, on)
		for ic in ["unchecked", "unchecked_mirrored", "radio_unchecked"]: t.set_icon(ic, cls, off)
		for ic in ["checked_disabled", "checked_disabled_mirrored", "radio_checked_disabled"]: t.set_icon(ic, cls, VecTex.new("box_on", 24, TBTokens.c("paper_1"), TBTokens.c("ink_off")))
		for ic in ["unchecked_disabled", "unchecked_disabled_mirrored", "radio_unchecked_disabled"]: t.set_icon(ic, cls, VecTex.new("box_off", 24, TBTokens.c("paper_1"), TBTokens.c("ink_off")))
	# panels are flat plates: paper-0, 1 px rule, cut 6, one hard shadow
	t.set_stylebox("panel", "PanelContainer", _pl("paper_0", "rule", TBTokens.CUT_PANEL, 1, 16, 12))
	t.set_stylebox("panel", "Panel", _pl("paper_0", "rule", TBTokens.CUT_PANEL, 1, 16, 12))
	# inputs: paper-1 plate, 1 px rule, cut 4
	var le := _pl("paper_1", "rule", 4, 0, 12, 10)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", TBFrame.focus(false, 4, 0))
	t.set_stylebox("read_only", "LineEdit", _pl("paper_1", "hair", 4, 0, 12, 10, false, 0.6))
	t.set_color("font_color", "LineEdit", TEXT); t.set_color("caret_color", "LineEdit", GOLD2); t.set_font("font", "LineEdit", body()); t.set_font_size("font_size", "LineEdit", fs(15))
	t.set_color("font_placeholder_color", "LineEdit", DIM); t.set_color("font_uneditable_color", "LineEdit", TBTokens.c("ink_off"))
	t.set_color("selection_color", "LineEdit", TBTokens.ca("brass", 0.45))
	t.set_constant("minimum_character_width", "LineEdit", 4)
	# slider: 4 px track, 24 px vector thumb (the thumb is a self-drawing texture, no Image)
	var rail := StyleBoxFlat.new(); rail.bg_color = TBTokens.c("paper_1"); rail.border_color = TBTokens.c("rule"); rail.set_border_width_all(1)
	rail.content_margin_top = 2; rail.content_margin_bottom = 2
	var fillbox := StyleBoxFlat.new(); fillbox.bg_color = TBTokens.c("ink_0"); fillbox.content_margin_top = 2; fillbox.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", rail); t.set_stylebox("grabber_area", "HSlider", fillbox); t.set_stylebox("grabber_area_highlight", "HSlider", fillbox)
	t.set_stylebox("focus", "HSlider", TBFrame.focus(false, 4, 0))
	t.set_icon("grabber", "HSlider", VecTex.new("thumb", TBTokens.THUMB, TBTokens.c("brass"), TBTokens.c("ink_0")))
	t.set_icon("grabber_highlight", "HSlider", VecTex.new("thumb", TBTokens.THUMB, TBTokens.c("brass_hover"), TBTokens.c("ink_0")))
	t.set_icon("grabber_disabled", "HSlider", VecTex.new("thumb", TBTokens.THUMB, TBTokens.c("paper_1"), TBTokens.c("ink_off")))
	t.set_icon("tick", "HSlider", VecTex.new("tick", 6, TBTokens.c("rule"), TBTokens.c("rule")))
	# scrollbars: a slim flat rule-coloured grabber
	var sb := StyleBoxEmpty.new(); sb.content_margin_left = 6; sb.content_margin_right = 6; sb.content_margin_top = 6; sb.content_margin_bottom = 6
	var grab := StyleBoxFlat.new(); grab.bg_color = TBTokens.c("rule"); grab.content_margin_left = 6; grab.content_margin_right = 6; grab.content_margin_top = 6; grab.content_margin_bottom = 6
	var grab_hot := StyleBoxFlat.new(); grab_hot.bg_color = TBTokens.c("ink_1"); grab_hot.content_margin_left = 6; grab_hot.content_margin_right = 6; grab_hot.content_margin_top = 6; grab_hot.content_margin_bottom = 6
	for cls in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", cls, sb); t.set_stylebox("scroll_focus", cls, sb)
		t.set_stylebox("grabber", cls, grab); t.set_stylebox("grabber_highlight", cls, grab_hot); t.set_stylebox("grabber_pressed", cls, grab_hot)
	# popups (option lists, context menus): a paper plate, rows at least 44 high
	t.set_stylebox("panel", "PopupMenu", _pl("paper_0", "rule", 4, 0, 6, 6))
	t.set_stylebox("hover", "PopupMenu", _pl("paper_hover", "", 0, 0, 0, 0))
	t.set_stylebox("separator", "PopupMenu", _hline())
	t.set_font("font", "PopupMenu", body_b()); t.set_font_size("font_size", "PopupMenu", fs(15))
	t.set_color("font_color", "PopupMenu", TEXT); t.set_color("font_hover_color", "PopupMenu", TEXT); t.set_color("font_disabled_color", "PopupMenu", TBTokens.c("ink_off"))
	t.set_constant("v_separation", "PopupMenu", maxi(18, touch() - roundi(fs(15) * 1.25)))
	t.set_stylebox("separator", "HSeparator", _hline())
	# tooltips: dark plate, cream text
	t.set_stylebox("panel", "TooltipPanel", _pl("bar_0", "rule_dark", 4, 0, 10, 6, false, 0.96))
	t.set_color("font_color", "TooltipLabel", TBTokens.c("cream")); t.set_font("font", "TooltipLabel", body()); t.set_font_size("font_size", "TooltipLabel", fs(14))
	return t

static func _hline() -> StyleBoxLine:
	var sep := StyleBoxLine.new(); sep.color = TBTokens.c("hair"); sep.thickness = 1
	return sep

# ---- buttons -----------------------------------------------------------------------------------------------------------------------
## secondary by default, `primary` = the ink slab with brass text (one per container). Focusable, >= 48 high, activates on release.
static func button(text: String, cb: Callable = Callable(), primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(96, touch())
	b.focus_mode = Control.FOCUS_ALL
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	if primary: b.theme_type_variation = &"PrimaryButton"
	if cb.is_valid(): b.pressed.connect(cb)
	a11y(b, text, "button")
	return b

## flat wax button for irreversible verbs (declare war, attack, break pact); a left glyph is drawn when given
class DangerBtn extends Button:
	signal confirmed
	const HOLD_T := 0.6
	var glyph := ""
	var hold_confirm := false         ## destructive confirm: hold 600 ms, or press Enter twice
	var _hold := 0.0
	var _holding := false
	var _armed := false
	var _text0 := ""
	func _init(g: String) -> void:
		glyph = g
	## turns the button into a hold-to-confirm control; `confirmed` fires instead of `pressed`
	func make_hold() -> void:
		hold_confirm = true; _text0 = text
		tooltip_text = TBI18n.T("hold_confirm")
		set_process(false)
	func _gui_input(e: InputEvent) -> void:
		if not hold_confirm or disabled: return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if e.pressed: _holding = true; _hold = 0.0; set_process(true)
			else:
				if _holding and _hold < HOLD_T: _flash_hint()
				_holding = false; _hold = 0.0; queue_redraw()
		elif e is InputEventScreenTouch:
			accept_event()
		elif e.is_action_pressed("ui_accept") and not e.is_echo():
			accept_event()
			if _armed: _armed = false; text = _text0; confirmed.emit()
			else:
				_armed = true; text = TBI18n.T("press_again")
				get_tree().create_timer(3.0).timeout.connect(func():
					if is_instance_valid(self) and _armed: _armed = false; text = _text0)
	func _flash_hint() -> void:
		text = TBI18n.T("hold_confirm")
		get_tree().create_timer(1.4).timeout.connect(func(): if is_instance_valid(self) and not _armed: text = _text0)
	func _process(delta: float) -> void:
		if not _holding: set_process(false); return
		_hold += delta
		queue_redraw()
		if _hold >= HOLD_T:
			_holding = false; _hold = 0.0; set_process(false); queue_redraw(); confirmed.emit()
	func _draw() -> void:
		if hold_confirm and _hold > 0.0:
			var w: float = size.x * clampf(_hold / HOLD_T, 0.0, 1.0)
			draw_rect(Rect2(0, size.y - 4.0, w, 4.0), Color(1, 1, 1, 0.85))
		if glyph == "": return
		var col := get_theme_color("font_disabled_color" if disabled else "font_color")
		var dy: float = 1.0 if get_draw_mode() == BaseButton.DRAW_PRESSED else 0.0
		TBGlyph.draw(self, glyph, Vector2(roundf(22.0), roundf(size.y * 0.5 + dy)), 20.0, col)

static func danger(text: String, cb: Callable = Callable(), glyph: String = "swords") -> Button:
	var b := DangerBtn.new(glyph)
	b.text = text
	b.custom_minimum_size = Vector2(96, touch())
	b.focus_mode = Control.FOCUS_ALL
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	b.theme_type_variation = &"DangerGlyphButton" if glyph != "" else &"DangerButton"
	if cb.is_valid(): b.pressed.connect(cb)
	a11y(b, text, "button")
	return b

## a drawn glyph as a Control: K.glyph("coin", 20, K.TEXT)
class GlyphIcon extends Control:
	var glyph := ""
	var col := Color.WHITE
	var filled := false
	var px := 20
	func _init(g: String, size_px: int, c: Color, fill: bool = false) -> void:
		glyph = g; px = size_px; col = c; filled = fill
		custom_minimum_size = Vector2(size_px + 2, size_px + 2); mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var c := Vector2(roundf(size.x * 0.5), roundf(size.y * 0.5))
		if filled: TBGlyph.draw_filled(self, glyph, c, float(px), col)
		else: TBGlyph.draw(self, glyph, c, float(px), col)

static func glyph(g: String, size_px: int = 20, color: Color = Color.TRANSPARENT, filled: bool = false) -> Control:
	return GlyphIcon.new(g, size_px, color if color.a > 0.0 else TEXT, filled)

## square button with only a drawn glyph (close, back...). Hit area >= 48, visual square 40 (art bible 7.5).
class IconBtn extends Button:
	var glyph := "close"
	var on_bar := false
	var active := false
	var preview_state := ""          # "hover" / "pressed" / "focus": freezes a state for specimen sheets and tests
	func _init(g: String, cb: Callable, px: int = 40, bar: bool = false) -> void:
		glyph = g; on_bar = bar
		var hit := maxi(px, TBKit.touch())
		custom_minimum_size = Vector2(hit, hit); focus_mode = Control.FOCUS_ALL; flat = true
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		if cb.is_valid(): pressed.connect(cb)
		var nm: String = {"gear": "settings"}.get(g, g)
		TBKit.a11y(self, TBI18n.T(nm) if TBI18n.has_key(nm) else nm.replace("_", " ").capitalize(), "button")     # icon-only: always named (callers may refine with K.a11y)
	func _draw() -> void:
		var mode := get_draw_mode()
		if preview_state == "hover": mode = BaseButton.DRAW_HOVER
		elif preview_state == "pressed": mode = BaseButton.DRAW_PRESSED
		var vis := float(mini(int(minf(size.x, size.y)), TBTokens.ICON_VISUAL))
		var r := Rect2(roundf((size.x - vis) * 0.5), roundf((size.y - vis) * 0.5), vis, vis)
		var fill := Color.TRANSPARENT
		if mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED: fill = TBTokens.c("bar_2" if on_bar else "paper_2")
		elif mode == BaseButton.DRAW_HOVER: fill = TBTokens.c("bar_2" if on_bar else "paper_hover")
		if fill.a > 0.0: draw_style_box(TBKit.flat_plate(fill, 4), r)
		var col: Color = TBTokens.c("ink_off" if not on_bar else "smoke") if disabled else TBTokens.c("cream" if on_bar else "ink_0")
		if active and on_bar: col = TBTokens.c("brass_lt")
		var dy: float = 1.0 if mode == BaseButton.DRAW_PRESSED else 0.0
		var gs: float = 24.0 if vis >= 32.0 else roundf(vis * 0.6)
		if active: TBGlyph.draw_filled(self, glyph, r.get_center().round() + Vector2(0, dy), gs, col)
		else: TBGlyph.draw(self, glyph, r.get_center().round() + Vector2(0, dy), gs, col)
		if has_focus() or preview_state == "focus": draw_style_box(TBFrame.focus(on_bar, 4, 0), r)

static func icon_button(g: String, cb: Callable, px: int = 40) -> Button: return IconBtn.new(g, cb, px)

# ---- ornament, ledger rows, pips, meters ---------------------------------------------------------------------------------------------------
## a thin ornamental rule: --- + --- . Hero sheets and the title screen only (D3): never on panels or plain modals.
class OrnamentRule extends Control:
	var col := Color.TRANSPARENT
	func _init() -> void:
		custom_minimum_size = Vector2(0, 12); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		TBGlyph.rule(self, 0.0, size.x, 6.0, col if col.a > 0.0 else TBTokens.ca("ink_0", 0.45))

## dotted leader between a caption and its figure (ledger line)
class Leader extends Control:
	func _init() -> void:
		size_flags_horizontal = Control.SIZE_EXPAND_FILL; custom_minimum_size = Vector2(8, 16); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var y := size.y - 5.0
		var x := 2.0
		var c := TBTokens.c("hair") if not TBTokens.is_hc() else TBTokens.c("ink_1")
		while x < size.x - 2.0:
			draw_rect(Rect2(x, y, 1, 1), c)
			x += 4.0

## n of max engraved diamonds, filled; empty ones are 1 px outlines
class Pips extends Control:
	var n := 0
	var maxn := 5
	var col := Color.TRANSPARENT
	func _init(value: int, max_value: int = 5, c: Color = Color.TRANSPARENT) -> void:
		n = value; maxn = max_value; col = c if c.a > 0.0 else TBTokens.c("oxblood"); custom_minimum_size = Vector2(max_value * 14, 16); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in maxn:
			var c := Vector2(7 + i * 14, roundf(size.y * 0.5))
			if i < n: TBGlyph.draw(self, "diamond", c, 12.0, col)
			else:
				var o: Color = TBTokens.with_a(col, 0.5)
				var pts: Array = [Vector2(0, -5.5), Vector2(5.5, 0), Vector2(0, 5.5), Vector2(-5.5, 0)]
				for k in 4: draw_line(c + pts[k], c + pts[(k + 1) % 4], o, 1.0, true)

## meter 0..100: 8 px track, ticks at 30 and 50, fill coloured by threshold (>= 50 pos, 30-49 warn, < 30 neg); below 30 the fill is hatched
class Meter extends Control:
	var v := 0.0
	var col := Color.TRANSPARENT
	var auto := true
	const _TICKS := [30.0, 50.0]
	func _init(value: float, c: Color = Color.TRANSPARENT) -> void:
		v = value; col = c; auto = c.a <= 0.0
		custom_minimum_size = Vector2(0, 12); size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func low() -> bool: return auto and v < 30.0
	func _draw() -> void:
		var y := roundf((size.y - 8.0) * 0.5)
		var w := roundf(size.x)
		draw_rect(Rect2(0, y, w, 8), TBTokens.c("rule"))
		draw_rect(Rect2(1, y + 1, w - 2, 6), TBTokens.c("paper_1"))
		var f: Color = col
		if auto: f = TBTokens.c("pos") if v >= 50.0 else (TBTokens.c("warn") if v >= 30.0 else TBTokens.c("neg"))
		var fw := roundf((w - 2.0) * clampf(v / 100.0, 0.0, 1.0))
		if fw > 0.0: draw_rect(Rect2(1, y + 1, fw, 6), f)
		if low() and fw > 0.0:                                   # 45 degree hatch, 2 px lines every 6 px, clipped to the fill
			var hc: Color = TBTokens.c("paper_0")
			var k := -6.0
			while k < fw:
				var a := Vector2(1.0 + k, y + 7.0); var b := Vector2(1.0 + k + 6.0, y + 1.0)
				if b.x > 1.0 and a.x < 1.0 + fw:
					var t0 := maxf(0.0, (1.0 - a.x) / 6.0); var t1 := minf(1.0, (1.0 + fw - a.x) / 6.0)
					draw_line(a.lerp(b, t0), a.lerp(b, t1), hc, 2.0, true)
				k += 6.0
		for tv in _TICKS:
			var x := roundf(1.0 + (w - 2.0) * tv / 100.0)
			draw_rect(Rect2(x, y - 2, 1, 12), TBTokens.c("ink_0"))

## caption ........ figure
static func row(caption: String, value: String, value_col: Color = Color.TRANSPARENT, extra: Control = null) -> HBoxContainer:
	var h := hbox(6)
	var c := label(caption, 13, DIM); h.add_child(c)
	h.add_child(Leader.new())
	if extra != null: h.add_child(extra)
	if value != "":
		var n := num(value, 14, value_col if value_col.a > 0.0 else TEXT); n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(n)
	return h

## caption  figure
## [=====|====] (meter). A low value (< 30) carries a down triangle beside its number.
static func meter_row(caption: String, value: float, col: Color = Color.TRANSPARENT) -> VBoxContainer:
	var v := vbox(2)
	var h := hbox(6); h.add_child(label(caption, 13, DIM)); h.add_child(Leader.new())
	var m := Meter.new(value, col)
	if m.low(): h.add_child(glyph("tri_down", 12, TBTokens.c("neg")))
	h.add_child(num(str(int(value)), 14, TEXT)); v.add_child(h)
	v.add_child(m)
	return v

## section caption: small caps label and one hairline (no ornament)
static func section(text: String) -> HBoxContainer:
	var h := hbox(8)
	h.add_child(caps(text, 12, DIM))
	var l := Control.new(); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.size_flags_vertical = Control.SIZE_SHRINK_CENTER; l.custom_minimum_size = Vector2(8, 1); l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.draw.connect(func(): if not TBTokens.is_hc(): l.draw_rect(Rect2(0, 0, l.size.x, 1), TBTokens.c("hair")))
	h.add_child(l)
	return h

# ---- list row ----------------------------------------------------------------------------------------------------------------------------
## flat list row: name left (ellipsis, full text in the tooltip), figure right, hairline below; 48 high.
## selected = paper-2 + 3 px oxblood bar + check. Focus ring inset 2.
class ListRow extends Button:
	var left := "":
		set(v): left = v; _dirty = true; queue_redraw()
	var right := "":
		set(v): right = v; _dirty = true; queue_redraw()
	var left_col := Color.TRANSPARENT
	var right_col := Color.TRANSPARENT
	var selected := false:
		set(v): selected = v; _slot = true; _dirty = true; queue_redraw()
	var preview_state := ""          # "hover" / "pressed" / "focus": freezes a state for specimen sheets and tests
	var _slot := false
	var _dirty := true
	var _tl := TextLine.new()
	var _trt := TextLine.new()
	func _init(l: String, r: String, cb: Callable, col: Color = Color.TRANSPARENT) -> void:
		left = l; right = r; left_col = col; flat = true; focus_mode = Control.FOCUS_ALL
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, maxf(float(TBKit.touch()), ceilf(TBKit.body_b().get_height(TBKit.fs(15))) + 16.0))     # grows with the text size
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		if cb.is_valid(): pressed.connect(cb)
		TBKit.a11y(self, l if r == "" else "%s, %s" % [l, r], "button")
	func _slot_w() -> float: return float(maxi(16, TBKit.fs(16))) + 6.0
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: _dirty = true
	func _rebuild() -> void:
		_dirty = false
		_trt.clear(); _trt.add_string(right, TBKit.mono_b(), TBKit.fs(14))
		var x0 := 12.0 + (_slot_w() if _slot else 0.0)
		_tl.clear(); _tl.add_string(left, TBKit.body_b(), TBKit.fs(15))
		_tl.width = maxf(size.x - x0 - _trt.get_line_width() - 24.0, 24.0)
		_tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tooltip_text = left if TBKit.body_b().get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(15)).x > _tl.width else ""
	func _draw() -> void:
		if _dirty: _rebuild()
		var w := size.x; var h := size.y
		var mode := get_draw_mode()
		if preview_state == "hover": mode = BaseButton.DRAW_HOVER
		elif preview_state == "pressed": mode = BaseButton.DRAW_PRESSED
		var ink: Color = TBTokens.c("ink_0")
		if selected: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_2"))
		elif disabled: pass
		elif mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_2"))
		elif mode == BaseButton.DRAW_HOVER: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_1"))
		if selected: draw_rect(Rect2(0, 0, 3, h - 1), TBTokens.c("oxblood"))
		if not TBTokens.is_hc(): draw_rect(Rect2(0, h - 1, w, 1), TBTokens.c("hair"))
		var x0 := 12.0 + (_slot_w() if _slot else 0.0)
		if selected: TBGlyph.draw_filled(self, "check", Vector2(12.0 + _slot_w() * 0.5 + 1.0, roundf(h * 0.5)), float(maxi(16, TBKit.fs(16))), TBTokens.c("oxblood"))
		var lc: Color = TBTokens.c("ink_off") if disabled else (left_col if left_col.a > 0.0 else ink)
		_tl.draw(get_canvas_item(), Vector2(x0, roundf((h - 1.0 - _tl.get_size().y) * 0.5)), lc)
		_trt.draw(get_canvas_item(), Vector2(roundf(w - 12.0 - _trt.get_line_width()), roundf((h - 1.0 - _trt.get_size().y) * 0.5)), TBTokens.c("ink_off") if disabled else (right_col if right_col.a > 0.0 else ink))
		if has_focus() or preview_state == "focus": draw_style_box(TBFrame.focus(false, 0, 2), Rect2(0, 0, w, h))

static func list_row(l: String, r: String, cb: Callable, col: Color = Color.TRANSPARENT) -> Button: return ListRow.new(l, r, cb, col)

# ---- segmented control and tabs ---------------------------------------------------------------------------------------------------------------
## Equal cells in one 1 px rule frame (cut 4). Items: [[id, label], ...]. Selected = paper-2 fill + 3 px oxblood underline + filled check + ink text
## (never a black slab, art review A-2); in high contrast also a 2 px ink outline. Cells are >= touch() high and >= 48 wide. When the labels do not fit one
## row (long words, 150 / 200 % text, narrow phones) the cells wrap into a grid, and a cell grows in HEIGHT before its text is ever truncated.
## compact = filter-chip density: 13 px text, tighter padding, no check glyph (the underline and fill still carry the state).
class Segmented extends Container:
	signal chosen(id: String)
	var current := ""
	var compact := false
	var _btns := {}
	var _order: Array = []
	var _items: Array = []
	var _cell_h := 0.0
	var _last_min := Vector2.ZERO
	var _sig := ""
	const GAP := 1.0
	func setup(items: Array, cur: String, compact_cells: bool = false) -> Segmented:
		current = cur; compact = compact_cells; _items = items
		var n := items.size()
		for i in n:
			var id: String = items[i][0]
			var b := Button.new(); b.text = items[i][1]; b.focus_mode = Control.FOCUS_ALL; b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.add_theme_font_size_override("font_size", TBKit.fs(13 if compact else 15))
			b.pressed.connect(func(): select(id, true))
			b.draw.connect(func(): _draw_cell(id, b))
			add_child(b); _btns[id] = b; _order.append(id)
		_restyle()
		return self
	func select(id: String, emit: bool = false) -> void:
		current = id; _restyle()
		if emit: chosen.emit(id)
	func _pad_x() -> float: return 8.0 if compact else 14.0
	func _nat(i: int) -> float:
		var f: Font = TBKit.body_b()
		return maxf(f.get_string_size(String(_items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(13 if compact else 15)).x + 2.0 * _pad_x(), float(TBKit.MIN_TOUCH))
	## Layout for a width: {"rows": [[cell index, ...], ...], "prop": bool, "h": cell height}. Preferred: one equal-width grid (columns as many as fit);
	## when packing the cells by their own widths needs fewer rows (one short word beside long ones) the proportional rows win.
	func _plan(w: float) -> Dictionary:
		var n := _order.size()
		if n == 0: return {"rows": [], "prop": false, "h": float(TBKit.touch())}
		var nat := PackedFloat32Array(); var widest: float = 0.0
		for i in n:
			nat.append(_nat(i)); widest = maxf(widest, nat[i])
		var rows_eq: Array = []
		var cols := 1
		if w <= 1.0: cols = n
		else:
			for c in range(n, 0, -1):
				if widest <= (w - (c - 1) * GAP) / c: cols = c; break
		var r0 := 0
		while r0 < n:
			var row: Array = []
			for k in range(r0, mini(r0 + cols, n)): row.append(k)
			rows_eq.append(row); r0 += cols
		var rows: Array = rows_eq; var prop := false
		if w > 1.0 and cols < n:
			var rows_pk: Array = []; var cur: Array = []; var used: float = 0.0
			for i in n:
				var need: float = nat[i] + (GAP if not cur.is_empty() else 0.0)
				if not cur.is_empty() and used + need > w: rows_pk.append(cur); cur = []; used = 0.0; need = nat[i]
				cur.append(i); used += need
			if not cur.is_empty(): rows_pk.append(cur)
			if rows_pk.size() < rows_eq.size(): rows = rows_pk; prop = true
		var f: Font = TBKit.body_b()
		var fsz: int = TBKit.fs(13 if compact else 15)
		var lh: float = f.get_height(fsz)
		var h: float = float(TBKit.touch())
		for row in rows:
			var widths := _row_widths(row, nat, w, prop)
			for k in row.size():
				var tw: float = f.get_string_size(String(_items[row[k]][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
				var lines: int = maxi(1, ceili(tw / maxf(widths[k] - 2.0 * _pad_x(), 16.0)))
				h = maxf(h, ceilf(lines * lh) + (18.0 if lines > 1 else 16.0))
		return {"rows": rows, "prop": prop, "h": h, "nat": nat}
	func _row_widths(row: Array, nat: PackedFloat32Array, w: float, prop: bool) -> PackedFloat32Array:
		var out := PackedFloat32Array()
		var m: int = row.size()
		var free: float = w - (m - 1) * GAP
		if w <= 1.0: free = 0.0
		if not prop:
			for k in m: out.append(free / m)
		else:
			var sum: float = 0.0
			for k in m: sum += nat[row[k]]
			var extra: float = maxf(free - sum, 0.0) / m
			for k in m: out.append(nat[row[k]] + extra if sum <= free else free * nat[row[k]] / sum)
		return out
	func _get_minimum_size() -> Vector2:
		var p := _plan(size.x)
		var widest: float = float(TBKit.MIN_TOUCH)
		for i in _order.size(): widest = maxf(widest, minf(_nat(i), 140.0))
		var rn: int = (p["rows"] as Array).size()
		return Vector2(widest, rn * float(p["h"]) + maxi(rn - 1, 0) * GAP)
	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN: _sort()
	func _sort() -> void:
		var n := _order.size()
		if n == 0: return
		var p := _plan(size.x)
		var rows: Array = p["rows"]; var h: float = p["h"]
		var nat: PackedFloat32Array = p["nat"]
		var sig := "%d,%d,%s" % [rows.size(), int(h), str(rows)]
		var mask_changed: bool = sig != _sig
		_sig = sig; _cell_h = h
		for r in rows.size():
			var row: Array = rows[r]
			var widths := _row_widths(row, nat, size.x, bool(p["prop"]))
			var x: float = 0.0
			for c in row.size():
				var b: Button = _btns[_order[row[c]]]
				var cw: float = roundf(widths[c]) if c < row.size() - 1 else size.x - x
				fit_child_in_rect(b, Rect2(x, r * (h + GAP), cw, h))
				x += cw + GAP
				var m := 0
				if r == 0 and c == 0: m |= TBFrame.TL
				if r == 0 and c == row.size() - 1: m |= TBFrame.TR
				if r == rows.size() - 1 and c == 0: m |= TBFrame.BL
				if r == rows.size() - 1 and c == row.size() - 1: m |= TBFrame.BR
				if int(b.get_meta("mask", -1)) != m: b.set_meta("mask", m); mask_changed = true
		var need := Vector2(_get_minimum_size().x, rows.size() * h + (rows.size() - 1) * GAP)
		if mask_changed: _restyle()
		if need != _last_min: _last_min = need; update_minimum_size()
	func _draw() -> void:
		draw_style_box(TBFrame.plate(TBTokens.c("rule"), TBTokens.c("rule"), 4, 0, 1, 1), Rect2(Vector2.ZERO, size))
	func _draw_cell(id: String, b: Button) -> void:
		if id != current: return
		var w: float = b.size.x; var h: float = b.size.y
		if TBTokens.is_hc(): b.draw_rect(Rect2(0, 0, w, h), TBTokens.c("ink_0"), false, 2.0)
		b.draw_rect(Rect2(0, h - 3.0, w, 3.0), TBTokens.c("oxblood"))
		if compact: return
		var f: Font = TBKit.body_b()
		var fsz: int = TBKit.fs(15)
		var tw: float = minf(f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x, w - 2.0 * _pad_x())
		var gs: float = float(maxi(14, int(fsz * 0.95)))
		var x: float = (w - tw) * 0.5 - gs * 0.5 - 6.0
		if x >= gs * 0.5 + 2.0 and tw < w - 2.0 * _pad_x() - 1.0:
			TBGlyph.draw_filled(b, "check", Vector2(roundf(x), roundf((h - 3.0) * 0.5)), gs, TBTokens.c("oxblood"))
	func _restyle() -> void:
		for k in _btns:
			var b: Button = _btns[k]
			var on: bool = k == current
			var m: int = int(b.get_meta("mask", TBFrame.ALL))
			var fills: Array = ["paper_2", "paper_2", "paper_2"] if on else ["paper_1", "paper_hover", "paper_2"]
			var py: float = 6.0
			b.add_theme_stylebox_override("normal", TBKit._pl(fills[0], "", 4, 0, _pad_x(), py, false, 1.0, m))
			b.add_theme_stylebox_override("hover", TBKit._pl(fills[1], "", 4, 0, _pad_x(), py, false, 1.0, m))
			b.add_theme_stylebox_override("pressed", TBKit._pl(fills[2], "", 4, 0, _pad_x(), py, false, 1.0, m))
			b.add_theme_stylebox_override("hover_pressed", TBKit._pl(fills[2], "", 4, 0, _pad_x(), py, false, 1.0, m))
			b.add_theme_stylebox_override("focus", TBFrame.focus(false, 0, 2))
			var tc: Color = TBTokens.c("ink_0")
			for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: b.add_theme_color_override(fc, tc)
			b.set_pressed_no_signal(false)
			b.tooltip_text = b.text if on else ""
			TBKit.a11y(b, b.text, "option", TBI18n.T("a11y_selected") if on else "")
			b.queue_redraw()

static func segmented(items: Array, current: String, cb: Callable, compact: bool = false) -> Control:
	var s := Segmented.new().setup(items, current, compact)
	s.chosen.connect(cb)
	return s

## text tab: 3 px oxblood underline with square ends under the active one
class TabBtn extends Button:
	var active := false
	func _init(txt: String) -> void:
		text = txt; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, TBKit.touch())
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_stylebox_override("normal", TBKit._empty); add_theme_stylebox_override("disabled", TBKit._empty)
		add_theme_stylebox_override("hover", TBKit._pl("paper_1", "", 0, 0, 12, 8))
		add_theme_stylebox_override("pressed", TBKit._pl("paper_2", "", 0, 0, 12, 8)); add_theme_stylebox_override("hover_pressed", TBKit._pl("paper_2", "", 0, 0, 12, 8))
		add_theme_stylebox_override("focus", TBFrame.focus(false, 0, 2))
		TBKit.a11y(self, txt, "tab")
	func _draw() -> void:
		if active: draw_rect(Rect2(0, size.y - 3, size.x, 3), TBTokens.c("oxblood"))

class Tabs extends HBoxContainer:
	signal chosen(id: String)
	var current := ""
	var _btns := {}
	func setup(items: Array, cur: String) -> Tabs:
		current = cur
		add_theme_constant_override("separation", 4)
		for it in items:
			var id: String = it[0]
			var b := TabBtn.new(it[1])
			b.pressed.connect(func(): select(id, true))
			add_child(b); _btns[id] = b
		_restyle()
		return self
	func select(id: String, emit: bool = false) -> void:
		current = id; _restyle()
		if emit: chosen.emit(id)
	func _restyle() -> void:
		for k in _btns:
			var b: TabBtn = _btns[k]
			b.active = k == current
			for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(fc, TBTokens.c("ink_0") if b.active or fc != "font_color" else TBTokens.c("ink_1"))
			b.add_theme_font_override("font", TBKit.body_b())
			b.queue_redraw()

static func tabs(items: Array, current: String, cb: Callable) -> Control:
	var s := Tabs.new().setup(items, current)
	s.chosen.connect(cb)
	return s

# ---- slider -----------------------------------------------------------------------------------------------------------------------------------------
## HSlider with a 48 px hit height; the thumb is drawn by the theme texture, the focus ring follows the thumb
class KSlider extends HSlider:
	func _init() -> void:
		custom_minimum_size = Vector2(0, TBKit.touch()); focus_mode = Control.FOCUS_ALL
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_theme_stylebox_override("focus", TBKit._empty)
	func _draw() -> void:
		if not (has_focus() and TBFrame.kbd_nav): return
		var span := size.x - TBTokens.THUMB
		var ratio := 0.0 if max_value <= min_value else (value - min_value) / (max_value - min_value)
		var c := Vector2(roundf(TBTokens.THUMB * 0.5 + span * ratio), roundf(size.y * 0.5))
		draw_arc(c, TBTokens.THUMB * 0.5 + 2.5, 0.0, TAU, 36, TBTokens.c("paper_0"), 1.0, true)
		draw_arc(c, TBTokens.THUMB * 0.5 + 4.0, 0.0, TAU, 36, TBTokens.c("ink_0"), 2.0, true)

static func slider(min_v: float, max_v: float, step_v: float, value: float, cb: Callable = Callable(), accessible_name: String = "") -> HSlider:
	var s := KSlider.new()
	s.min_value = min_v; s.max_value = max_v; s.step = step_v; s.value = value
	if cb.is_valid(): s.value_changed.connect(cb)
	a11y(s, accessible_name if accessible_name != "" else TBI18n.T("a11y_slider"), "slider")
	return s

## [-] [slider] [+] [value]: a slider with 48 px steppers (A11Y-TCH-004); dragging is optional. Value text through `fmt` (default "NN%").
class SliderRow extends HBoxContainer:
	signal changed(v: float)
	var slider: HSlider
	var value_label: Label
	var _fmt := Callable()
	var _name := ""
	func _init(min_v: float, max_v: float, step_v: float, value: float, label_text: String, fmt: Callable = Callable()) -> void:
		_fmt = fmt; _name = label_text
		add_theme_constant_override("separation", 6)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var minus := TBKit.button("−", func(): _nudge(-step_v)); minus.custom_minimum_size = Vector2(TBKit.touch(), TBKit.touch())
		TBKit.a11y(minus, TBI18n.T("step_down", {"s": label_text}), "button")
		var plus := TBKit.button("+", func(): _nudge(step_v)); plus.custom_minimum_size = Vector2(TBKit.touch(), TBKit.touch())
		TBKit.a11y(plus, TBI18n.T("step_up", {"s": label_text}), "button")
		slider = TBKit.slider(min_v, max_v, step_v, value, Callable(), label_text)
		value_label = TBKit.num(_text(value), 14)
		value_label.custom_minimum_size.x = maxf(48.0, TBKit.mono_b().get_string_size("100%", HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(14)).x + 12.0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(minus); add_child(slider); add_child(plus); add_child(value_label)
		slider.value_changed.connect(func(v: float):
			value_label.text = _text(v); TBKit.a11y(slider, "%s %s" % [_name, _text(v)], "slider")
			changed.emit(v))
	func _text(v: float) -> String: return String(_fmt.call(v)) if _fmt.is_valid() else "%d%%" % int(round(v))
	func _nudge(d: float) -> void:
		slider.value = clampf(slider.value + d, slider.min_value, slider.max_value)
	func set_value(v: float) -> void:
		slider.set_value_no_signal(v); value_label.text = _text(v)

static func slider_row(label_text: String, min_v: float, max_v: float, step_v: float, value: float, cb: Callable = Callable(), fmt: Callable = Callable()) -> SliderRow:
	var r := SliderRow.new(min_v, max_v, step_v, value, label_text, fmt)
	if cb.is_valid(): r.changed.connect(cb)
	return r

## Switch row: the whole row is the target (>= touch() high, grows with the text), label left, the state as the WORD On / Off plus a drawn switch whose
## knob carries a check (on) or a dash (off): never colour alone. cb(value: bool). Announces the new state when speech is on.
class ToggleRow extends Button:
	signal toggled_to(v: bool)
	var on := false
	var _word: Label
	var _sw: Control
	func _init(label_text: String, value: bool, cb: Callable) -> void:
		on = value
		flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, TBKit.touch())
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		var row := TBKit.hbox(10); row.set_anchors_preset(Control.PRESET_FULL_RECT); row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.offset_left = 12; row.offset_right = -12
		add_child(row)
		var l := TBKit.label(label_text, 15); l.add_theme_font_override("font", TBKit.body_b())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.custom_minimum_size.x = 40; l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(l); _l = l
		resized.connect(_fit); l.minimum_size_changed.connect(_fit)
		_word = TBKit.label("", 15); _word.add_theme_font_override("font", TBKit.body_b()); _word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_word.custom_minimum_size.x = TBKit.body_b().get_string_size(TBI18n.T("off"), HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(15)).x
		row.add_child(_word)
		_sw = Control.new(); _sw.custom_minimum_size = Vector2(44, 26); _sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER; _sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sw.draw.connect(_draw_switch)
		row.add_child(_sw)
		pressed.connect(func():
			set_on(not on)
			if cb.is_valid(): cb.call(on)
			toggled_to.emit(on)
			TBKit.announce("%s %s" % [label_text, TBI18n.T("on") if on else TBI18n.T("off")]))
		_label_text = label_text
		_sync()
	var _label_text := ""
	var _l: Label
	func set_on(v: bool) -> void:
		on = v; _sync()
	func _sync() -> void:
		_word.text = TBI18n.T("on") if on else TBI18n.T("off")
		TBKit.a11y(self, _label_text, "switch", _word.text)
		if _sw != null: _sw.queue_redraw()
		queue_redraw()
	func _draw_switch() -> void:
		var w: float = _sw.size.x; var h: float = _sw.size.y
		_sw.draw_rect(Rect2(0, 0, w, h), TBTokens.c("rule"))
		_sw.draw_rect(Rect2(1, 1, w - 2, h - 2), TBTokens.c("act") if on else TBTokens.c("paper_1"))
		var k: float = h - 6.0
		var kx: float = w - 3.0 - k if on else 3.0
		_sw.draw_rect(Rect2(kx, 3, k, k), TBTokens.c("on_act") if on else TBTokens.c("ink_0"))
		var c := Vector2(kx + k * 0.5, 3.0 + k * 0.5)
		var ink: Color = TBTokens.c("act") if on else TBTokens.c("paper_1")
		if on: TBGlyph.draw_filled(_sw, "check", c.round(), k - 2.0, ink)
		else: _sw.draw_rect(Rect2(c.x - 4.0, c.y - 1.0, 8.0, 2.0), ink)
	func _draw() -> void:
		var w := size.x; var h := size.y
		var mode := get_draw_mode()
		if mode == BaseButton.DRAW_HOVER: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_1"))
		elif mode == BaseButton.DRAW_PRESSED: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_2"))
		if not TBTokens.is_hc(): draw_rect(Rect2(0, h - 1, w, 1), TBTokens.c("hair"))
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(false, 0, 2), Rect2(0, 0, w, h))
	func _fit() -> void:                  # a wrapped label makes the row taller (never truncates)
		if _l == null: return
		var want: float = maxf(float(TBKit.touch()), _l.get_combined_minimum_size().y + 16.0)
		if absf(custom_minimum_size.y - want) > 0.5: custom_minimum_size.y = want
		if size.y > want + 0.5 and want <= float(TBKit.touch()) + 0.5: reset_size()

static func toggle(text: String, value: bool, cb: Callable = Callable()) -> Button:
	return ToggleRow.new(text, value, cb)

## visual twin of a sound / alert (A11Y-AUD-006): an "Alert" glyph + word + the caption on a bar plate. kind: info | warn | neg
static func alert_strip(text: String, kind: String = "info") -> Control:
	var tone := "info" if kind == "info" else ("warn" if kind == "warn" else "neg")
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _pl("bar_0", "rule_dark", 4, 0, 10, 6, false, 0.96))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := hbox(8); h.mouse_filter = Control.MOUSE_FILTER_IGNORE; pc.add_child(h)
	var col: Color = TBTokens.c({"info": "info_bar", "warn": "warn_bar", "neg": "neg_bar"}[tone])
	h.add_child(glyph({"info": "info", "warn": "warning", "neg": "warning"}[tone], 20, col))
	var wd := caps(TBI18n.T("a11y_alert"), 12, col); h.add_child(wd)
	var l := label(text, 14, TBTokens.c("cream")); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.custom_minimum_size.x = 40
	h.add_child(l)
	a11y(pc, "%s: %s" % [TBI18n.T("a11y_alert"), text], "")
	return pc

# ---- command card, chip, glyph label -------------------------------------------------------------------------------------------------------------------
static var _card_styles := {}
static func card_style(state: String, recommended: bool, armed: bool) -> TBFrame:
	var key := "%s%d%d%d" % [state, int(recommended), int(armed), TBTokens.sig()]
	if _card_styles.has(key): return _card_styles[key]
	var fill := "paper_1"
	match state:
		"hover": fill = "paper_hover"
		"pressed": fill = "paper_2"
	var f := TBFrame.plate(TBTokens.ca(fill, 0.6 if state == "disabled" else 1.0), TBTokens.c("brass_ink" if armed else ("ink_off" if state == "disabled" else "rule")), 4, 0, 12, 8, state == "pressed", 2 if armed else 1)
	if armed or recommended: f.accent = TBTokens.c("brass" if not armed else "brass_ink"); f.accent_w = 3
	if armed or recommended: f.set_content_margin(SIDE_LEFT, 16)
	_card_styles[key] = f
	return f

## an order card: 32 px glyph tile, title (Alegreya 700 15), consequence line (13, ink-1), cost chip right (Mono 700 14 + coin).
## `disabled_reason` != "" disables the card and prints the reason beneath; `unaffordable` colours the cost neg with a lock.
## Armed (map gesture started) = 2 px brass-ink outline + 3 px bar; recommended = 3 px brass bar.
class CommandCard extends PanelContainer:
	signal activated
	var armed := false:
		set(v): armed = v; _apply()
	var recommended := false
	var disabled := false
	var _hover := false
	var _down := false
	var _cb := Callable()
	var preview_state := "":          # "hover" / "pressed" / "focus": freezes a state for specimen sheets and tests
		set(v): preview_state = v; _apply(); queue_redraw()
	func _init(glyph_id: String, title_text: String, consequence: String, cost_text: String, cb: Callable, disabled_reason: String, rec: bool, arm: bool, unaffordable: bool) -> void:
		recommended = rec; armed = arm; _cb = cb; disabled = disabled_reason != "" or unaffordable
		focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(0, 56)
		var row := TBKit.hbox(12); add_child(row)
		var ink: Color = TBTokens.c("ink_off") if disabled else TBTokens.c("ink_0")
		if glyph_id != "":
			var tile := Control.new(); tile.custom_minimum_size = Vector2(32, 32); tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var tile_style := TBFrame.plate(TBTokens.c("paper_0"), TBTokens.c("hair"), 2, 0, 0, 0)
			tile.draw.connect(func():
				tile.draw_style_box(tile_style, Rect2(Vector2.ZERO, tile.size))
				TBGlyph.draw(tile, glyph_id, (tile.size * 0.5).round(), 20.0, ink))
			row.add_child(tile)
		var col := TBKit.vbox(2); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.size_flags_vertical = Control.SIZE_SHRINK_CENTER; col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := TBKit.label(title_text, 15, ink); t.add_theme_font_override("font", TBKit.body_b())
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; t.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t.custom_minimum_size.x = 40
		col.add_child(t)
		if consequence != "":
			var d := TBKit.label(consequence, 13, TBTokens.c("ink_off") if disabled else TBTokens.c("ink_1")); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE; d.size_flags_horizontal = Control.SIZE_EXPAND_FILL; d.custom_minimum_size.x = 40
			col.add_child(d)
		if disabled_reason != "":
			var rr := TBKit.hbox(4); rr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var lk := TBKit.glyph("lock", 14, TBTokens.c("neg")); rr.add_child(lk)
			var rl := TBKit.label(disabled_reason, 13, TBTokens.c("neg")); rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rl.custom_minimum_size.x = 40
			rr.add_child(rl); col.add_child(rr)
			tooltip_text = disabled_reason
		row.add_child(col)
		if cost_text != "":
			var cost := TBKit.hbox(4); cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER; cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost.add_child(TBKit.glyph("lock" if unaffordable else "coin", 16, TBTokens.c("neg") if unaffordable else ink))
			var cl := TBKit.num(cost_text, 14, TBTokens.c("neg") if unaffordable else ink); cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cost.add_child(cl)
			row.add_child(cost)
		mouse_entered.connect(func(): _hover = true; _apply())
		mouse_exited.connect(func(): _hover = false; _apply())
		_apply()
	func _apply() -> void:
		var st := "disabled" if disabled else ("pressed" if (_down or preview_state == "pressed") else ("hover" if (_hover or preview_state == "hover") else "normal"))
		add_theme_stylebox_override("panel", TBKit.card_style(st, recommended, armed))
	func _draw() -> void:
		if has_focus() or preview_state == "focus": draw_style_box(TBFrame.focus(false, 4, 0), Rect2(Vector2.ZERO, size))
	func _gui_input(e: InputEvent) -> void:
		if disabled: return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_down = true; _apply()
			else:
				var fire := _down and Rect2(Vector2.ZERO, size).has_point(e.position)       # release inside fires; sliding off cancels (A11Y-TCH-005)
				_down = false; _apply()
				if fire: _fire()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			_fire(); accept_event()
	func _fire() -> void:
		activated.emit()
		if _cb.is_valid(): _cb.call()

static func command_card(glyph_id: String, title_text: String, consequence: String, cost_text: String, cb: Callable, disabled_reason: String = "", recommended: bool = false, armed: bool = false, unaffordable: bool = false) -> Control:
	return CommandCard.new(glyph_id, title_text, consequence, cost_text, cb, disabled_reason, recommended, armed, unaffordable)

## event choice = a command card without glyph or cost
static func choice_card(title_text: String, detail: String, cb: Callable, primary: bool = false) -> Control:
	return CommandCard.new("", title_text, detail, "", cb, "", primary, false, false)

## status chip, cut 2, 28 high. tone: neutral | pos | neg | warn | info | own. Glyph backs every hue (default per tone).
## On paper by default; on_bar = dark furniture. Warning is an amber FILL with ink text (never amber text).
static func chip(text: String, glyph_id: String = "", tone: String = "neutral", on_bar: bool = false, height: int = 28) -> Control:
	var suffix := "_bar" if on_bar else ""
	var tone_tok := {"pos": "pos", "neg": "neg", "warn": "warn", "info": "info", "own": "brass_lt" if on_bar else "brass_ink"}
	var fill_tok := "bar_1" if on_bar else "paper_1"
	var border_tok := "" if on_bar else "rule"
	var text_tok := "cream" if on_bar else "ink_0"
	var gl := glyph_id
	if tone != "neutral":
		var tk: String = tone_tok[tone]
		var colour: String = tk + suffix if tone != "own" else tk
		if tone == "warn":
			fill_tok = "warn_bar"; border_tok = "warn" if not on_bar else ""; text_tok = "on_brass"
			if gl == "": gl = "warning"
		else:
			border_tok = colour; text_tok = colour
			if gl == "": gl = {"pos": "tri_up", "neg": "tri_down", "info": "info", "own": ""}[tone]
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _pl(fill_tok, border_tok, TBTokens.CUT_CHIP, 0, 8, 2))
	pc.custom_minimum_size = Vector2(0, height); pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := hbox(4); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink: Color = TBTokens.c(text_tok)
	if gl != "": h.add_child(glyph(gl, maxi(16, fs(16)), ink))
	var l := label(text, 13, ink); l.add_theme_font_override("font", body_b()); l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	pc.add_child(h)
	return pc

## tiny drawn glyph followed by a Mono figure
class GlyphLabel extends HBoxContainer:
	func _init(g: String, text: String, col: Color, size_px: int = 13) -> void:
		add_theme_constant_override("separation", 4)
		add_child(TBKit.glyph(g, maxi(size_px, 16), col))
		add_child(TBKit.num(text, size_px, col))

static func glyph_label(g: String, text: String, col: Color = Color.TRANSPARENT, size_px: int = 13) -> Control: return GlyphLabel.new(g, text, col if col.a > 0.0 else GOLD2, size_px)

static func ornament() -> Control: return OrnamentRule.new()

static func glyph_label_big(g: String) -> Control:
	var ic := glyph(g, 24, GOLD2)
	ic.custom_minimum_size = Vector2(30, 30)
	return ic

# ---- modal ---------------------------------------------------------------------------------------------------------------------------------------------------
## Esc closes the top modal (unless it is a decision: no title), Tab / arrows stay inside it, focus returns to the opener
class ModalGuard extends Node:
	var back: Control
	var dismissable := true
	func _is_top() -> bool:
		var par := back.get_parent()
		if par == null: return false
		var top: Node = null
		for ch in par.get_children():
			if ch.has_meta("tb_modal") and not ch.is_queued_for_deletion(): top = ch
		return top == back
	func _input(e: InputEvent) -> void:
		if not (e is InputEventKey) or not e.pressed or e.echo or not _is_top(): return
		var vp := get_viewport()
		if e.is_action_pressed("ui_cancel"):
			if dismissable: back.queue_free()
			vp.set_input_as_handled(); return
		var f := vp.gui_get_focus_owner()
		var inside: bool = f != null and back.is_ancestor_of(f)
		if e.is_action_pressed("ui_accept") and f != null and not inside:       # nothing behind the scrim may be activated
			vp.set_input_as_handled(); return
		var tab_n: bool = e.is_action_pressed("ui_focus_next")
		var tab_p: bool = e.is_action_pressed("ui_focus_prev")
		var arrow_n: bool = e.is_action_pressed("ui_down") or e.is_action_pressed("ui_right")
		var arrow_p: bool = e.is_action_pressed("ui_up") or e.is_action_pressed("ui_left")
		if not (tab_n or tab_p or arrow_n or arrow_p): return
		if inside and (arrow_n or arrow_p):
			if f is LineEdit or f is TextEdit: return                              # the caret keeps its arrows (Tab still leaves)
			if f is Range and (e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right")): return
		var nxt: bool = tab_n or arrow_n
		var list: Array = TBKit.focusables(back)
		if list.is_empty(): return
		var i: int = list.find(f) if inside else -1
		var j: int = 0
		if i < 0: j = 0 if nxt else list.size() - 1
		else: j = (i + (1 if nxt else -1) + list.size()) % list.size()
		(list[j] as Control).grab_focus()
		vp.set_input_as_handled()

static func focusables(root: Node) -> Array:
	var out: Array = []
	for ch in root.get_children():
		if ch is Control:
			var c := ch as Control
			if not c.visible: continue
			if c.focus_mode == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled) and not (c is LineEdit and not (c as LineEdit).editable): out.append(c)
		out.append_array(focusables(ch))
	return out

static func _focus_first(back: Control) -> void:
	if not is_instance_valid(back) or not back.is_inside_tree(): return
	var list := focusables(back)
	var pick: Control = null
	for c in list:
		if c is Button and (c as Button).theme_type_variation == &"PrimaryButton": pick = c; break
	if pick == null:
		for c in list:
			if not (c is Button and (c as Button).theme_type_variation in [&"DangerButton", &"DangerGlyphButton"]) and not (c is IconBtn): pick = c; break
	if pick == null and not list.is_empty(): pick = list[0]
	if pick != null: pick.grab_focus()


## AoC dialog footer button: a flat square cell filling its half of the footer (primary in brass text, danger in wax)
static func style_footer_button(b: Button) -> void:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 44.0)
	var pr: bool = b.theme_type_variation == "PrimaryButton"
	var dg: bool = b.theme_type_variation == "DangerButton" or b.theme_type_variation == "DangerGlyphButton"
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.set_corner_radius_all(0)
		bs.bg_color = TBTokens.c("paper_1")
		if st == "hover": bs.bg_color = TBTokens.c("paper_hover")
		elif st == "pressed" or st == "hover_pressed": bs.bg_color = TBTokens.c("paper_2")
		if dg and st != "disabled": bs.bg_color = TBTokens.c("wax")
		if st == "focus":
			bs.bg_color = Color.TRANSPARENT; bs.set_border_width_all(2 if TBFrame.kbd_nav else 0); bs.border_color = TBTokens.c("cream")
		bs.content_margin_left = 44 if b.theme_type_variation == "DangerGlyphButton" else 12; bs.content_margin_right = 12; bs.content_margin_top = 10; bs.content_margin_bottom = 10
		b.add_theme_stylebox_override(st, bs)
	var fc: Color = TBTokens.c("on_wax") if dg else (TBTokens.c("brass_lt") if pr else TBTokens.c("ink_0"))
	for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]: b.add_theme_color_override(cn, fc)
	b.add_theme_color_override("font_disabled_color", TBTokens.c("ink_off"))

## the dialog header strip (AoC): a darker bar with a rule under it, carrying `content`
static func header_strip(content: Control, left: int = 14, right: int = 6) -> PanelContainer:
	var strip := PanelContainer.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = TBTokens.ca("bar_2", 0.95); ssb.border_color = TBTokens.ca("brass", 0.7); ssb.border_width_bottom = 2
	ssb.set_corner_radius_all(0)
	ssb.content_margin_left = left; ssb.content_margin_right = right; ssb.content_margin_top = 4; ssb.content_margin_bottom = 4
	strip.add_theme_stylebox_override("panel", ssb)
	strip.add_child(content)
	return strip

## centred modal card over the scrim; returns [backdrop, body_vbox, footer_hbox].
## Landscape: card up to 920 wide. Portrait: full-width bottom sheet <= 92 %. Header bar = title (Cinzel 700 22 oxblood) + close (48 hit).
## `hero` = the one hero sheet (ceremony only) with its single ornament rule. Enter 180 ms, no scale (respects reduce motion).
static func modal(parent: Control, title_text: String = "", width: int = 520, glyph_id: String = "", hero: bool = false) -> Array:
	TBFrame.ensure_watch()
	var vp := parent.get_viewport_rect().size
	var portrait := vp.y > vp.x
	var pad: int = 16 if portrait else 24
	var max_h: float = vp.y * 0.92 if portrait else vp.y - 96.0
	var back := ColorRect.new()
	back.color = TBTokens.ca("table", TBTokens.SCRIM_ALPHA)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_STOP
	back.set_meta("tb_modal", true)
	var card := PanelContainer.new()
	var holder: Control
	if portrait:
		holder = Control.new(); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		holder = CenterContainer.new(); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		card.custom_minimum_size = Vector2(mini(mini(420 if width <= 520 else width, TBTokens.MODAL_W_MAX), int(vp.x) - 32), 0)
		holder.add_child(card)
	back.add_child(holder)
	var outer := vbox(12)
	var head: Control = null
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var footer := hbox(8)          # pinned below the scrolling body: primary right, secondary left (callers add)
	var v := vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	if hero:
		card.add_theme_stylebox_override("panel", TBFrame.hero(pad + 4, pad))
		card.add_child(outer)
		if title_text != "":
			var hh := hbox(12)
			if glyph_id != "": hh.add_child(glyph_label_big(glyph_id))
			var t := title(title_text, 20 if portrait else 22)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t.size_flags_vertical = Control.SIZE_SHRINK_CENTER; t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hh.add_child(t)
			hh.add_child(IconBtn.new("close", func(): if is_instance_valid(back): back.queue_free(), 40))
			outer.add_child(hh); head = hh
			outer.add_child(ornament())
		outer.add_child(scroll)
		outer.add_child(footer)
	else:
		# Atlas dialog (guide 6.10): card (ink-800, hairline, radius 16), 52 px header (icon + 20/600 title + close), scrolling body, footer: secondary left, primary right
		back.color = TBTokens.ca("table", 0.55)
		card.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_0"), TBTokens.c("rule"), TBTokens.CUT_PANEL, 2, 0, 0, false, 1, (TBFrame.TL | TBFrame.TR) if portrait else TBFrame.ALL))
		outer.add_theme_constant_override("separation", 0)
		card.add_child(outer)
		var hh2 := hbox(10)
		hh2.custom_minimum_size = Vector2(0, 52)
		if glyph_id != "": hh2.add_child(glyph_label_big(glyph_id))
		var t2 := title(title_text, 20, TBTokens.c("ink_0"))
		t2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t2.size_flags_vertical = Control.SIZE_SHRINK_CENTER; t2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hh2.add_child(t2)
		if title_text != "": hh2.add_child(IconBtn.new("close", func(): if is_instance_valid(back): back.queue_free(), 36))
		var hm2 := MarginContainer.new()
		hm2.add_theme_constant_override("margin_left", 16); hm2.add_theme_constant_override("margin_right", 10)
		hm2.add_child(hh2)
		if title_text != "":
			outer.add_child(hm2); head = hm2
			var hr := ColorRect.new(); hr.color = TBTokens.c("rule"); hr.custom_minimum_size = Vector2(0, 1); hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			outer.add_child(hr)
		var body_m := MarginContainer.new()
		body_m.add_theme_constant_override("margin_left", pad); body_m.add_theme_constant_override("margin_right", pad)
		body_m.add_theme_constant_override("margin_top", 16); body_m.add_theme_constant_override("margin_bottom", 8)
		body_m.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body_m.add_child(scroll)
		outer.add_child(body_m)
		var fpc := MarginContainer.new()
		fpc.add_theme_constant_override("margin_left", pad); fpc.add_theme_constant_override("margin_right", pad)
		fpc.add_theme_constant_override("margin_top", 8); fpc.add_theme_constant_override("margin_bottom", 16)
		footer.add_theme_constant_override("separation", 8)
		fpc.add_child(footer)
		outer.add_child(fpc)
	var opener := parent.get_viewport().gui_get_focus_owner()
	parent.add_child(back)
	var guard := ModalGuard.new(); guard.back = back; guard.dismissable = title_text != ""
	back.add_child(guard)
	if opener != null: parent.get_viewport().gui_release_focus()
	back.tree_exiting.connect(func(): if is_instance_valid(opener) and opener.is_inside_tree() and opener.focus_mode != Control.FOCUS_NONE: opener.grab_focus.call_deferred())
	if TBFrame.kbd_nav: _focus_first.call_deferred(back)
	if motion_ok():                       # sheet rises 8 px while the scrim fades in; no scale
		back.modulate.a = 0.0
		var tw := back.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(back, "modulate:a", 1.0, 0.18)
		tw.tween_property(holder, "offset_top", 0.0, 0.18).from(8.0)
		tw.tween_property(holder, "offset_bottom", 0.0, 0.18).from(8.0)
	# a ScrollContainer reports zero height: size it to its content, capped to the viewport
	var fit := func():
		if not is_instance_valid(back) or not back.is_inside_tree(): return
		var vh: float = back.get_viewport_rect().size.y
		var mh: float = vh * 0.92 if back.get_viewport_rect().size.y > back.get_viewport_rect().size.x else vh - 96.0
		var head_h: float = head.get_combined_minimum_size().y + 12.0 if head != null else 0.0
		var cap: float = mh - 2.0 * pad - head_h - footer.get_combined_minimum_size().y - 30.0
		scroll.custom_minimum_size.y = minf(v.get_combined_minimum_size().y + 4.0, cap)
	v.minimum_size_changed.connect(fit)
	footer.minimum_size_changed.connect(fit)
	back.resized.connect(fit)
	fit.call_deferred()
	return [back, v, footer]
