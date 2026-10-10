## Alert ticker (zone C of design/ux/hud.md): a priority-sorted stack of notices for what needs an answer. Notices are state-based:
## the HUD re-feeds the current entries (TBAdvisor.ticker) after every change; a notice whose condition cleared shows a tick
## for 600 ms and collapses. Look: the Bezel demo's `.tz` notice (b_demo.html `notice()`): an instrument medallion on the left edge of a notched plate,
## the kind's colour in the medallion's icon (bad red, offer brass, information blue, done green), the text in Alegreya 500 15.5 and a small x.
## Tap a notice = look at its cause; offers answer inline.
class_name TBAlertTicker
extends Control

const K = preload("res://src/ui/ui_kit.gd")
const P = preload("res://src/ui/hud_parts.gd")
const BZ = preload("res://src/ui/bezel.gd")

## the notice medallion (the demo's 46 unit svg: shadow disc, brass band, dark face, hairline, 24 ticks), `s` = the svg's scale (1; 0.826 on a phone)
static func medallion(ci: CanvasItem, c: Vector2, s: float, hot: bool = false) -> void:
	ci.draw_circle(c, 24.0 * s, TBTokens.with_a(TBTokens.BZ_SHADOW, 0.45))
	BZ.grad_disc(ci, c, 21.0 * s, [[0.0, TBTokens.BZ_G_A], [0.5, TBTokens.BZ_G_B], [1.0, TBTokens.BZ_G_C]])
	ci.draw_circle(c, 17.0 * s, TBTokens.c("bar_0"))
	ci.draw_arc(c, 16.4 * s, 0.0, TAU, 48, P.tk("brass_lt"), 0.6 * s, true)
	BZ.ticks(ci, c, 16.0 * s, 24, 2.6 * s, 6, BZ.BRASS, 0.9 * s, 0.0, TAU, true)

signal activated(entry: Dictionary)         ## notice tapped: entry.cls / .p / .n / .uid say where to look
signal answered(uid: int, choice: int)      ## inline Accept (0) / Decline (1) on an offer notice
signal overflow_pressed                     ## the "+n" pill: open the full list
signal report_pressed                       ## the turn-report notice: open the Annals
signal layout_changed                       ## stack height changed (keep-outs)
signal tip_requested(anchor: Control, pair: Array)
signal tip_hidden

var gap: float = 14.0                       ## space between notices (the demo: 14, phone 10)
var compact: bool = false                   ## phone landscape: 34 high, medallion 38, text 13
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

func row_h() -> float: return 34.0 if compact else 40.0

# ---------------------------------------------------------------- look of an entry
## the demo's notice kind of an entry: bad (red) for crises and warnings, dip (brass) for offers, info (blue) for events
static func kind_of(e: Dictionary) -> String:
	if String(e["cls"]) == "offer": return "dip"
	if String(e["cls"]) == "event": return "info"
	return "bad"

static func kind_color(kind: String) -> Color:
	match kind:
		"bad": return TBTokens.BZ_NOTICE_BAD
		"dip": return TBTokens.c("brass_lt")
		"good": return TBTokens.BZ_GOOD
	return TBTokens.BZ_INFO

static func kind_icon(e: Dictionary) -> String:
	if String(e["cls"]) == "offer": return "envoys"
	if String(e["cls"]) == "event": return "info"
	return "warn"

static func bar_color(e: Dictionary) -> Color: return kind_color(kind_of(e))

