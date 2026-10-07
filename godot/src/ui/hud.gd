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
var _date_bar: P.Surface                      # the slanted date plate (top right)
var _tab_dip: P.Tab                           # Diplomacy tab (opens the nations screen)
var _tab_maps: P.Tab                          # Map Modes tab (opens the lens list)
var _annals_btn: P.IconBtn                    # left slot of the date plate: the Annals
var _chips: Dictionary = {}
var _suffix: Dictionary = {}
var _war: P.Chip
var _inf: P.Chip
var _lens_btns: Array = []
var _menu_btn: P.IconBtn
var _dots_btn: P.IconBtn
var _dock: Array = []
var _dock_more: P.IconBtn
var _ticker: TBAlertTicker
var _seal: P.Seal
var _note: P.SealNote                         # the End Turn summary chip above the seal
var _rows: int = 1                            # top bar rows (2 when the chips no longer fit one row)
var _rail_mode: bool = false                  # the screens rail is shown (else the menu button / bottom bar)
var _rail_w: float = 0.0
var _comp: Dictionary = {}
var _legend: P.Legend
var _strip: P.SeatStrip
var map_view: TBMapView                      # the main map (the minimap shows and steers it)
var _minimap: TBMinimap
var _stats: P.StatsColumn
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
	P.sync_settings(); TBCmdCard.text_scale = P.text_scale
	for c in get_children(): c.queue_free()
	_chips.clear(); _suffix.clear(); _lens_btns.clear(); _dock.clear()
	_pop = null; _catcher = null; _tip = null; _preview = null; _active = ""
	_bar = P.Surface.new(); _bar.kind = "bar"; add_child(_bar)
	_nat = P.NationChip.new(); _nat.set_a11y(T.call("tk_realm")); _wire(_nat, _tip_nation); _nat.pressed.connect(_open_realm); add_child(_nat)
	_date = P.DateText.new(); add_child(_date)
	for spec in [["gold", "coin", "gold"], ["mp", "arrowhead", "mp"], ["man", "men", "manpower"], ["dp", "dove", "dp"]]:
		var c := P.Chip.new(); c.glyph = spec[1]; c.set_a11y(T.call(spec[2]))
		if spec[0] == "gold": c.val_col = P.tk("brass_lt")
		if spec[0] == "mp": c.glyph_col = P.tk("info")
		if spec[0] == "dp": c.glyph_col = P.tk("cream")
		if spec[0] == "man": c.glyph_col = P.tk("smoke")
		var key: String = spec[0]
		_wire(c, _tip_chip.bind(key)); c.pressed.connect(_pin_chip.bind(key))
		add_child(c); _chips[key] = c
	_war = P.Chip.new(); _war.glyph = "swords"; _war.set_a11y(T.call("hud_wars")); _wire(_war, _tip_chip.bind("wars")); _war.pressed.connect(func(): tapped.emit(); wars_pressed.emit()); add_child(_war)
	_inf = P.Chip.new(); _inf.glyph = "skull"; _inf.set_a11y(T.call("infamy")); _wire(_inf, _tip_chip.bind("infamy")); _inf.pressed.connect(_pin_chip.bind("infamy")); add_child(_inf)
	for lens in LENS_PINNED:
		var b := P.IconBtn.new(); b.glyph = P.lens_glyph(lens); b.sq = 40.0; b.icon_px = 20.0; b.show_label = false; b.edge = 1
		b.set_a11y(T.call("lens_" + lens))
		b.pressed.connect(func(): tapped.emit(); _pick_lens(lens))
		_wire(b, _tip_lens.bind(lens))
		b.set_meta("lens", lens)
		add_child(b); _lens_btns.append(b)
	var more_l := P.IconBtn.new(); more_l.glyph = "dots"; more_l.sq = 40.0; more_l.icon_px = 20.0; more_l.show_label = false; more_l.edge = 1
	more_l.set_a11y(T.call("tk_more_lenses")); more_l.pressed.connect(func(): tapped.emit(); _open_lens_pop(more_l)); _wire(more_l, _tip_text.bind(T.call("tk_more_lenses"), "L"))
	more_l.set_meta("lens", "")
	add_child(more_l); _lens_btns.append(more_l)
	_tab_dip = P.Tab.new(); _tab_dip.label = T.call("aoc_diplomacy"); _tab_dip.set_a11y(T.call("aoc_diplomacy")); _tab_dip.pressed.connect(func(): tapped.emit(); _screen("nations")); _wire(_tab_dip, _tip_text.bind(T.call("dk_nations"), "F1")); add_child(_tab_dip)
	_tab_maps = P.Tab.new(); _tab_maps.label = T.call("aoc_map_modes"); _tab_maps.set_a11y(T.call("tk_lens")); _tab_maps.pressed.connect(func(): tapped.emit(); _open_lens_pop(_tab_maps)); _wire(_tab_maps, _tip_text.bind(T.call("tk_lens"), "L")); add_child(_tab_maps)
	_date_bar = P.Surface.new(); _date_bar.kind = "date"; add_child(_date_bar); move_child(_date_bar, 1)
	_annals_btn = P.IconBtn.new(); _annals_btn.glyph = "book"; _annals_btn.show_label = false; _annals_btn.set_a11y(T.call("dk_chronicle")); _annals_btn.pressed.connect(func(): tapped.emit(); _screen("chronicle")); _wire(_annals_btn, _tip_text.bind(T.call("dk_chronicle"), "F5")); add_child(_annals_btn)
	_menu_btn = P.IconBtn.new(); _menu_btn.glyph = "menu"; _menu_btn.sq = 40.0; _menu_btn.icon_px = 20.0; _menu_btn.show_label = false; _menu_btn.edge = 1
	_menu_btn.set_a11y(T.call("tk_menu")); _menu_btn.pressed.connect(func(): tapped.emit(); _open_menu(_menu_btn, false)); add_child(_menu_btn)
	_dots_btn = P.IconBtn.new(); _dots_btn.glyph = "dots"; _dots_btn.sq = 40.0; _dots_btn.icon_px = 22.0; _dots_btn.show_label = false; _dots_btn.edge = 1
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
	# ---- ticker, legend, hot-seat strip, End Turn plate
	_ticker = TBAlertTicker.new()
	_ticker.activated.connect(_on_alert); _ticker.answered.connect(func(uid: int, c: int): tapped.emit(); offer_answered.emit(uid, c))
	_ticker.overflow_pressed.connect(_open_drawer); _ticker.report_pressed.connect(func(): tapped.emit(); chronicle_pressed.emit())
	_ticker.tip_requested.connect(_tip_show); _ticker.tip_hidden.connect(_tip_hide)
	add_child(_ticker)
	_legend = P.Legend.new(); add_child(_legend)
	_strip = P.SeatStrip.new(); _strip.visible = false; add_child(_strip)
	_minimap = TBMinimap.new(); add_child(_minimap)
	_stats = P.StatsColumn.new(); _stats.heading = T.call("aoc_stats"); _stats.set_a11y(T.call("aoc_stats")); _stats.pressed.connect(func(): tapped.emit(); _screen("nations")); add_child(_stats)
	_note = P.SealNote.new(); _note.visible = false; add_child(_note)
	_seal = P.Seal.new(); _seal.set_a11y(T.call("end_turn")); _seal.pressed.connect(_seal_pressed); add_child(_seal)
	_wire(_seal, _tip_seal)
	_lens_changed()
	layout_for(size if size.x > 1.0 else get_viewport_rect().size)

