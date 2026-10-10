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
## the End Turn footprint or the bar changed: the command card re-fits its band
signal layout_changed

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
const PRIMARY := 6
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
var _rail: P.Surface                          # the 64 px rail card (landscape)
var _bottom: P.Surface                        # the phone tab bar
var _nat: P.NationChip                        # crest
var _date: P.DateText
var _chips: Dictionary = {}
var _suffix: Dictionary = {}
var _war: P.Chip
var _inf: P.Chip
var _more_chip: P.Chip                        # phone: "+N" for the resource chips that did not fit
var _menu_btn: P.IconBtn                      # gear: the menu list (save, options, the rest of the screens)
var _dock: Array = []                         # rail items (landscape) / tab bar items (phone)
var _dock_more: P.IconBtn
var _mode: P.ModeSwitch                       # map lens segmented control next to the minimap
var _mm_btn: P.IconBtn                        # (retired: the round mini-globe is always shown on a desktop)
var _lens_btn: P.IconBtn                      # "more lenses" beside the tuner
var _zin: P.IconBtn                           # round zoom buttons beside the minimap
var _zout: P.IconBtn
var _mm_open: bool = false
var _ticker: TBAlertTicker                    # toasts
var _seal: P.Seal                             # the primary turn button
var _note: P.SealNote                         # the turn button's summary pill
var _legend: P.Legend
var _strip: P.SeatStrip
var map_view: TBMapView                      # the main map (the minimap shows and steers it)
var _minimap: TBMinimap
var _rail_n: int = 6                          # rail items shown (the rest sit behind More)
var _minimap_ok: bool = false
var _mm_globe: bool = false                  # the minimap's shape when the layout last ran (it follows the map's view mode)
var _insp: Rect2 = Rect2()                    # where the inspector (province card) goes, hud coordinates
var _drawer: Rect2 = Rect2()                  # where drawers open (right of the rail)
var _strip_rows_h: float = 72.0
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

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

# ================================================================== build
func build() -> void:
	P.sync_settings(); TBCmdCard.text_scale = P.text_scale
	for c in get_children(): c.queue_free()
	_chips.clear(); _suffix.clear(); _dock.clear()
	_pop = null; _catcher = null; _tip = null; _preview = null; _active = ""
	_nat = P.NationChip.new(); _nat.set_a11y(T.call("tk_realm")); _wire(_nat, _tip_nation); _nat.pressed.connect(_open_realm); add_child(_nat)
	_date = P.DateText.new(); add_child(_date)
	for spec in [["gold", "coin", "gold"], ["man", "men", "manpower"], ["mp", "arrowhead", "mp"], ["dp", "dove", "dp"]]:
		var c := P.Chip.new(); c.glyph = spec[1]; c.set_a11y(T.call("hud_cap_" + String(spec[0])))
		c.caption = T.call("hud_cap_" + String(spec[0]))
		if spec[0] == "gold": c.glyph_col = TBBezel.BRASS; c.delta_tone = 1                # Treasury: brass arc, the figure under it green / red
		if spec[0] == "mp": c.glyph_col = TBTokens.BZ_BAD                                 # Host: the demo's #D2603F
		if spec[0] == "man": c.glyph_col = TBTokens.BZ_GOOD                               # People
		if spec[0] == "dp": c.glyph_col = TBTokens.BZ_INFO                                # Envoys
		var key: String = spec[0]
		_wire(c, _tip_chip.bind(key)); c.pressed.connect(_pin_chip.bind(key))
		add_child(c); _chips[key] = c
	_war = P.Chip.new(); _war.glyph = "swords"; _war.glyph_col = TBTokens.BZ_BAD; _war.caption = T.call("hud_wars"); _war.set_a11y(T.call("hud_wars")); _wire(_war, _tip_chip.bind("wars")); _war.pressed.connect(func(): tapped.emit(); wars_pressed.emit()); add_child(_war)
	_inf = P.Chip.new(); _inf.glyph = "skull"; _inf.glyph_col = TBTokens.BZ_BAD; _inf.caption = T.call("infamy"); _inf.set_a11y(T.call("infamy")); _wire(_inf, _tip_chip.bind("infamy")); _inf.pressed.connect(_pin_chip.bind("infamy")); add_child(_inf)
	_more_chip = P.Chip.new(); _more_chip.glyph = "dots"; _more_chip.set_a11y(T.call("tk_more")); _more_chip.pressed.connect(_open_more_chips); add_child(_more_chip)
	_menu_btn = P.IconBtn.new(); _menu_btn.glyph = "gear"; _menu_btn.show_label = false; _menu_btn.framed = true; _menu_btn.icon_px = 22.0
	_menu_btn.set_a11y(T.call("tk_menu")); _menu_btn.pressed.connect(func(): tapped.emit(); _open_menu(_menu_btn, false)); _wire(_menu_btn, _tip_text.bind(T.call("tk_menu"), "")); add_child(_menu_btn)
	# ---- rail (landscape) / tab bar (phone)
	_rail = P.Surface.new(); _rail.kind = "card"; add_child(_rail)
	_bottom = P.Surface.new(); _bottom.kind = "bottom"; add_child(_bottom)
	for i in PRIMARY:
		var sc: Array = SCREENS[i]
		var b2 := P.IconBtn.new(); b2.glyph = sc[1]; b2.label = T.call(sc[2]); b2.set_a11y(T.call(sc[2]))
		b2.set_meta("screen", sc[0])
		var sid: String = sc[0]
		b2.pressed.connect(_screen.bind(sid))
		_wire(b2, _tip_text.bind(T.call(sc[2]), sc[3]))
		add_child(b2); _dock.append(b2)
	_dock_more = P.IconBtn.new(); _dock_more.glyph = "dots"; _dock_more.label = T.call("tk_more"); _dock_more.set_a11y(T.call("tk_more"))
	_dock_more.pressed.connect(func(): tapped.emit(); _open_menu(_dock_more, true)); add_child(_dock_more)
	# ---- map mode switch + minimap
	_mode = P.ModeSwitch.new(); _mode.set_a11y(T.call("tk_lens"))
	_mode.picked.connect(func(id: String): tapped.emit(); if id == "": _open_lens_pop(_mode) else: _pick_lens(id))
	_mode.items = []
	for l in LENS_PINNED: _mode.items.append([l, T.call("lens_" + l)])
	add_child(_mode)
	_lens_btn = P.IconBtn.new(); _lens_btn.glyph = "dots"; _lens_btn.show_label = false; _lens_btn.framed = true; _lens_btn.ticks_n = 0
	_lens_btn.set_a11y(T.call("tk_lens")); _lens_btn.pressed.connect(func(): tapped.emit(); _open_lens_pop(_lens_btn)); _wire(_lens_btn, _tip_text.bind(T.call("tk_lens"), "L")); add_child(_lens_btn)
	_mm_btn = P.IconBtn.new(); _mm_btn.glyph = "globe"; _mm_btn.show_label = false; _mm_btn.framed = true; _mm_btn.icon_px = 20.0
	_mm_btn.set_a11y(T.call("tk_minimap")); _mm_btn.pressed.connect(func(): _mm_open = not _mm_open; layout_for(_vp)); add_child(_mm_btn)
	_zin = P.IconBtn.new(); _zin.glyph = "plus"; _zin.show_label = false; _zin.framed = true; _zin.ticks_n = 0; _zin.icon_px = 16.0
	_zin.set_a11y(T.call("nav_zoom_in")); _zin.pressed.connect(func(): tapped.emit(); if map_view != null: map_view.zoom_by(1.4, true)); _wire(_zin, _tip_text.bind(T.call("nav_zoom_in"), "+")); add_child(_zin)
	_zout = P.IconBtn.new(); _zout.glyph = "minus"; _zout.show_label = false; _zout.framed = true; _zout.ticks_n = 0; _zout.icon_px = 16.0
	_zout.set_a11y(T.call("nav_zoom_out")); _zout.pressed.connect(func(): tapped.emit(); if map_view != null: map_view.zoom_by(1.0 / 1.4, true)); _wire(_zout, _tip_text.bind(T.call("nav_zoom_out"), "−")); add_child(_zout)
	_minimap = TBMinimap.new(); add_child(_minimap)
	_minimap.tip_requested.connect(func(): _tip_show(_minimap, [T.call("tk_minimap"), T.call("tk_minimap_hint")])); _minimap.tip_hidden.connect(_tip_hide)
	# ---- toasts, legend, hot-seat strip, turn button
	_ticker = TBAlertTicker.new()
	_ticker.activated.connect(_on_alert); _ticker.answered.connect(func(uid: int, c: int): tapped.emit(); offer_answered.emit(uid, c))
	_ticker.overflow_pressed.connect(_open_drawer); _ticker.report_pressed.connect(func(): tapped.emit(); chronicle_pressed.emit())
	_ticker.tip_requested.connect(_tip_show); _ticker.tip_hidden.connect(_tip_hide)
	add_child(_ticker)
	_legend = P.Legend.new(); add_child(_legend)
	_strip = P.SeatStrip.new(); _strip.visible = false; add_child(_strip)
	_note = P.SealNote.new(); _note.visible = false; add_child(_note)
	_seal = P.Seal.new(); _seal.set_a11y(T.call("end_turn")); _seal.pressed.connect(_seal_pressed); add_child(_seal)
	_wire(_seal, _tip_seal)
	_lens_changed()
	layout_for(size if size.x > 1.0 else get_viewport_rect().size)