## the notice's plate (outer notched hairline plate #7F6A33 / hover #C9A24B, inner #15110d, notch 7 / 6) with its drop shadow; `r` is the plate rect
static func draw_plate(ci: CanvasItem, r: Rect2, hot: bool, edge_col: Color = Color.TRANSPARENT) -> void:
	BZ.plate_shadow(ci, r, 7.0, 5.0, 7.0, TBTokens.with_a(Color.BLACK, 0.55))
	var lo: Color = edge_col if edge_col.a > 0.0 else (BZ.BRASS if hot else BZ.BRASS_LO)
	if TBTokens.is_hc(): lo = P.tk("brass_lt") if hot else P.tk("rule_dark")
	ci.draw_colored_polygon(BZ.notch(r, 7.0), lo)
	ci.draw_colored_polygon(BZ.notch(r.grow(-1.0), 6.0), TBTokens.BZ_NOTICE if not TBTokens.is_hc() else P.tk("bar_0"))

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
	var compact: bool = false
	var _buttons: HBoxContainer
	var lines: int = 1                   # 1 or 2 text lines (a long notice wraps; the full text is also the tooltip)
	var _w: float = 0.0
	var _nat: float = 0.0                # the plate's natural width
	func fz() -> int: return P.fu(13.0 if compact else 15.5)
	func font() -> Font: return P.fal(500)
	func line_h() -> float: return font().get_height(fz())
	func plate_h() -> float: return 34.0 if compact else 40.0
	func base_h() -> float:
		var one: float = plate_h()
		return one if lines <= 1 else maxf(one, lines * line_h() + 18.0)
	func pad_l() -> float: return 28.0 if compact else 34.0
	func lead() -> float: return 18.0 if compact else 22.0                 # the .tz margin-left: room for the medallion's left half
	func text_right() -> float: return 10.0 + (0.0 if drawer else 28.0)             # the x slot is always there (the demo: every notice has one); it is drawn only when the notice can be dismissed
	func med_s() -> float: return 38.0 / 46.0 if compact else 1.0
	## decide one or two lines for a row width, and the plate's natural width
	func set_width(w: float) -> void:
		_w = w
		var avail: float = maxf(40.0, w - lead() - 2.0 - pad_l() - text_right())
		var need: float = P.tw(font(), text, fz())
		var n: int = 1 if need <= avail else 2
		if n != lines: lines = n; queue_redraw()
		_nat = (w if (drawer or compact) else lead() + 2.0 + pad_l() + (need if n == 1 else avail) + text_right())      # phones: the demo stretches the notice over its column
	## the width this row takes in the stack
	func natural_w() -> float: return _nat if _nat > 0.0 else _w
	func full_h() -> float: return base_h() + ((P.touch() if compact else 32.0) + 6.0 if expanded else 0.0)
	func _init() -> void:
		super()
	func set_entry(e: Dictionary, t: String) -> void:
		entry = e; text = t
		if _w > 0.0: set_width(_w)
		dismissible = int(e["uid"]) < 0 and String(e["cls"]) != "offer" and String(e["cls"]) != "event"
		set_a11y(t)
		queue_redraw()
	func build_buttons(on_answer: Callable) -> void:
		if _buttons != null: return
		_buttons = HBoxContainer.new(); _buttons.add_theme_constant_override("separation", 8)
		_buttons.position = Vector2(lead() + 12.0, base_h() + 2.0)
		var ult: bool = bool(entry["ult"])
		var yes: Button = TBHudParts.btn(TBI18n.T("mp_yield") if ult else TBI18n.T("mp_accept"), "primary", func(): on_answer.call(int(entry["uid"]), 0), true, 14)
		var no: Button = TBHudParts.btn(TBI18n.T("mp_defy") if ult else TBI18n.T("mp_decline"), "secondary", func(): on_answer.call(int(entry["uid"]), 1), true, 14)
		var bh: float = TBHudParts.touch() if compact else 32.0
		yes.custom_minimum_size = Vector2(96, bh); no.custom_minimum_size = Vector2(96, bh)
		_buttons.add_child(yes); _buttons.add_child(no)
		add_child(_buttons)
	func clear_flash() -> void:
		flash = 0.0; queue_redraw()
	func set_expanded(on: bool) -> void:
		expanded = on
		if _buttons != null: _buttons.visible = on
	func _has_point(p: Vector2) -> bool:
		var h: float = base_h()
		return Rect2(lead() - 24.0, 0.0, size.x - lead() + 24.0, h).has_point(p) or (expanded and Rect2(Vector2.ZERO, size).has_point(p))
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not (e as InputEventMouseButton).pressed and dismissible and not drawer:
			var pos: Vector2 = (e as InputEventMouseButton).position
			if pos.x > size.x - 34.0 and pos.y < base_h() and down:
				down = false; queue_redraw(); dismiss_pressed.emit(); accept_event(); return
		super(e)
	func _draw() -> void:
		var bh: float = base_h()
		var lx: float = lead()
		var pr := Rect2(lx, 0.0, size.x - lx, bh)
		var hot: bool = hover or down
		var kind: String = TBAlertTicker.kind_of(entry) if not done else "good"
		var kc: Color = TBAlertTicker.kind_color(kind)
		TBAlertTicker.draw_plate(self, pr, hot)
		var c := Vector2(lx + 1.0, bh * 0.5)
		TBAlertTicker.medallion(self, c, med_s(), hot)
		var ic: String = "check" if done else TBAlertTicker.kind_icon(entry)
		TBBzIcons.draw(self, ic, c, 14.0 if compact else 17.0, kc)
		var f: Font = font()
		var z: int = fz()
		var x: float = lx + 1.0 + pad_l()
		var cream: Color = TBTokens.c("cream") if not done else TBTokens.c("smoke")
		var right: float = text_right()
		if lines <= 1:
			var s1: String = TBHudParts.fit(f, text, z, size.x - x - right)
			draw_string(f, Vector2(x, bh * 0.5 + (f.get_ascent(z) - f.get_height(z) * 0.5)), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, z, cream)
		else:
			var y0: float = (bh - 2.0 * line_h()) * 0.5 + f.get_ascent(z)
			draw_multiline_string(f, Vector2(x, y0), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - right, z, 2, cream, TextServer.BREAK_WORD_BOUND)
		if dismissible and not drawer and not done:
			TBBzIcons.draw(self, "close", Vector2(size.x - 10.0 - 1.0 - 9.0, bh * 0.5), 10.0, TBTokens.c("cream") if hot else (TBTokens.c("ink_off") if not TBTokens.is_hc() else TBTokens.c("smoke")), 1.7)
		if flash > 0.0:
			var line: PackedVector2Array = BZ.notch(pr.grow(-1.0), 6.0)
			line.append(line[0])
			draw_polyline(line, TBHudParts.al(TBHudParts.tk("brass_lt"), flash), 2.0, true)
		if has_focus(): TBHudParts.focus_box(self, pr.grow(3.0))

