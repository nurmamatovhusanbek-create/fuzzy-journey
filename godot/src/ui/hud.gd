## In-game HUD (design/ux/hud.md): flat top bar (nation, date, resource chips), screens rail / bottom bar, lens selector, alert ticker,
## End Turn plate, legend, hot-seat strip, realm sheet. Pure view: it reads the game and emits signals; it never changes state.
class_name TBHud
extends Control

signal end_turn_pressed
signal lens_selected(name: String)
signal nations_pressed
signal wars_pressed
signal goals_pressed
signal decisions_pressed
signal chronicle_pressed
signal advisor_pressed
signal budget_pressed
signal save_pressed
signal settings_pressed
signal tapped
## an alert chip was tapped: look at this province (fly + select)
signal goto_province(p: int)
## open the nation card of n
signal nation_pressed(n: int)
## inline answer on an offer chip: choice 0 = accept / yield, 1 = decline / defy (send as an eventChoice command)
signal offer_answered(uid: int, choice: int)
## a deferred event chip was tapped: show its prompt again
signal event_requested(uid: int)

const K = preload("res://src/ui/ui_kit.gd")
const P = preload("res://src/ui/hud_parts.gd")
const AT = preload("res://src/ui/alert_ticker.gd")
static var T: Callable = TBI18n.T

enum Prof { DESKTOP, PHONE_L, SHORT, PORTRAIT }

## id, glyph, label key, hotkey hint (the first 4 are the rail, the rest sit behind "More")
const SCREENS := [
	["nations", "globe", "dk_nations", "F1"], ["budget", "coins", "dk_budget", "F2"], ["decisions", "scales", "dk_decisions", "F3"], ["advisor", "lamp", "dk_advisor", "F4"],
	["chronicle", "book", "dk_chronicle", "F5"], ["goals", "trophy", "dk_goals", "F6"], ["save", "save", "dk_save", ""], ["settings", "gear", "dk_settings", ""],
]
const PRIMARY := 4
const LENS_PINNED := ["political", "diplomatic", "military", "terrain"]

var g: TBGame
var seat_tag: String = ""                   # hot-seat seat label ("P2"); derived from the game when left empty
var confirm_mode: String = "smart"           # smart | always | never  (Confirm End Turn)
var input_blocked_fn: Callable = Callable()  # -> true while a modal / curtain is up or the game is not running (hotkeys pause)
var mp_waiting_fn: Callable = Callable()     # -> true in a multiplayer game (a busy End Turn then reads "waiting for players")
var feed: Array = []                         # text mirror of every toast / alert / report: {"turn", "date", "text", "bad"} (read by the Annals / screen readers)
var tts_mode: String = "off"                 # off | critical | all: announce new alert chips with DisplayServer.tts_speak

var _prof: int = Prof.DESKTOP
var _vp: Vector2 = Vector2(1280, 720)
var _bar: P.Surface
var _rail: P.Surface
var _bottom: P.Surface
var _nat: P.NationChip
var _date: P.DateText
var _chips: Dictionary = {}
var _suffix: Dictionary = {}
var _war: P.Chip
var _inf: P.Chip
var _lens_btns: Array = []
var _lens_chip: LensChip
var _menu_btn: P.IconBtn
var _dots_btn: P.IconBtn
var _dock: Array = []
var _dock_more: P.IconBtn
var _lens_bottom: P.IconBtn
var _ticker: TBAlertTicker
var _seal: P.Seal
var _legend: P.Legend
var _strip: P.SeatStrip
var _catcher: Control
var _pop: Control
var _pop_kind: String = ""
var _tip: Control
var _preview: PanelContainer
var _active: String = ""
var _active_t: float = 0.0
var _lens: String = "political"
var _lens_more: bool = false
var _wars: int = 0
var _inf_on: bool = false
var _busy: bool = false
var _busy_turn: int = 0
var _hint_gen: int = 0
var _entries: Array = []
var _announced: Dictionary = {}
var _rep: Array = []
var _rep_gen: int = 0
var _stage: int = 0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

# ================================================================== build
func build() -> void:
	for c in get_children(): c.queue_free()
	_chips.clear(); _suffix.clear(); _lens_btns.clear(); _dock.clear()
	_pop = null; _catcher = null; _tip = null; _preview = null; _active = ""
	_bar = P.Surface.new(); _bar.kind = "bar"; add_child(_bar)
	_nat = P.NationChip.new(); _nat.set_a11y(T.call("tk_realm")); _wire(_nat, _tip_nation); _nat.pressed.connect(_open_realm); add_child(_nat)
	_date = P.DateText.new(); add_child(_date)
	for spec in [["gold", "coin", "gold"], ["man", "men", "manpower"], ["mp", "swords", "mp"], ["dp", "scroll", "dp"]]:
		var c := P.Chip.new(); c.glyph = spec[1]; c.set_a11y(T.call(spec[2]))
		var key: String = spec[0]
		_wire(c, _tip_chip.bind(key)); c.pressed.connect(_pin_chip.bind(key))
		add_child(c); _chips[key] = c
	_war = P.Chip.new(); _war.glyph = "swords"; _war.set_a11y(T.call("hud_wars")); _wire(_war, _tip_chip.bind("wars")); _war.pressed.connect(func(): tapped.emit(); wars_pressed.emit()); add_child(_war)
	_inf = P.Chip.new(); _inf.glyph = "skull"; _inf.set_a11y(T.call("infamy")); _wire(_inf, _tip_chip.bind("infamy")); _inf.pressed.connect(_pin_chip.bind("infamy")); add_child(_inf)
	for lens in LENS_PINNED:
		var b := P.IconBtn.new(); b.glyph = P.lens_glyph(lens); b.sq = 32.0; b.icon_px = 20.0; b.show_label = false; b.edge = 1
		b.set_a11y(T.call("lens_" + lens))
		b.pressed.connect(func(): tapped.emit(); _pick_lens(lens))
		_wire(b, _tip_lens.bind(lens))
		b.set_meta("lens", lens)
		add_child(b); _lens_btns.append(b)
	var more_l := P.IconBtn.new(); more_l.glyph = "dots"; more_l.sq = 32.0; more_l.icon_px = 20.0; more_l.show_label = false; more_l.edge = 1
	more_l.set_a11y(T.call("tk_more_lenses")); more_l.pressed.connect(func(): tapped.emit(); _open_lens_pop(more_l)); _wire(more_l, _tip_text.bind(T.call("tk_more_lenses"), "L"))
	more_l.set_meta("lens", "")
	add_child(more_l); _lens_btns.append(more_l)
	_lens_chip = LensChip.new(); _lens_chip.set_a11y(T.call("tk_lens")); _lens_chip.pressed.connect(func(): tapped.emit(); _open_lens_pop(_lens_chip)); _wire(_lens_chip, _tip_text.bind(T.call("tk_lens"), "L")); add_child(_lens_chip)
	_menu_btn = P.IconBtn.new(); _menu_btn.glyph = "menu"; _menu_btn.sq = 32.0; _menu_btn.icon_px = 20.0; _menu_btn.show_label = false; _menu_btn.edge = 1
	_menu_btn.set_a11y(T.call("tk_menu")); _menu_btn.pressed.connect(func(): tapped.emit(); _open_menu(_menu_btn, false)); add_child(_menu_btn)
	_dots_btn = P.IconBtn.new(); _dots_btn.glyph = "dots"; _dots_btn.sq = 36.0; _dots_btn.icon_px = 22.0; _dots_btn.show_label = false; _dots_btn.edge = 1
	_dots_btn.set_a11y(T.call("tk_realm")); _dots_btn.pressed.connect(func(): tapped.emit(); _open_realm()); add_child(_dots_btn)
	# ---- rail (landscape) / bottom bar (portrait)
	_rail = P.Surface.new(); _rail.kind = "rail"; add_child(_rail)
	_bottom = P.Surface.new(); _bottom.kind = "bottom"; add_child(_bottom)
	for i in SCREENS.size():
		if i >= PRIMARY: break
		var sc: Array = SCREENS[i]
		var b2 := P.IconBtn.new(); b2.glyph = sc[1]; b2.label = T.call(sc[2]); b2.set_a11y(T.call(sc[2]))
		b2.set_meta("screen", sc[0])
		var sid: String = sc[0]
		b2.pressed.connect(_screen.bind(sid))
		_wire(b2, _tip_text.bind(T.call(sc[2]), sc[3]))
		add_child(b2); _dock.append(b2)
	_dock_more = P.IconBtn.new(); _dock_more.glyph = "dots"; _dock_more.label = T.call("tk_more"); _dock_more.set_a11y(T.call("tk_more"))
	_dock_more.pressed.connect(func(): tapped.emit(); _open_menu(_dock_more, true)); add_child(_dock_more)
	_lens_bottom = P.IconBtn.new(); _lens_bottom.label = T.call("tk_lens_short"); _lens_bottom.set_a11y(T.call("tk_lens")); _lens_bottom.edge = 2
	_lens_bottom.pressed.connect(func(): tapped.emit(); _open_lens_pop(_lens_bottom)); add_child(_lens_bottom)
	# ---- ticker, legend, hot-seat strip, End Turn plate
	_ticker = TBAlertTicker.new()
	_ticker.activated.connect(_on_alert); _ticker.answered.connect(func(uid: int, c: int): tapped.emit(); offer_answered.emit(uid, c))
	_ticker.overflow_pressed.connect(_open_drawer); _ticker.report_pressed.connect(func(): tapped.emit(); chronicle_pressed.emit())
	_ticker.tip_requested.connect(_tip_show); _ticker.tip_hidden.connect(_tip_hide)
	add_child(_ticker)
	_legend = P.Legend.new(); add_child(_legend)
	_strip = P.SeatStrip.new(); _strip.visible = false; add_child(_strip)
	_seal = P.Seal.new(); _seal.set_a11y(T.call("end_turn")); _seal.pressed.connect(_seal_pressed); add_child(_seal)
	_wire(_seal, _tip_seal)
	_lens_changed()
	layout_for(size if size.x > 1.0 else get_viewport_rect().size)

