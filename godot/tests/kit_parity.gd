extends SceneTree
## Bezel kit parity sheet: the Godot twin of docs/ui_variants/src/b_kitparity.html (render the demo side with docs/ui_variants/shoot_kit.mjs).
## 1 logical unit = 1 pixel, window 1280 x 1180; the same specimens at the same coordinates. Compare with tools/kit_cmp.py (see tools/kit_parity.sh).
##   TB_NOANIM=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 -s tests/kit_parity.gd -- /tmp/par3/kit_gd.png [--dump]
const K = preload("res://src/ui/ui_kit.gd")
const W := 1280
const H := 1180

static func place(parent: Control, c: Control, x: float, y: float, w: float = 0.0) -> void:
	c.position = Vector2(x, y)
	if w > 0.0: c.custom_minimum_size.x = w; c.size.x = w
	parent.add_child(c)

static func row(sep: int, kids: Array) -> HBoxContainer:
	var h := K.hbox(sep)
	for k in kids: h.add_child(k)
	return h

static func _lab(t: String, size: float, face: Font, col: Color) -> Control:
	var l := TBBz.TLabel.new(face, size, 0.0)
	l.text = t; l.add_theme_color_override("font_color", col)
	return l

## the budget-like drawer (`panel()` of the demo): header, gauge + leader rows, three slider blocks, footer
static func drawer(r: Control) -> void:
	var hd := TBPanel.open(r, TBPanel.Kind.DRAWER, "Budget", "treasury", {"w": 560, "sub": "Net income +629 gold per turn", "pos": Vector2(24, 25), "scrim": false})
	hd.body.add_theme_constant_override("separation", 0)
	var top := K.hbox(18)
	var gw := MarginContainer.new(); gw.add_theme_constant_override("margin_right", 8); gw.add_theme_constant_override("margin_bottom", 5); gw.add_child(K.gauge(40, "+629", "PER TURN", 0.52, K.GREEN)); gw.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(gw)
	var rc := K.vbox(0); rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rc.add_child(K.caps("NET INCOME"))
	var mt := MarginContainer.new(); mt.add_theme_constant_override("margin_top", 6)
	mt.add_child(K.fxl([["Taxes", "+640", 1], ["Trade", "+180", 1], ["Provinces", "0", 0], ["Upkeep", "−62", -1], ["Spending", "−67", -1]]))
	rc.add_child(mt); top.add_child(rc)
	var tm := MarginContainer.new(); tm.add_theme_constant_override("margin_bottom", 12); tm.add_child(top)
	hd.body.add_child(tm)
	var g := K.vbox(14)
	g.add_child(K.srow("tax", "Tax", 0, 100, 5, 50, Callable(), Callable(), func(v): return "Tolerable" if v <= 50 else "People grow restless", 50))
	var s2 := K.srow("happy", "Public goods", 0, 100, 5, 20, Callable(), Callable(), func(v): return "+%d happiness / turn" % roundi(v * 0.3))
	g.add_child(s2)
	s2.slider._hot = true; s2.minus.preview_state = "hover"
	g.add_child(K.srow("research", "Research", 0, 100, 5, 15, Callable(), Callable(), func(v): return "%s research points / turn" % str(snappedf(v * 0.44, 0.1))))
	hd.body.add_child(g)
	hd.actions(K.button("Revert"), K.button("Done", Callable(), true))