## player text scale (1.0 / 1.25 / 1.5 / 1.75): every HUD font goes through TBHudParts.fs(); rebuilds the HUD
func set_text_scale(f: float) -> void:
	P.text_scale = clampf(f, 1.0, 2.0)
	TBCmdCard.text_scale = P.text_scale
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

## top bar height: one row, or two rows (row 1 identity + controls, row 2 the resource chips) when the chips no longer fit one row
func _bar_h() -> float:
	var base: float = [40.0, 36.0, 32.0, 40.0][_prof]
	var one: float = maxf(base, _chip_h() + (6.0 if _prof == Prof.SHORT else 8.0))
	return one if _rows == 1 else _chip_h() * 2.0 + 14.0

func _row_pitch() -> float:
	return maxf(P.touch(), P.fs(12.0) + 10.0 + _sq())
func _sq() -> float: return 40.0 if _prof == Prof.DESKTOP else 36.0
func _show_labels() -> bool: return TBKit.large_targets or TBKit.text_scale >= 1.5          # icon-only dock unless the player asked for bigger UI

## the layout profile for a logical viewport (design/ux/hud.md 3.1)
static func profile_for(vp: Vector2) -> int:
	if vp.y > vp.x: return Prof.PORTRAIT
	if vp.y < 380.0: return Prof.SHORT
	if vp.y < 560.0: return Prof.PHONE_L
	return Prof.DESKTOP