## player text scale (1.0 / 1.25 / 1.5 / 1.75): every HUD font goes through TBHudParts.fs(); rebuilds the HUD
func set_text_scale(f: float) -> void:
	P.text_scale = clampf(f, 1.0, 2.0)
	if g != null and _bar != null:
		build(); refresh()

## wire a control's tooltip (hover 350 ms / long-press 450 ms): fn -> [title, body]
func _wire(h: P.Hit, fn: Callable) -> void:
	h.tip_on.connect(func(): _tip_show(h, fn.call()))
	h.tip_off.connect(_tip_hide)

# ================================================================== layout
func _chip_h() -> float:
	var base: float = [32.0, 28.0, 26.0, 32.0][_prof]
	return maxf(base, P.fs(14.0 if (_prof == Prof.PHONE_L or _prof == Prof.SHORT) else 16.0) + 10.0)

func _bar_h() -> float:
	var base: float = [40.0, 36.0, 32.0, 40.0][_prof]
	return maxf(base, _chip_h() + (6.0 if _prof == Prof.SHORT else 8.0))

func _row_pitch() -> float:
	return (P.fs(12.0) + 10.0 + _sq()) if _show_labels() else _sq() + 8.0
func _sq() -> float: return 40.0 if _prof == Prof.DESKTOP else 36.0
func _show_labels() -> bool: return true

## the layout profile for a logical viewport (design/ux/hud.md 3.1)
static func profile_for(vp: Vector2) -> int:
	if vp.y > vp.x: return Prof.PORTRAIT
	if vp.y < 380.0: return Prof.SHORT
	if vp.y < 560.0: return Prof.PHONE_L
	return Prof.DESKTOP

func layout_for(vp: Vector2) -> void:
	if _bar == null: return
	var old: int = _prof
	_vp = vp
	_prof = profile_for(vp)
	_tip_hide(); _close_pop()
	var m: float = 8.0
	var bh: float = _bar_h()
	_bar.position = Vector2.ZERO; _bar.size = Vector2(vp.x, bh)
	var portrait: bool = _prof == Prof.PORTRAIT
	# ---- rail (landscape) or bottom bar (portrait)
	var sq: float = _sq()
	var pitch: float = _row_pitch()
	var rail_w: float = 0.0
	for b in _dock + [_dock_more]:
		(b as P.IconBtn).sq = sq; (b as P.IconBtn).icon_px = 24.0 if _prof == Prof.DESKTOP else 22.0; (b as P.IconBtn).edge = 0; (b as P.IconBtn).show_label = true
		rail_w = maxf(rail_w, P.tw(P.body_b(), (b as P.IconBtn).label, P.fs(12.0)) + 14.0)
	rail_w = clampf(maxf(rail_w, 56.0 if _prof != Prof.DESKTOP else 64.0), 56.0, 96.0)
	var has_rail: bool = _prof == Prof.DESKTOP or _prof == Prof.PHONE_L
	_rail.visible = has_rail
	_bottom.visible = portrait
	var rail_top: float = bh + (8.0 if _prof == Prof.DESKTOP else 6.0)
	if has_rail:
		_rail.position = Vector2(m, rail_top); _rail.size = Vector2(rail_w, pitch * 5.0 + 8.0)
		var all: Array = _dock + [_dock_more]
		for i in all.size():
			var b2: P.IconBtn = all[i]
			b2.visible = true; b2.position = Vector2(m, rail_top + 4.0 + i * pitch); b2.size = Vector2(rail_w, pitch)
	else:
		for b3 in _dock: (b3 as P.IconBtn).visible = portrait
		_dock_more.visible = false
	_lens_bottom.visible = portrait
	var bottom_h: float = 56.0
	if portrait:
		var by: float = vp.y - bottom_h
		_bottom.position = Vector2(0, by); _bottom.size = Vector2(vp.x, bottom_h)
		var cell: float = 40.0
		var labels_fit: bool = true                      # labels on the bottom bar only when every one fits its cell
		for b4 in _dock + [_lens_bottom]: labels_fit = labels_fit and P.tw(P.body_b(), (b4 as P.IconBtn).label, P.fs(12.0)) <= cell - 2.0
		for i in _dock.size():
			var bb: P.IconBtn = _dock[i]
			bb.sq = 36.0; bb.icon_px = 22.0; bb.edge = 2
			bb.show_label = labels_fit
			bb.position = Vector2(m + i * cell, by + 2.0); bb.size = Vector2(cell, bottom_h - 4.0)
		_lens_bottom.sq = 36.0; _lens_bottom.icon_px = 22.0; _lens_bottom.show_label = labels_fit
		_lens_bottom.position = Vector2(m + _dock.size() * cell, by + 2.0); _lens_bottom.size = Vector2(cell, bottom_h - 4.0)
	# ---- ticker
	var tx: float = m
	if has_rail: tx = m + rail_w + 8.0
	_ticker.max_rows = 3 if _prof == Prof.DESKTOP else 1
	_ticker.inline_pill = _prof != Prof.DESKTOP
	_ticker.row_w = 280.0 if _prof == Prof.DESKTOP else (vp.x - m * 2.0 if portrait else (280.0 if _prof == Prof.PHONE_L else 260.0))
	_ticker.position = Vector2(tx, bh + (8.0 if _prof == Prof.DESKTOP else 6.0))
	if portrait and _prof != old: pass
	_ticker._layout()
	# ---- seal
	_seal.compact = _prof != Prof.DESKTOP
	var sw: float = 168.0 if _prof == Prof.DESKTOP else 128.0
	var sh: float = 56.0 if _prof != Prof.PORTRAIT else 48.0
	if portrait: sw = clampf(vp.x - m * 3.0 - (_dock.size() + 1) * 40.0, 112.0, 168.0)
	_seal.size = Vector2(sw, sh)
	_seal.position = Vector2(vp.x - m - sw, vp.y - m - sh if not portrait else vp.y - bottom_h + (bottom_h - sh) * 0.5)
	# ---- legend (desktop only; the other profiles show it inside the lens popover)
	_legend.framed = true
	_place_legend()
	_place_strip()
	if _prof != old: refresh()
	else: _layout_bar()
	_sync_seal()