## "+3 v" overflow pill
class Pill extends P.Hit:
	var count: int = 0
	func desired_w() -> float: return ceilf(TBHudParts.tw(K.mono_b(), "+%d" % count, TBHudParts.fu(14.0)) + 12.0 + 12.0 + 12.0)
	func _draw() -> void:
		var hot: bool = hover or down
		TBAlertTicker.draw_plate(self, Rect2(0, 3, size.x, size.y - 6), hot)
		var cy: float = size.y * 0.5
		var f: Font = K.mono_b()
		var fsz: int = TBHudParts.fu(14.0)
		var x: float = 12.0 + TBHudParts.txt(self, f, Vector2(12.0, TBHudParts.base(f, fsz, cy)), "+%d" % count, fsz, TBHudParts.tk("cream"))
		TBHudParts.tri(self, Vector2(x + 10.0, cy), 8.0, TBHudParts.tk("smoke"), false)
		if has_focus(): TBHudParts.focus_ring(self, Rect2(Vector2.ZERO, size))

## the toast row: a message from an order, or the turn report
class InfoRow extends P.Hit:
	var text: String = ""
	var kind: String = "info"            # info | warn | report
	var lines: int = 1
	var ap: float = 1.0
	var compact: bool = false
	var _w: float = 0.0
	func fz() -> int: return P.fu(13.0 if compact else 15.5)
	func font() -> Font: return P.fal(500)
	func lead() -> float: return 18.0 if compact else 22.0
	func pad_l() -> float: return 28.0 if compact else 34.0
	func med_s() -> float: return 38.0 / 46.0 if compact else 1.0
	## height for a max row width (also decides the line count and the natural width)
	func measure(w: float) -> float:
		var f: Font = font()
		var avail: float = w - lead() - 2.0 - pad_l() - 10.0 - 28.0
		var need: float = P.tw(f, text, fz())
		lines = 1 if need <= avail else 2
		_w = lead() + 2.0 + pad_l() + (need if lines == 1 else avail) + 10.0 + 28.0
		return maxf(34.0 if compact else 40.0, 0.0 if lines == 1 else lines * f.get_height(fz()) + 18.0)
	func natural_w() -> float: return _w
	func _has_point(p: Vector2) -> bool: return Rect2(lead() - 24.0, 0.0, size.x - lead() + 24.0, size.y).has_point(p)
	func _draw() -> void:
		var kc: Color = TBAlertTicker.kind_color("bad" if kind == "warn" else ("dip" if kind == "report" else "info"))
		var ic: String = "warn" if kind == "warn" else ("annals" if kind == "report" else "info")
		var hot: bool = hover or down
		var lx: float = lead()
		TBAlertTicker.draw_plate(self, Rect2(lx, 0.0, size.x - lx, size.y), hot)
		var c := Vector2(lx + 1.0, size.y * 0.5)
		TBAlertTicker.medallion(self, c, med_s(), hot)
		TBBzIcons.draw(self, ic, c, 14.0 if compact else 17.0, kc)
		var f: Font = font()
		var z: int = fz()
		var x: float = lx + 1.0 + pad_l()
		var w: float = size.x - x - 10.0 - 28.0
		var cream: Color = TBTokens.c("cream")
		if lines <= 1:
			draw_string(f, Vector2(x, size.y * 0.5 + (f.get_ascent(z) - f.get_height(z) * 0.5)), text, HORIZONTAL_ALIGNMENT_LEFT, w, z, cream)
		else:
			var y0: float = (size.y - lines * f.get_height(z)) * 0.5 + f.get_ascent(z)
			draw_multiline_string(f, Vector2(x, y0), text, HORIZONTAL_ALIGNMENT_LEFT, w, z, 2, cream)
		TBBzIcons.draw(self, "close", Vector2(size.x - 10.0 - 1.0 - 9.0, size.y * 0.5), 10.0, TBTokens.c("cream") if hot else (TBTokens.c("ink_off") if not TBTokens.is_hc() else TBTokens.c("smoke")), 1.7)
		if has_focus(): TBHudParts.focus_box(self, Rect2(lx, 0.0, size.x - lx, size.y).grow(3.0))

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
	rw.compact = compact
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
		tw.tween_method(func(v: float): rw.ap = v; _layout(), 0.0, 1.0, 0.3)          # .slide-in: .3 s from 24 to the right

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
	if ps.size() > 1:                                # a merged notice cycles through its provinces
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