## player text scale (1.0 / 1.25 / 1.5 / 1.75): every HUD font goes through TBHudParts.fs(); rebuilds the HUD
func set_text_scale(f: float) -> void:
	P.text_scale = clampf(f, 1.0, 2.0)
	TBCmdCard.text_scale = P.text_scale
	if g != null and _rail != null:
		build(); refresh()

## wire a control's tooltip (hover 350 ms / long-press 450 ms): fn -> [title, body]
func _wire(h: P.Hit, fn: Callable) -> void:
	h.tip_on.connect(func(): _tip_show(h, fn.call()))
	h.tip_off.connect(_tip_hide)

# ================================================================== layout
## the layout profile for a logical viewport (design units: a stage 1180 tall, or 390 for a phone in landscape): phone = portrait or narrower than 700
static func profile_for(vp: Vector2) -> int:
	if vp.y > vp.x or vp.x < 700.0: return Prof.PORTRAIT
	if vp.y < 380.0: return Prof.SHORT
	if vp.y < 560.0: return Prof.PHONE_L
	return Prof.DESKTOP

func _chip_h() -> float: return 60.0

## the demo's layout object `L` (b_demo.html layout()): every size of the HUD chrome in design units, for a desktop or a phone in landscape
static func demo_layout(vp: Vector2, phone: bool) -> Dictionary:
	var d := {"phone": phone, "W": vp.x, "H": vp.y, "m": 8.0 if phone else 28.0}
	if phone: d.merge({"med": 25.0, "gr": 15.0, "gsz": 56.0, "railD": 40.0, "railStep": 49.0, "railX": 12.0, "chr": 38.0, "mmR": 0.0, "tunW": 380.0, "panelX": 60.0, "panelY": 8.0, "panelH": vp.y - 16.0, "alertW": 330.0, "ar": 360.0})
	else: d.merge({"med": 46.0, "gr": 30.0, "gsz": 84.0, "railD": 52.0, "railStep": 78.0, "railX": 28.0, "chr": 74.0, "mmR": 74.0, "tunW": 560.0, "panelX": 340.0, "panelY": 190.0, "panelH": vp.y - 190.0 - 130.0, "alertW": 400.0, "ar": 560.0})
	d["axis"] = float(d["m"]) + maxf(float(d["med"]), maxf(float(d["mmR"]), float(d["railD"]) * 0.5))
	return d

var _L: Dictionary = {}
var _ribbon_h: float = 124.0

## Bezel HUD (docs/ui_variants/src/b_demo.html layout / renderTop / renderRail / renderTuner / renderMM): crest, four gauges, date and gear along the top, the arc rail with its
## ruler on the left, the round mini-globe bottom left, the lens tuner bottom centre, End Turn bottom right, notices top right. Portrait phones keep the tab bar.
func layout_for(vp: Vector2) -> void:
	if _rail == null: return
	P.sync_settings(); TBCmdCard.text_scale = P.text_scale
	var old: int = _prof
	_vp = vp
	_prof = profile_for(vp)
	_tip_hide(); _close_pop()
	P.u = P.text_scale
	if is_inside_tree(): TBBezel.ppu = maxf(0.2, get_viewport().get_final_transform().get_scale().x)
	if _prof == Prof.PORTRAIT: _layout_portrait(vp)
	else: _layout_demo(vp)
	_place_legend()
	_place_strip()
	_last_sig = _bar_sig()
	if _prof != old: refresh()
	else: _layout_bar()
	_sync_seal()
	layout_changed.emit()