## the screens rail fits below the bar (it turns into the single menu button at large text sizes, hud.md 10.2)
func _rail_fits(bh: float) -> bool:
	if _prof != Prof.DESKTOP and _prof != Prof.PHONE_L: return false
	return bh + (8.0 if _prof == Prof.DESKTOP else 6.0) + _row_pitch() * 5.0 + 8.0 <= _vp.y - 8.0

## Age-of-Civilizations layout. Everything is designed in 1080p pixels ("R" units) and scaled by u (window height, text scale included):
## flag block top-left, a slanted stat strip (gold / moves / army / diplomacy) with the Diplomacy and Map Modes tabs, the date plate top-right,
## the End Turn plate bottom-right. The rail / bottom dock of the old HUD no longer exist (their screens live in the realm panel).
func layout_for(vp: Vector2) -> void:
	if _bar == null: return
	P.sync_settings(); TBCmdCard.text_scale = P.text_scale
	var old: int = _prof
	_vp = vp
	_prof = profile_for(vp)
	_tip_hide(); _close_pop()
	P.u = clampf(minf(vp.y / 1080.0, vp.x / 1500.0), 0.6, 1.5) * P.text_scale
	var u: float = P.u
	var m: float = P.R(8.0)
	var portrait: bool = _prof == Prof.PORTRAIT
	_rail_mode = false; _rail_w = 0.0
	_rail.visible = false; _bottom.visible = false
	for b in _dock + [_dock_more, _dots_btn]: (b as Control).visible = false
	for b in _lens_btns: (b as Control).visible = false
	# ---- flag block
	var fw: float = P.R(148.0)
	var th: float = P.R(55.0)
	# ---- date plate (right): annals | date | menu. Narrow windows drop the annals button and shrink the flag block
	var bs: float = th - P.R(8.0)
	var dw: float = P.R(285.0) if _vp.x > 900.0 else P.R(235.0)
	var wide_date: bool = true
	var min_date: float = _date.desired_w() + bs + P.R(30.0)
	var gold_w: float = (_chips["gold"] as P.Chip).desired_w()
	if vp.x - dw - fw - gold_w - P.R(20.0) < 0.0:
		wide_date = false
		dw = maxf(min_date, P.R(130.0))
	if vp.x - dw - fw - gold_w - P.R(20.0) < 0.0: fw = P.R(100.0)
	_nat.position = Vector2.ZERO; _nat.size = Vector2(fw, P.R(100.0) * (fw / P.R(148.0))); _nat.visible = true
	_date_bar.position = Vector2(vp.x - dw, 0); _date_bar.size = Vector2(dw, th); _date_bar.visible = true
	var sl: float = P.R(18.0)
	_annals_btn.sq = bs; _annals_btn.icon_px = P.R(26.0); _annals_btn.show_label = false; _annals_btn.edge = 0
	_annals_btn.position = Vector2(vp.x - dw + sl + P.R(2.0), P.R(4.0)); _annals_btn.size = Vector2(bs, bs); _annals_btn.visible = wide_date
	_menu_btn.sq = bs; _menu_btn.icon_px = P.R(26.0); _menu_btn.show_label = false; _menu_btn.edge = 0
	_menu_btn.position = Vector2(vp.x - bs - P.R(6.0), P.R(4.0)); _menu_btn.size = Vector2(bs, bs); _menu_btn.visible = true
	_date.compact = _prof != Prof.DESKTOP
	var dx0: float = _annals_btn.position.x + bs if wide_date else vp.x - dw + sl
	_date.position = Vector2(dx0, 0); _date.size = Vector2(_menu_btn.position.x - dx0, th); _date.visible = true
	# ---- strip: cells by priority, then tabs; a cell that does not fit drops (dove, army, moves) and a second row takes the tabs on narrow windows
	var x0: float = fw - P.R(2.0)
	var avail: float = vp.x - dw - P.R(10.0) - x0
	var keys: Array = ["gold", "mp", "man", "dp"]
	if g == null or g.rules < 1: keys.erase("dp")
	var tabs_w: float = _tab_dip.desired_w() + _tab_maps.desired_w()
	var cell_gap: float = P.R(6.0)
	var cells_w: float = 0.0
	for k in keys: cells_w += (_chips[k] as P.Chip).desired_w() + cell_gap
	var two_rows: bool = false
	var shown: Array = keys.duplicate()
	while shown.size() > 1 and P.R(12.0) + _sum_w(shown, cell_gap) + tabs_w + sl > avail:
		if portrait or avail < P.R(560.0):                          # tabs wrap to their own strip under the first
			two_rows = true
			if P.R(12.0) + _sum_w(shown, cell_gap) + sl <= avail: break
		shown.pop_back()
	var strip_end: float = x0 + P.R(12.0) + _sum_w(shown, cell_gap) + (0.0 if two_rows else tabs_w) + sl
	_bar.position = Vector2(x0, 0); _bar.size = Vector2(strip_end - x0, th); _bar.visible = true
	var cx: float = x0 + P.R(10.0)
	for k in _chips.keys(): (_chips[k] as Control).visible = false
	for k in shown:
		var c: P.Chip = _chips[k]
		c.compact = false; c.tight = false; c.delta_on = true
		c.position = Vector2(cx, P.R(4.0)); c.size = Vector2(c.desired_w(), th - P.R(8.0)); c.visible = true
		cx += c.size.x + cell_gap
	if not two_rows:
		cx += P.R(6.0)
		_tab_dip.position = Vector2(cx, 0); _tab_dip.size = Vector2(_tab_dip.desired_w(), th); cx += _tab_dip.size.x
		_tab_maps.position = Vector2(cx, 0); _tab_maps.size = Vector2(_tab_maps.desired_w(), th)
	else:
		var x1: float = x0 + P.R(10.0)
		_tab_dip.position = Vector2(x1, th + 2.0); _tab_dip.size = Vector2(_tab_dip.desired_w(), P.R(40.0)); x1 += _tab_dip.size.x
		_tab_maps.position = Vector2(x1, th + 2.0); _tab_maps.size = Vector2(_tab_maps.desired_w(), P.R(40.0))
	_tab_dip.visible = true; _tab_maps.visible = true
	_rows = 2 if two_rows else 1
	_strip_rows_h = th + (P.R(42.0) if two_rows else 0.0)
	# ---- status boxes (wars / infamy) under the strip
	var sy: float = _strip_rows_h + P.R(7.0)
	var sx: float = x0 + P.R(2.0)
	for c2 in [_war, _inf]:
		var ch: P.Chip = c2
		var on: bool = (ch == _war and _wars > 0) or (ch == _inf and _inf_on)
		ch.visible = on
		if not on: continue
		ch.delta_on = false; ch.compact = false
		ch.position = Vector2(sx, sy); ch.size = Vector2(ch.desired_w(), P.R(40.0))
		sx += ch.size.x + P.R(6.0)
	_place_realm()
	# ---- ticker (alerts) under the flag block / realm panel
	var tx: float = m
	var ty: float = maxf(P.R(100.0), sy + P.R(44.0)) + P.R(6.0)
	if _realm_panel != null and _realm_panel.visible: tx = _realm_panel.position.x + _realm_panel.size.x + m
	_ticker.max_rows = 4 if _prof == Prof.DESKTOP else 1
	_ticker.inline_pill = _prof != Prof.DESKTOP
	_ticker.row_w = clampf(vp.x - tx - m, 150.0, 300.0) if portrait else (280.0 if _prof == Prof.DESKTOP else 240.0)
	_ticker.position = Vector2(tx, ty)
	_ticker._layout()
	# ---- Next Turn plate, bottom-right
	_seal.compact = _prof == Prof.SHORT or portrait
	_seal.narrow = false
	var sw_: float = _seal.width_px()
	var sh_: float = _seal.diameter()
	_seal.size = Vector2(sw_, sh_)
	_seal.position = Vector2(vp.x - m - sw_, vp.y - m - sh_)
	# ---- minimap, bottom-left (kept only where the information bar still has its room next to it)
	_minimap_ok = not portrait and vp.x >= P.R(300.0) + 380.0 + sw_ + 40.0
	_minimap.size = Vector2(P.R(297.0), P.R(145.0)); _minimap.position = Vector2(0, vp.y - _minimap.size.y); _minimap.visible = _minimap_ok and not (_realm_panel != null and _realm_panel.visible)
	# ---- stats column (right) and legend
	var show_stats: bool = not portrait and vp.y >= 420.0 and vp.x >= 900.0
	_stats.visible = show_stats
	if show_stats:
		var sw2: float = P.R(150.0)
		_stats.size = Vector2(sw2, _stats.desired_h())
		_stats.position = Vector2(vp.x - sw2, th + P.R(16.0))
	# ---- legend (top right under the date plate), seat strip
	_legend.framed = true
	_place_legend()
	_place_strip()
	_last_sig = _bar_sig()
	if _prof != old: refresh()
	else: _layout_bar()
	_sync_seal()
	layout_changed.emit()