## builds every specimen into `r` (a Control 1280 x 1180)
static func build(r: Control) -> void:
	drawer(r)
	var b1 := K.button("Secondary"); var b2 := K.button("Primary", Callable(), true); var b3 := K.danger("Danger", Callable(), ""); var b4 := K.button("Small", Callable(), false, true)
	var b5 := K.button("Disabled"); b5.disabled = true
	place(r, row(14, [b1, b2, b3, b4, b5]), 640, 24)
	var h1 := K.button("Hover"); h1.preview_state = "hover"
	var h2 := K.button("Hover", Callable(), true); h2.preview_state = "hover"
	var h3 := K.danger("Hover", Callable(), ""); h3.preview_state = "hover"
	var h4 := K.button("Active"); h4.preview_state = "pressed"
	var h5 := K.button("Disabled", Callable(), true); h5.disabled = true
	place(r, row(14, [h1, h2, h3, h4, h5]), 640, 76)
	var i1 := K.button("With icon", Callable(), false, false, "recruit", "8 g")
	var i2 := K.danger("Attack", Callable(), "attack"); i2.kbd = "↵"; i2._refit()
	var i3 := K.button("Sm", Callable(), false, true, "close")
	place(r, row(14, [i1, i2, i3]), 640, 128)
	# round things
	var x1 := K.IconBtn.new("close", Callable(), 36); var x2 := K.IconBtn.new("close", Callable(), 36); x2.preview_state = "hover"
	var st1 := TBBzParts.Stp.new("−"); var st2 := TBBzParts.Stp.new("+"); st2.preview_state = "hover"
	var rr := row(18, [K.ring_icon("annals", 46), x1, x2, st1, st2, K.ring_icon("war", 38), K.ring_icon("pact", 36)])
	rr.add_theme_constant_override("separation", 18)
	place(r, rr, 640, 184)
	# marks and leaders
	var mv := K.vbox(6)
	mv.add_child(K.chip("+8% tax", "", "pos")); mv.add_child(K.chip("−3 happiness", "", "neg")); mv.add_child(K.chip("2 envoys", "", "info")); mv.add_child(K.chip("Neutral"))
	var mm := MarginContainer.new(); mm.add_theme_constant_override("margin_top", 4)
	mm.add_child(row(14, [K.mark("Good", "good"), K.mark("Bad", "bad"), K.mark("Info", "info"), K.mark("Zero", "zero")]))
	mv.add_child(mm)
	place(r, mv, 640, 250, 260)
	place(r, K.fxl([["Conscription law", "+8", 1], ["Civil code", "−3", -1], ["Continental system", "12%", 1], ["Truce", "ends", 0], ["Relations", "−20", -1]]), 930, 252, 320)
	# rows
	var rv := K.vbox(0)
	for it in [["war", "Normal row", ""], ["pact", "Hover row", "hover"], ["trade", "Selected row", "on"]]:
		var rb := K.row_box(12, 10)
		var hb := K.hbox(14)
		hb.add_child(K.ring_icon(it[0], 34)); hb.add_child(_lab(it[1], 16.0, K.alegreya(400), TBTokens.c("ink_0")))
		rb.add_child(hb)
		if it[2] == "hover": rb.preview_state = "hover"
		if it[2] == "on": rb.selected = true
		rv.add_child(rb)
	place(r, rv, 640, 404, 300)
	place(r, K.tabs([["a", "All"], ["b", "War"], ["c", "Diplomacy"], ["d", "Economy"]], "a", func(_i): pass), 960, 404, 300)
	var tb := MarginContainer.new(); tb.add_theme_constant_override("margin_top", 6); tb.add_child(K.tbl([["Taxes", "+640"], ["Trade", "+180"], ["Net", "+758", true]]))
	place(r, tb, 960, 462, 300)
	# tooltip, notices
	var tp := K.tip("Treasury", "Gold in the treasury. Next turn [b][color=#69B3A2]+731[/color][/b].", "B", true)
	place(r, tp, 640, 573)
	r.set_meta("tip", tp)
	var nv := K.vbox(14)
	var ns: Array = []
	for it in [["bad", "warn", "Austria masses troops on your border"], ["dip", "envoys", "Spain proposes a pact"], ["good", "check", "Turn 3 ended: +629 gold"], ["info", "info", "Spanish envoys arrive in Paris."]]:
		var n := K.notice(it[0], it[1], it[2]); n.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nv.add_child(n); ns.append(n)
	ns[1].preview_hover = true
	place(r, nv, 940, 572, 330)
	# menu list
	var mp := PanelContainer.new(); mp.add_theme_stylebox_override("panel", TBBz.plate_box(8.0, true))
	var mg := MarginContainer.new()
	for sd in ["left", "right", "top", "bottom"]: mg.add_theme_constant_override("margin_" + sd, 6)
	mp.add_child(mg)
	var mvv := K.vbox(0); mg.add_child(mvv)
	var idx := 0
	for it in [["check", "Resume", "Esc"], ["save", "Save game", "S"], ["settings", "Settings", ""]]:
		var rb2 := K.row_box(12, 10); if idx == 1: rb2.preview_state = "hover"
		var hb2 := K.hbox(14)
		hb2.add_child(K.glyph(it[0], 18, TBTokens.c("brass_lt")))
		var tl := K.title(it[1], 12, TBTokens.c("ink_0"), 0.14, 0.0); (tl as TBBz.TLabel).px = 12.5; (tl as TBBz.TLabel).refit(); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb2.add_child(tl)
		hb2.add_child(_lab(it[2], 10.5, K.jbm(), TBTokens.c("ink_off")))
		rb2.add_child(hb2); mvv.add_child(rb2); idx += 1
	mp.custom_minimum_size.x = 250
	place(r, mp, 640, 731)
	# gauges
	place(r, row(10, [K.gauge(34, "172", "", 0.62, TBTokens.c("brass")), K.gauge(34, "87%", "", 0.87, K.GREEN)]), 940, 800)
	# scrim + modal
	var bgc := ColorRect.new(); bgc.color = Color("2A3A4A"); bgc.position = Vector2(24, 700); bgc.size = Vector2(580, 420); r.add_child(bgc)
	var scr := ColorRect.new(); scr.color = TBTokens.BZ_SCRIM; scr.position = Vector2(24, 700); scr.size = Vector2(580, 420); r.add_child(scr)
	var md := TBPanel.open(r, TBPanel.Kind.DIALOG, "Declare war?", "war", {"w": 460, "pos": Vector2(84, 741), "scrim": false})
	md.body.add_theme_constant_override("separation", 0)
	md.body.add_child(K.para_bz("Casus belli: border dispute. It costs [b][color=#EFE6CF]3 envoys[/color][/b], drops your standing with every neutral court and cannot be undone.", 17.0, 1.4, K.DIM))
	var fm := MarginContainer.new(); fm.add_theme_constant_override("margin_top", 12)
	fm.add_child(K.fxl([["Envoys", "−3", -1], ["Relations (neutral courts)", "−20", -1], ["Truce", "ends", 0]]))
	md.body.add_child(fm)
	md.actions(K.button("Cancel"), K.danger("Hold to declare war", Callable(), "war"))