func _place_legend() -> void:
	if _legend == null: return
	var show: bool = _prof == Prof.DESKTOP and _legend.has_key()
	_legend.visible = show
	if not show: return
	_legend.width = 214.0 if _legend.ramp.size() > 0 else 252.0
	_legend.custom_minimum_size = Vector2(_legend.width, _legend.height_needed())
	_legend.size = _legend.custom_minimum_size
	_legend.position = Vector2(_vp.x - 8.0 - _legend.size.x, _bar_h() + 8.0)
	_legend.queue_redraw()

func _place_strip() -> void:
	if _strip == null: return
	var hot: bool = _is_hot()
	_strip.visible = hot and _prof == Prof.DESKTOP
	if not _strip.visible: return
	var w: float = _strip.desired_w()
	_strip.size = Vector2(w, 24.0)
	_strip.position = Vector2((_vp.x - w) * 0.5, _bar_h() + 6.0)
	_strip.queue_redraw()

## compose the bar for a collapse stage (design/ux/hud.md section 6) and report its width
func _compose_bar(stage: int) -> Dictionary:
	var compact: bool = _prof != Prof.DESKTOP
	var portrait: bool = _prof == Prof.PORTRAIT
	var left: Array = []
	var right: Array = []
	var dl: int = 2 if stage < 2 else (1 if stage < 3 else 0)
	var group: bool = stage < 4 and not portrait
	_nat.show_name = stage < 7 and not portrait
	_nat.badge = 0 if group else (_wars + (1 if _inf_on else 0))
	_nat.compact = compact
	left.append([_nat, 0.0, _nat.desired_w()])
	if stage < 6 and not portrait:
		_date.compact = compact
		left.append([_date, 10.0, _date.desired_w()])
	var first: bool = true
	for key in ["gold", "man", "mp", "dp"]:
		if key == "dp" and (g == null or g.rules < 1 or stage >= 5): continue
		var c: P.Chip = _chips[key]
		c.compact = compact
		c.delta_on = dl == 2 or (dl == 1 and key == "gold")
		c.suffix = String(_suffix.get(key, "")) if stage < 3 else ""
		left.append([c, 12.0 if first else 4.0, c.desired_w()]); first = false
	if group:
		if _wars > 0:
			_war.compact = compact; _war.delta_on = false; left.append([_war, 8.0, _war.desired_w()])
		if _inf_on:
			_inf.compact = compact; _inf.delta_on = false; left.append([_inf, 4.0 if _wars > 0 else 8.0, _inf.desired_w()])
	if _prof == Prof.DESKTOP and stage < 1:
		for i in _lens_btns.size():
			var lb: P.IconBtn = _lens_btns[i]
			lb.sq = 32.0
			right.append([lb, 2.0, 36.0])
	elif not portrait:
		_lens_chip.compact = compact
		right.append([_lens_chip, 0.0, _lens_chip.desired_w()])
		if _prof == Prof.SHORT: right.append([_menu_btn, 4.0, 36.0])
	else:
		right.append([_dots_btn, 0.0, 40.0])
	var total: float = 0.0
	for it in left: total += float(it[1]) + float(it[2])
	for it in right: total += float(it[1]) + float(it[2])
	total += 16.0
	return {"left": left, "right": right, "total": total}

func _layout_bar() -> void:
	if _nat == null: return
	var m: float = 8.0
	var avail: float = _vp.x - m * 2.0
	var stage: int = 0 if _prof != Prof.PORTRAIT else 2
	var comp: Dictionary = _compose_bar(stage)
	while float(comp["total"]) > avail and stage < 8:
		stage += 1
		comp = _compose_bar(stage)
	_stage = stage
	var ch: float = _chip_h()
	var bh: float = _bar_h()
	var y: float = (bh - ch) * 0.5
	for c in [_nat, _date, _war, _inf, _lens_chip, _menu_btn, _dots_btn]: (c as Control).visible = false
	for c in _chips.values(): (c as Control).visible = false
	for b in _lens_btns: (b as Control).visible = false
	var x: float = m
	for it in comp["left"]:
		var c2: Control = it[0]
		x += float(it[1])
		c2.visible = true; c2.position = Vector2(x, y); c2.size = Vector2(float(it[2]), ch)
		x += float(it[2])
	var rx: float = _vp.x - m
	for k in range((comp["right"] as Array).size() - 1, -1, -1):
		var it2: Array = (comp["right"] as Array)[k]
		var c3: Control = it2[0]
		rx -= float(it2[2])
		c3.visible = true
		if c3 is P.IconBtn:
			c3.position = Vector2(rx, (bh - 36.0) * 0.5); c3.size = Vector2(float(it2[2]), 36.0)
		else:
			c3.position = Vector2(rx, y); c3.size = Vector2(float(it2[2]), ch)
		rx -= float(it2[1])
	_apply_dates()
	for c4 in [_nat, _date, _war, _inf, _lens_chip]: (c4 as Control).queue_redraw()
	_sync_seal()

## hud rectangles (global) the map labels must keep clear of
func keepouts() -> Array:
	var out: Array = []
	if not visible or _bar == null: return out
	out.append(_bar.get_global_rect())
	if _rail.visible: out.append(_rail.get_global_rect().grow(4.0))
	if _bottom.visible: out.append(_bottom.get_global_rect())
	var tr: Rect2 = _ticker.occupied_rect()
	if tr.size.x > 0.0: out.append(tr.grow(4.0))
	out.append(_seal.get_global_rect().grow(10.0))
	if _legend.visible: out.append(_legend.get_global_rect().grow(4.0))
	if _strip.visible: out.append(_strip.get_global_rect().grow(4.0))
	return out

## vertical space the top bar occupies
func ribbon_height() -> float:
	return _bar.size.y if _bar != null else 40.0

# ================================================================== refresh
static func _year(y: int) -> String:
	return "%d BC" % -y if y < 0 else "%d AD" % y

func _fmt_num(v: float, compact: bool) -> String:
	var a: float = absf(v)
	if a >= 1000000.0: return "%.1fM" % (v / 1000000.0)
	if a >= (1000.0 if compact else 10000.0): return "%.1fk" % (v / 1000.0)
	var s: String = str(int(round(absf(v))))
	if s.length() > 3: s = s.left(s.length() - 3) + ("," if TBI18n.lang == "en" else " ") + s.right(3)
	return ("−" + s) if v < 0.0 and int(round(v)) != 0 else s

func _is_hot() -> bool:
	if g == null: return false
	if mp_waiting_fn.is_valid() and bool(mp_waiting_fn.call()): return false
	return g.humans().size() > 1

func _tag() -> String:
	if g != null and _is_hot(): return "P%d" % (g.humans().find(g.human_id) + 1)
	return seat_tag