var _strip_rows_h: float = 40.0
var _minimap_ok: bool = true
var _realm_panel: Control                    # TBRealmPanel (left)

func _sum_w(keys: Array, gap: float) -> float:
	var w: float = 0.0
	for k in keys: w += (_chips[k] as P.Chip).desired_w() + gap
	return w

## rectangle (hud coordinates) the End Turn seal and its summary chip occupy: the command card keeps clear of it
func end_turn_rect() -> Rect2:
	if _seal == null: return Rect2()
	var r := Rect2(_seal.position, _seal.size)
	if _note != null and _note.visible: r = r.merge(Rect2(_note.position, _note.size))
	return r

## horizontal band (x0, x1; hud coordinates) the command card may use: right of the minimap, left of the End Turn plate
func card_band() -> Vector2:
	var x0: float = P.R(300.0) if (_prof != Prof.PORTRAIT and _minimap_ok) else P.R(8.0)
	if _realm_panel != null and _realm_panel.visible and _prof != Prof.PORTRAIT: x0 = _realm_panel.position.x + _realm_panel.size.x + P.R(3.0)
	var x1: float = _vp.x - P.R(8.0)
	if _prof != Prof.PORTRAIT: x1 = end_turn_rect().position.x - maxf(17.0, P.R(10.0))
	return Vector2(x0, maxf(x0 + 200.0, x1))