## which resource gauges the bar shows, in order
func _chip_order() -> Array:
	var keys: Array = ["gold", "man", "mp", "dp"]
	if g == null or g.rules < 1: keys.erase("dp")
	var extra: Array = []
	if _wars > 0: extra.append("war")
	if _inf_on: extra.append("inf")
	return keys + extra

## flow the gauges from x0 along the top row; the ones that do not fit before x1 go behind the "+N" chip. Returns the bottom of the row.
func _flow_chips(x0: float, x1: float, top: float, gap_c: float, compact: bool) -> float:
	var order: Array = _chip_order()
	var shown: Array = order.duplicate()
	for k in ["gold", "man", "mp", "dp"]: (_chips[k] as Control).visible = false
	_war.visible = false; _inf.visible = false
	for k2 in ["gold", "man", "mp", "dp"]:
		var cc: P.Chip = _chips[k2]; cc.compact = compact; cc.tight = false; cc.delta_on = true
	for k3 in [_war, _inf, _more_chip]:
		var c3: P.Chip = k3; c3.compact = compact; c3.tight = false; c3.delta_on = false
	var more_w: float = 56.0 if compact else 84.0
	var more_needed: bool = false
	while true:
		var tot: float = 0.0
		for k in shown: tot += _chip_for(k).desired_w() + gap_c
		tot -= gap_c
		if tot + (gap_c + more_w if more_needed else 0.0) <= x1 - x0 or shown.size() <= 1: break
		shown.pop_back(); more_needed = true
	if g != null and _vp.x >= 1100.0: _refresh_spark()
	var cx: float = x0
	var bottom: float = top
	for k in shown:
		var c: P.Chip = _chip_for(k)
		c.size = Vector2(c.desired_w(), c.desired_h()); c.position = Vector2(cx, top); c.visible = true
		bottom = maxf(bottom, top + c.size.y)
		cx += c.size.x + gap_c
	var dropped: Array = []
	for k in order:
		if not shown.has(k): dropped.append(k)
	_more_chip.visible = not dropped.is_empty()
	if _more_chip.visible:
		_more_chip.caption = ""; _more_chip.has_delta = false; _more_chip.frac = -1.0
		_more_chip.set_num(float(dropped.size()), func(v: float) -> String: return "+%d" % int(v))
		_more_chip.size = Vector2(_more_chip.desired_w(), _more_chip.desired_h()); _more_chip.position = Vector2(cx, top)
	return bottom

func _layout_demo(vp: Vector2) -> void:
	var ph: bool = _prof != Prof.DESKTOP
	var L: Dictionary = demo_layout(vp, ph)
	_L = L
	var m: float = L["m"]; var med: float = L["med"]; var axis: float = L["axis"]
	# ---- top row
	_nat.compact = ph; _nat.show_name = not ph
	_nat.size = Vector2(_nat.desired_w(), 2.0 * med + 8.0); _nat.position = Vector2(axis - med - 4.0, m - 4.0); _nat.visible = true
	var gear: float = 40.0 if ph else 54.0
	_menu_btn.framed = true; _menu_btn.ticks_n = 24; _menu_btn.icon_px = 18.0 if ph else 22.0
	_menu_btn.size = Vector2(gear, gear); _menu_btn.position = Vector2(vp.x - m - (54.0 if ph else 100.0) - gear, m + med - (20.0 if ph else 27.0)); _menu_btn.visible = true
	_menu_btn.sq = gear
	_date.compact = ph; _date.visible = true
	_date.size = Vector2(_date.medal(), _date.medal()); _date.position = Vector2(vp.x - m - _date.medal(), m + med - (23.0 if ph else 42.0))
	var gsz: float = L["gsz"]
	var gap_c: float = 6.0 if ph else 20.0
	var x0: float = axis + med + (14.0 if ph else 200.0)
	var x1: float = _menu_btn.position.x - 12.0
	var chips_bottom: float = _flow_chips(x0, x1, m + med - gsz * 0.5, gap_c, ph)
	_ribbon_h = maxf(m + 2.0 * med + 4.0, chips_bottom)
	# ---- rail (the six screens on a shallow arc, ruler beside it)
	var D: float = L["railD"]; var st: float = L["railStep"]
	var bx: float = axis - D * 0.5
	var top_b: float = m + med * 2.0 + (8.0 if ph else 78.0)
	var bot_b: float = vp.y - m - (10.0 if ph else (float(L["mmR"]) * 2.0 + 66.0))
	var cnt: int = PRIMARY
	while cnt > 3 and float(cnt - 1) * st + D > vp.y - 6.0 - top_b: cnt -= 1
	var overflow: bool = cnt < PRIMARY
	_rail_n = cnt - 1 if overflow else cnt
	var tot_h: float = float(cnt - 1) * st + D
	var y0: float = maxf(top_b, roundf((top_b + bot_b - tot_h) * 0.5))
	var half: float = tot_h * 0.5
	_rail.visible = not ph; _bottom.visible = false
	_rail.ruler_r = L["ar"]
	_rail.position = Vector2(bx - 14.0, y0); _rail.size = Vector2(10.0 + ceilf(P.Surface.arc_dx(half, tot_h, L["ar"]) + 0.0) + 14.0, tot_h)
	var all: Array = _dock + [_dock_more]
	for b in all: (b as Control).visible = false
	for i in cnt:
		var b3: P.IconBtn = _dock[i] if i < _rail_n else _dock_more
		b3.visible = true; b3.edge = 0; b3.framed = false; b3.compact = ph; b3.dia = D
		b3.icon_px = 20.0 if ph else 24.0; b3.show_label = not ph
		b3.size = Vector2(b3.row_w(), D)
		b3.position = Vector2(bx + (0.0 if ph else P.Surface.arc_dx(float(i) * st + D * 0.5, tot_h, L["ar"])), y0 + float(i) * st)
	# ---- bottom left: the round mini-globe and its zoom buttons (desktop), zoom beside End Turn (phone)
	var r_mm: float = L["mmR"]
	var cy_mm: float = vp.y - m - r_mm - 26.0
	var show_mm: bool = not ph and vp.y >= 520.0
	_minimap_ok = show_mm
	_mm_globe = true
	_minimap.round_r = r_mm
	_minimap.visible = show_mm
	var mm_top: float = vp.y - m
	if show_mm:
		var mw: float = 2.0 * r_mm + 20.0
		_minimap.size = Vector2(mw, 2.0 * r_mm + 20.0 + 14.0)
		_minimap.position = Vector2(axis - mw * 0.5, cy_mm - r_mm - 10.0)
		mm_top = cy_mm - r_mm
	for z in [_zin, _zout]:
		var zb: P.IconBtn = z
		zb.framed = true; zb.ticks_n = 0; zb.size = Vector2(34.0, 34.0); zb.icon_px = 34.0 * 0.46; zb.visible = true
	if show_mm:
		_zin.position = Vector2(axis + r_mm + 26.0, cy_mm - 38.0)
	else:
		_zin.position = Vector2(vp.x - m - float(L["chr"]) - 17.0, vp.y - m - 21.0 - 2.0 * float(L["chr"]) - 24.0 - 76.0)
	_zout.position = _zin.position + Vector2(0, 42.0)
	_mm_btn.visible = false
	# ---- lens tuner (bottom centre)
	var tw_: float = L["tunW"]; var th_: float = 38.0 if ph else 60.0
	_mode.compact = ph
	_mode.size = Vector2(tw_, th_); _mode.position = Vector2(roundf((vp.x - tw_) * 0.5), vp.y - m - th_); _mode.visible = true
	_lens_btn.framed = true; _lens_btn.ticks_n = 0; _lens_btn.size = Vector2(34.0, 34.0); _lens_btn.icon_px = 34.0 * 0.46
	_lens_btn.position = Vector2(_mode.position.x + tw_ + 12.0, _mode.position.y + (th_ - 34.0) * 0.5); _lens_btn.visible = true
	_lens_btn.glyph = "dots"
	# ---- End Turn (bottom right): the dial's centre is the demo's (W - m - r, H - m - r - 29)
	var rc: float = L["chr"]
	_seal.compact = ph; _seal.narrow = false
	_seal_geom(vp, m, rc, ph)
	# ---- notices (top right; phones: beside the gauges)
	var aw: float = L["alertW"]
	_ticker.max_rows = 3 if not ph else 1
	_ticker.inline_pill = false
	_ticker.row_w = aw
	_ticker.gap = 10.0 if ph else 14.0
	_ticker.compact = ph
	_ticker.position = Vector2(vp.x - m - aw, m + 2.0 * med + 22.0) if not ph else Vector2(axis + med + 14.0 + gsz * 4.0 + 30.0, m)
	_ticker._layout()
	# ---- inspector + drawer areas
	var tk_bottom: float = _ticker.position.y
	var tr: Rect2 = _ticker.occupied_rect()
	if tr.size.x > 0.0 and not ph: tk_bottom = maxf(tk_bottom, tr.end.y - global_position.y + 12.0)
	var iw: float = (300.0 if not ph else 240.0) * (1.0 + (P.text_scale - 1.0) * 0.7)
	iw = minf(iw, vp.x * 0.62)
	var ibottom: float = _seal_rect().position.y - 16.0
	_insp = Rect2(vp.x - m - iw, tk_bottom, iw, maxf(130.0, ibottom - tk_bottom))
	var dw: float = minf(660.0 if not ph else vp.x - float(L["panelX"]) - m, vp.x - float(L["panelX"]) - m)
	_drawer = Rect2(float(L["panelX"]), float(L["panelY"]), dw, maxf(200.0, float(L["panelH"])))