func refresh() -> void:
	if g == null or _nat == null: return
	var n: int = g.human_id
	var inc: Dictionary = g.income(n)
	var bd: Dictionary = TBAdvisor.breakdown(g, n, inc)
	var compact: bool = _prof != Prof.DESKTOP
	var fmt := func(v: float) -> String: return _fmt_num(v, compact)
	_nat.flag = TBFlags.texture(g.nat_code[n], g.color[n])
	_nat.nation = g.dname(n)
	var tag: String = _tag()
	_nat.seat = (g.humans().find(n)) if _is_hot() else -1
	_nat.seat_text = tag
	var net: int = bd["net"]
	var gc: P.Chip = _chips["gold"]
	gc.set_num(g.gold[n], fmt); gc.has_delta = true; gc.delta = net
	gc.state = 2 if (g.gold[n] <= 0.0 and net < 0) else (1 if (net < 0 and g.gold[n] < -net * 5.0) else 0)
	_suffix["gold"] = ""
	var mc: P.Chip = _chips["man"]
	mc.set_num(g.manpower[n], fmt); mc.has_delta = true; mc.delta = int(bd["man_gain"]); mc.state = 1 if bd["man_full"] else 0
	_suffix["man"] = "/%s" % _fmt_num(float(bd["man_cap"]), compact)
	var pc: P.Chip = _chips["mp"]
	pc.set_num(floorf(g.mp[n]), fmt); pc.has_delta = false
	_suffix["mp"] = "/%d" % int(bd["mp_cap"])
	var dc: P.Chip = _chips["dp"]
	dc.set_num(floorf(g.dp[n]), fmt); dc.has_delta = true; dc.delta = int(round(float(bd["dp_gain"])))
	_suffix["dp"] = ""
	_wars = 0
	for o in range(1, g.N1):
		if g.alive[o] != 0 and g.get_rel(n, o) == 1: _wars += 1
	_war.set_num(float(_wars), fmt); _war.glyph_col = P.tk("neg_bar"); _inf.glyph_col = P.tk("neg_bar")
	_inf_on = g.rules >= 1 and (g.infamy[n] >= 5.0 or g.coalition[n] != 0)
	_inf.set_num(floorf(g.infamy[n]), fmt); _inf.state = 2 if g.coalition[n] != 0 else 0
	_date.year = _year(g.year)
	_date.turn_cap = "%s %d" % [T.call("turn"), g.turn] if _prof == Prof.DESKTOP else T.call("tk_turn_short", {"k": g.turn})
	# alerts
	_entries = TBAdvisor.ticker(g, n)
	for e in _entries: _describe(e)
	_ticker.update(_entries, g.turn)
	_announce_new()
	var al: Array = TBAdvisor.alerts(g, n)
	var crit: int = 0
	for a in al: if int(a["sev"]) == 2: crit += 1
	var adv: P.IconBtn = _dock[3]
	adv.badge = al.size(); adv.badge_crit = crit > 0; adv.queue_redraw()
	_lens_bottom.glyph = P.lens_glyph(_lens)
	_seal.attention = crit
	_layout_bar()
	_place_strip()
	_place_legend()

func _apply_dates() -> void:
	if _strip != null and _strip.visible: _strip.queue_redraw()

# ================================================================== alert text
## fill e["text"] (one line) and the tooltip pair
func _describe(e: Dictionary) -> void:
	var id: String = String(e["id"])
	var pn: String = TBI18n.place(g.world.name[int(e["p"])]) if int(e["p"]) >= 0 else ""
	var on: String = g.dname(int(e["n"])) if int(e["n"]) > 0 else ""
	var vars := {"k": int(e["k"]), "r": "%.1f" % (int(e["k"]) / 10.0), "p": pn, "a": on}
	var text: String = ""
	var long: String = ""
	match String(e["cls"]):
		"offer":
			text = T.call("tk_offer_" + id, vars)
			long = T.call("prop_" + id, vars) if TBI18n.has_key("prop_" + id) else text
		"event":
			text = T.call("tk_event", {"t": _event_title(int(e["uid"]), id)})
			long = text
		_:
			var key: String = "tk_" + id
			if id == "unrest": key = "tk_unrest_1" if int(e["k"]) <= 1 else "tk_unrest_n"
			elif id == "attrition": key = "tk_attrition_1" if int(e["k"]) <= 1 else "tk_attrition_n"
			text = T.call(key, vars)
			long = T.call("al_" + id, vars)
	e["text"] = text
	e["tip"] = [T.call("cls_" + String(e["cls"])) + (" · " + T.call("tk_critical") if int(e["sev"]) >= 2 else ""), long + "\n" + T.call("tk_tap_look") if String(e["cls"]) != "offer" else long + "\n" + T.call("tk_tap_answer")]

func _event_title(uid: int, id: String) -> String:
	for pe in g.pending:
		if int(pe["uid"]) != uid: continue
		if String(pe["kind"]) == "rand": return T.call("ev_%s_t" % id)
		var ti: Variant = pe.get("title", {})
		if ti is Dictionary: return String((ti as Dictionary).get(TBI18n.lang, (ti as Dictionary).get("en", id)))
		return String(ti)
	return id

## new alert chips are mirrored to the text feed once, and optionally spoken
func _announce_new() -> void:
	var seen: Dictionary = {}
	for e in _entries:
		var k: String = String(e["key"])
		seen[k] = true
		if _announced.has(k): continue
		_announced[k] = true
		var tx: String = ("%s: %s" % [T.call("cls_" + String(e["cls"])), String(e["text"])])
		_feed_add(tx, int(e["sev"]) >= 2)
		if tts_mode == "all" or (tts_mode == "critical" and int(e["sev"]) >= 2):
			DisplayServer.tts_speak(tx, "", 80)
	for k in _announced.keys():
		if not seen.has(k): _announced.erase(k)

func _on_alert(e: Dictionary) -> void:
	tapped.emit()
	var id: String = String(e["id"])
	if id == "bankrupt" or id == "low_treasury": budget_pressed.emit()
	elif String(e["cls"]) == "event": event_requested.emit(int(e["uid"]))
	elif id == "war_declared" and int(e["n"]) > 0: nation_pressed.emit(int(e["n"]))
	elif id == "coalition" and g != null: nation_pressed.emit(g.human_id)
	elif int(e["p"]) >= 0: goto_province.emit(int(e["p"]))
	elif int(e["n"]) > 0: nation_pressed.emit(int(e["n"]))

## next / previous alert chip (hotkey A / Shift+A): look at its cause
func cycle_alert(dir: int) -> void:
	var live: Array = []
	for e in _entries:
		if String(e["cls"]) != "offer": live.append(e)
	if live.is_empty(): return
	_alert_i = posmod(_alert_i + dir, live.size())
	_on_alert(live[_alert_i])
var _alert_i: int = -1

# ================================================================== feed + turn report + toast
func _feed_add(text: String, bad: bool) -> void:
	if g == null: return
	feed.append({"turn": g.turn, "date": _year(g.year), "text": text, "bad": bad})
	if feed.size() > 600: feed = feed.slice(feed.size() - 500)

## the newest feed lines, newest last
func feed_lines(count: int = 20) -> Array:
	return feed.slice(maxi(0, feed.size() - count))

## one toast-style message at a time (a new one replaces the old); mirrored to the text feed
func toast(msg: String, bad: bool = false) -> void:
	_feed_add(msg, bad)
	if _ticker == null: return
	_ticker.show_info(msg, "warn" if bad else "info", clampf(5.0 + maxf(0.0, msg.length() - 40.0) * 0.05, 5.0, 10.0))

## collect one end-of-turn log line (category from TBChron.category); report_flush() shows one summary chip
func report_line(text: String, bad: bool, cat: String) -> void:
	_feed_add(text, bad)
	_rep.append({"text": text, "bad": bad, "cat": cat})

func report_flush(battles: int = 0) -> void:
	if _rep.is_empty(): return
	var lines: Array = _rep
	_rep = []
	var text: String
	if lines.size() == 1:
		text = String(lines[0]["text"])
	else:
		var counts: Dictionary = {}
		for l in lines: counts[String(l["cat"])] = int(counts.get(String(l["cat"]), 0)) + 1
		var parts: PackedStringArray = PackedStringArray()
		for c in ["war", "diplo", "events", "mine", "all"]:
			if counts.has(c): parts.append(T.call("rep_" + c, {"k": counts[c]}))
		text = " · ".join(parts)
	var full: String = T.call("tk_report", {"t": g.turn, "s": text})
	_rep_gen += 1
	var gen: int = _rep_gen
	var delay: float = 0.0 if reduce_motion_now() else minf(8.0, float(battles)) * 0.22 + 0.2
	if delay <= 0.0 or not is_inside_tree():
		_ticker.show_info(full, "report", 6.0)
	else:
		get_tree().create_timer(delay).timeout.connect(func(): if gen == _rep_gen and _ticker != null: _ticker.show_info(full, "report", 6.0))

func reduce_motion_now() -> bool: return P.reduced_motion()

