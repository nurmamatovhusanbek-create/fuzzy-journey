## Alert ticker (zone C of design/ux/hud.md): a priority-sorted stack of chips for what needs an answer. Chips are state-based:
## the HUD re-feeds the current entries (TBAdvisor.ticker) after every change; a chip whose condition cleared shows a tick
## for 600 ms and collapses. Shape code (art bible 7.3): filled triangle = crisis, outlined triangle = warning,
## diamond = offer, circle = information. Tap a chip = look at its cause; offers answer inline.
class_name TBAlertTicker
extends Control

const K = preload("res://src/ui/ui_kit.gd")
const P = preload("res://src/ui/hud_parts.gd")

signal activated(entry: Dictionary)         ## chip tapped: entry.cls / .p / .n / .uid say where to look
signal answered(uid: int, choice: int)      ## inline Accept (0) / Decline (1) on an offer chip
signal overflow_pressed                     ## the "+n" pill: open the full list
signal report_pressed                       ## the turn-report chip: open the Annals
signal layout_changed                       ## stack height changed (keep-outs)
signal tip_requested(anchor: Control, pair: Array)
signal tip_hidden

const GAP := 4.0

var max_rows: int = 4
var row_w: float = 280.0
var inline_pill: bool = false               ## 1-row layouts: the "+n" pill sits beside the row instead of under it
var rows: Dictionary = {}                   ## key -> AlertRow
var order: Array = []                       ## display order of row keys (live and lingering)
var overflow: int = 0
var dismissed: Dictionary = {}
var _turn: int = -1
var _pill: Pill
var info: InfoRow
var _info_gen: int = 0
var _entries: Array = []

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func row_h() -> float: return maxf(minf(P.touch(), P.R(44.0) + 6.0), P.fs(14.0) + 16.0)

# ---------------------------------------------------------------- look of an entry
static func bar_color(e: Dictionary) -> Color:
	if int(e["sev"]) >= 2: return P.tk("neg_bar")
	match String(e["cls"]):
		"offer": return P.tk("brass_lt")
		"event": return P.tk("info_bar")
	return P.tk("warn_bar")

static func class_glyph(cls: String) -> String:
	match cls:
		"war": return "swords"
		"revolt": return "revolt"
		"offer": return "scroll"
		"event": return "book"
		"supply": return "supply"
	return "info"

## the shape mark: crisis = filled triangle, warning = outlined triangle, offer = diamond, information = circle
static func draw_shape(ci: CanvasItem, c: Vector2, e: Dictionary, s: float = 14.0) -> void:
	var col: Color = bar_color(e)
	if int(e["sev"]) >= 2 and String(e["cls"]) != "offer": P.warn_mark(ci, c, s + 2.0, col, true)
	elif String(e["cls"]) == "offer": P.diamond(ci, c, s, col, true)
	elif String(e["cls"]) == "event": ci.draw_circle(c, s * 0.5, col)
	else: P.warn_mark(ci, c, s + 2.0, col, false)