## space the portrait sheet keeps free at the bottom (the Next Turn plate and its summary chip)
func bottom_reserve() -> float:
	if _prof != Prof.PORTRAIT: return 12.0
	return maxf(0.0, _vp.y - end_turn_rect().position.y) + 18.0

func _place_legend() -> void:
	if _legend == null: return
	var show: bool = _prof == Prof.DESKTOP and _legend.has_key()
	_legend.visible = show
	if not show: return
	_legend.width = 214.0 if _legend.ramp.size() > 0 else 252.0
	_legend.custom_minimum_size = Vector2(_legend.width, _legend.height_needed())
	_legend.size = _legend.custom_minimum_size
	_legend.position = Vector2(_vp.x - 8.0 - _legend.size.x - (P.R(150.0) if _stats != null and _stats.visible else 0.0), ribbon_height() + 8.0)
	_legend.queue_redraw()

func _place_strip() -> void:
	if _strip == null: return
	var hot: bool = _is_hot()
	_strip.visible = hot and _prof == Prof.DESKTOP
	if not _strip.visible: return
	var w: float = _strip.desired_w()
	_strip.size = Vector2(w, 24.0)
	_strip.position = Vector2((_vp.x - w) * 0.5, ribbon_height() + 6.0)
	_strip.queue_redraw()