## place the End Turn dial: unchanged drawing, centred on the demo's dial centre
func _seal_geom(vp: Vector2, m: float, rc: float, ph: bool) -> void:
	var sw_: float = _seal.width_px()
	var sh_: float = _seal.height_px()
	var k: float = (2.0 * rc) / _seal.diameter()
	_seal.u = k; _seal.scale = Vector2.ONE; _seal.pivot_offset = Vector2.ZERO
	_seal.size = Vector2(sw_ * k, sh_ * k)
	var cx: float = vp.x - m - rc
	var cy: float = vp.y - m - rc - (21.0 if ph else 29.0)
	_seal.position = Vector2(cx - sw_ * k * 0.5, cy - _seal.diameter() * k * 0.5)

## portrait phones (no demo layout): crest + gauges + gear on the top row, the tab bar below, bottom sheets
func _layout_portrait(vp: Vector2) -> void:
	_L = demo_layout(vp, true)
	var m: float = 8.0; var med: float = 25.0
	_nat.compact = true; _nat.show_name = false
	_nat.size = Vector2(_nat.desired_w(), 2.0 * med + 8.0); _nat.position = Vector2(m, m - 4.0 + 2.0); _nat.visible = true
	var gear: float = 40.0
	_menu_btn.framed = true; _menu_btn.ticks_n = 24; _menu_btn.icon_px = 18.0
	_menu_btn.size = Vector2(gear, gear); _menu_btn.position = Vector2(vp.x - m - gear, m + med - gear * 0.5 + 2.0); _menu_btn.visible = true; _menu_btn.sq = gear
	_date.visible = false
	var x0: float = _nat.position.x + _nat.size.x + 6.0
	var bottom: float = _flow_chips(x0, _menu_btn.position.x - 6.0, m, 6.0, true)
	_ribbon_h = maxf(m + 2.0 * med + 4.0, bottom)
	var rail_top: float = _ribbon_h + 8.0
	_rail.visible = false; _bottom.visible = true
	var all: Array = _dock + [_dock_more]
	for b in all: (b as Control).visible = false
	var bh: float = 56.0
	_bottom.position = Vector2(0, vp.y - bh); _bottom.size = Vector2(vp.x, bh)
	var cell: float = vp.x / 5.0
	for i in 4:
		var b4: P.IconBtn = _dock[i]
		b4.visible = true; b4.edge = 2; b4.framed = false; b4.icon_px = 22.0; b4.show_label = true
		b4.position = Vector2(i * cell, vp.y - bh); b4.size = Vector2(cell, bh)
	_dock_more.visible = true; _dock_more.edge = 2; _dock_more.framed = false; _dock_more.icon_px = 22.0; _dock_more.show_label = true
	_dock_more.position = Vector2(4.0 * cell, vp.y - bh); _dock_more.size = Vector2(cell, bh)
	_minimap.visible = false; _minimap_ok = false; _mode.visible = false; _lens_btn.visible = false; _mm_btn.visible = false
	_zin.visible = false; _zout.visible = false
	_seal.compact = false; _seal.narrow = true; _seal.scale = Vector2.ONE; _seal.pivot_offset = Vector2.ZERO; _seal.u = 1.0
	var sw_: float = _seal.width_px(); var sh_: float = _seal.height_px()
	_seal.size = Vector2(sw_, sh_)
	_seal.position = Vector2(vp.x - m - sw_, vp.y - (bh + 12.0) - sh_)
	_ticker.max_rows = 1; _ticker.inline_pill = true; _ticker.row_w = vp.x - 2.0 * m; _ticker.gap = 10.0; _ticker.compact = true
	_ticker.position = Vector2(m, rail_top); _ticker._layout()
	var tk_bottom: float = rail_top
	var iw: float = minf(320.0 * (1.0 + (P.text_scale - 1.0) * 0.7), vp.x * 0.62)
	_insp = Rect2(vp.x - m - iw, tk_bottom, iw, maxf(130.0, _seal.position.y - 16.0 - tk_bottom))
	_drawer = Rect2(m, rail_top, minf(340.0, vp.x - 2.0 * m), maxf(200.0, vp.y - bh - rail_top - 12.0))