# ---------------------------------------------------------------- rows
class AlertRow extends P.Hit:
	signal answered(uid: int, choice: int)
	signal dismiss_pressed
	var entry: Dictionary = {}
	var text: String = ""
	var done: bool = false
	var ap: float = 1.0                  # appear 0..1
	var collapse: float = 1.0            # 1 -> 0 when cleared
	var flash: float = 0.0
	var expanded: bool = false
	var cycle: int = 0
	var dismissible: bool = true
	var drawer: bool = false
	var _buttons: HBoxContainer
	var lines: int = 1                   # 1 or 2 text lines (a long chip wraps; the full text is also the tooltip)
	var _w: float = 0.0
	func line_h() -> float: return TBHudParts.body_b().get_height(TBHudParts.fs(14.0))
	func base_h() -> float:
		var one: float = maxf(minf(TBHudParts.touch(), TBHudParts.R(44.0) + 6.0), TBHudParts.fs(14.0) + 16.0)
		return one if lines <= 1 else maxf(one, lines * line_h() + 16.0)
	func text_x() -> float: return 16.0 + 14.0 + 8.0 + 18.0 + 8.0
	func text_right() -> float: return 10.0 + (24.0 if dismissible and not drawer and not done else 0.0)
	## decide one or two lines for a row width
	func set_width(w: float) -> void:
		_w = w
		var avail: float = maxf(40.0, w - text_x() - text_right())
		var f: Font = TBHudParts.body_b()
		var need: float = TBHudParts.tw(f, text, TBHudParts.fs(14.0))
		var n: int = 1 if need <= avail else 2
		if n != lines: lines = n; queue_redraw()
	func full_h() -> float: return base_h() + (TBHudParts.touch() + 6.0 if expanded else 0.0)
	func _init() -> void:
		super()
		clip_contents = true
	func set_entry(e: Dictionary, t: String) -> void:
		entry = e; text = t
		if _w > 0.0: set_width(_w)
		dismissible = int(e["uid"]) < 0 and String(e["cls"]) != "offer" and String(e["cls"]) != "event"
		set_a11y(t)
		queue_redraw()
	func build_buttons(on_answer: Callable) -> void:
		if _buttons != null: return
		_buttons = HBoxContainer.new(); _buttons.add_theme_constant_override("separation", 8)
		_buttons.position = Vector2(12, base_h() + 2.0)
		var ult: bool = bool(entry["ult"])
		var yes: Button = TBHudParts.btn(TBI18n.T("mp_yield") if ult else TBI18n.T("mp_accept"), "primary", func(): on_answer.call(int(entry["uid"]), 0), true, 14)
		var no: Button = TBHudParts.btn(TBI18n.T("mp_defy") if ult else TBI18n.T("mp_decline"), "secondary", func(): on_answer.call(int(entry["uid"]), 1), true, 14)
		yes.custom_minimum_size = Vector2(96, TBHudParts.touch()); no.custom_minimum_size = Vector2(96, TBHudParts.touch())
		_buttons.add_child(yes); _buttons.add_child(no)
		add_child(_buttons)
	func clear_flash() -> void:
		flash = 0.0; queue_redraw()
	func set_expanded(on: bool) -> void:
		expanded = on
		if _buttons != null: _buttons.visible = on
	func _has_point(p: Vector2) -> bool:
		return Rect2(Vector2.ZERO, Vector2(size.x, base_h())).has_point(p) or (expanded and Rect2(Vector2.ZERO, size).has_point(p))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (e as InputEventMouseButton).pressed and dismissible and not drawer:
			var pos: Vector2 = (e as InputEventMouseButton).position
			if pos.x > size.x - 48.0 and pos.y < base_h() and down:
				down = false; queue_redraw(); dismiss_pressed.emit(); accept_event(); return
		super(e)
	func _draw() -> void:
		var bh: float = base_h()
		var r := Rect2(0, 0, size.x, bh)
		var col: Color = TBAlertTicker.bar_color(entry) if not done else TBHudParts.tk("pos_bar")
		var crit: bool = int(entry["sev"]) >= 2 and not done
		var pr := Rect2(0, 3, size.x, size.y - 6)
		draw_style_box(TBHudParts.sbox(TBHudParts.tk("bar_2") if (hover or down) else TBHudParts.al(TBHudParts.tk("bar_0"), 0.82), col if crit else TBHudParts.al(TBHudParts.tk("rule"), 0.8), TBHudParts.R(5.0), 1), pr)
		var cy: float = bh * 0.5
		var x: float = 16.0
		var cream: Color = TBHudParts.tk("cream") if not done else TBHudParts.tk("smoke")
		if done:
			TBHudParts.tick(self, Vector2(x + 7.0, cy), 14.0, TBHudParts.tk("pos_bar"), 2.0)
			x += 14.0 + 8.0
		else:
			TBAlertTicker.draw_shape(self, Vector2(x + 7.0, cy), entry)
			x += 14.0 + 8.0
			TBGlyph.draw(self, TBAlertTicker.class_glyph(String(entry["cls"])), Vector2(x + 9.0, cy), 18.0, col, 1.6)
			x += 18.0 + 8.0
		var f: Font = P.body_b()
		var fsz: int = TBHudParts.fs(14.0)
		var right: float = text_right()
		if lines <= 1:
			var s1: String = TBHudParts.fit(f, text, fsz, size.x - x - right)
			draw_string(f, Vector2(x, TBHudParts.base(f, fsz, cy)), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, cream)
		else:
			var y0: float = (bh - 2.0 * line_h()) * 0.5 + f.get_ascent(fsz)
			draw_multiline_string(f, Vector2(x, y0), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - right, fsz, 2, cream, TextServer.BREAK_WORD_BOUND)
		if dismissible and not drawer and not done:
			TBGlyph.draw(self, "close", Vector2(size.x - 18.0, cy), 12.0, TBHudParts.tk("smoke"), 1.5)
		if flash > 0.0:
			var line: PackedVector2Array = TBHudParts.chamfer(Rect2(0, 0, size.x, bh).grow(-1.0), 2.0)
			line.append(line[0])
			draw_polyline(line, TBHudParts.al(TBHudParts.tk("brass_lt"), flash), 2.0, true)
		if has_focus(): TBHudParts.focus_ring(self, r)

