## Modal container system (design/ux/modal-system.md): ONE factory for the three presentations and one pop-stack.
##   DIALOG  centred card over a scrim (blocking, one screen): events, confirms, pass-device, briefing, tutorial, game over
##   DRAWER  right-rail drawer on landscape / bottom sheet on portrait; non-modal, the map stays live (Budget, Annals, Council)
##   PANEL   wide panel on landscape (two columns) / full-screen page with a header Back arrow on portrait (Nations, Menu hub, New game, Decisions)
## Anatomy everywhere: header (glyph, title, context chip, X) / optional tab row / scrolling body / pinned footer (no Back button).
## Android Back, Esc and X share TBPanel.pop(). Plain panels carry no ornament; only `hero` dialogs use the hero sheet.
class_name TBPanel
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

enum Kind { DIALOG, DRAWER, PANEL }
const DRAWER_TOP := 56            ## drawer top = bottom edge of the top bar (HUD may raise it)
const DRAWER_BOTTOM := 108        ## drawer ends above End Turn (80 seal + 16 margin + 12 gap)
const SHEET_BOTTOM := 88          ## portrait sheet rises above the dock rail and End Turn
const DRAWER_W := 400
static var drawer_opened_fn: Callable           ## called when a side drawer opens (the HUD hides the inspector when the two cannot share the width)
static var drawer_rect_fn: Callable             ## () -> Rect2 : the HUD's drawer slot (right of the rail), null rect = use the legacy right-hand slot
const SNAP_LOW := 0.56
const SNAP_HIGH := 0.92