func _chip_for(k: String) -> P.Chip:
	if k == "war": return _war
	if k == "inf": return _inf
	return _chips[k]

func _refresh_spark() -> void:
	var gc: P.Chip = _chips["gold"]
	gc.spark = []
	if g == null: return
	var ser: Array = TBStats.series(g, g.human_id, "g")
	for e in ser.slice(maxi(0, ser.size() - 14)): gc.spark.append(float(e[1]))
	if gc.spark.size() >= 2: gc.spark.append(float(g.gold[g.human_id]))
	else: gc.spark = []

## rectangle (hud coordinates) the turn button and its note occupy
func end_turn_rect() -> Rect2:
	if _seal == null: return Rect2()
	var r := _seal_rect()
	if _note != null and _note.visible: r = r.merge(Rect2(_note.position, _note.size))
	return r

## the dial's footprint with its scale applied
func _seal_rect() -> Rect2:
	var k: Vector2 = _seal.scale
	var piv: Vector2 = _seal.pivot_offset
	return Rect2(_seal.position + piv - piv * k, _seal.size * k)

## horizontal band the inspector may use (kept for the province panel)
func card_band() -> Vector2: return Vector2(_insp.position.x, _insp.end.x)

## where the inspector (province card) sits: right of the map, below the toasts, above the turn button (hud coordinates)
func inspector_rect() -> Rect2: return _insp
func _on_view_changed() -> void:
	if _minimap == null: return
	_minimap.queue_redraw()

## where drawers open: right of the rail, above the tuner
func drawer_rect() -> Rect2: return _drawer
## phones show the inspector as a bottom sheet; true there
func sheet_mode() -> bool: return _prof == Prof.PORTRAIT
## mid-width landscape (700-1099 px): drawer and inspector are mutually exclusive
func exclusive_panels() -> bool: return _vp.x < 1100.0
func foreign_enabled() -> bool: return false

## space the phone sheet keeps free at the bottom (tab bar + turn button + its label)
func bottom_reserve() -> float:
	if _prof != Prof.PORTRAIT: return 12.0
	return maxf(_bottom.size.y, _vp.y - end_turn_rect().position.y) + 16.0

func _place_legend() -> void:
	if _legend == null: return
	var show: bool = _prof == Prof.DESKTOP and _legend.has_key() and not _vp.x < 700.0
	_legend.visible = show
	if not show: return
	_legend.width = 220.0
	_legend.custom_minimum_size = Vector2(_legend.width, _legend.height_needed())
	_legend.size = _legend.custom_minimum_size
	var base_y: float = (_minimap.position.y if _minimap.visible else (_mode.position.y if _mode.visible else _vp.y - 16.0)) - 12.0
	_legend.position = Vector2(float(_L.get("m", 28.0)), base_y - _legend.size.y)
	_legend.queue_redraw()

func _place_strip() -> void:
	if _strip == null: return
	var hot: bool = _is_hot()
	_strip.visible = hot and _prof == Prof.DESKTOP
	if not _strip.visible: return
	var w: float = _strip.desired_w()
	_strip.size = Vector2(w, 24.0)
	_strip.position = Vector2(roundf((_vp.x - w) * 0.5), _ribbon_h + 8.0)
	_strip.queue_redraw()

## the layout depends on chip widths: a refresh that changes them re-flows
func _layout_bar() -> void:
	if _nat == null: return
	if _bar_sig() != _last_sig:
		layout_for(_vp)
		return
	_apply_dates()
	for c4 in [_nat, _date, _war, _inf]: (c4 as Control).queue_redraw()
	_sync_seal()

var _last_sig: String = ""
var _gauge_nat: int = -1
func _bar_sig() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k in ["gold", "man", "mp", "dp"]: parts.append(str((_chips[k] as P.Chip).desired_w()))
	parts.append(str(_wars > 0)); parts.append(str(_inf_on)); parts.append(_nat.nation); parts.append(_nat.subtitle); parts.append(_date.year + _date.turn_cap)
	parts.append(str(P.text_scale))
	for k2 in ["gold", "man", "mp", "dp"]: parts.append(str((_chips[k2] as P.Chip).desired_h()))
	return ",".join(parts)

## hud rectangles (global) the map labels must keep clear of
func keepouts() -> Array:
	var out: Array = []
	if not visible or _rail == null: return out
	out.append(_nat.get_global_rect())
	for k in ["gold", "man", "mp", "dp"]:
		if (_chips[k] as Control).visible: out.append((_chips[k] as Control).get_global_rect())
	for c in [_war, _inf, _more_chip, _date, _menu_btn]:
		if (c as Control).visible: out.append((c as Control).get_global_rect())
	for b in _dock + [_dock_more]:
		if (b as Control).visible and not _bottom.visible: out.append((b as Control).get_global_rect().grow(4.0))
	if _bottom.visible: out.append(_bottom.get_global_rect())
	var tr: Rect2 = _ticker.occupied_rect()
	if tr.size.x > 0.0: out.append(tr.grow(4.0))
	var sr: Rect2 = _seal_rect()
	out.append(Rect2(sr.position + global_position, sr.size).grow(6.0))
	if _note != null and _note.visible: out.append(_note.get_global_rect().grow(4.0))
	if _minimap.visible: out.append(_minimap.get_global_rect().grow(4.0))
	for c5 in [_zin, _zout, _lens_btn]:
		if (c5 as Control).visible: out.append((c5 as Control).get_global_rect().grow(4.0))
	if _mode.visible: out.append(_mode.get_global_rect().grow(4.0))
	if _legend.visible: out.append(_legend.get_global_rect().grow(4.0))
	if _strip.visible: out.append(_strip.get_global_rect().grow(4.0))
	return out