## the strip plan is fixed by layout_for(); a refresh only re-flows (a chip width can change with its number)
func _layout_bar() -> void:
	if _nat == null: return
	if _bar_sig() != _last_sig:
		layout_for(_vp)
		return
	_apply_dates()
	for c4 in [_nat, _date, _war, _inf, _tab_maps, _tab_dip]: (c4 as Control).queue_redraw()
	_sync_seal()

var _last_sig: String = ""
## signature of everything the strip layout depends on (chip widths, which status boxes show)
func _bar_sig() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for k in ["gold", "mp", "man", "dp"]: parts.append(str((_chips[k] as P.Chip).desired_w()))
	parts.append(str(_wars > 0)); parts.append(str(_inf_on))
	parts.append(str(snappedf(P.u, 0.001)))
	var sg: String = ",".join(parts)
	return sg

## hud rectangles (global) the map labels must keep clear of
func keepouts() -> Array:
	var out: Array = []
	if not visible or _bar == null: return out
	out.append(_nat.get_global_rect())
	out.append(_bar.get_global_rect())
	out.append(_date_bar.get_global_rect())
	if _rows == 2: out.append(Rect2(_tab_dip.get_global_rect().position, Vector2(_tab_dip.size.x + _tab_maps.size.x, _tab_dip.size.y)))
	for c in [_war, _inf]:
		if (c as Control).visible: out.append((c as Control).get_global_rect().grow(4.0))
	var tr: Rect2 = _ticker.occupied_rect()
	if tr.size.x > 0.0: out.append(tr.grow(4.0))
	out.append(_seal.get_global_rect().grow(10.0))
	if _minimap != null and _minimap.visible: out.append(_minimap.get_global_rect())
	if _stats != null and _stats.visible: out.append(_stats.get_global_rect())
	if _note != null and _note.visible: out.append(_note.get_global_rect().grow(4.0))
	if _legend.visible: out.append(_legend.get_global_rect().grow(4.0))
	if _strip.visible: out.append(_strip.get_global_rect().grow(4.0))
	if _realm_panel != null and _realm_panel.visible: out.append(_realm_panel.get_global_rect().grow(4.0))
	return out

