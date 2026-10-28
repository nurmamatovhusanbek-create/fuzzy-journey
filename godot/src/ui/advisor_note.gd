## F2: the Advisor's note. One true line of the game's own advice (data/i18n advice_*) on a small Bezel plate: on the title, under the menu, a new line every 12 s;
## in a game, above the lens bar while a turn takes more than a second to process. A shuffled bag, so no line comes twice before the others have been seen.
## Fades with TBFx (Light and Full); with Effects Off or Reduce motion the lines swap and the plate appears at once. Switch: Settings > Display (cfg "tips").
class_name TBAdvisorNote
extends Control

const KEYS := ["advice_turn", "advice_infamy", "advice_war", "advice_trade", "advice_ruler", "advice_decrees", "advice_merc", "advice_cap", "advice_colonize", "advice_attack", "advice_annals", "advice_minimap"]
const INTERVAL := 12.0
var u := 1.0                       # layout unit: 1.0 = the desktop stage (a title scales it with the screen)
var auto := false                  # rotates by itself (the title) / one line per showing (a game)
var bottom_y := -1.0               # when set, the plate keeps its bottom edge here whatever its height
var _bag: Array = []
var _pos := -1
var _key := ""
var _t := 0.0
var _tw: Tween
var _want_w := 270.0
var shown := false
static var fixed_seed := -1          # tests: a fixed shuffle, so two runs of the same screen show the same line

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE; focus_mode = Control.FOCUS_NONE; modulate.a = 0.0; visible = false

## the key of the current line (tests)
func key() -> String: return _key
func line() -> String: return TBI18n.T(_key) if _key != "" else ""

func setup(unit: float, width: float, rotate: bool) -> void:
	u = unit; _want_w = width; auto = rotate
	if _key == "": _take_next()
	_relayout()

## the next line of the bag (a new shuffle when it is used up; never the one just shown first)
func _take_next() -> void:
	_pos += 1
	if _pos >= _bag.size():
		_bag = range(KEYS.size())
		if fixed_seed >= 0:
			var r := RandomNumberGenerator.new(); r.seed = fixed_seed + _pos + _bag.size()
			for i in range(_bag.size() - 1, 0, -1):
				var j := r.randi_range(0, i); var tmp = _bag[i]; _bag[i] = _bag[j]; _bag[j] = tmp
		else: _bag.shuffle()
		if _key != "" and KEYS[_bag[0]] == _key and _bag.size() > 1: var t = _bag[0]; _bag[0] = _bag[1]; _bag[1] = t
		_pos = 0
	_key = KEYS[_bag[_pos]]

func next_tip() -> void:
	if _tw != null and _tw.is_valid(): _tw.kill()
	if shown and TBFx.on(TBFx.LIGHT) and is_inside_tree():
		_tw = create_tween()
		_tw.tween_property(self, "modulate:a", 0.0, 0.2)
		_tw.tween_callback(func(): _take_next(); _relayout())
		_tw.tween_property(self, "modulate:a", 1.0, 0.3)
	else:
		_take_next(); _relayout()
		if shown: modulate.a = 1.0

func show_note() -> void:
	if shown: return
	shown = true; visible = true; _t = 0.0
	if _tw != null and _tw.is_valid(): _tw.kill()
	_relayout()
	if TBFx.on(TBFx.LIGHT) and is_inside_tree():
		_tw = create_tween(); _tw.tween_property(self, "modulate:a", 1.0, 0.4).from(0.0)
	else: modulate.a = 1.0

func hide_note() -> void:
	if not shown: return
	shown = false
	if _tw != null and _tw.is_valid(): _tw.kill()
	if TBFx.on(TBFx.LIGHT) and is_inside_tree():
		_tw = create_tween(); _tw.tween_property(self, "modulate:a", 0.0, 0.25); _tw.tween_callback(func(): visible = shown)
	else: modulate.a = 0.0; visible = false

func _process(delta: float) -> void:
	if not auto or not shown or not is_visible_in_tree(): return
	_t += delta
	if _t >= INTERVAL: _t = 0.0; next_tip()

# ---------------------------------------------------------------- geometry and drawing
func _fs_label() -> int: return maxi(8, int(round(8.7 * u)))
func _fs_text() -> int: return maxi(10, int(round(14.0 * u)))
func _pad() -> float: return 12.0 * u
func _font_label() -> Font: return TBKit.tracked(TBKit.cinzel(700), 3)
func _font_text() -> Font: return TBKit.alegreya(400, true)

func _text_h(w: float) -> float:
	return _font_text().get_multiline_string_size(line(), HORIZONTAL_ALIGNMENT_LEFT, w - 2.0 * _pad(), _fs_text(), 4, TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE, TextServer.JUSTIFICATION_NONE).y

func _relayout() -> void:
	var w: float = _want_w
	var h: float = _pad() * 0.9 + 11.0 * u + 7.0 * u + _text_h(w) + _pad() * 1.15
	custom_minimum_size = Vector2(w, h); size = Vector2(w, h)
	if bottom_y >= 0.0: position.y = bottom_y - h
	queue_redraw()

func _draw() -> void:
	if _key == "": return
	var w := size.x; var h := size.y; var n := 8.5 * u; var pad := _pad()
	var plate := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h - n), Vector2(w - n, h), Vector2(0, h)])
	draw_colored_polygon(plate, TBTokens.with_a(TBTokens.c("bar_0"), 0.88))
	var line_pts := plate.duplicate(); line_pts.append(plate[0])
	draw_polyline(line_pts, TBTokens.c("rule_dark"), 1.0, true)
	var lf := _font_label(); var ls := _fs_label()
	var ly := pad * 0.9 + 9.0 * u
	var d := 3.4 * u
	draw_colored_polygon(PackedVector2Array([Vector2(pad + d, ly - 0.35 * ls - d), Vector2(pad + 2.0 * d, ly - 0.35 * ls), Vector2(pad + d, ly - 0.35 * ls + d), Vector2(pad, ly - 0.35 * ls)]), TBTokens.c("brass_lt"))
	draw_string(lf, Vector2(pad + 2.0 * d + 5.0 * u, ly), TBI18n.T("advisor_note").to_upper() if TBI18n.lang != "ru" else TBI18n.T("advisor_note"), HORIZONTAL_ALIGNMENT_LEFT, w - 2.0 * pad, ls, TBTokens.c("brass_lt"), TextServer.JUSTIFICATION_NONE)
	var tf := _font_text(); var ts := _fs_text()
	draw_multiline_string(tf, Vector2(pad, ly + 7.0 * u + tf.get_ascent(ts)), line(), HORIZONTAL_ALIGNMENT_LEFT, w - 2.0 * pad, ts, 4, TBTokens.c("cream"), TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE, TextServer.JUSTIFICATION_NONE)
	if auto:                                                                                  # where in the bag we are
		var cnt := KEYS.size()
		for i in cnt:
			draw_circle(Vector2(w - pad - float(cnt - 1 - i) * 5.4 * u - 1.5 * u, h - 11.0 * u), 1.5 * u, TBTokens.c("brass_lt") if i == _pos else TBTokens.with_a(TBTokens.c("rule_dark"), 0.7))