## vertical space the top row occupies
func ribbon_height() -> float: return _ribbon_h

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
	_pull_cfg()
	var n: int = g.human_id
	if n != _gauge_nat:                                   # another seat (hot-seat) or a new game: its numbers are not a change of ours, so no rising +/- figures
		_gauge_nat = n
		for ck in _chips: (_chips[ck] as P.Chip).forget()
		for c3 in [_war, _inf, _more_chip]: (c3 as P.Chip).forget()
	var inc: Dictionary = g.income(n)
	var bd: Dictionary = TBAdvisor.breakdown(g, n, inc)
	var fmt := func(v: float) -> String: return _fmt_num(v, true)
	_nat.flag = TBFlags.medal(g.nat_code[n], g.era_id)
	if _nat.flag == null: _nat.flag = TBFlags.texture(g.nat_code[n], g.color[n], g.era_id)
	_nat.nation = g.dname(n)
	_nat.rank_text = str(g.owned(n).size())
	var tag: String = _tag()
	_nat.seat = (g.humans().find(n)) if _is_hot() else -1
	_nat.seat_text = tag
	var net: int = bd["net"]
	var gc: P.Chip = _chips["gold"]
	gc.set_num(g.gold[n], fmt); gc.has_delta = true; gc.delta = net; gc.delta_on = true
	gc.frac = g.gold[n] / (g.gold[n] + 8.0 * maxf(1.0, absf(float(net))) + 100.0) if g.gold[n] > 0.0 else 0.0
	if _vp.x >= 1100.0: _refresh_spark()
	gc.state = 2 if (g.gold[n] <= 0.0 and net < 0) else (1 if (net < 0 and g.gold[n] < -net * 5.0) else 0)
	var mc: P.Chip = _chips["man"]
	mc.set_num(g.manpower[n], fmt); mc.has_delta = true; mc.delta = int(bd["man_gain"]); mc.state = 1 if bd["man_full"] else 0
	mc.sub_text = "%d%%" % int(round(100.0 * g.manpower[n] / maxf(1.0, float(bd["man_cap"]))))
	mc.frac = g.manpower[n] / maxf(1.0, float(bd["man_cap"]))
	_suffix["man"] = ""
	var pc: P.Chip = _chips["mp"]
	pc.set_num(floorf(g.mp[n]), fmt); pc.has_delta = true; pc.delta_on = true
	pc.suffix = "/%d" % int(bd["mp_cap"])
	pc.sub_text = "+%.1f" % float(bd["mp_gain"])
	pc.frac = g.mp[n] / maxf(1.0, float(bd["mp_cap"]))
	var dc: P.Chip = _chips["dp"]
	dc.set_num(floorf(g.dp[n]), fmt); dc.has_delta = true; dc.delta = int(round(float(bd["dp_gain"])))
	dc.frac = g.dp[n] / maxf(1.0, float(bd["dp_cap"]))
	_wars = 0
	for o in range(1, g.N1):
		if g.alive[o] != 0 and g.get_rel(n, o) == 1: _wars += 1
	_war.set_num(float(_wars), fmt); _war.glyph_col = P.tk("neg_bar"); _inf.glyph_col = P.tk("neg_bar")
	_inf_on = g.rules >= 1 and (g.infamy[n] >= 5.0 or g.coalition[n] != 0)
	_inf.set_num(floorf(g.infamy[n]), fmt); _inf.state = 2 if g.coalition[n] != 0 else 0
	_war.frac = clampf(float(_wars) / 4.0, 0.0, 1.0); _inf.frac = clampf(g.infamy[n] / 100.0, 0.0, 1.0)
	_nat.badge = 0
	_nat.subtitle = (T.call(TBRulers.title_key(g, n)) + " " + TBRulers.display_name(g, n)) if (g.rules >= 1 and g.r_name[n] != "") else T.call("era_name_%d" % g.era[n])
	_seal.turn_no = g.turn
	_seal.year_phase = float(g.month_idx + 6) / 12.0
	_date.year = _year(g.year)
	_date.turn_no = g.turn; _date.phase = float(g.month_idx + 6) / 12.0
	_date.turn_cap = T.call("aoc_turn", {"k": g.turn}).replace(":", "")
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
	_seal.attention = crit
	if _minimap != null and map_view != null:
		if _minimap.g != g or _minimap.map != map_view:
			_minimap.setup(g, map_view)
			if not map_view.view_changed.is_connected(_on_view_changed): map_view.view_changed.connect(_on_view_changed)
		_minimap.refresh()
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
		announce(tx, int(e["sev"]) >= 2)
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
## the player's settings dictionary (the parent scene's cfg), read defensively: {} when absent
func _cfg() -> Dictionary:
	var par: Node = get_parent()
	if par != null:
		var c: Variant = par.get("cfg")
		if c is Dictionary: return c
	return {}

## pull the settings the HUD honours from cfg (confirm mode, text-to-speech); missing keys keep the current value
func _pull_cfg() -> void:
	var c: Dictionary = _cfg()
	var cm: Variant = c.get("confirm_mode", null)
	if cm is String and (cm as String) in ["smart", "always", "never"]: confirm_mode = cm
	var t: Variant = c.get("tts", null)
	if t is bool: tts_mode = "all" if t else "off"
	elif t is String and (t as String) in ["off", "critical", "all"]: tts_mode = t

## speak a line with the OS text-to-speech when the player turned it on (cfg["tts"]; "critical" speaks only critical lines)
func announce(text: String, critical: bool = true) -> void:
	_pull_cfg()
	if tts_mode == "off" or text == "": return
	if tts_mode == "critical" and not critical: return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH): return
	DisplayServer.tts_speak(text, "", 80)

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
	announce(msg, bad)
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
## close the tooltip and the open popover (a modal is taking over the screen)
func dismiss_floating() -> void:
	_tip_hide(); _close_pop()

func _tip_hide() -> void:
	if _tip != null and is_instance_valid(_tip): _tip.queue_free()
	_tip = null

func _tip_show(anchor: Control, pair: Array) -> void:
	_tip_hide()
	if _pop != null or pair.size() < 2 or not is_instance_valid(anchor): return
	_tip = P.tip_box(String(pair[0]), String(pair[1]), 320.0, pair[2] if pair.size() > 2 else [], String(pair[3]) if pair.size() > 3 else "")
	_tip.z_index = 70
	add_child(_tip)
	_place_tip(_tip, anchor)