## vertical space the top strip occupies
func ribbon_height() -> float:
	return _strip_rows_h if _bar != null else 40.0

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
	var inc: Dictionary = g.income(n)
	var bd: Dictionary = TBAdvisor.breakdown(g, n, inc)
	var fmt := func(v: float) -> String: return _fmt_num(v, true)
	_nat.flag = TBFlags.texture(g.nat_code[n], g.color[n])
	_nat.nation = g.dname(n)
	_nat.rank_text = str(g.owned(n).size())
	var tag: String = _tag()
	_nat.seat = (g.humans().find(n)) if _is_hot() else -1
	_nat.seat_text = tag
	var net: int = bd["net"]
	var gc: P.Chip = _chips["gold"]
	gc.set_num(g.gold[n], fmt); gc.has_delta = true; gc.delta = net; gc.delta_on = true
	gc.state = 2 if (g.gold[n] <= 0.0 and net < 0) else (1 if (net < 0 and g.gold[n] < -net * 5.0) else 0)
	var mc: P.Chip = _chips["man"]
	mc.set_num(g.manpower[n], fmt); mc.has_delta = true; mc.delta = int(bd["man_gain"]); mc.state = 1 if bd["man_full"] else 0
	mc.sub_text = "%d%%" % int(round(100.0 * g.manpower[n] / maxf(1.0, float(bd["man_cap"]))))
	_suffix["man"] = ""
	var pc: P.Chip = _chips["mp"]
	pc.set_num(floorf(g.mp[n]), fmt); pc.has_delta = true; pc.delta_on = true
	pc.suffix = "/%d" % int(bd["mp_cap"])
	pc.sub_text = "+%.1f" % float(bd["mp_gain"])
	var dc: P.Chip = _chips["dp"]
	dc.set_num(floorf(g.dp[n]), fmt); dc.has_delta = true; dc.delta = int(round(float(bd["dp_gain"])))
	_wars = 0
	for o in range(1, g.N1):
		if g.alive[o] != 0 and g.get_rel(n, o) == 1: _wars += 1
	_war.set_num(float(_wars), fmt); _war.glyph_col = P.tk("neg_bar"); _inf.glyph_col = P.tk("neg_bar")
	_inf_on = g.rules >= 1 and (g.infamy[n] >= 5.0 or g.coalition[n] != 0)
	_inf.set_num(floorf(g.infamy[n]), fmt); _inf.state = 2 if g.coalition[n] != 0 else 0
	_nat.badge = 0
	if _stats != null:
		var st_sum: int = 0
		var own_l: PackedInt32Array = g.owned(n)
		for q in own_l: st_sum += g.stab[q]
		var st_avg: int = int(round(float(st_sum) / maxf(1.0, float(own_l.size()))))
		_stats.flag = _nat.flag
		_stats.rows = [["flask", "%.1f" % g.tech_level[n], "info"], ["men", _fmt_num(float(inc.get("pop", 0)), true), "pos_bar"], ["flag", str(own_l.size()), "brass_lt"], ["scales", "%d%%" % st_avg, "cream"], ["smile", "%d%%" % int(inc.get("happyAvg", 60)), "warn_bar"]]
		if g.rules >= 1: _stats.rows.append(["skull", str(int(g.infamy[n])), "neg_bar"])
		_stats.size.y = _stats.desired_h(); _stats.queue_redraw()
	_date.year = _year(g.year)
	_date.turn_cap = T.call("aoc_turn", {"k": g.turn})
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
			if not map_view.view_changed.is_connected(_minimap.queue_redraw): map_view.view_changed.connect(_minimap.queue_redraw)
		_minimap.refresh()
	if _realm_panel != null and _realm_panel.visible: (_realm_panel as TBRealmPanel).rebuild()
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
	if _minimap != null: _minimap.refresh()
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
	if _tab_maps != null:
		_tab_maps.glyph = "" if _lens == "political" else P.lens_glyph(_lens); _tab_maps.active = _lens != "political"; _tab_maps.queue_redraw()

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

# ================================================================== realm sheet
func _open_realm() -> void:
	if g == null: return
	tapped.emit()
	if _realm_panel != null and _realm_panel.visible:
		close_realm(); return
	if _realm_panel == null:
		_realm_panel = TBRealmPanel.new()
		_realm_panel.action.connect(_realm_action)
		_realm_panel.nation_pressed.connect(func(o: int): nation_pressed.emit(o))
		add_child(_realm_panel)
	(_realm_panel as TBRealmPanel).g = g
	(_realm_panel as TBRealmPanel).rebuild()
	_realm_panel.visible = true
	layout_for(_vp)

## close the realm panel; true when it was open (the back stack uses this)
func close_realm() -> bool:
	if _realm_panel == null or not _realm_panel.visible: return false
	_realm_panel.visible = false
	layout_for(_vp)
	return true

func _realm_action(id: String) -> void:
	if id == "nation":
		tapped.emit(); nation_pressed.emit(g.human_id); return
	close_realm()
	_screen(id)

func _place_realm() -> void:
	if _realm_panel == null: return
	var top: float = P.R(100.0)
	_realm_panel.position = Vector2(0, top)
	_realm_panel.size = Vector2(minf(P.R(345.0), _vp.x * 0.62), maxf(120.0, _vp.y - top))

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
					KEY_L: _open_lens_pop(_tab_maps); handled = true
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