# ================================================================== tooltips and popovers
func _tip_hide() -> void:
	if _tip != null and is_instance_valid(_tip): _tip.queue_free()
	_tip = null

func _tip_show(anchor: Control, pair: Array) -> void:
	_tip_hide()
	if _pop != null or pair.size() < 2 or not is_instance_valid(anchor): return
	_tip = P.tip_box(String(pair[0]), String(pair[1]))
	_tip.z_index = 70
	add_child(_tip)
	_place_near(_tip, anchor)

func _place_near(c: Control, anchor: Control) -> void:
	var sz: Vector2 = c.get_combined_minimum_size()
	c.size = sz
	var ar := Rect2(anchor.global_position - global_position, anchor.size)
	var pos := Vector2(ar.position.x, ar.end.y + 6.0)
	if pos.y + sz.y > size.y - 4.0 or ar.position.y > size.y * 0.55: pos.y = ar.position.y - sz.y - 6.0
	if ar.position.x > size.x * 0.6 and ar.size.y > 60.0: pos = Vector2(ar.position.x - sz.x - 6.0, ar.position.y)
	if _rail != null and _rail.visible and anchor.get_parent() == self and ar.position.x < _rail.size.x + 16.0 and ar.position.y > _bar_h():
		pos = Vector2(ar.end.x + 6.0, ar.position.y)
	pos.x = clampf(pos.x, 4.0, maxf(4.0, size.x - sz.x - 4.0))
	pos.y = clampf(pos.y, 4.0, maxf(4.0, size.y - sz.y - 4.0))
	c.position = pos

func _open_pop(kind: String, content: Control, anchor: Control) -> void:
	_close_pop(); _tip_hide()
	_pop_kind = kind
	_catcher = Control.new(); _catcher.set_anchors_preset(Control.PRESET_FULL_RECT); _catcher.mouse_filter = Control.MOUSE_FILTER_STOP; _catcher.z_index = 60
	_catcher.gui_input.connect(func(e: InputEvent): if e is InputEventMouseButton and (e as InputEventMouseButton).pressed: _close_pop(); _catcher_eat(e))
	add_child(_catcher)
	_pop = content; _pop.z_index = 65
	add_child(_pop)
	_place_near(_pop, anchor)
	set_process(true)

func _catcher_eat(e: InputEvent) -> void:
	if _catcher != null: _catcher.accept_event()

func _close_pop() -> void:
	if _pop != null and is_instance_valid(_pop): _pop.queue_free()
	if _catcher != null and is_instance_valid(_catcher): _catcher.queue_free()
	_pop = null; _catcher = null; _pop_kind = ""

func is_popover_open() -> bool: return _pop != null

# ---- tooltip content
func _tip_text(title: String, key_hint: String) -> Array:
	return [title, (T.call("tk_key", {"k": key_hint}) if key_hint != "" else "")]

func _tip_lens(lens: String) -> Array:
	var i: int = TBLenses.NAMES.find(lens)
	return [T.call("lens_" + lens), T.call("tk_key", {"k": "Alt+%d" % (i + 1)})]

func _tip_nation() -> Array:
	return [T.call("tk_realm"), T.call("tk_realm_hint")]

func _tip_seal() -> Array:
	return [T.call("end_turn"), T.call("tk_key", {"k": "Enter"})]

func _chip_text(key: String) -> Array:
	var n: int = g.human_id
	var bd: Dictionary = TBAdvisor.breakdown(g, n)
	var fmt := func(v: float) -> String: return _fmt_num(v, false)
	match key:
		"gold":
			var lines: PackedStringArray = PackedStringArray()
			lines.append(T.call("tk_gold_1", {"v": fmt.call(float(bd["gold"]))}))
			lines.append(T.call("tk_gold_2", {"g": fmt.call(float(bd["gross"])), "u": fmt.call(float(bd["upkeep"])), "a": fmt.call(float(bd["admin"]))}))
			lines.append(T.call("tk_gold_3", {"n": ("+" if int(bd["net"]) >= 0 else "−") + fmt.call(absf(float(bd["net"])))}))
			var ro: int = int(bd["runs_out"])
			lines.append(T.call("tk_gold_safe") if ro < 0 else (T.call("tk_gold_empty") if ro == 0 else T.call("tk_gold_out", {"k": ro})))
			return [T.call("gold"), "\n".join(lines)]
		"man":
			var l2: PackedStringArray = PackedStringArray()
			l2.append(T.call("tk_man_1", {"v": fmt.call(float(bd["man"])), "c": fmt.call(float(bd["man_cap"]))}))
			l2.append(T.call("tk_man_2", {"g": int(bd["man_gain"])}))
			l2.append(T.call("tk_man_3", {"g": TBData.COST_RECRUIT_GOLD, "m": TBData.COST_RECRUIT_MAN}))
			if bool(bd["man_full"]): l2.append(T.call("tk_man_full"))
			return [T.call("manpower"), "\n".join(l2)]
		"mp":
			return [T.call("mp"), "\n".join(PackedStringArray([T.call("tk_mp_1", {"v": int(floorf(float(bd["mp"]))), "c": int(bd["mp_cap"])}), T.call("tk_mp_2", {"g": "%.1f" % float(bd["mp_gain"]), "c": int(bd["mp_cap"])}), T.call("tk_mp_3", {"m": TBData.MP_MOVE, "a": TBData.MP_ATTACK, "r": TBData.MP_RECRUIT})]))]
		"dp":
			return [T.call("dp"), "\n".join(PackedStringArray([T.call("tk_dp_1", {"v": int(floorf(float(bd["dp"]))), "c": int(bd["dp_cap"])}), T.call("tk_dp_2", {"g": "%.1f" % float(bd["dp_gain"])}), T.call("tk_dp_3", {"u": TBDiplo.DP_ULT, "n": TBData.DP_NAP, "a": TBData.DP_ALLY, "m": TBDiplo.DP_MARRY})]))]
		"wars":
			var names: PackedStringArray = PackedStringArray()
			for o in range(1, g.N1):
				if g.alive[o] != 0 and g.get_rel(n, o) == 1: names.append(g.dname(o))
			return [T.call("hud_wars"), T.call("tk_wars_with", {"l": ", ".join(names)})]
		"infamy":
			var inf_s: String = T.call("tk_inf_1", {"v": int(g.infamy[n])})
			if g.coalition[n] != 0: inf_s += "\n" + T.call("tk_inf_coal")
			return [T.call("infamy"), inf_s]
	return ["", ""]

func _tip_chip(key: String) -> Array:
	if g == null: return []
	return _chip_text(key)

func _pin_chip(key: String) -> void:
	if g == null: return
	tapped.emit()
	var pair: Array = _chip_text(key)
	var box: PanelContainer = P.tip_box(String(pair[0]), String(pair[1]))
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var link: String = ""
	var act: Callable = Callable()
	match key:
		"gold": link = T.call("tk_open_budget"); act = func(): budget_pressed.emit()
		"dp": link = T.call("tk_open_nations"); act = func(): nations_pressed.emit()
		"infamy": link = T.call("tk_open_decrees"); act = func(): decisions_pressed.emit()
	if link != "":
		var b: Button = P.btn(link, "secondary", func(): _close_pop(); act.call(), true, 14)
		(box.get_child(0) as VBoxContainer).add_child(b)
	_open_pop("chip", box, _chips[key] if _chips.has(key) else (_inf if key == "infamy" else _war))

# ================================================================== screens, lens
func _screen(id: String) -> void:
	tapped.emit(); _tip_hide()
	_set_active(id)
	match id:
		"nations": nations_pressed.emit()
		"budget": budget_pressed.emit()
		"decisions": decisions_pressed.emit()
		"advisor": advisor_pressed.emit()
		"chronicle": chronicle_pressed.emit()
		"goals": goals_pressed.emit()
		"save": save_pressed.emit()
		"settings": settings_pressed.emit()