## everything a caller needs about an open container
class Handle extends RefCounted:
	var root: Control
	var holder: Control
	var backdrop: ColorRect
	var card: PanelContainer
	var kind := 0
	var form := "dialog"                 # dialog | drawer | sheet | panel | page
	var wide := false
	var hero := false
	var modal := true
	var dismissable := true
	var on_back := Callable()            # returns true when it consumed a Back press (drill-in inside the screen)
	var on_dismiss := Callable()         # called after X / Esc / Back closed it (not after close())
	var focus_target: Control
	var head: Control
	var back_btn: Control
	var title_label: Label
	var sub_label: Label                 # the italic subtitle under the title (bezel header)
	var bz_w := 0.0                      # bezel: card width in units (the demo's per-screen widths)
	var bz_h := 0.0                      # bezel: maximum card height in units (0 = the demo's panel height)
	var bz_pos := Vector2(-1, -1)        # bezel: fixed top-left (tests, specimen sheets); (-1, -1) = docked by `dock`
	var dock := "left"                   # bezel: left (next to the rail) | right | center
	var bz := false                      # drawn as the demo's plate
	var chip_slot: HBoxContainer
	var action_slot: HBoxContainer
	var tabs_slot: PanelContainer
	var tabs_ctl: Control
	var scroll: ScrollContainer
	var body_wrap: MarginContainer
	var body: VBoxContainer
	var footer_wrap: Control
	var footer: BoxContainer
	var handle_ctl: Control
	var head_row: HBoxContainer          # header row (tabs and actions move into it on short screens)
	var short := false                   # viewport height < 480u: page presentation, merged header, no footer
	var pinned: VBoxContainer            # split dialogs: choices pinned beside / beneath the scrolling narrative
	var pinned_sc: ScrollContainer
	var split_wide := false
	var narrow := false                  # viewport narrower than 480u: footer buttons may wrap
	var snap := 0.56
	var pad := 24
	var fit_pending := false
	func is_open() -> bool: return is_instance_valid(root) and not root.is_queued_for_deletion()
	func close() -> void:
		if is_instance_valid(root) and not root.is_queued_for_deletion(): root.queue_free()
	func set_title(t: String) -> void:
		if title_label != null: title_label.text = t; title_label.tooltip_text = t
	func set_sub(t: String) -> void:
		if sub_label != null: sub_label.text = t; sub_label.visible = t != ""
	func set_chip(c: Control) -> void:
		if narrow and K.text_scale >= 1.4:               # no room for a context chip in the header at large text
			if c != null: c.queue_free()
			return
		for ch in chip_slot.get_children(): ch.queue_free()
		if c != null: chip_slot.add_child(c)
	func set_tabs(c: Control) -> void:
		for ch in tabs_slot.get_children(): ch.queue_free()
		tabs_ctl = c
		var sc := ScrollContainer.new()               # overflowing tabs scroll sideways (no scrollbar), the active one is kept in view
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER; sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true; sc.custom_minimum_size = Vector2(0, 0 if bz else TBKit.touch())
		if bz and body_wrap != null: body_wrap.add_theme_constant_override("margin_top", 12)
		sc.add_child(c); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if short and head_row != null:                 # short screens: the tabs live in the header row (title, tabs, chip, actions)
			sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head_row.add_child(sc); head_row.move_child(sc, title_label.get_index() + 1)
			title_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			tabs_slot.visible = false
		else:
			tabs_slot.add_child(sc); tabs_slot.visible = true
		(func():
			var tb := c as TBKit.Tabs
			if tb != null and is_instance_valid(sc) and tb._btns.has(tb.current): sc.ensure_control_visible(tb._btns[tb.current])).call_deferred()
	func inner_w() -> float: return card.size.x - 2.0 * pad
	func clear_actions() -> void:
		for c in footer.get_children(): c.queue_free()
		if action_slot != null:
			for c in action_slot.get_children(): c.queue_free()
	## secondary left, primary right (the primary takes the larger share of the free width). Short pages put the actions in the header.
	func actions(secondary: Control, primary: Control) -> void:
		if short and action_slot != null and form == "page":
			if secondary != null: action_slot.add_child(secondary)
			if primary != null: action_slot.add_child(primary)
			return
		for b in [secondary, primary]:                   # long labels wrap instead of widening the card (narrow screens, text size 150 / 200 %)
			if K.text_scale >= 1.4 and b is Button and (b as Button).autowrap_mode == TextServer.AUTOWRAP_OFF: (b as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; (b as Button).clip_text = false
		if footer.vertical:                               # narrow + large text: stacked, the primary first (top)
			for b2 in [primary, secondary]:
				if b2 != null: (b2 as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL; footer.add_child(b2)
			return
		if bz:                                            # `.foot{justify-content:space-between}`: buttons keep their own width
			var room: float = minf(bz_w if bz_w > 0.0 else 460.0, TBPanel._vs(self).x - 32.0) - 36.0 - 10.0
			var need := 0.0
			for b0 in [secondary, primary]: need += (b0 as Control).custom_minimum_size.x if b0 != null else 0.0
			if need > room:                               # a narrow screen: the labels wrap instead of pushing the card off the screen
				for b1 in [secondary, primary]:
					if b1 is TBBz.Btn and not (b1 as TBBz.Btn).legacy: (b1 as TBBz.Btn).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; (b1 as TBBz.Btn)._go_native(); (b1 as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if secondary != null: footer.add_child(secondary)
			var sp0 := Control.new(); sp0.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp0.mouse_filter = Control.MOUSE_FILTER_IGNORE
			footer.add_child(sp0)
			if primary != null: footer.add_child(primary)
			return
		if secondary != null: footer.add_child(secondary)
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp.size_flags_stretch_ratio = 0.35; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer.add_child(sp)
		if primary != null:
			primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL; primary.size_flags_stretch_ratio = 1.0
			if primary is Button and not (primary as Button).text.is_empty():          # never narrower than its own label (+ glyph / padding)
				var pb := primary as Button
				var tw: float = pb.get_theme_font("font").get_string_size(pb.text, HORIZONTAL_ALIGNMENT_LEFT, -1, pb.get_theme_font_size("font_size")).x
				pb.custom_minimum_size.x = maxf(pb.custom_minimum_size.x, ceilf(tw) + 64.0)
			footer.add_child(primary)
	func relayout() -> void: TBPanel._layout(self)

# ---------------------------------------------------------------------------------------------------------------------------------------
## size profile of the viewport (logical px): P portrait, S short landscape, L landscape phone, D desktop / tablet
## close every open side drawer under `parent` (dialogs stay)
static func close_drawers(parent: Node) -> void:
	for ch in parent.get_children():
		if ch.has_meta("tb_handle") and not ch.is_queued_for_deletion():
			var oh: Handle = ch.get_meta("tb_handle")
			if oh.kind == Kind.DRAWER: oh.close()

static func profile(vs: Vector2) -> String:
	if vs.y > vs.x: return "P"
	if vs.y <= 400.0: return "S"
	if vs.y <= 520.0: return "L"
	return "D"

static func is_portrait(vs: Vector2) -> bool: return vs.y > vs.x

## below this height (logical px) wide panels and drawers become full-screen pages (modal-system.md 5.2)
const SHORT_H := 480.0
static func is_short(vs: Vector2) -> bool: return vs.y < SHORT_H and vs.y <= vs.x

## page presentation (list / detail stacked with a Back arrow): portrait phones and short landscape screens
static func stacked(vs: Vector2) -> bool: return vs.y > vs.x or vs.y < SHORT_H

## hardware input expected (desktop, or a keyboard / pad was used): modals focus their first control so Tab / arrows / Enter work from a cold start
static func wants_focus() -> bool: return TBFrame.kbd_nav or not OS.has_feature("mobile")

static func top(overlay: Node) -> Handle:
	var t: Handle = null
	for ch in overlay.get_children():
		if ch.has_meta("tb_handle") and not ch.is_queued_for_deletion(): t = ch.get_meta("tb_handle")
	return t

## any modal currently open?
static func any_open(overlay: Node) -> bool: return top(overlay) != null

## one step of the back stack: "none" | "back" (consumed inside the screen) | "closed" | "locked" (an answer is required)
static func pop(overlay: Node) -> String:
	var h := top(overlay)
	if h == null: return "none"
	return pop_handle(h)

static func pop_handle(h: Handle) -> String:
	if not h.is_open(): return "none"
	if h.on_back.is_valid() and bool(h.on_back.call()): return "back"
	if not h.dismissable: return "locked"
	h.close()
	if h.on_dismiss.is_valid(): h.on_dismiss.call()
	return "closed"

static func is_top(h: Handle) -> bool:
	var par := h.root.get_parent() if is_instance_valid(h.root) else null
	if par == null: return false
	var t: Handle = top(par)
	return t == h

# ---- keyboard: Esc = pop, Tab / arrows trapped inside modal kinds, [ ] / Ctrl+Tab switch tabs --------------------------------------------
class Guard extends Node:
	var h: Handle
	func _input(e: InputEvent) -> void:
		if TBNegotiate.active and e is InputEventKey and e.pressed:           # a negotiation dial owns the keyboard: any key skips the needle, nothing reaches the panel
			if not e.echo and TBNegotiate.skip_fn.is_valid(): TBNegotiate.skip_fn.call()
			get_viewport().set_input_as_handled(); return
		if not (e is InputEventKey) or not e.pressed or e.echo or h == null or not h.is_open() or not TBPanel.is_top(h): return
		var vp := get_viewport()
		if e.is_action_pressed("ui_cancel"):
			TBPanel.pop_handle(h)
			vp.set_input_as_handled(); return
		var f := vp.gui_get_focus_owner()
		var inside: bool = f != null and h.root.is_ancestor_of(f)
		if h.tabs_ctl != null and h.tabs_ctl is TBKit.Tabs and not (f is LineEdit):
			var ke := e as InputEventKey
			var step := 0
			if ke.keycode == KEY_BRACKETRIGHT or (ke.keycode == KEY_TAB and ke.ctrl_pressed and not ke.shift_pressed): step = 1
			elif ke.keycode == KEY_BRACKETLEFT or (ke.keycode == KEY_TAB and ke.ctrl_pressed and ke.shift_pressed): step = -1
			if step != 0:
				var tb: TBKit.Tabs = h.tabs_ctl
				var ids: Array = tb._btns.keys()
				var i: int = ids.find(tb.current)
				tb.select(ids[(i + step + ids.size()) % ids.size()], true)
				vp.set_input_as_handled(); return
		if not h.modal: return
		if e.is_action_pressed("ui_accept") and f != null and not inside:
			vp.set_input_as_handled(); return
		var tab_n: bool = e.is_action_pressed("ui_focus_next")
		var tab_p: bool = e.is_action_pressed("ui_focus_prev")
		var arrow_n: bool = e.is_action_pressed("ui_down") or e.is_action_pressed("ui_right")
		var arrow_p: bool = e.is_action_pressed("ui_up") or e.is_action_pressed("ui_left")
		if not (tab_n or tab_p or arrow_n or arrow_p): return
		if inside and (arrow_n or arrow_p):
			if f is LineEdit or f is TextEdit: return
			if f is Range and (e.is_action_pressed("ui_left") or e.is_action_pressed("ui_right")): return
		var nxt: bool = tab_n or arrow_n
		var list: Array = TBKit.focusables(h.root)
		if list.is_empty(): return
		var i2: int = list.find(f) if inside else -1
		var j: int = 0
		if i2 < 0: j = 0 if nxt else list.size() - 1
		else: j = (i2 + (1 if nxt else -1) + list.size()) % list.size()
		(list[j] as Control).grab_focus()
		vp.set_input_as_handled()

# ---------------------------------------------------------------------------------------------------------------------------------------
## Opens a container. opts: width (dialog, default 440), wide (wide dialog 640 on landscape), hero, dismissable, scroll (default true),
## on_back (Callable -> bool), backdrop_dismiss, opaque, focus (Control to focus first), padded (default true), no_close.
static func open(parent: Control, kind: int, title_text: String = "", glyph_id: String = "", opts: Dictionary = {}) -> Handle:
	TBFrame.ensure_watch()
	var h := Handle.new()
	h.kind = kind
	h.hero = bool(opts.get("hero", false))
	h.dismissable = bool(opts.get("dismissable", true))
	h.on_back = opts.get("on_back", Callable())
	h.on_dismiss = opts.get("on_dismiss", Callable())
	var vp0: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var portrait := is_portrait(vp0)
	var short := is_short(vp0)
	h.wide = bool(opts.get("wide", false))
	match kind:
		Kind.DIALOG: h.form = "dialog"
		Kind.DRAWER: h.form = "sheet" if portrait else ("page" if (short and not TBFrame.bezel) else "drawer")      # the demo keeps floating windows on a phone in landscape
		_: h.form = "page" if (portrait or (short and not TBFrame.bezel)) else "panel"
	h.modal = kind != Kind.DRAWER or h.form == "page"
	h.short = short and h.form in ["page", "dialog"]
	h.narrow = vp0.x < 480.0
	h.pad = 16 if portrait else (12 if short else 24)
	h.bz = TBFrame.bezel
	h.bz_w = float(opts.get("w", 0.0)); h.bz_h = float(opts.get("h", 0.0))
	h.dock = String(opts.get("dock", "center" if kind == Kind.DIALOG else "left"))
	h.bz_pos = opts.get("pos", Vector2(-1, -1))
	if h.bz: h.pad = 14 if vp0.y < 560.0 else 22
	# at most one panel: a new drawer / panel replaces the old one (dialogs may stack above a panel)
	if kind != Kind.DIALOG:
		for ch in parent.get_children():
			if ch.has_meta("tb_handle") and not ch.is_queued_for_deletion():
				var oh: Handle = ch.get_meta("tb_handle")
				if oh.kind != Kind.DIALOG: oh.close()
	if h.form == "drawer" and drawer_opened_fn.is_valid(): drawer_opened_fn.call()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP if h.modal else Control.MOUSE_FILTER_IGNORE
	root.set_meta("tb_handle", h)
	root.set_meta("tb_modal", true)
	root.z_index = TBTokens.Z_MODAL                  # above every HUD tooltip / popover (they sit at 60-70)
	h.root = root
	if h.modal and bool(opts.get("scrim", true)):
		var bd := ColorRect.new()
		bd.set_anchors_preset(Control.PRESET_FULL_RECT)
		bd.color = TBTokens.c("table") if bool(opts.get("opaque", false)) else TBTokens.ca("table", 0.55 if h.form == "dialog" else 0.40)
		bd.mouse_filter = Control.MOUSE_FILTER_STOP
		root.add_child(bd); h.backdrop = bd
		if bool(opts.get("backdrop_dismiss", false)):
			bd.gui_input.connect(func(e: InputEvent): if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: pop_handle(h))
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT); holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder); h.holder = holder
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(card); h.card = card
	var pad := h.pad
	if h.bz and h.form in ["dialog", "drawer", "panel"]:
		card.add_theme_stylebox_override("panel", TBBz.plate_box(12.0 if not (h.short or vp0.y < 560.0) else 10.0, true))
	elif h.hero:
		card.add_theme_stylebox_override("panel", TBFrame.hero(pad + 4, pad))
	elif h.form == "page":
		card.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_0"), Color.TRANSPARENT, 0, 0, 0, 0, false, 0))
	elif h.form == "sheet":
		card.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_0"), TBTokens.c("rule"), TBTokens.CUT_PANEL, 2, 0, 0, false, 1, TBFrame.TL | TBFrame.TR))
	else:
		card.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_0"), TBTokens.c("rule"), TBTokens.CUT_PANEL, 2 if h.modal else 1, 0, 0))
	var outer := K.vbox(0)
	card.add_child(outer)
	var padded: bool = (not h.hero or h.bz) and bool(opts.get("padded", true))
	# ---- sheet handle
	if h.form == "sheet":
		var hd := Control.new(); hd.custom_minimum_size = Vector2(0, 24); hd.mouse_filter = Control.MOUSE_FILTER_STOP
		hd.draw.connect(func():
			var w: float = hd.size.x
			hd.draw_rect(Rect2(roundf(w * 0.5 - 18.0), 10, 36, 4), TBTokens.c("rule")))
		hd.mouse_default_cursor_shape = Control.CURSOR_VSIZE
		var drag := {"y0": 0.0, "down": false}
		hd.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				if e.pressed: drag["y0"] = e.global_position.y; drag["down"] = true
				elif drag["down"]:
					drag["down"] = false
					var dy: float = e.global_position.y - float(drag["y0"])
					if absf(dy) < 12.0: _snap(h, SNAP_HIGH if h.snap < 0.7 else SNAP_LOW)
					elif dy > 12.0:
						if h.snap > 0.7: _snap(h, SNAP_LOW)
						else: pop_handle(h)
					else: _snap(h, SNAP_HIGH))
		K.a11y(hd, T.call("sheet_handle"), "button")
		hd.focus_mode = Control.FOCUS_ALL
		hd.gui_input.connect(func(e: InputEvent):
			if e.is_action_pressed("ui_accept"): _snap(h, SNAP_HIGH if h.snap < 0.7 else SNAP_LOW)
			elif e.is_action_pressed("ui_down"): _snap(h, SNAP_LOW)
			elif e.is_action_pressed("ui_up"): _snap(h, SNAP_HIGH))
		outer.add_child(hd); h.handle_ctl = hd
	# ---- header
	if h.bz and title_text != "" and h.form != "sheet":
		_bz_header(h, outer, title_text, glyph_id, opts, vp0)
	elif title_text != "" and not h.hero:
		var hm := MarginContainer.new()
		hm.add_theme_constant_override("margin_left", 12 if h.form == "page" else 16); hm.add_theme_constant_override("margin_right", 6)
		var hb := K.hbox(10 if not h.short else 8); hb.custom_minimum_size = Vector2(0, K.touch() + (4 if not h.short else 0))
		hm.add_child(hb); h.head_row = hb
		if h.form == "page":
			var bb := K.IconBtn.new("back", func(): pop_handle(h), 40)
			K.a11y(bb, T.call("back"), "button"); hb.add_child(bb); h.back_btn = bb
		elif glyph_id != "":
			var gl: Control = K.ring_icon(glyph_id, 40 if not h.short else 34) if TBFrame.bezel else K.glyph(glyph_id, 24, TBTokens.c("oxblood"))
			if not TBFrame.bezel: gl.custom_minimum_size = Vector2(28, 28)
			hb.add_child(gl)
		var tl := K.title(title_text, 20, TBTokens.c("ink_0"))
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tl.custom_minimum_size.x = 40; tl.tooltip_text = title_text
		if h.form == "dialog": tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART           # a dialog title wraps (a confirm names the act), page titles ellipsize
		else: tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if h.short: tl.custom_minimum_size.x = 120
		hb.add_child(tl); h.title_label = tl
		var chips := K.hbox(6); chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(chips); h.chip_slot = chips
		var acts := K.hbox(4); hb.add_child(acts); h.action_slot = acts
		if h.dismissable and h.form != "page" and not bool(opts.get("no_close", false)):
			var xb := K.IconBtn.new("close", func(): pop_handle(h), 40)
			K.a11y(xb, T.call("close"), "button"); hb.add_child(xb)
		h.head = hm
		outer.add_child(hm)
		outer.add_child(K.header_rule())
	# ---- tab row (filled by set_tabs)
	var tp := PanelContainer.new()
	if h.bz:                                               # the demo's `.tabs` sit in the body: no band, the body's own padding above
		var tsb := StyleBoxEmpty.new(); tsb.content_margin_left = float(pad); tsb.content_margin_right = float(pad); tsb.content_margin_top = 16.0 if vp0.y >= 560.0 else 10.0; tsb.content_margin_bottom = 0.0
		tp.add_theme_stylebox_override("panel", tsb)
	else:
		tp.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_1"), Color.TRANSPARENT, 0, 0, 8, 0, false, 0))
	tp.visible = false
	outer.add_child(tp); h.tabs_slot = tp
	# ---- body
	var wrap := MarginContainer.new()
	var side: int = pad if padded else 0
	wrap.add_theme_constant_override("margin_left", side); wrap.add_theme_constant_override("margin_right", side)
	wrap.add_theme_constant_override("margin_top", (12 if not h.short else 6) if padded else 0); wrap.add_theme_constant_override("margin_bottom", (12 if not h.short else 6) if padded else 0)
	if h.bz and padded:                                    # `.body{padding:16px 22px 20px}` (phone 10 14 12)
		var ph0: bool = vp0.y < 560.0
		wrap.add_theme_constant_override("margin_top", 10 if ph0 else 16); wrap.add_theme_constant_override("margin_bottom", 12 if ph0 else 20)
	var body := K.vbox(10 if not h.short else 8)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_child(body)
	h.body_wrap = wrap; h.body = body
	var split: bool = bool(opts.get("split", false)) and kind == Kind.DIALOG
	if split:
		# hero dialog with pinned choices: the narrative scrolls, the choices (h.pinned) stay on screen beside it (wide) or beneath it
		h.split_wide = bool(opts.get("split_wide", false))
		var sp := BoxContainer.new(); sp.vertical = not h.split_wide
		sp.add_theme_constant_override("separation", 24 if h.split_wide else 8)
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sc0 := ScrollContainer.new()
		sc0.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc0.follow_focus = true; sc0.scroll_deadzone = 12
		sc0.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc0.add_child(wrap); wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.add_child(sc0); h.scroll = sc0
		var psc := ScrollContainer.new()
		psc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		psc.follow_focus = true; psc.scroll_deadzone = 12
		psc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; psc.size_flags_vertical = Control.SIZE_EXPAND_FILL if h.split_wide else Control.SIZE_SHRINK_END
		var pv := K.vbox(10 if not h.short else 8); pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		psc.add_child(pv); sp.add_child(psc)
		h.pinned = pv; h.pinned_sc = psc
		outer.add_child(sp)
	elif bool(opts.get("scroll", true)):
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.follow_focus = true; sc.scroll_deadzone = 12
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.add_child(wrap); wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		outer.add_child(sc); h.scroll = sc
	else:
		wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer.add_child(wrap)
	# ---- footer (pinned; hidden while empty)
	var fw := VBoxContainer.new(); fw.add_theme_constant_override("separation", 0); fw.visible = false
	var frule := ColorRect.new(); frule.color = TBTokens.c("hair") if not TBTokens.is_hc() else TBTokens.c("rule")
	if h.bz and not TBTokens.is_hc(): frule.color = TBTokens.BZ_FOOT_LINE
	frule.custom_minimum_size = Vector2(0, 1); frule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fw.add_child(frule)
	var fm := MarginContainer.new()
	fm.add_theme_constant_override("margin_left", side if padded else pad); fm.add_theme_constant_override("margin_right", side if padded else pad)
	fm.add_theme_constant_override("margin_top", 8 if not h.short else 4); fm.add_theme_constant_override("margin_bottom", 12 if not h.short else 4)
	if h.bz:                                               # `.foot{padding:10px 18px 14px;gap:10px}` (phone: tighter)
		var ph1: bool = vp0.y < 560.0
		fm.add_theme_constant_override("margin_left", 12 if ph1 else 18); fm.add_theme_constant_override("margin_right", 12 if ph1 else 18)
		fm.add_theme_constant_override("margin_top", 8 if ph1 else 10); fm.add_theme_constant_override("margin_bottom", 10 if ph1 else 14)
	var foot := BoxContainer.new(); foot.add_theme_constant_override("separation", 10 if h.bz else 8)
	foot.vertical = K.text_scale >= 1.4 and vp0.x < 700.0               # narrow and large text: the buttons stack instead of overflowing
	fm.add_child(foot); fw.add_child(fm)
	outer.add_child(fw); h.footer_wrap = fw; h.footer = foot
	foot.child_order_changed.connect(func(): fw.visible = foot.get_child_count() > 0; _queue_fit(h))
	# ---- hooks
	var opener := parent.get_viewport().gui_get_focus_owner()
	parent.add_child(root)
	var guard := Guard.new(); guard.h = h
	root.add_child(guard)
	if opener != null and h.modal: parent.get_viewport().gui_release_focus()
	var opener_ref: WeakRef = weakref(opener)                    # a weak reference: the opener (a title entry, a card) may be gone when this closes
	root.tree_exiting.connect(func():
		var op: Object = opener_ref.get_ref()
		if op is Control and is_instance_valid(op) and (op as Control).is_inside_tree() and (op as Control).focus_mode != Control.FOCUS_NONE: (op as Control).grab_focus.call_deferred())
	h.focus_target = opts.get("focus", null)
	if wants_focus(): _focus_first.call_deferred(h)
	root.resized.connect(func(): _layout(h))
	body.minimum_size_changed.connect(func(): _queue_fit(h))
	if h.pinned != null: h.pinned.minimum_size_changed.connect(func(): _queue_fit(h))
	foot.minimum_size_changed.connect(func(): _queue_fit(h))
	_layout(h)
	_queue_fit(h)
	if K.motion_ok():
		root.modulate.a = 0.0
		var tw := root.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(root, "modulate:a", 1.0, 0.18 if h.bz else 0.16)
		if h.bz and h.form in ["drawer", "panel"]: tw.tween_property(holder, "position:x", 0.0, 0.22).from(-16.0)     # `.scr`: opacity .18s, translateX(-16px) -> 0 in .22s
		elif h.bz and h.form == "dialog":
			card.scale = Vector2(0.97, 0.97)                                                                          # `.scr.modal`: scale(.97) -> 1
			tw.tween_property(card, "scale", Vector2.ONE, 0.22)
		else:
			match h.form:
				"drawer": tw.tween_property(holder, "position:x", 0.0, 0.18).from(24.0)
				"sheet": tw.tween_property(holder, "position:y", 0.0, 0.2).from(40.0)
				"page": tw.tween_property(holder, "position:x", 0.0, 0.2).from(24.0)
				_: tw.tween_property(holder, "position:y", 0.0, 0.18).from(8.0)
	return h