func _init() -> void:
	var out: String = "/tmp/par3/kit_gd.png"
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: out = ua[0]
	TBTokens.legacy = false; K.serif = true; TBFrame.rounded = false; TBFrame.bezel = true
	TBI18n.load_lang("en")
	if "--hc" in ua: TBTokens.mode = TBTokens.Mode.HIGH_CONTRAST
	if "--hcd" in ua: TBTokens.mode = TBTokens.Mode.HC_DARK
	if "--scale" in ua: K.text_scale = float(ua[ua.find("--scale") + 1])
	await process_frame
	var vp := SubViewport.new(); vp.size = Vector2i(W, H); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var r := Control.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.theme = K.theme(); vp.add_child(r)
	var bg := ColorRect.new(); bg.color = TBTokens.c("table"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); r.add_child(bg)
	await process_frame
	build(r)
	for i in 10: await process_frame
	vp.get_texture().get_image().save_png(out)
	if "--dump" in ua:
		_dump(r, "")
		_dump_tree(r.get_meta("tip"), "")
	print("KIT PARITY written to ", out)
	quit()

## prints the global rect of every Button / Label under n (compare with docs/ui_variants/measure_kit.mjs)
func _dump(n: Node, ind: String) -> void:
	for c in n.get_children():
		if c is HSlider or c is TextureRect:
			var sc := c as Control
			print("DUMP Slider\t\t%.2f\t%.2f\t%.2f\t%.2f" % [sc.global_position.x, sc.global_position.y, sc.size.x, sc.size.y])
		if c is Button or c is Label:
			var cc := c as Control
			print("DUMP %s\t%s\t%.2f\t%.2f\t%.2f\t%.2f" % [c.get_class(), String(c.get("text")).substr(0, 18), cc.global_position.x, cc.global_position.y, cc.size.x, cc.size.y])
			if c is Label and String(c.get("text")) == "Declare war?": print("DBG vis ", (c as Label).visible_characters, " native ", c.get("_native"), " fs ", (c as Label).get_theme_font_size("font_size"), " col ", (c as Label).get_theme_color("font_color"), " visible ", cc.is_visible_in_tree(), " mod ", cc.modulate)
		_dump(c, ind + " ")

func _dump_tree(n: Node, ind: String) -> void:
	if n is TBBz.TLabel: print("TL px ", n.px, " fsz ", n.fsz(), " lh ", n.lh, " line_h ", n.line_h(), " asc ", TBBz.ascent(n.face, n.fsz()), " desc ", TBBz.descent(n.face, n.fsz()), " min ", n.custom_minimum_size)
	if n is Control: print("TREE ", ind, n.get_class(), " ", (n as Control).global_position, " ", (n as Control).size)
	for c in n.get_children(): _dump_tree(c, ind + "  ")