func _set_active(id: String) -> void:
	_active = id
	_active_t = 0.0
	for b in _dock:
		var ib: P.IconBtn = b
		ib.active = String(ib.get_meta("screen", "")) == id
		ib.queue_redraw()
	var behind: bool = id != "" and not (id in ["nations", "budget", "decisions", "advisor"])
	_dock_more.active = behind; _dock_more.queue_redraw()
	set_process(id != "" or _pop != null or _hint_gen > 0)

func _process(d: float) -> void:
	if _active != "":
		_active_t += d
		if _active_t > 0.4 and input_blocked_fn.is_valid() and not bool(input_blocked_fn.call()): _set_active("")
	if _pop == null and _active == "": set_process(false)

func _pick_lens(lens: String) -> void:
	_close_pop()
	set_lens_legend(lens)
	lens_selected.emit(lens)

func set_lens_legend(lens: String) -> void:
	_lens = lens
	if _legend != null: _legend.setup(lens)
	_lens_changed()
	_place_legend()
	_layout_bar()

func _lens_changed() -> void:
	for b in _lens_btns:
		var ib: P.IconBtn = b
		var l: String = String(ib.get_meta("lens", ""))
		if l == "":                                       # the "more" button lights up when the active lens is not pinned
			ib.active = not LENS_PINNED.has(_lens)
			ib.glyph = P.lens_glyph(_lens) if ib.active else "dots"
		else:
			ib.active = l == _lens
		ib.queue_redraw()
	if _lens_chip != null:
		_lens_chip.lens = _lens; _lens_chip.label = T.call("lens_" + _lens); _lens_chip.queue_redraw()
	if _lens_bottom != null: _lens_bottom.glyph = P.lens_glyph(_lens); _lens_bottom.queue_redraw()

## "L" / chip: 4 pinned lenses, the rest behind "More", the legend of the active lens underneath
func _open_lens_pop(anchor: Control) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", P.bar_box(12, 10, 4, true))
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 6); pc.add_child(v)
	var hd := Label.new(); hd.text = T.call("tk_lens"); hd.add_theme_font_override("font", P.body_b()); hd.add_theme_font_size_override("font_size", P.fs(12.0)); hd.add_theme_color_override("font_color", P.tk("smoke")); v.add_child(hd)
	var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 4); grid.add_theme_constant_override("v_separation", 4); v.add_child(grid)
	var rest: Array = []
	for i in TBLenses.NAMES.size():
		var l: String = TBLenses.NAMES[i]
		if LENS_PINNED.has(l): grid.add_child(_lens_row(l, i))
		else: rest.append([l, i])
	var more := GridContainer.new(); more.columns = 2; more.add_theme_constant_override("h_separation", 4); more.add_theme_constant_override("v_separation", 4)
	for r in rest: more.add_child(_lens_row(String(r[0]), int(r[1])))
	more.visible = _lens_more or not LENS_PINNED.has(_lens)
	var tog := RowBtn.new(); tog.glyph = "dots"; tog.label = T.call("tk_more_lenses"); tog.custom_minimum_size = Vector2(0, 40)
	tog.pressed.connect(func(): more.visible = not more.visible; _lens_more = more.visible; pc.reset_size(); _place_near(pc, anchor))
	v.add_child(tog); v.add_child(more)
	if _legend.has_key() and _prof != Prof.DESKTOP:
		var lg := P.Legend.new(); lg.framed = false; lg.width = minf(260.0, _vp.x - 56.0); lg.setup(_lens); lg.visible = true; v.add_child(lg)
	_open_pop("lens", pc, anchor)

func _lens_row(lens: String, i: int) -> RowBtn:
	var r := RowBtn.new(); r.glyph = P.lens_glyph(lens); r.label = T.call("lens_" + lens); r.hint = ("Alt+%d" % (i + 1)) if (_prof == Prof.DESKTOP and i < 9) else ""
	r.active = lens == _lens; r.custom_minimum_size = Vector2(minf(196.0, (_vp.x - 56.0) * 0.5), 44); r.set_a11y(r.label)
	r.pressed.connect(func(): tapped.emit(); _pick_lens(lens))
	return r

## every screen as a list (SHORT "menu" button, "More" on the rail, the portrait overflow)
func _open_menu(anchor: Control, only_more: bool) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", P.bar_box(8, 8, 4, true))
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); pc.add_child(v)
	for i in SCREENS.size():
		if only_more and i < PRIMARY: continue
		var sc: Array = SCREENS[i]
		var r := RowBtn.new(); r.glyph = sc[1]; r.label = T.call(sc[2]); r.hint = sc[3]; r.custom_minimum_size = Vector2(190, 48); r.set_a11y(r.label)
		var sid: String = sc[0]
		r.pressed.connect(func(): _close_pop(); _screen(sid))
		if sid == "advisor": r.badge = (_dock[3] as P.IconBtn).badge
		v.add_child(r)
	_open_pop("menu", pc, anchor)

# ================================================================== realm sheet
func _open_realm() -> void:
	if g == null: return
	tapped.emit()
	var n: int = g.human_id
	var inc: Dictionary = g.income(n)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", P.paper_box(16, 14))
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); pc.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 12); v.add_child(head)
	if g.rules >= 1 and g.r_name[n] != "":
		head.add_child(TBPortrait.new().setup(g, n, 56))
	var hv := VBoxContainer.new(); hv.add_theme_constant_override("separation", 0); hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER; head.add_child(hv)
	hv.add_child(K.title(g.dname(n), 20, P.tk("oxblood")))
	if g.rules >= 1 and g.r_name[n] != "":
		var rt: Label = K.label("%s %s" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)], P.fs(14.0), P.tk("ink_1"))
		hv.add_child(rt)
	if _is_hot(): hv.add_child(K.label("%s · %s" % [_tag(), T.call("tk_round", {"k": g.turn})], P.fs(13.0), P.tk("brass_ink")))
	v.add_child(_sheet_row(T.call("lands"), str(int(inc["lands"]))))
	if g.rules >= 1: v.add_child(_sheet_row(T.call("hud_intel"), str(int(floorf(g.intel[n])))))
	v.add_child(_sheet_row(T.call("tech"), "%.1f · %s" % [g.tech_level[n], T.call("era_name_%d" % g.era[n])]))
	v.add_child(_sheet_row(T.call("tk_date"), "%s · %s" % [_year(g.year), T.call("turn") + " %d" % g.turn]))
	if _stage >= 4 or _prof == Prof.PORTRAIT:
		v.add_child(_sheet_row(T.call("hud_wars"), str(_wars)))
		if g.rules >= 1: v.add_child(_sheet_row(T.call("infamy"), str(int(g.infamy[n]))))
	if _stage >= 5 or _prof == Prof.PORTRAIT:
		if g.rules >= 1: v.add_child(_sheet_row(T.call("dp"), "%d" % int(floorf(g.dp[n]))))
	var open := P.btn(T.call("tk_nation_sheet"), "secondary", func(): _close_pop(); nation_pressed.emit(n), false, 14)
	v.add_child(open)
	if _prof == Prof.PORTRAIT:
		var cap := K.label(T.call("tk_more"), P.fs(12.0), P.tk("ink_1")); v.add_child(cap)
		var grid := GridContainer.new(); grid.columns = 2; grid.add_theme_constant_override("h_separation", 6); grid.add_theme_constant_override("v_separation", 6); v.add_child(grid)
		for i in range(PRIMARY, SCREENS.size()):
			var sc: Array = SCREENS[i]
			var sid: String = sc[0]
			grid.add_child(P.btn(T.call(sc[2]), "secondary", func(): _close_pop(); _screen(sid), false, 14))
	pc.custom_minimum_size = Vector2(minf(300.0, _vp.x - 16.0), 0)
	_open_pop("realm", pc, _nat if _prof != Prof.PORTRAIT else _dots_btn)

func _sheet_row(cap: String, val: String) -> HBoxContainer:
	var h := HBoxContainer.new(); h.add_theme_constant_override("separation", 8)
	var l: Label = K.label(cap, P.fs(13.0), P.tk("ink_1")); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(l)
	var vl: Label = K.label(val, P.fs(14.0), P.tk("ink_0")); vl.add_theme_font_override("font", K.mono_b()); vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; h.add_child(vl)
	return h