## the demo's header (`.hd`): ring icon 46, title (Cinzel 700 22, .12em) over an italic subtitle, 36 unit close button, then the graduated rule
static func _bz_header(h: Handle, outer: VBoxContainer, title_text: String, glyph_id: String, opts: Dictionary, vp0: Vector2) -> void:
	var phone: bool = vp0.y < 560.0
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 0)
	var hm := MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 14 if phone else 22); hm.add_theme_constant_override("margin_right", 14 if phone else 22)
	hm.add_theme_constant_override("margin_top", 10 if phone else 18); hm.add_theme_constant_override("margin_bottom", 8 if phone else 12)
	var hb := K.hbox(12 if phone else 14)
	hm.add_child(hb); h.head_row = hb
	if h.form == "page":
		var bb := K.IconBtn.new("back", func(): pop_handle(h), 36)
		K.a11y(bb, T.call("back"), "button"); hb.add_child(bb); h.back_btn = bb
	elif glyph_id != "":
		hb.add_child(K.ring_icon(glyph_id, 36 if phone else 46))
	var tb := K.vbox(0)
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tl := K.title(title_text, 17 if phone else 22, TBTokens.c("ink_0"))
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.custom_minimum_size.x = 40; tl.tooltip_text = title_text
	if h.form == "dialog": (tl as TBBz.TLabel).wrap_ok = true                           # a dialog title wraps when it does not fit (a confirm names the act), page titles ellipsize
	else: tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tb.add_child(tl); h.title_label = tl
	var gap5 := Control.new(); gap5.custom_minimum_size = Vector2(0, 5); gap5.mouse_filter = Control.MOUSE_FILTER_IGNORE; tb.add_child(gap5)            # `.s{margin-top:5px}` is there even when the subtitle is empty
	var sub := TBBz.TLabel.new(K.alegreya(400, true), 13.0 if phone else 16.0, 0.0)                    # `.hd .s`: italic 16, dim
	sub.add_theme_color_override("font_color", K.DIM); sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; sub.custom_minimum_size.x = 40
	sub.visible = false; sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tb.add_child(sub); h.sub_label = sub
	if opts.has("sub"): h.set_sub(String(opts["sub"]))
	hb.add_child(tb)
	var chips := K.hbox(6); chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(chips); h.chip_slot = chips
	var acts := K.hbox(4); acts.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(acts); h.action_slot = acts
	if h.dismissable and h.form != "page" and not bool(opts.get("no_close", false)):
		var xb := K.IconBtn.new("close", func(): pop_handle(h), 36)
		K.a11y(xb, T.call("close"), "button"); hb.add_child(xb)
	box.add_child(hm); box.add_child(K.header_rule(14 if phone else 22))
	h.head = box
	outer.add_child(box)