## showTip(): centred under the anchor 10 units below it, above it when it does not fit, kept 6 from the stage edges
func _place_tip(c: Control, anchor: Control) -> void:
	var sz: Vector2 = c.get_combined_minimum_size()
	c.size = sz
	var ar := Rect2(anchor.global_position - global_position, anchor.size * anchor.scale)
	if anchor is P.Hit: ar = Rect2(ar.position, ar.size)
	var x: float = ar.position.x + ar.size.x * 0.5 - sz.x * 0.5
	var y: float = ar.end.y + 10.0
	if y + sz.y > size.y - 6.0: y = ar.position.y - sz.y - 10.0
	if y < 4.0: y = 4.0
	x = maxf(6.0, minf(size.x - sz.x - 6.0, x))
	c.position = Vector2(x, y)

func _place_near(c: Control, anchor: Control) -> void:
	var sz: Vector2 = c.get_combined_minimum_size()
	c.size = sz
	var ar := Rect2(anchor.global_position - global_position, anchor.size)
	var pos := Vector2(ar.position.x, ar.end.y + 6.0)
	if pos.y + sz.y > size.y - 4.0 or ar.position.y > size.y * 0.55: pos.y = ar.position.y - sz.y - 6.0
	if ar.position.x > size.x * 0.6 and ar.size.y > 60.0: pos = Vector2(ar.position.x - sz.x - 6.0, ar.position.y)
	if _rail != null and _rail.visible and anchor.get_parent() == self and ar.position.x < _rail.size.x + 16.0 and ar.position.y > ribbon_height():
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
	var sg := func(v: float) -> String: return ("+" if v >= 0.0 else "−") + fmt.call(absf(v))
	match key:
		"gold":
			var ro: int = int(bd["runs_out"])
			var rows: Array = [[T.call("tkr_income"), sg.call(float(bd["gross"])), "pos"], [T.call("tkr_upkeep"), sg.call(-float(bd["upkeep"])), "neg"], [T.call("tkr_admin"), sg.call(-float(bd["admin"])), "neg"], [T.call("tkr_net"), sg.call(float(bd["net"])), "sum"]]
			return [T.call("hud_cap_gold"), T.call("tk_gold_1", {"v": fmt.call(float(bd["gold"]))}), rows, T.call("tk_gold_safe") if ro < 0 else (T.call("tk_gold_empty") if ro == 0 else T.call("tk_gold_out", {"k": ro}))]
		"man":
			var rows2: Array = [[T.call("tkr_men"), "%s / %s" % [fmt.call(float(bd["man"])), fmt.call(float(bd["man_cap"]))], ""], [T.call("tkr_growth"), "+%d" % int(bd["man_gain"]), "pos"], [T.call("tkr_recruit"), "%d g · %d" % [TBData.COST_RECRUIT_GOLD, TBData.COST_RECRUIT_MAN], ""]]
			return [T.call("hud_cap_man"), T.call("tk_man_1", {"v": fmt.call(float(bd["man"])), "c": fmt.call(float(bd["man_cap"]))}), rows2, T.call("tk_man_full") if bool(bd["man_full"]) else ""]
		"mp":
			var rows3: Array = [[T.call("tkr_moves"), "%d / %d" % [int(floorf(float(bd["mp"]))), int(bd["mp_cap"])], ""], [T.call("tkr_refill"), "+%.1f" % float(bd["mp_gain"]), "pos"], [T.call("tkr_move"), str(TBData.MP_MOVE), ""], [T.call("tkr_attack"), str(TBData.MP_ATTACK), ""], [T.call("tkr_recr"), str(TBData.MP_RECRUIT), ""]]
			return [T.call("hud_cap_mp"), T.call("tk_mp_1", {"v": int(floorf(float(bd["mp"]))), "c": int(bd["mp_cap"])}), rows3, ""]
		"dp":
			var rows4: Array = [[T.call("tkr_points"), "%d / %d" % [int(floorf(float(bd["dp"]))), int(bd["dp_cap"])], ""], [T.call("tkr_growth"), "+%.1f" % float(bd["dp_gain"]), "pos"], [T.call("tkr_pact"), str(TBData.DP_NAP), ""], [T.call("tkr_ally"), str(TBData.DP_ALLY), ""], [T.call("tkr_ult"), str(TBDiplo.DP_ULT), ""], [T.call("tkr_marry"), str(TBDiplo.DP_MARRY), ""]]
			return [T.call("hud_cap_dp"), T.call("tk_dp_1", {"v": int(floorf(float(bd["dp"]))), "c": int(bd["dp_cap"])}), rows4, ""]
		"wars":
			var names: PackedStringArray = PackedStringArray()
			for o in range(1, g.N1):
				if g.alive[o] != 0 and g.get_rel(n, o) == 1: names.append(g.dname(o))
			return [T.call("hud_wars"), T.call("tk_wars_with", {"l": ", ".join(names)}), [], ""]
		"infamy":
			var rows5: Array = [[T.call("tkr_infamy"), str(int(g.infamy[n])), "neg" if g.infamy[n] >= 12.0 else ""]]
			if g.coalition[n] != 0: rows5.append([T.call("tkr_coal"), T.call("tkr_yes"), "neg"])
			return [T.call("infamy"), T.call("tk_inf_1", {"v": int(g.infamy[n])}), rows5, ""]
	return ["", ""]

func _tip_chip(key: String) -> Array:
	if g == null: return []
	return _chip_text(key)

func _pin_chip(key: String) -> void:
	if g == null: return
	tapped.emit()
	var pair: Array = _chip_text(key)
	var box: PanelContainer = P.tip_box(String(pair[0]), String(pair[1]), 320.0, pair[2] if pair.size() > 2 else [], String(pair[3]) if pair.size() > 3 else "")
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
	if _minimap != null: _minimap.refresh()
	_lens_changed()
	_place_legend()
	_layout_bar()