# ================================================================== alert drawer ("+n")
func _open_drawer() -> void:
	tapped.emit()
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", P.bar_box(10, 10, 4, true))
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; pc.add_child(sc)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); v.custom_minimum_size = Vector2(minf(300.0, _vp.x - 40.0), 0); sc.add_child(v)
	if _entries.is_empty(): v.add_child(_cap_label(T.call("al_none")))
	var last: String = ""
	for e in _entries:
		if String(e["cls"]) != last:
			last = String(e["cls"]); v.add_child(_cap_label(T.call("cls_" + last)))
		var row := AT.AlertRow.new(); row.drawer = true; row.set_entry(e, String(e["text"]))
		row.custom_minimum_size = Vector2(minf(300.0, _vp.x - 40.0), row.base_h())
		row.pressed.connect(func(): _close_pop(); _on_alert(e) if String(e["cls"]) != "offer" else null)
		v.add_child(row)
	var msgs: Array = feed_lines(8)
	if not msgs.is_empty():
		v.add_child(_cap_label(T.call("tk_messages")))
		for i in range(msgs.size() - 1, -1, -1):
			var m: Dictionary = msgs[i]
			var l := Label.new(); l.text = "%s  %s" % [m["date"], m["text"]]; l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(minf(300.0, _vp.x - 40.0), 0)
			l.add_theme_font_override("font", P.body()); l.add_theme_font_size_override("font_size", P.fs(13.0)); l.add_theme_color_override("font_color", P.tk("smoke"))
			v.add_child(l)
	sc.custom_minimum_size = Vector2(0, minf(v.get_combined_minimum_size().y, _vp.y * 0.6))
	_open_pop("drawer", pc, _ticker)

func _cap_label(t: String) -> Label:
	var l := Label.new(); l.text = t; l.add_theme_font_override("font", P.body_b()); l.add_theme_font_size_override("font_size", P.fs(12.0)); l.add_theme_color_override("font_color", P.tk("smoke"))
	return l

# ================================================================== End Turn plate
func _pending_count() -> int:
	if g == null: return 0
	var k: int = 0
	for e in g.pending:
		if int(e["n"]) == g.human_id: k += 1
	return k

func _seal_pressed() -> void:
	if _seal.state == P.Seal.S.BUSY or _seal.state == P.Seal.S.WAIT or _seal.state == P.Seal.S.OVER: return
	var pend: int = _pending_count()
	var need: bool = confirm_mode == "always" or (confirm_mode == "smart" and pend > 0)
	if need and _seal.state != P.Seal.S.HINT:
		_arm_hint(pend); return
	_clear_hint()
	end_turn_pressed.emit()

func force_end_turn() -> void:
	if _seal.state == P.Seal.S.BUSY or _seal.state == P.Seal.S.WAIT or _seal.state == P.Seal.S.OVER: return
	_clear_hint(); end_turn_pressed.emit()

func _arm_hint(pend: int) -> void:
	_hint_gen += 1
	var gen: int = _hint_gen
	_seal.hint_left = 1.0
	_seal.set_state(P.Seal.S.HINT)
	_sync_seal()
	_ticker.pulse("offer"); _ticker.pulse("event")
	get_tree().create_timer(3.0).timeout.connect(func(): if gen == _hint_gen: _clear_hint())

func _clear_hint() -> void:
	_hint_gen += 1
	if _seal != null and _seal.state == P.Seal.S.HINT:
		_seal.set_state(P.Seal.S.IDLE)
	_sync_seal()

func _moves_text() -> String:
	var mp: int = int(floorf(g.mp[g.human_id]))
	return T.call("tk_moves_left", {"k": mp}) if mp > 0 else T.call("tk_moves_none")

func _next_seat() -> int:
	var hs: PackedInt32Array = g.humans()
	var i: int = hs.find(g.human_id)
	for k in range(i + 1, hs.size()):
		if g.alive[hs[k]] != 0: return hs[k]
	return 0

## caption + sub-line + state of the End Turn plate
func _sync_seal() -> void:
	if _seal == null or g == null: return
	var S = P.Seal.S
	var date_hidden: bool = _prof == Prof.PORTRAIT or _stage >= 6
	var lead: String = (T.call("tk_turn_short", {"k": g.turn}) + " · ") if date_hidden else ""
	if g.over:
		_seal.set_state(S.OVER); _seal.caption = T.call("tk_game_over"); _seal.sub = ""
	elif _busy:
		var waiting: bool = mp_waiting_fn.is_valid() and bool(mp_waiting_fn.call())
		_seal.set_state(S.WAIT if waiting else S.BUSY)
		_seal.caption = T.call("tk_waiting") if waiting else T.call("tk_resolving")
		_seal.sub = "" if waiting else T.call("tk_turn_range", {"a": _busy_turn, "b": _busy_turn + 1})
	elif _seal.state == S.HINT:
		var offers: int = 0; var events: int = 0
		for e in g.pending:
			if int(e["n"]) != g.human_id: continue
			if String(e["kind"]) == "prop": offers += 1
			else: events += 1
		_seal.caption = T.call("tk_end_anyway") if confirm_mode != "always" or offers + events > 0 else T.call("tk_confirm")
		if offers + events == 0: _seal.sub = T.call("tk_confirm_sub")
		elif events == 0: _seal.sub = T.call("tk_hint_offers", {"k": offers})
		elif offers == 0: _seal.sub = T.call("tk_hint_events", {"k": events})
		else: _seal.sub = T.call("tk_hint_both", {"k": offers + events})
	elif _is_hot():
		var nx: int = _next_seat()
		_seal.set_state(S.SEAT)
		_seal.caption = T.call("tk_pass_to", {"p": "P%d" % (g.humans().find(nx) + 1)}) if nx != 0 else T.call("tk_end_round")
		_seal.sub = lead + _moves_text()
	else:
		_seal.set_state(S.IDLE)
		_seal.caption = T.call("end_turn"); _seal.sub = lead + _moves_text()
	_seal.set_a11y("%s. %s" % [_seal.caption, _seal.sub])
	_seal.queue_redraw()
	# hot-seat strip
	if _is_hot() and _strip != null:
		var hs: PackedInt32Array = g.humans()
		var cur: int = hs.find(g.human_id)
		_strip.round_text = T.call("tk_round", {"k": g.turn})
		_strip.seats = []
		for i in hs.size():
			var st: int = 0 if i < cur else (1 if i == cur else 2)
			_strip.seats.append({"i": i, "tag": "P%d" % (i + 1), "state": st, "word": T.call(["tk_ended", "tk_playing", "tk_waiting_seat"][st])})
		_place_strip()

func set_seal_pulse(on: bool) -> void:
	if _seal: _seal.set_pulse(on)

## true while the turn resolves (local worker thread, or "ready" in multiplayer)
func set_busy(b: bool) -> void:
	_busy = b
	if b and g != null: _busy_turn = g.turn
	if _seal != null:
		_seal.hint_left = 0.0
		if b: _clear_hint()
	_sync_seal()

