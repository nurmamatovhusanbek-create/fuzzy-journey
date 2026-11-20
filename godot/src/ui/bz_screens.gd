## Council, Goals and Annals as the Bezel demo draws them (b_demo.html: councilBody, goalsBody, annalsBody): the pieces the three screens are built from.
class_name TBBzScreens
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

## "Jan 1804": the month and year a turn began (a turn is half a year)
static func date_str(g: TBGame, turn: int) -> String:
	var m: int = g.start_month + turn * 6
	var y: int = g.start_year + m / 12
	return "%s %s" % [T.call("mo_%d" % (m % 12)), ("%d BC" % -y) if y < 0 else str(y)]

## a chronicle entry's headline and icon, from its kind
static func chron_kind(kind: String) -> Array:
	match kind:
		"war", "occupied", "annexed", "liberated", "call_refused", "ceded", "eliminated", "independence", "ultimatum", "rebels", "reconciled", "rebels_end", "victory", "defeat": return ["war", "an_war"]
		"peace", "ally", "vassal", "coalition", "coalition_end", "marriage", "marriage_end", "union", "spy": return ["pact", "an_dip"]
		"trade": return ["trade", "an_dip"]
		"formed", "estate_courted", "reform": return ["crown", "an_gov"]
		"inst_born", "inst_embraced": return ["lamp", "an_prog"]
		"bankrupt", "decision", "doctrine": return ["treasury", "an_econ"]
		"era": return ["star", "an_age"]
		"ruler", "realm": return ["crown", "an_crown"]
	return ["info", "an_event"]

## one timeline entry: a 30 unit medal hanging off the left rule, the date in brass caps, the headline in Cinzel, the line in Alegreya.
class TimelineItem extends MarginContainer:
	var icon := "info"
	var click: Callable = Callable()
	func _init(ic: String, date: String, head: String, body: String, cb: Callable = Callable()) -> void:
		icon = ic; click = cb
		add_theme_constant_override("margin_top", 3); add_theme_constant_override("margin_bottom", 16)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); v.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(v)
		var c := K.caps(date, 10, TBTokens.c("brass")); (c as TBBz.TLabel).px = 10.5; (c as TBBz.TLabel).refit(); v.add_child(c)
		var t := K.title(head, 15, Color.TRANSPARENT, 0.08, 14.5 * 1.2); (t as TBBz.TLabel).px = 14.5; (t as TBBz.TLabel).lh = 0.0; (t as TBBz.TLabel).refit()
		var tm := MarginContainer.new(); tm.add_theme_constant_override("margin_top", 2); tm.add_theme_constant_override("margin_bottom", 2); tm.mouse_filter = Control.MOUSE_FILTER_IGNORE; tm.add_child(t); v.add_child(tm)
		v.add_child(K.para_bz(body, 16.0, 1.3))
		if cb.is_valid():
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		else: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _gui_input(e: InputEvent) -> void:
		if click.is_valid() and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			click.call(); accept_event()
	func _draw() -> void:
		var c := Vector2(-42.0 + 15.0, 1.0 + 15.0)
		draw_circle(c, 15.0, TBTokens.BZ_FACE)
		draw_arc(c, 15.75, 0.0, TAU, 40, TBTokens.c("brass"), 1.5, true)
		TBBzIcons.draw(self, icon, c, 16.0, TBTokens.c("brass_lt"))

## the rule down the left of the timeline: minor ticks every 8 units on its left half, a 1 unit lo line
class TimelineHolder extends MarginContainer:
	func _init() -> void:
		add_theme_constant_override("margin_left", 42); size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		if size.y < 14.0: return
		var y := 6.0
		while y < size.y - 6.0:
			draw_rect(Rect2(14, y, 5, 1), TBTokens.c("rule")); y += 8.0
		draw_rect(Rect2(23, 6, 1, size.y - 12.0), TBTokens.c("rule"))