func _lens_changed() -> void:
	if _mode != null:
		_mode.set_current(_lens if LENS_PINNED.has(_lens) else "")
		_mode.queue_redraw()
	if _lens_btn != null:
		_lens_btn.active = not LENS_PINNED.has(_lens); _lens_btn.queue_redraw()

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
	var tog := RowBtn.new(); tog.glyph = "dots"; tog.label = T.call("tk_more_lenses"); tog.custom_minimum_size = Vector2(0, P.touch())
	tog.pressed.connect(func(): more.visible = not more.visible; _lens_more = more.visible; pc.reset_size(); _place_near(pc, anchor))
	v.add_child(tog); v.add_child(more)
	if _legend.has_key() and _prof != Prof.DESKTOP:
		var lg := P.Legend.new(); lg.framed = false; lg.width = minf(260.0, _vp.x - 56.0); lg.setup(_lens); lg.visible = true; v.add_child(lg)
	_open_pop("lens", pc, anchor)

func _lens_row(lens: String, i: int) -> RowBtn:
	var r := RowBtn.new(); r.glyph = P.lens_glyph(lens); r.label = T.call("lens_" + lens); r.hint = ("Alt+%d" % (i + 1)) if (_prof == Prof.DESKTOP and i < 9) else ""
	r.active = lens == _lens; r.custom_minimum_size = Vector2(minf(196.0, (_vp.x - 56.0) * 0.5), P.touch()); r.set_a11y(r.label)
	r.pressed.connect(func(): tapped.emit(); _pick_lens(lens))
	return r

## every screen as a list (SHORT "menu" button, "More" on the rail and the portrait bottom bar); portrait adds the map lens
func _open_menu(anchor: Control, only_more: bool) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", P.bar_box(8, 8, 4, true))
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); pc.add_child(v)
	var rw: float = minf(240.0, _vp.x - 32.0)
	for i in SCREENS.size():
		if only_more and i < PRIMARY: continue
		var sc: Array = SCREENS[i]
		var r := RowBtn.new(); r.glyph = sc[1]; r.label = T.call(sc[2]); r.hint = sc[3]; r.custom_minimum_size = Vector2(rw, P.touch()); r.set_a11y(r.label)
		var sid: String = sc[0]
		r.pressed.connect(func(): _close_pop(); _screen(sid))
		if sid == "advisor": r.badge = (_dock[3] as P.IconBtn).badge
		v.add_child(r)
	if only_more and _prof == Prof.PORTRAIT:
		var lr := RowBtn.new(); lr.glyph = P.lens_glyph(_lens); lr.label = T.call("tk_lens"); lr.hint = T.call("lens_" + _lens)
		lr.custom_minimum_size = Vector2(rw, P.touch()); lr.set_a11y(lr.label)
		lr.pressed.connect(func(): tapped.emit(); _close_pop(); _open_lens_pop(anchor))
		v.add_child(lr)
	_open_pop("menu", pc, anchor)

# ================================================================== crest / nation
## the crest opens the player's nation card
func _open_realm() -> void:
	if g == null: return
	tapped.emit()
	nation_pressed.emit(g.human_id)

## kept API: nothing to close any more (the realm panel is gone)
func close_realm() -> bool: return false
func show_foreign(_o: int, _rows: Array) -> void: pass

## the "+N" chip: every resource figure that did not fit the bar, as one popover
func _open_more_chips() -> void:
	if g == null: return
	tapped.emit()
	var lines: PackedStringArray = PackedStringArray()
	for k in ["gold", "man", "mp", "dp"]:
		if (_chips[k] as Control).visible or (k == "dp" and g.rules < 1): continue
		var pair: Array = _chip_text(k)
		lines.append("%s: %s" % [String(pair[0]), String(pair[1]).split("\n")[0]])
	if _war.visible == false and _wars > 0: lines.append(_chip_text("wars")[0] + ": %d" % _wars)
	if _inf.visible == false and _inf_on: lines.append(_chip_text("infamy")[0] + ": %d" % int(g.infamy[g.human_id]))
	var box: PanelContainer = P.tip_box(T.call("tk_more"), "\n".join(lines))
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	_open_pop("chip", box, _more_chip)

## "Round 4 · P1/2": the hot-seat round and this seat (realm sheet, End Turn summary)
func _round_text() -> String:
	var hs: PackedInt32Array = g.humans()
	return T.call("tk_round_seat", {"k": g.turn, "p": hs.find(g.human_id) + 1, "n": hs.size()})

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
		row.set_width(minf(300.0, _vp.x - 40.0)); row.custom_minimum_size = Vector2(minf(300.0, _vp.x - 40.0), row.base_h())
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
	var date_hidden: bool = _prof == Prof.PORTRAIT
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
		_seal.sub = _round_text() + " · " + lead + _moves_text()
	else:
		_seal.set_state(S.IDLE)
		_seal.caption = T.call("end_turn"); _seal.sub = lead.trim_suffix(" · ")          # the moves figure lives in the top bar; the seal stays quiet
	_seal.set_a11y("%s. %s" % [_seal.caption, _seal.sub])
	_seal.caption_inside = _seal.fits_inside(_seal.caption)
	_seal.sub_inside = _seal.caption_inside and _seal._one_line() and _seal.sub_fits(_seal.sub)
	_seal.queue_redraw()
	_place_note()
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

## the summary chip above the seal: the sub-line, and the caption too when it does not fit the disc (never truncated, it wraps)
func _place_note() -> void:
	if _note == null or _seal == null: return
	var old: Rect2 = end_turn_rect()
	_note.head = "" if _seal.caption_inside else _seal.caption
	if _seal.state == P.Seal.S.OVER: _note.head = _seal.caption
	_note.body = "" if _seal.sub_inside else _seal.sub
	_note.visible = not _note.is_empty()
	if _note.visible:
		var sz: Vector2 = _note.measure(minf(240.0, _vp.x * 0.62))
		_note.size = sz
		_note.position = Vector2(_seal.position.x + _seal.size.x - sz.x, _seal.position.y - 6.0 - sz.y)
		_note.queue_redraw()
	if end_turn_rect() != old: layout_changed.emit()

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
		elif close_realm(): get_viewport().set_input_as_handled()
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
					KEY_L: _open_lens_pop(_mode if _mode.visible else _nat); handled = true
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
	if win: res = T.call("pv_win", {"k": int(info.get("hold", 0)), "l": int(info.get("lost", 0))})
	else: res = T.call("pv_lose", {"a": int(info.get("lost", 0)), "d": int(info["enemy_lost"])})
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
	_preview.position = Vector2(clampf((_vp.x - sz.x) * 0.5, 8.0, _vp.x - sz.x - 8.0), clampf(_vp.y * 0.3, ribbon_height() + 40.0, _vp.y - sz.y - 120.0))

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
		custom_minimum_size = Vector2(150, P.touch())
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