## "+3 v" overflow pill
class Pill extends P.Hit:
	var count: int = 0
	func desired_w() -> float: return ceilf(TBHudParts.tw(K.mono_b(), "+%d" % count, TBHudParts.fs(14.0)) + 12.0 + 12.0 + 12.0)
	func _draw() -> void:
		draw_style_box(TBHudParts.sbox(TBHudParts.tk("bar_2") if (hover or down) else TBHudParts.al(TBHudParts.tk("bar_0"), 0.82), TBHudParts.al(TBHudParts.tk("rule"), 0.8), TBHudParts.R(5.0), 1), Rect2(0, 3, size.x, size.y - 6))
		var cy: float = size.y * 0.5
		var f: Font = K.mono_b()
		var fsz: int = TBHudParts.fs(14.0)
		var x: float = 12.0 + TBHudParts.txt(self, f, Vector2(12.0, TBHudParts.base(f, fsz, cy)), "+%d" % count, fsz, TBHudParts.tk("cream"))
		TBHudParts.tri(self, Vector2(x + 10.0, cy), 8.0, TBHudParts.tk("smoke"), false)
		if has_focus(): TBHudParts.focus_ring(self, Rect2(Vector2.ZERO, size))

## the one toast-style row: a message from an order, or the turn report
class InfoRow extends P.Hit:
	var text: String = ""
	var kind: String = "info"            # info | warn | report
	var lines: int = 1
	var ap: float = 1.0
	func _init() -> void:
		super()
		clip_contents = true
	func measure(w: float) -> float:
		var f: Font = P.body()
		var fsz: int = TBHudParts.fs(14.0)
		var sz: Vector2 = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0 - 24.0 - 8.0 - 10.0, fsz, 2)
		lines = clampi(int(round(sz.y / maxf(1.0, f.get_height(fsz)))), 1, 2)
		return maxf(40.0, lines * f.get_height(fsz) + 18.0)
	func _draw() -> void:
		var bar: Color = TBHudParts.tk("info_bar")
		if kind == "warn": bar = TBHudParts.tk("warn_bar")
		elif kind == "report": bar = TBHudParts.tk("brass_lt")
		TBHudParts.plate(self, Rect2(Vector2.ZERO, size), TBHudParts.tk("bar_2") if (hover or down) else TBHudParts.al(TBHudParts.tk("bar_0"), 0.96), TBHudParts.tk("rule_dark"), 2.0, bar, 4.0)
		var c := Vector2(16.0 + 8.0, size.y * 0.5)
		match kind:
			"warn": TBHudParts.warn_mark(self, c, 16.0, bar, false)
			"report": TBGlyph.draw(self, "scroll", c, 18.0, bar, 1.6)
			_:
				draw_circle(c, 8.0, bar)
				var fi: Font = K.mono_b()
				draw_string(fi, Vector2(c.x - TBHudParts.tw(fi, "i", 13) * 0.5, TBHudParts.base(fi, 13, c.y)), "i", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TBHudParts.tk("bar_0"))
		var f: Font = P.body()
		var fsz: int = TBHudParts.fs(14.0)
		var x: float = 16.0 + 24.0 + 8.0
		var w: float = size.x - x - 10.0
		var y0: float = (size.y - lines * f.get_height(fsz)) * 0.5 + f.get_ascent(fsz)
		draw_multiline_string(f, Vector2(x, y0), text, HORIZONTAL_ALIGNMENT_LEFT, w, fsz, 2, TBHudParts.tk("cream"))
		if has_focus(): TBHudParts.focus_ring(self, Rect2(Vector2.ZERO, size))