## one attention pulse on the notices of a class ("offer", "event"); static ring when motion is reduced
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
		info.compact = compact
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
		create_tween().tween_property(info, "modulate:a", 1.0, 0.3)
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
## stack bounds in ticker-local coordinates (top-left origin); notices are right-aligned in the row width (the demo: flex-end)
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
		rw.compact = compact
		var fw: float = row_w if not (inline_pill and live_total > max_rows) else row_w - 60.0
		rw.set_width(fw)
		var fh: float = rw.full_h()
		if not rw.done and shown >= max_rows:
			rw.visible = false; continue
		rw.visible = true
		if not rw.done: shown += 1
		var h: float = fh * rw.collapse
		var nw: float = rw.natural_w()
		rw.size = Vector2(nw, fh)
		rw.position = Vector2(fw - nw + 24.0 * (1.0 - rw.ap), y)
		rw.modulate.a = rw.ap * (1.0 if rw.collapse > 0.999 else rw.collapse)
		rw.custom_minimum_size = Vector2.ZERO
		if rw.collapse < 1.0: rw.size.y = maxf(1.0, h)
		pill_x = rw.position.x + rw.size.x + gap; pill_y = y
		y += h + gap
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
			_pill.position = Vector2(row_w - pw, y); _pill.size = Vector2(pw, rh)
			y += rh + gap
		_pill.queue_redraw()
	elif _pill != null:
		_pill.visible = false
	if info != null:
		info.compact = compact
		var ih: float = info.measure(row_w)
		var iw: float = info.natural_w()
		if not order.is_empty(): y += (12.0 if compact else 20.0) - gap                    # the demo's toast stack starts 114 below the notices' top (two notices are 94 high)
		info.position = Vector2(row_w - iw, y); info.size = Vector2(iw, ih)
		y += ih + gap
	var h_total: float = maxf(0.0, y - gap)
	custom_minimum_size = Vector2(row_w, h_total)
	size = Vector2(row_w, h_total)
	layout_changed.emit()

## live notice count (notices that are not ticking off)
func live_count() -> int:
	var n: int = 0
	for k in rows: if not rows[k].done: n += 1
	return n

## bounds of everything the ticker currently draws (global), for map-label keep-outs
func occupied_rect() -> Rect2:
	if order.is_empty() and info == null: return Rect2()
	return Rect2(global_position, size)