## bezel placement and size of a dialog / drawer / panel: the width of the screen (opts w), as tall as its content up to the demo's panel height,
## docked next to the rail (x 340, y 190), to the right (x = W - w - 28) or, for modals, at x centred / y = max(100, (H - h) / 2 - 20)
static func _fit_bz(h: Handle) -> void:
	if not h.is_open() or not h.bz: return
	var vs := _vs(h)
	var phone: bool = vs.y < 560.0
	var wdef: float = {"dialog": 460.0, "drawer": 560.0, "panel": 900.0}.get(h.form, 460.0)
	var w: float = h.bz_w if h.bz_w > 0.0 else (600.0 if (h.wide and h.form == "dialog") else wdef)
	w = minf(w, vs.x - (12.0 if phone else 32.0))
	var panel_h: float = (vs.y - 16.0) if phone else maxf(vs.y - 320.0, 240.0)
	var hmax: float = minf(h.bz_h if h.bz_h > 0.0 else panel_h, panel_h)
	var c := h.card
	c.custom_minimum_size = Vector2(w, 0)
	if h.scroll != null:
		var chrome: float = 0.0
		if h.head != null: chrome += h.head.get_combined_minimum_size().y
		if h.tabs_slot.visible: chrome += h.tabs_slot.get_combined_minimum_size().y
		if h.footer_wrap.visible: chrome += h.footer_wrap.get_combined_minimum_size().y
		var body_min: float = h.body_wrap.get_combined_minimum_size().y
		var avail: float = (hmax - 2.0) - chrome
		if h.pinned != null:
			var pm: float = h.pinned.get_combined_minimum_size().y
			if h.split_wide:
				h.scroll.custom_minimum_size.y = clampf(maxf(body_min, pm), 40.0, maxf(avail, 40.0))
				h.pinned_sc.custom_minimum_size.y = 0.0
			else:
				var ph: float = minf(pm, avail * 0.6)
				h.pinned_sc.custom_minimum_size.y = ph
				h.scroll.custom_minimum_size.y = clampf(body_min, 40.0, maxf(avail - ph - 8.0, 40.0))
		else:
			h.scroll.custom_minimum_size.y = maxf(minf(body_min, avail), 40.0)
	c.size = Vector2(w, 0)
	c.reset_size()
	var x: float
	var y: float
	if h.form == "dialog":
		x = floorf((vs.x - w) * 0.5); y = maxf(8.0 if phone else 100.0, (vs.y - hmax) * 0.5 - 20.0)
		if h.dock == "left":
			x = 60.0 if phone else 340.0; y = 8.0 if phone else 190.0
	else:
		x = 60.0 if phone else 340.0; y = 8.0 if phone else 190.0
		if h.dock == "right": x = vs.x - w - (8.0 if phone else 28.0)
		elif h.dock == "center": x = floorf((vs.x - w) * 0.5)
		elif drawer_rect_fn.is_valid() and not phone:
			var dr: Rect2 = drawer_rect_fn.call()
			if dr.size.x > 100.0:
				x = dr.position.x; y = dr.position.y
	if x + w > vs.x - 4.0: x = maxf(4.0, vs.x - w - 4.0)
	if h.bz_pos.x >= 0.0: x = h.bz_pos.x; y = h.bz_pos.y
	c.position = Vector2(x, y).floor()
	c.pivot_offset = c.size * 0.5