# ================================================================== keyboard
func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not (e as InputEventKey).pressed or (e as InputEventKey).echo or not visible or g == null: return
	var k: InputEventKey = e
	if k.keycode == KEY_ESCAPE:
		if _pop != null or _tip != null:
			_close_pop(); _tip_hide(); get_viewport().set_input_as_handled()
		return
	if input_blocked_fn.is_valid() and bool(input_blocked_fn.call()): return
	var handled: bool = true
	match k.keycode:
		KEY_F1: _screen("nations")
		KEY_F2: _screen("budget")
		KEY_F3: _screen("decisions")
		KEY_F4: _screen("advisor")
		KEY_F5: _screen("chronicle")
		KEY_F6: _screen("goals")
		KEY_ENTER, KEY_KP_ENTER:
			if k.ctrl_pressed or k.meta_pressed: force_end_turn()
			else: _seal_pressed()
		_:
			handled = false
			if k.alt_pressed and k.keycode >= KEY_1 and k.keycode <= KEY_9:
				var i: int = k.keycode - KEY_1
				if i < TBLenses.NAMES.size(): _pick_lens(TBLenses.NAMES[i]); handled = true
			elif not (k.ctrl_pressed or k.alt_pressed or k.meta_pressed):
				match k.keycode:
					KEY_L: _open_lens_pop(_lens_chip if _lens_chip.visible else (_lens_bottom if _lens_bottom.visible else _nat)); handled = true
					KEY_A: cycle_alert(-1 if k.shift_pressed else 1); handled = true
					KEY_N: _screen("nations"); handled = true
					KEY_B: _screen("budget"); handled = true
					KEY_D: _screen("decisions"); handled = true
					KEY_Y: _screen("chronicle"); handled = true
	if handled: get_viewport().set_input_as_handled()

# ================================================================== battle preview (kept API; restyled)
func hide_preview() -> void:
	if is_instance_valid(_preview): _preview.queue_free()
	_preview = null

## the exact outcome of an attack before it is committed: strengths with both numbers, the result in words, Attack / Cancel
func show_preview(info: Dictionary, place: String, on_ok: Callable, on_cancel: Callable) -> void:
	hide_preview()
	var win: bool = info["win"]
	_preview = PanelContainer.new()
	_preview.add_theme_stylebox_override("panel", P.paper_box(14, 12))
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); _preview.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 8); v.add_child(head)
	var ic := Control.new(); ic.custom_minimum_size = Vector2(24, 24); ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER; ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func(): TBGlyph.draw(ic, "swords", ic.size * 0.5, 22.0, P.tk("oxblood"), 1.8))
	head.add_child(ic)
	var tl: Label = K.label(T.call("pv_title", {"p": place}), P.fs(15.0), P.tk("ink_0")); tl.add_theme_font_override("font", P.body_b()); head.add_child(tl)
	var a: float = info["atk"]; var d: float = info["dfn"]
	var share: float = a / maxf(0.01, a + d)
	var bar := Control.new(); bar.custom_minimum_size = Vector2(250, 20); bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var own_n: String = K.fmt(float(int(info["send"]))); var def_n: String = K.fmt(float(int(info["defenders"])))
	bar.draw.connect(func():
		var w: float = bar.size.x
		bar.draw_rect(Rect2(0, 0, w, 20), P.tk("neg"))
		bar.draw_rect(Rect2(0, 0, w * share, 20), P.tk("brass_ink"))
		bar.draw_rect(Rect2(w * 0.5 - 1.0, 0, 2.0, 20), P.tk("paper_0"))
		var fm: Font = K.mono_b()
		bar.draw_string(fm, Vector2(6, P.base(fm, 13, 10.0)), own_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, P.tk("paper_0"))
		bar.draw_string(fm, Vector2(w - 6.0 - P.tw(fm, def_n, 13), P.base(fm, 13, 10.0)), def_n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, P.tk("paper_0")))
	v.add_child(bar)
	var res: String
	if win: res = T.call("pv_win", {"k": int(info["hold"]), "l": int(info["lost"])})
	else: res = T.call("pv_lose", {"a": int(info["lost"]), "d": int(info["enemy_lost"])})
	var rrow := HBoxContainer.new(); rrow.add_theme_constant_override("separation", 6); v.add_child(rrow)
	var mk := Control.new(); mk.custom_minimum_size = Vector2(16, 18); mk.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; mk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mk.draw.connect(func(): P.tri(mk, Vector2(8, 10), 12.0, P.tk("pos") if win else P.tk("neg"), win))
	rrow.add_child(mk)
	var rl: Label = K.label(res, P.fs(14.0), P.tk("ink_0")); rl.add_theme_font_override("font", P.body_b()); rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rl.custom_minimum_size = Vector2(230, 0); rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rrow.add_child(rl)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); v.add_child(row)
	row.add_child(P.btn(T.call("pv_cancel"), "secondary", func(): hide_preview(); on_cancel.call(), false, 15))
	var ok: Button = P.btn(T.call("pv_attack"), "danger", func(): hide_preview(); on_ok.call(), false, 15)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(ok)
	_preview.z_index = 40
	add_child(_preview)
	var sz: Vector2 = _preview.get_combined_minimum_size()
	_preview.size = sz
	_preview.position = Vector2(clampf((_vp.x - sz.x) * 0.5, 8.0, _vp.x - sz.x - 8.0), clampf(_vp.y * 0.3, _bar_h() + 40.0, _vp.y - sz.y - 120.0))

# ================================================================== small classes
## flat row button: glyph, label, hotkey hint, optional count badge; active = brass bar + tick
class RowBtn extends P.Hit:
	var glyph: String = "gear"
	var label: String = ""
	var hint: String = ""
	var active: bool = false
	var badge: int = 0
	func _init() -> void:
		super()
		custom_minimum_size = Vector2(150, 44)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		P.plate(self, r, P.tk("bar_2") if (hover or down or active) else P.tk("bar_1"), Color.TRANSPARENT, 2.0, P.tk("brass_lt") if active else Color.TRANSPARENT, 3.0)
		var cy: float = size.y * 0.5
		P.icon(self, glyph, Vector2(24.0, cy), 22.0, P.tk("brass_lt") if active else P.tk("cream"), 2.2 if active else 1.7)
		var f: Font = P.body_b()
		var fsz: int = P.fs(14.0)
		var right: float = 10.0 + (P.tw(K.mono(), hint, P.fs(12.0)) + 6.0 if hint != "" else 0.0) + (22.0 if badge > 0 else 0.0) + (18.0 if active else 0.0)
		draw_string(f, Vector2(44.0, P.base(f, fsz, cy)), P.fit(f, label, fsz, size.x - 44.0 - right), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, P.tk("cream"))
		var x: float = size.x - 10.0
		if active:
			P.tick(self, Vector2(x - 6.0, cy), 12.0, P.tk("brass_lt"), 2.0)
			x -= 18.0
		if badge > 0:
			draw_circle(Vector2(x - 8.0, cy), 9.0, P.tk("brass_lt"))
			var fb: Font = K.mono_b()
			var s: String = str(mini(badge, 99))
			draw_string(fb, Vector2(x - 8.0 - P.tw(fb, s, P.fs(12.0)) * 0.5, P.base(fb, P.fs(12.0), cy)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, P.fs(12.0), P.tk("bar_0"))
			x -= 22.0
		if hint != "":
			var fm: Font = K.mono()
			draw_string(fm, Vector2(x - P.tw(fm, hint, P.fs(12.0)), P.base(fm, P.fs(12.0), cy)), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, P.fs(12.0), P.tk("smoke"))
		if has_focus(): P.focus_ring(self, r)

## "Political v": the lens chip for bars that cannot hold the pinned strip
class LensChip extends P.Hit:
	var lens: String = "political"
	var label: String = ""
	var compact: bool = false
	func fv() -> int: return P.fs(13.0 if compact else 14.0)
	func desired_w() -> float:
		return ceilf(8.0 + 18.0 + 6.0 + P.tw(P.body_b(), label, fv()) + 8.0 + 8.0 + 8.0)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		P.plate(self, r, P.tk("bar_2") if (hover or down) else P.tk("bar_1"), Color.TRANSPARENT, 2.0)
		var cy: float = size.y * 0.5 + (1.0 if down else 0.0)
		TBGlyph.draw(self, P.lens_glyph(lens), Vector2(8.0 + 9.0, cy), 18.0, P.tk("brass_lt"), 1.6)
		var f: Font = P.body_b()
		var x: float = 8.0 + 18.0 + 6.0
		x += P.txt(self, f, Vector2(x, P.base(f, fv(), cy)), label, fv(), P.tk("cream")) + 8.0
		P.tri(self, Vector2(x + 3.0, cy), 8.0, P.tk("smoke"), false)
		if has_focus(): P.focus_ring(self, r)