## a minister: a 50 unit ring with the icon, the name (Cinzel 14.5), the role in brass caps, the advice in italic, an optional small button
## the council, one minister at a time: a heading (ring icon, name, role, how many matters) and under it one row per matter: a severity bar (crisis / warning / tip: the status tokens), the quote, the action.
## items: [{sev: 0..2, quote, btn, cb}]
static func minister_group(icon: String, name_text: String, role: String, items: Array) -> Control:
	var box := VBoxContainer.new(); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation", 0)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 12)
	var ring := K.ring_icon(icon, 40); ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER; head.add_child(ring)
	var hv := VBoxContainer.new(); hv.add_theme_constant_override("separation", 0); hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER; head.add_child(hv)
	var t := K.title(name_text, 15, Color.TRANSPARENT, 0.08, 0.0); (t as TBBz.TLabel).px = 14.5; (t as TBBz.TLabel).refit(); hv.add_child(t)
	var c := K.caps("%s  ·  %d" % [role, items.size()], 10, TBTokens.c("brass")); (c as TBBz.TLabel).px = 10.5; (c as TBBz.TLabel).refit(); hv.add_child(c)
	var hm := MarginContainer.new(); hm.add_theme_constant_override("margin_top", 14); hm.add_theme_constant_override("margin_bottom", 6); hm.add_child(head); box.add_child(hm)
	for it in items:
		var sev: int = int(it["sev"])
		var tone: Color = TBTokens.c("neg") if sev >= 2 else (TBTokens.c("warn") if sev == 1 else TBTokens.c("hair"))
		var row := PanelContainer.new(); row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new(); sb.bg_color = Color.TRANSPARENT; sb.border_color = tone; sb.border_width_left = 3
		sb.content_margin_left = 14; sb.content_margin_right = 4; sb.content_margin_top = 6; sb.content_margin_bottom = 8
		row.add_theme_stylebox_override("panel", sb)
		var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation", 0); row.add_child(rv)
		rv.add_child(K.para_bz('[i]"%s"[/i]' % String(it["quote"]), 16.5, 1.35, TBTokens.BZ_IVORY))
		var cb: Callable = it["cb"]
		if String(it["btn"]) != "" and cb.is_valid():
			var bm := MarginContainer.new(); bm.add_theme_constant_override("margin_top", 6)
			var b: Button = K.button(String(it["btn"]), cb, false, true); b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			bm.add_child(b); rv.add_child(bm)
		var gap := MarginContainer.new(); gap.add_theme_constant_override("margin_bottom", 4); gap.add_child(row); box.add_child(gap)
	return box

## a goal: the progress medal (a ring, a 6 unit track and arc, the percentage) beside the title and the italic line, in a well
class GoalCard extends PanelContainer:
	var frac := 0.0
	var on_press := Callable()                                  # a card that leads somewhere (an ambition to form a name opens the Realm page)
	func _gui_input(ev: InputEvent) -> void:
		if on_press.is_valid() and ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			accept_event(); on_press.call()
	func _init(title: String, sub: String, f: float, tip: String = "") -> void:
		if not TBTokens.on_paper(): set_meta("tb_dark", true)           # a dark well keeps its cream text; in high contrast light the card is paper
		frac = clampf(f, 0.0, 1.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tooltip_text = tip
		var sb := StyleBoxEmpty.new(); for s in ["left", "right", "top", "bottom"]: sb.set("content_margin_" + s, 12.0)
		add_theme_stylebox_override("panel", sb)
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 12); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(hb)
		var m := TBBzParts.Gauge.new(27.0, "%d%%" % int(roundf(frac * 100.0)), "", frac, TBTokens.BZ_GOOD if frac >= 1.0 else TBTokens.c("brass"))       # the HUD's gauge: its figure sits in the middle of the ring
		hb.add_child(m)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 0); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; v.size_flags_vertical = Control.SIZE_SHRINK_CENTER; v.mouse_filter = Control.MOUSE_FILTER_IGNORE; hb.add_child(v)
		var t := K.title(title, 13, Color.TRANSPARENT, 0.07, 12.5 * 1.25); (t as TBBz.TLabel).px = 12.5; (t as TBBz.TLabel).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; (t as TBBz.TLabel).refit()
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t.custom_minimum_size.x = 40; v.add_child(t)
		var sm := MarginContainer.new(); sm.add_theme_constant_override("margin_top", 3); sm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sm.add_child(K.para_bz("[i]%s[/i]" % sub, 15.0, 1.25)); v.add_child(sm)
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, TBTokens.c("paper_1") if TBTokens.on_paper() else TBTokens.BZ_WELL)
		draw_rect(Rect2(0.5, 0.5, size.x - 1.0, size.y - 1.0), TBTokens.c("rule") if TBTokens.on_paper() else TBTokens.BZ_WELL_LINE, false, 1.0)

class Medal extends Control:
	var frac := 0.0
	func _init(f: float) -> void:
		frac = f; custom_minimum_size = Vector2(72, 72); size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; size_flags_vertical = Control.SIZE_SHRINK_CENTER; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var k: float = 72.0 / 86.0
		var c := Vector2(36, 36)
		TBBezel.ring(self, c, 40.0 * k, 0, Color.TRANSPARENT, true, false, k)
		var r: float = 30.0 * k
		var w: float = 6.0 * k
		draw_arc(c, r, 0.0, TAU, 64, TBTokens.BZ_TRACK, w, true)
		var col: Color = TBTokens.BZ_GOOD if frac >= 1.0 else TBTokens.c("brass")
		var a0: float = -PI * 0.5
		var a1: float = a0 + TAU * maxf(1.0 / 360.0, minf(359.0 / 360.0, frac)) if frac < 1.0 else a0 + TAU * 359.9 / 360.0
		draw_arc(c, r, a0, a1, maxi(8, int(64 * maxf(frac, 0.05))), col, w, true)
		for a in [a0, a1]: draw_circle(c + Vector2(cos(a), sin(a)) * r, w * 0.5, col)
		var f: Font = TBKit.alegreya(700)
		var txt := "%d%%" % int(roundf(frac * 100.0))
		var sz: float = 17.0 * k
		TBBz.text(get_canvas_item(), f, Vector2(36.0 - TBBz.tw(f, txt, sz) * 0.5, 48.0 * k + sz * 0.3), txt, sz, TBTokens.BZ_IVORY)