static func _focus_first(h: Handle) -> void:
	if not h.is_open() or not h.root.is_inside_tree(): return
	if h.focus_target != null and is_instance_valid(h.focus_target) and h.focus_target.is_visible_in_tree(): h.focus_target.grab_focus(); return
	K._focus_first(h.root)

# ---- layout ------------------------------------------------------------------------------------------------------------------------------
static func _vs(h: Handle) -> Vector2:
	if is_instance_valid(h.root) and h.root.size.x > 1.0: return h.root.size
	return h.root.get_viewport_rect().size if h.root.is_inside_tree() else Vector2(1280, 720)

static func _layout(h: Handle) -> void:
	if not h.is_open(): return
	var vs := _vs(h)
	var prof := profile(vs)
	var c := h.card
	if h.bz and h.form in ["dialog", "drawer", "panel"]:
		_fit_bz(h); return
	match h.form:
		"panel":
			var w: float = minf(vs.x - 16.0, clampf(vs.x * 0.9, 640.0, 960.0))
			var hh: float = minf(vs.y * 0.88, 600.0) if prof == "D" else vs.y * 0.92
			c.position = ((vs - Vector2(w, hh)) * 0.5).floor(); c.size = Vector2(w, hh)
			c.custom_minimum_size = Vector2(w, hh)
		"page":
			c.position = Vector2.ZERO; c.size = vs; c.custom_minimum_size = vs
		"drawer":
			if drawer_rect_fn.is_valid() and prof != "P":
				var dr: Rect2 = drawer_rect_fn.call()
				if dr.size.x > 100.0:
					c.position = dr.position; c.size = dr.size; c.custom_minimum_size = dr.size
					return
			var w2: float = {"D": 400.0, "L": 340.0, "S": 320.0}.get(prof, 400.0)
			var top_y := float(DRAWER_TOP); var bot := float(DRAWER_BOTTOM)
			var hh2: float = maxf(vs.y - top_y - bot, 220.0)
			c.position = Vector2(vs.x - w2 - 12.0, top_y); c.size = Vector2(w2, hh2); c.custom_minimum_size = Vector2(w2, hh2)
		"sheet":
			var avail: float = vs.y - float(SHEET_BOTTOM)
			var hs: float = clampf(vs.y * h.snap, 240.0, avail)
			c.position = Vector2(0, vs.y - float(SHEET_BOTTOM) - hs); c.size = Vector2(vs.x, hs); c.custom_minimum_size = Vector2(vs.x, hs)
		_:
			_fit_dialog(h)
	if h.form == "sheet" and h.root != null:
		h.root.mouse_filter = Control.MOUSE_FILTER_STOP if h.snap > 0.6 else Control.MOUSE_FILTER_IGNORE      # above 60 %: the map must not take orders

static func _queue_fit(h: Handle) -> void:
	if h.fit_pending or not h.is_open() or not (h.form == "dialog" or h.bz): return
	h.fit_pending = true
	_deferred_fit.call_deferred(h)

static func _deferred_fit(h: Handle) -> void:
	h.fit_pending = false
	if h.is_open(): _fit_bz(h) if (h.bz and h.form in ["dialog", "drawer", "panel"]) else _fit_dialog(h)