# ---------------------------------------------------------------- feeding
## entries: TBAdvisor.ticker() output, each with "text" (one line) added by the caller; turn clears "dismissed for this turn"
func update(entries: Array, turn: int) -> void:
	if turn != _turn:
		dismissed.clear(); _turn = turn
	_entries = entries
	var live: Array = []
	var seen: Dictionary = {}
	for e in entries:
		if dismissed.has(String(e["key"])): continue
		live.append(e); seen[String(e["key"])] = true
	for k in rows.keys():
		var rw: AlertRow = rows[k]
		if not seen.has(k) and not rw.done: _resolve(String(k))
	var new_order: Array = []
	for e in live:
		var k: String = String(e["key"])
		if rows.has(k):
			var rw2: AlertRow = rows[k]
			rw2.set_entry(e, String(e["text"]))
			if rw2.done: rw2.done = false
		else:
			_add(e)
		new_order.append(k)
	for k in order:                                    # lingering (ticked) rows keep their slot until they collapse
		if rows.has(k) and rows[k].done and not new_order.has(k): new_order.insert(mini(order.find(k), new_order.size()), k)
	order = new_order
	_layout()

func _add(e: Dictionary) -> void:
	var rw := AlertRow.new()
	rw.set_entry(e, String(e["text"]))
	rw.pressed.connect(_on_row.bind(rw))
	rw.answered.connect(func(uid: int, c: int): answered.emit(uid, c))
	rw.dismiss_pressed.connect(_on_dismiss.bind(rw))
	rw.tip_on.connect(func(): tip_requested.emit(rw, rw.entry.get("tip", [])))
	rw.tip_off.connect(func(): tip_hidden.emit())
	if String(e["cls"]) == "offer":
		rw.build_buttons(func(uid: int, c: int): answered.emit(uid, c))
		rw._buttons.visible = false
	rows[String(e["key"])] = rw
	add_child(rw)
	if not P.reduced_motion():
		rw.ap = 0.0
		var tw := rw.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_method(func(v: float): rw.ap = v; _layout(), 0.0, 1.0, 0.16)

func _resolve(k: String) -> void:
	var rw: AlertRow = rows[k]
	rw.done = true; rw.set_expanded(false); rw.queue_redraw()
	if P.reduced_motion():
		_drop(k); return
	var tw := rw.create_tween()
	tw.tween_interval(0.6)
	tw.tween_method(func(v: float): rw.collapse = v; _layout(), 1.0, 0.0, 0.4)
	tw.tween_callback(_drop.bind(k))

func _drop(k: String) -> void:
	if not rows.has(k): return
	var rw: AlertRow = rows[k]
	if not rw.done: return                           # condition came back while the tick was showing
	rows.erase(k); order.erase(k)
	rw.queue_free()
	_layout()

func _on_row(rw: AlertRow) -> void:
	var e: Dictionary = rw.entry
	if String(e["cls"]) == "offer":
		rw.set_expanded(not rw.expanded)
		_layout()
		if not rw.expanded: return
		return
	var out: Dictionary = e.duplicate()
	var ps: Array = e["ps"]
	if ps.size() > 1:                                # a merged chip cycles through its provinces
		rw.cycle = (rw.cycle + 1) % ps.size()
		out["p"] = int(ps[rw.cycle])
	activated.emit(out)

func _on_dismiss(rw: AlertRow) -> void:
	dismissed[String(rw.entry["key"])] = _turn
	update(_entries, _turn)

func expand_offer(key: String) -> void:
	if rows.has(key):
		var rw: AlertRow = rows[key]
		rw.set_expanded(true); _layout()