## a dialog is as tall as its content, capped to the viewport (a ScrollContainer reports zero height, so it is sized by hand)
static func _fit_dialog(h: Handle) -> void:
	if not h.is_open() or h.form != "dialog": return
	var vs := _vs(h)
	var portrait := is_portrait(vs)
	var w: float
	var aoc_side: bool = false
	if h.wide and not portrait and vs.x >= 720.0: w = minf(vs.x - 32.0, 700.0)
	elif aoc_side: w = clampf(TBHudParts.R(620.0), 420.0, vs.x * 0.42)
	else: w = minf(vs.x - 32.0, 460.0 if portrait else 420.0)
	var c := h.card
	c.custom_minimum_size = Vector2(w, 0)
	var cap: float = vs.y - (24.0 if (portrait or h.short) else 40.0)
	if h.scroll != null:
		var chrome: float = 0.0
		if h.head != null: chrome += h.head.get_combined_minimum_size().y + 1.0
		if h.tabs_slot.visible: chrome += h.tabs_slot.get_combined_minimum_size().y
		if h.footer_wrap.visible: chrome += h.footer_wrap.get_combined_minimum_size().y
		var frame: float = 4.0 if not h.hero else float(h.pad * 2 + 8)
		var body_min: float = h.body_wrap.get_combined_minimum_size().y
		var avail: float = cap - chrome - frame
		if h.pinned != null:
			var pm: float = h.pinned.get_combined_minimum_size().y
			if h.split_wide:
				h.scroll.custom_minimum_size.y = clampf(maxf(body_min, pm), 40.0, maxf(avail, 40.0))
				h.pinned_sc.custom_minimum_size.y = 0.0
			else:
				var ph: float = minf(pm, avail * 0.6)
				h.pinned_sc.custom_minimum_size.y = ph
				h.scroll.custom_minimum_size.y = clampf(body_min, 40.0, maxf(avail - ph - 8.0, 40.0))
		else:
			h.scroll.custom_minimum_size.y = maxf(minf(body_min, avail), 40.0)
	c.size = Vector2(w, 0)
	c.reset_size()
	c.position = ((vs - c.size) * 0.5).floor()
	if aoc_side:
		var top_y: float = maxf(TBHudParts.R(112.0), 64.0)
		c.position = Vector2(vs.x - c.size.x - maxf(TBHudParts.R(150.0), 24.0), minf(top_y, maxf(8.0, vs.y - c.size.y - 8.0))).floor()

static func _snap(h: Handle, to: float) -> void:
	if not h.is_open(): return
	h.snap = to
	var vs := _vs(h)
	var avail: float = vs.y - float(SHEET_BOTTOM)
	var hs: float = clampf(vs.y * to, 240.0, avail)
	var target_pos := Vector2(0, vs.y - float(SHEET_BOTTOM) - hs)
	h.card.custom_minimum_size = Vector2(vs.x, hs)
	if K.motion_ok():
		var tw := h.card.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(h.card, "position", target_pos, 0.2); tw.tween_property(h.card, "size", Vector2(vs.x, hs), 0.2)
	else:
		h.card.position = target_pos; h.card.size = Vector2(vs.x, hs)
	h.root.mouse_filter = Control.MOUSE_FILTER_STOP if to > 0.6 else Control.MOUSE_FILTER_IGNORE

# ---- small shared builders ---------------------------------------------------------------------------------------------------------------
## wrapping paragraph
static func para(text: String, size: int = 15, color: Color = Color.TRANSPARENT) -> Label:
	var l := K.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 40
	return l

## section caption + hairline; at large text the caption wraps instead of widening the page
static func section(text: String) -> HBoxContainer:
	var h := K.section(text)
	if K.text_scale >= 1.4 and h.get_child_count() > 0 and h.get_child(0) is Label:
		var l: Label = h.get_child(0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size.x = 40; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

## row of equal wrapping chips
static func flow(sep: int = 6) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep); f.add_theme_constant_override("v_separation", sep)
	f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return f

## glyph + line + (why or next) + optional action (P-18)
static func empty_state(glyph_id: String, line: String, why: String = "", action_text: String = "", cb: Callable = Callable()) -> Control:
	var v := K.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gl := K.glyph(glyph_id, 40, TBTokens.c("ink_1")); gl.custom_minimum_size = Vector2(0, 46); gl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	gl.custom_minimum_size = Vector2(46, 46)
	v.add_child(gl)
	var l1 := para(line, 15, K.TEXT); l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l1)
	if why != "":
		var l2 := para(why, 13, K.DIM); l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(l2)
	if action_text != "":
		var b := K.button(action_text, cb); b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; v.add_child(b)
	return v

## caption left, figure right (ledger line without leader) as a 2-column grid
static func facts_grid(rows: Array, cols_pairs: int = 1) -> GridContainer:
	var g := GridContainer.new(); g.columns = 2 * cols_pairs
	g.add_theme_constant_override("h_separation", 14); g.add_theme_constant_override("v_separation", 6)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in rows:
		var cap := K.label(String(r[0]), 13, K.DIM)
		g.add_child(cap)
		var val := K.label(String(r[1]), 15, r[2] if r.size() > 2 else K.TEXT)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; val.size_flags_horizontal = Control.SIZE_EXPAND_FILL; val.custom_minimum_size.x = 40
		g.add_child(val)
	return g

# ---- toggle row (P-14): whole row is the target, label left, switch + visible On / Off word right ---------------------------------------------
class ToggleRow extends Button:
	var label_text := ""
	var on := false
	var cb := Callable()
	func _init(l: String, value: bool, callback: Callable) -> void:
		label_text = l; on = value; cb = callback
		flat = true; toggle_mode = false; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, TBKit.touch())
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		pressed.connect(func():
			on = not on; queue_redraw()
			if cb.is_valid(): cb.call(on))
		TBKit.a11y(self, l, "switch")
	func _draw() -> void:
		var w := size.x; var h := size.y
		var mode := get_draw_mode()
		if mode == BaseButton.DRAW_HOVER: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_1"))
		elif mode == BaseButton.DRAW_PRESSED: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_2"))
		if not TBTokens.is_hc(): draw_rect(Rect2(0, h - 1, w, 1), TBTokens.c("hair"))
		var f := TBKit.body_b()
		var fsz := TBKit.fs(15)
		var word: String = TBI18n.T("on") if on else TBI18n.T("off")
		var ww: float = f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		var ink: Color = TBTokens.c("ink_0")
		var ty := roundf((h - 1.0 - f.get_height(fsz)) * 0.5 + f.get_ascent(fsz))
		draw_string(f, Vector2(12, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, maxf(w - 24.0 - ww - 70.0, 40.0), fsz, ink)
		draw_string(f, Vector2(roundf(w - 12.0 - ww), ty), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, ink)
		# switch: 40 x 22 plate; on = ink fill with a cream square at the right, off = paper with an ink square at the left (position + word, not colour)
		var sx: float = roundf(w - 12.0 - ww - 12.0 - 40.0); var sy: float = roundf((h - 1.0 - 22.0) * 0.5)
		draw_rect(Rect2(sx, sy, 40, 22), TBTokens.c("rule"))
		draw_rect(Rect2(sx + 1, sy + 1, 38, 20), TBTokens.c("ink_0") if on else TBTokens.c("paper_1"))
		var kx: float = sx + (21.0 if on else 3.0)
		draw_rect(Rect2(kx, sy + 3, 16, 16), TBTokens.c("cream") if on else TBTokens.c("ink_0"))
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(false, 0, 2), Rect2(0, 0, w, h))

static func toggle(label_text: String, value: bool, cb: Callable) -> Button:
	return ToggleRow.new(label_text, value, cb)

# ---- confirmation dialog (P-16): L1 consequence / L2 data loss; default focus Cancel, the confirm names the act -------------------------------
static func confirm(parent: Control, title_text: String, text: String, confirm_label: String, on_yes: Callable, danger: bool = true, glyph_id: String = "warning", cancel_label: String = "", extra: Control = null) -> Handle:
	var h := open(parent, Kind.DIALOG, title_text, glyph_id, {"width": 420})
	h.body.add_child(para(text, 15))
	if extra != null: h.body.add_child(extra)
	var cancel := K.button(cancel_label if cancel_label != "" else T.call("cancel"), func(): h.close())
	var yes: Button
	if danger:                                                   # destructive: hold 600 ms (or Enter twice)
		var db := K.danger(confirm_label, Callable(), "warning") as K.DangerBtn
		db.make_hold()
		db.confirmed.connect(func(): h.close(); on_yes.call())
		yes = db
	else:
		yes = K.button(confirm_label, func(): h.close(); on_yes.call(), true)
	h.actions(cancel, yes)
	h.focus_target = cancel
	if wants_focus(): cancel.grab_focus.call_deferred()
	return h

# ---- card: command-card look with effect / cost chips (event choices, diplomacy and spy actions) ------------------------------------------------
class Card extends PanelContainer:
	signal activated
	var disabled := false
	var recommended := false
	var _hover := false
	var _down := false
	var _cb := Callable()
	## chips: [[text, glyph, tone], ...]; `below` puts them under the title (effects), otherwise at the right (cost)
	func _init(glyph_id: String, title_text: String, detail: String, chips: Array, cb: Callable, reason: String = "", rec: bool = false, below: bool = true) -> void:
		recommended = rec; _cb = cb; disabled = reason != ""
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_mode = Control.FOCUS_ALL; mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		custom_minimum_size = Vector2(0, 56)
		var row := TBKit.hbox(12); add_child(row)
		var ink: Color = TBTokens.c("ink_off") if disabled else TBTokens.c("ink_0")
		if glyph_id != "" and TBFrame.bezel:
			row.add_child(TBKit.ring_icon(glyph_id, 36, disabled))
		elif glyph_id != "":
			var tile := Control.new(); tile.custom_minimum_size = Vector2(32, 32); tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var ts := TBFrame.plate(TBTokens.c("paper_0"), TBTokens.c("hair"), 2, 0, 0, 0)
			tile.draw.connect(func():
				tile.draw_style_box(ts, Rect2(Vector2.ZERO, tile.size))
				TBGlyph.draw(tile, glyph_id, (tile.size * 0.5).round(), 20.0, ink))
			row.add_child(tile)
		var col := TBKit.vbox(3); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.size_flags_vertical = Control.SIZE_SHRINK_CENTER; col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := TBKit.label(TBKit._cap(title_text), 13 if TBFrame.bezel else 15, ink); t.add_theme_font_override("font", TBKit.tracked(TBKit.display(), 1) if TBFrame.bezel else TBKit.body_b())
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; t.mouse_filter = Control.MOUSE_FILTER_IGNORE; t.size_flags_horizontal = Control.SIZE_EXPAND_FILL; t.custom_minimum_size.x = 40
		col.add_child(t)
		if detail != "":
			var d := TBKit.label(detail, 13, TBTokens.c("ink_off") if disabled else TBTokens.c("ink_1")); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.mouse_filter = Control.MOUSE_FILTER_IGNORE; d.size_flags_horizontal = Control.SIZE_EXPAND_FILL; d.custom_minimum_size.x = 40
			col.add_child(d)
		var cf := HFlowContainer.new(); cf.add_theme_constant_override("h_separation", 6); cf.add_theme_constant_override("v_separation", 4); cf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for c in chips:
			var cc: Control = TBKit.chip(String(c[0]), String(c[1]) if c.size() > 1 else "", String(c[2]) if c.size() > 2 else "neutral")
			cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cf.add_child(cc)
		if TBFrame.bezel and not chips.is_empty():
			var fxv := TBKit.vbox(0); fxv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var rest: Array = []
			for c2 in chips:
				var gl2: String = String(c2[1]) if c2.size() > 1 else ""
				if gl2 == "tri_up" or gl2 == "tri_down":
					var fr: Control = TBKit.fx_row(String(c2[0]), String(c2[2]) if c2.size() > 2 else "neutral"); fr.mouse_filter = Control.MOUSE_FILTER_IGNORE; fxv.add_child(fr)
				else: rest.append(c2)
			if fxv.get_child_count() > 0: col.add_child(fxv)
			for c3 in cf.get_children(): c3.queue_free()
			for c4 in rest:
				var cc4: Control = TBKit.chip(String(c4[0]), String(c4[1]) if c4.size() > 1 else "", String(c4[2]) if c4.size() > 2 else "neutral")
				cc4.mouse_filter = Control.MOUSE_FILTER_IGNORE; cf.add_child(cc4)
			if not rest.is_empty(): col.add_child(cf)
		elif below and not chips.is_empty(): col.add_child(cf)
		if reason != "":
			var rr := TBKit.hbox(4); rr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rr.add_child(TBKit.glyph("lock", 14, TBTokens.c("neg")))
			var rl := TBKit.label(reason, 13, TBTokens.c("neg")); rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rl.custom_minimum_size.x = 40
			rr.add_child(rl); col.add_child(rr)
			tooltip_text = reason
		row.add_child(col)
		if not below and not TBFrame.bezel and not chips.is_empty():
			cf.size_flags_horizontal = Control.SIZE_SHRINK_END; cf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(cf)
		mouse_entered.connect(func(): _hover = true; _apply())
		mouse_exited.connect(func(): _hover = false; _apply())
		_apply()
	func _apply() -> void:
		var st := "disabled" if disabled else ("pressed" if _down else ("hover" if _hover else "normal"))
		add_theme_stylebox_override("panel", TBKit.card_style(st, recommended, false))
	func _draw() -> void:
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(false, 4, 0), Rect2(Vector2.ZERO, size))
	func _gui_input(e: InputEvent) -> void:
		if disabled: return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				_down = true; _apply()
			else:
				var fire := _down and Rect2(Vector2.ZERO, size).has_point(e.position)
				_down = false; _apply()
				if fire: _fire()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			_fire(); accept_event()
	func _fire() -> void:
		activated.emit()
		if _cb.is_valid(): _cb.call()

static func card(glyph_id: String, title_text: String, detail: String, chips: Array, cb: Callable, reason: String = "", rec: bool = false, below: bool = true) -> Card:
	return Card.new(glyph_id, title_text, detail, chips, cb, reason, rec, below)

# ---- selectable chip button (filters, tiers, legend toggles): selected = paper-2 fill + 3 px oxblood bar + check glyph (never a black slab, never colour alone) ----
class ChipBtn extends Button:
	var on := false
	func _init(txt: String, selected: bool, cb: Callable) -> void:
		text = txt; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, TBKit.touch() - 8)
		if cb.is_valid(): pressed.connect(cb)
		set_on(selected)
	func set_on(v: bool) -> void:
		on = v
		var fills: Array = ["paper_2", "paper_2", "paper_2"] if on else ["paper_0", "paper_hover", "paper_2"]
		var border: String = "ink_1" if on else "rule"
		var sf := TBKit._pl(fills[0], border, 4, 0, 10.0, 6); if on: sf.set_content_margin(SIDE_LEFT, 28.0)
		var hf := TBKit._pl(fills[1], border, 4, 0, 10.0, 6); if on: hf.set_content_margin(SIDE_LEFT, 28.0)
		var pf := TBKit._pl(fills[2], border, 4, 0, 10.0, 6); if on: pf.set_content_margin(SIDE_LEFT, 28.0)
		add_theme_stylebox_override("normal", sf); add_theme_stylebox_override("hover", hf)
		add_theme_stylebox_override("pressed", pf); add_theme_stylebox_override("hover_pressed", pf)
		add_theme_font_size_override("font_size", TBKit.fs(14))
		add_theme_font_override("font", TBKit.body_b() if on else TBKit.body())
		add_theme_stylebox_override("focus", TBFrame.focus(false, 4, 0))
		var tc: Color = TBTokens.c("ink_0")
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: add_theme_color_override(fc, tc)
		queue_redraw()
	func _draw() -> void:
		if on:
			TBGlyph.draw_filled(self, "check", Vector2(15, roundf(size.y * 0.5)), 14.0, TBTokens.c("oxblood"))
			draw_rect(Rect2(4, size.y - 3, size.x - 8, 3), TBTokens.c("oxblood"))