## one attention pulse on the chips of a class ("offer", "event"); static ring when motion is reduced
func pulse(cls: String) -> void:
	for k in rows:
		var rw: AlertRow = rows[k]
		if String(rw.entry["cls"]) != cls: continue
		if TBHudParts.reduced_motion():
			rw.flash = 1.0; rw.queue_redraw()
			get_tree().create_timer(0.8).timeout.connect(rw.clear_flash)
		else:
			var tw := rw.create_tween()
			tw.tween_method(func(v: float): rw.flash = v; rw.queue_redraw(), 0.0, 1.0, 0.25)
			tw.tween_method(func(v: float): rw.flash = v; rw.queue_redraw(), 1.0, 0.0, 0.45)

# ---------------------------------------------------------------- the info row (toast / turn report)
func show_info(text: String, kind: String, seconds: float) -> void:
	if info == null:
		info = InfoRow.new()
		info.pressed.connect(func():
			var was: String = info.kind
			hide_info()
			if was == "report": report_pressed.emit())
		add_child(info)
	info.text = text; info.kind = kind
	info.set_a11y(text)
	_info_gen += 1
	var gen: int = _info_gen
	info.ap = 1.0
	if not P.reduced_motion():
		info.modulate.a = 0.0
		create_tween().tween_property(info, "modulate:a", 1.0, 0.16)
	else:
		info.modulate.a = 1.0
	info.queue_redraw()
	_layout()
	get_tree().create_timer(seconds).timeout.connect(func(): if gen == _info_gen: hide_info())

func hide_info() -> void:
	if info == null: return
	_info_gen += 1
	info.queue_free(); info = null
	_layout()

# ---------------------------------------------------------------- layout
## stack bounds in ticker-local coordinates (top-left origin)
func _layout() -> void:
	var rh: float = row_h()
	var y: float = 0.0
	var shown: int = 0
	var live_total: int = 0
	for k in order:
		if not rows[k].done: live_total += 1
	var pill_x: float = 0.0
	var pill_y: float = 0.0
	for k in order:
		var rw: AlertRow = rows[k]
		var fw: float = row_w if not (inline_pill and live_total > max_rows) else row_w - 60.0
		rw.set_width(fw)
		var fh: float = rw.full_h()
		if not rw.done and shown >= max_rows:
			rw.visible = false; continue
		rw.visible = true
		if not rw.done: shown += 1
		var h: float = fh * rw.collapse
		rw.size = Vector2(fw, fh)
		rw.position = Vector2(-12.0 * (1.0 - rw.ap), y)
		rw.modulate.a = rw.ap * (1.0 if rw.collapse > 0.999 else rw.collapse)
		rw.custom_minimum_size = Vector2.ZERO
		if rw.collapse < 1.0: rw.size.y = maxf(1.0, h)
		pill_x = rw.position.x + rw.size.x + GAP; pill_y = y
		y += h + GAP
	overflow = maxi(0, live_total - shown)
	if overflow > 0:
		if _pill == null:
			_pill = Pill.new(); _pill.pressed.connect(func(): overflow_pressed.emit()); _pill.set_a11y(TBI18n.T("tk_more")); add_child(_pill)
		_pill.count = overflow
		_pill.visible = true
		var pw: float = _pill.desired_w()
		if inline_pill and shown > 0:
			_pill.position = Vector2(pill_x, pill_y); _pill.size = Vector2(pw, rh)
		else:
			_pill.position = Vector2(0, y); _pill.size = Vector2(pw, rh)
			y += rh + GAP
		_pill.queue_redraw()
	elif _pill != null:
		_pill.visible = false
	if info != null:
		var ih: float = info.measure(row_w)
		info.position = Vector2(0, y); info.size = Vector2(row_w, ih)
		y += ih + GAP
	var h_total: float = maxf(0.0, y - GAP)
	custom_minimum_size = Vector2(row_w, h_total)
	size = Vector2(row_w, h_total)
	layout_changed.emit()

## live chip count (chips that are not ticking off)
func live_count() -> int:
	var n: int = 0
	for k in rows: if not rows[k].done: n += 1
	return n

## bounds of everything the ticker currently draws (global), for map-label keep-outs
func occupied_rect() -> Rect2:
	if order.is_empty() and info == null: return Rect2()
	return Rect2(global_position, size)