# ---- compact segmented control: 40 high, selected = paper-2 fill + heavier text + 3 px oxblood bottom bar (the lighter treatment of art review A-2) ----
class SegCell extends Button:
	var on := false
	func _draw() -> void:
		if on: draw_rect(Rect2(0, size.y - 3, size.x, 3), TBTokens.c("oxblood"))

class Seg extends PanelContainer:
	signal chosen(id: String)
	var current := ""
	var _btns := {}
	func setup(items: Array, cur: String) -> Seg:
		current = cur
		add_theme_stylebox_override("panel", TBKit._empty if TBFrame.bezel else TBFrame.plate(TBTokens.c("rule"), TBTokens.c("rule"), 4, 0, 1, 1))
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 6 if TBFrame.bezel else 1); add_child(row)
		var n := items.size()
		for i in n:
			var id: String = items[i][0]
			var b := SegCell.new(); b.text = String(items[i][1]); b.focus_mode = Control.FOCUS_ALL; b.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b.custom_minimum_size = Vector2(0, (TBKit.touch() if TBKit.touch_large else 28) if TBFrame.bezel else TBKit.touch() - 8)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.set_meta("mask", (TBFrame.TL | TBFrame.BL if i == 0 else 0) | (TBFrame.TR | TBFrame.BR if i == n - 1 else 0))
			b.pressed.connect(func(): select(id, true))
			row.add_child(b); _btns[id] = b
		_restyle()
		return self
	func select(id: String, emit: bool = false) -> void:
		current = id; _restyle()
		if emit: chosen.emit(id)
	func _restyle() -> void:
		for k in _btns:
			var b: SegCell = _btns[k]
			var on: bool = k == current
			if TBFrame.bezel:
				TBBz.style_cell(b, on); b.on = on; continue
			var m: int = b.get_meta("mask")
			var fills: Array = ["paper_2", "paper_2", "paper_2"] if on else ["paper_0", "paper_hover", "paper_2"]
			b.add_theme_stylebox_override("normal", TBKit._pl(fills[0], "", 4, 0, 10.0, 6, false, 1.0, m))
			b.add_theme_stylebox_override("hover", TBKit._pl(fills[1], "", 4, 0, 10.0, 6, false, 1.0, m))
			b.add_theme_stylebox_override("pressed", TBKit._pl(fills[2], "", 4, 0, 10.0, 6, false, 1.0, m))
			b.add_theme_stylebox_override("hover_pressed", TBKit._pl(fills[2], "", 4, 0, 10.0, 6, false, 1.0, m))
			b.add_theme_stylebox_override("focus", TBFrame.focus(false, 0, 2))
			b.add_theme_font_override("font", TBKit.body_b() if on else TBKit.body())
			b.add_theme_font_size_override("font_size", TBKit.fs(14))
			var tc: Color = TBTokens.c("ink_0")
			for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: b.add_theme_color_override(fc, tc)
			b.on = on
			b.set_pressed_no_signal(false)
			b.tooltip_text = b.text if on else ""
			b.queue_redraw()

static func seg(items: Array, current: String, cb: Callable) -> Seg:
	var s := Seg.new().setup(items, current)
	s.chosen.connect(cb)
	return s

static func chip_button(txt: String, selected: bool, cb: Callable) -> ChipBtn:
	return ChipBtn.new(txt, selected, cb)

## a nation as a small button: flag + name (jumps to that nation)
static func nation_button(g: TBGame, n: int, cb: Callable) -> Button:
	var b := K.button(g.dname(n), cb)
	b.icon = TBFlags.texture(g.nat_code[n], g.color[n]); b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 24)
	b.custom_minimum_size = Vector2(0, K.touch() - 8)
	b.clip_text = false
	return b

## flag + name (+ a mono figure) as a static tag, e.g. the great powers of an era
static func flag_tag(tex: Texture2D, text: String, figure: String = "") -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_1"), TBTokens.c("rule"), TBTokens.CUT_CHIP, 0, 8, 4))
	pc.custom_minimum_size = Vector2(0, 32); pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := K.hbox(6); h.mouse_filter = Control.MOUSE_FILTER_IGNORE; pc.add_child(h)
	if tex != null:
		var tr := TextureRect.new(); tr.texture = tex; tr.custom_minimum_size = Vector2(24, 16); tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tr.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(tr)
	var l := K.label(text, 14, TBTokens.c("ink_0")); l.add_theme_font_override("font", K.body_b()); l.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(l)
	if figure != "":
		var n := K.num(figure, 12, TBTokens.c("ink_1")); n.size_flags_vertical = Control.SIZE_SHRINK_CENTER; h.add_child(n)
	return pc

# ---- flat entry: a wrapping text row with an optional leading glyph, hairline below, whole row is the target (Annals, alerts) --------------------------
class Entry extends PanelContainer:
	signal activated
	var _cb := Callable()
	var _hover := false
	var _down := false
	func _init(text: String, glyph_id: String, text_col: Color, cb: Callable, glyph_col: Color = Color.TRANSPARENT, trailing: String = "") -> void:
		_cb = cb
		custom_minimum_size = Vector2(0, TBKit.touch())
		var interactive := cb.is_valid()
		focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
		if interactive: mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_theme_stylebox_override("panel", TBFrame.plate(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 10, 8, false, 0))
		var row := TBKit.hbox(10); row.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(row)
		if glyph_id != "":
			var gl := TBKit.glyph(glyph_id, 18, glyph_col if glyph_col.a > 0.0 else text_col); gl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; gl.custom_minimum_size = Vector2(20, 22)
			row.add_child(gl)
		var l := TBKit.label(text, 14, text_col); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.custom_minimum_size.x = 40
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE; l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
		if trailing != "":
			var tg := TBKit.glyph(trailing, 18, TBTokens.c("ink_1")); tg.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(tg)
		if interactive:
			mouse_entered.connect(func(): _hover = true; queue_redraw())
			mouse_exited.connect(func(): _hover = false; queue_redraw())
			TBKit.a11y(self, text, "button")
	func _draw() -> void:
		if _down: draw_rect(Rect2(0, 0, size.x, size.y - 1), TBTokens.c("paper_2"))
		elif _hover: draw_rect(Rect2(0, 0, size.x, size.y - 1), TBTokens.c("paper_1"))
		if not TBTokens.is_hc(): draw_rect(Rect2(0, size.y - 1, size.x, 1), TBTokens.c("hair"))
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(false, 0, 2), Rect2(Vector2.ZERO, size))
	func _gui_input(e: InputEvent) -> void:
		if not _cb.is_valid(): return
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: _down = true; queue_redraw()
			else:
				var fire := _down and Rect2(Vector2.ZERO, size).has_point(e.position)
				_down = false; queue_redraw()
				if fire: activated.emit(); _cb.call()
			accept_event()
		elif e.is_action_pressed("ui_accept"):
			activated.emit(); _cb.call(); accept_event()

static func entry(text: String, glyph_id: String, text_col: Color, cb: Callable, glyph_col: Color = Color.TRANSPARENT, trailing: String = "") -> Entry:
	return Entry.new(text, glyph_id, text_col, cb, glyph_col, trailing)
