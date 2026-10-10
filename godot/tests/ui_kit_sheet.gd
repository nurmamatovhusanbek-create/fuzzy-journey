extends SceneTree
## Specimen boards of every kit control in all states -> /tmp/ui_foundation/*.png (art bible 7.5 check).
## TB_NOANIM=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 -s tests/ui_kit_sheet.gd
const K = preload("res://src/ui/ui_kit.gd")
const KP = preload("res://tests/kit_parity.gd")      # the Bezel specimen sheet (same specimens as docs/ui_variants/src/b_kitparity.html)
var OUT := "/tmp/ui_foundation"          # first user arg overrides

## mode: 0 normal, 1 high contrast light, 2 high contrast dark; scale = text size step (1.0 / 1.25 / 1.5 / 2.0)
func _board(file: String, size: Vector2i, builder: Callable, mode: int = 0, kbd: bool = true, scale: float = 1.0) -> void:
	TBTokens.mode = mode
	K.text_scale = scale
	TBFrame.kbd_nav = kbd
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.theme = K.theme()
	vp.add_child(r)
	var bg := ColorRect.new(); bg.color = TBTokens.c("table"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); r.add_child(bg)
	builder.call(r)
	for i in 6: await process_frame
	vp.get_texture().get_image().save_png("%s/%s.png" % [OUT, file])
	vp.queue_free()
	await process_frame

func _panel(parent: Control, pos: Vector2, w: float, title_text: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.position = pos; pc.custom_minimum_size = Vector2(w, 0)
	parent.add_child(pc)
	var v := K.vbox(8)
	pc.add_child(v)
	v.add_child(K.title(title_text, 20))
	return v

func _focus(c: Control, bar: bool = false, cut: int = 4, inset: int = 0) -> void:
	c.draw.connect(func(): c.draw_style_box(TBFrame.focus(bar, cut, inset), Rect2(Vector2.ZERO, c.size)))

func _st(b: Button, state: String) -> void:           # freeze a Button in a state through the theme's own styleboxes
	var t: Theme = b.get_theme() if b.get_theme() != null else K.theme()
	var tv: String = b.theme_type_variation if b.theme_type_variation != &"" else "Button"
	b.add_theme_stylebox_override("normal", t.get_stylebox(state, tv))

func _controls(r: Control) -> void:
	var p := _panel(r, Vector2(16, 16), 460, "Buttons and inputs")
	p.add_child(K.caps("Secondary: default, hover, pressed"))
	var row := K.hbox(8); p.add_child(row)
	var b1 := K.button("Default"); row.add_child(b1)
	var b2 := K.button("Hover"); _st(b2, "hover"); row.add_child(b2)
	var b3 := K.button("Pressed"); _st(b3, "pressed"); row.add_child(b3)
	var row2 := K.hbox(8); p.add_child(row2)
	var b4 := K.button("Disabled"); K.disable(b4, "Needs 3 diplomacy"); row2.add_child(b4)
	var b5 := K.button("Focused"); _focus(b5); row2.add_child(b5)
	p.add_child(K.caps("Primary (one per container)"))
	var row3 := K.hbox(8); p.add_child(row3)
	var p1 := K.button("Recruit", Callable(), true); row3.add_child(p1)
	var p2 := K.button("Hover", Callable(), true); _st(p2, "hover"); row3.add_child(p2)
	var p3 := K.button("Pressed", Callable(), true); _st(p3, "pressed"); row3.add_child(p3)
	var row4 := K.hbox(8); p.add_child(row4)
	var p4 := K.button("Disabled", Callable(), true); p4.disabled = true; row4.add_child(p4)
	var p5 := K.button("Focused", Callable(), true); _focus(p5); row4.add_child(p5)
	p.add_child(K.caps("Danger (flat wax)"))
	var row5 := K.hbox(8); p.add_child(row5)
	row5.add_child(K.danger("Declare war"))
	var d2 := K.danger("Hover"); _st(d2, "hover"); row5.add_child(d2)
	var row6 := K.hbox(8); p.add_child(row6)
	var d3 := K.danger("Disabled"); d3.disabled = true; row6.add_child(d3)
	var d4 := K.danger("Focused", Callable(), "skull"); _focus(d4, true); row6.add_child(d4)
	var d5 := K.danger("Pressed"); _st(d5, "pressed"); row6.add_child(d5)
	p.add_child(K.caps("Text input"))
	var le := LineEdit.new(); le.text = "Samarkand"; p.add_child(le)
	var le2 := LineEdit.new(); le2.placeholder_text = "Search nations"; p.add_child(le2)
	p.add_child(K.caps("Slider 0 / 50 / 100, disabled"))
	for val in [0.0, 50.0, 100.0]:
		p.add_child(K.slider(0, 100, 5, val))
	var sd := K.slider(0, 100, 5, 40); sd.editable = false; p.add_child(sd)
	var sf := K.slider(0, 100, 5, 70); p.add_child(sf)
	sf.grab_focus.call_deferred()
	p.add_child(K.caps("Slider with steppers"))
	p.add_child(K.slider_row("Music", 0, 100, 5, 80))
	var p2c := _panel(r, Vector2(490, 16), 390, "Segmented, tabs, rows")
	p2c.add_child(K.caps("Segmented"))
	p2c.add_child(K.segmented([["25", "25%"], ["50", "50%"], ["75", "75%"], ["100", "100%"]], "50", func(_i): pass))
	var seg2 := K.segmented([["a", "Standard"], ["b", "Large"], ["c", "Large 150"]], "a", func(_i): pass)
	p2c.add_child(seg2)
	p2c.add_child(K.caps("Tabs"))
	p2c.add_child(K.tabs([["a", "Orders"], ["b", "Ledger"], ["c", "Notes"]], "b", func(_i): pass))
	p2c.add_child(K.caps("Toggles"))
	p2c.add_child(K.toggle("Reduce motion", true))
	p2c.add_child(K.toggle("Readable fonts", false))
	p2c.add_child(K.caps("Compact segmented (filter chips, wraps)"))
	p2c.add_child(K.segmented([["a", "All"], ["b", "Earned"], ["c", "Locked"], ["d", "Wars"], ["e", "Diplomacy"], ["f", "Events"]], "b", func(_i): pass, true))
	p2c.add_child(K.caps("List rows"))
	var lr1 := K.list_row("Byzantium", "1 204", Callable()); p2c.add_child(lr1)
	var lr2 := K.list_row("Hover row", "88", Callable()); lr2.preview_state = "hover"; p2c.add_child(lr2)
	var lr3 := K.list_row("Selected row", "312", Callable()); lr3.selected = true; p2c.add_child(lr3)
	var lr4 := K.list_row("Focused row", "5", Callable()); lr4.preview_state = "focus"; p2c.add_child(lr4)
	var lr5 := K.list_row("A very long nation name that must be trimmed with an ellipsis", "12.4k", Callable()); p2c.add_child(lr5)
	p2c.add_child(K.caps("Meters 80 / 40 / 20, pips"))
	p2c.add_child(K.meter_row("Stability", 80, Color.TRANSPARENT))
	p2c.add_child(K.meter_row("Loyalty", 40, Color.TRANSPARENT))
	p2c.add_child(K.meter_row("Supply", 20, Color.TRANSPARENT))
	var pr := K.hbox(12); pr.add_child(K.Pips.new(3, 5)); pr.add_child(K.Pips.new(1, 5)); p2c.add_child(pr)
	p2c.add_child(K.row("Income", "+608", K.GREEN))
	var p3c := _panel(r, Vector2(896, 16), 370, "Command cards, chips")
	p3c.add_child(K.command_card("swords", "Recruit levies", "+15 men this turn", "120", func(): pass))
	p3c.add_child(K.command_card("flag", "Fortify (recommended)", "+1 defence for 3 turns", "60", func(): pass, "", true))
	var armed := K.command_card("swords", "Move army (armed)", "Choose a target province", "", func(): pass, "", false, true)
	p3c.add_child(armed)
	var hv := K.command_card("coin", "Hover card", "State preview", "40", func(): pass); hv.preview_state = "hover"; p3c.add_child(hv)
	var fc := K.command_card("coin", "Focused card", "State preview", "40", func(): pass); fc.preview_state = "focus"; p3c.add_child(fc)
	p3c.add_child(K.command_card("crown", "Build Palace", "+3 stability in the province", "900", func(): pass, "Needs 900 gold, you have 410", false, false, true))
	p3c.add_child(K.command_card("scroll", "Sign treaty", "", "", func(): pass, "Needs 3 diplomacy"))
	p3c.add_child(K.caps("Chips: neutral, pos, neg, warn, info, own"))
	var cr := K.hbox(6); p3c.add_child(cr)
	cr.add_child(K.chip("Peace")); cr.add_child(K.chip("+608", "", "pos")); cr.add_child(K.chip("−42", "", "neg"))
	var cr2 := K.hbox(6); p3c.add_child(cr2)
	cr2.add_child(K.chip("Low supply", "", "warn")); cr2.add_child(K.chip("Ally", "link", "info")); cr2.add_child(K.chip("Own", "", "own"))
	p3c.add_child(K.caps("Icon buttons (hit 48, visual 40)"))
	var ir := K.hbox(8); p3c.add_child(ir)
	ir.add_child(K.icon_button("close", Callable()))
	var i2 := K.IconBtn.new("gear", Callable()); i2.preview_state = "hover"; ir.add_child(i2)
	var i3 := K.IconBtn.new("save", Callable()); i3.preview_state = "pressed"; ir.add_child(i3)
	var i4 := K.IconBtn.new("pin", Callable()); i4.preview_state = "focus"; ir.add_child(i4)
	var i5 := K.IconBtn.new("lock", Callable()); i5.disabled = true; ir.add_child(i5)

func _furniture(r: Control) -> void:
	# bar strip
	var bar := PanelContainer.new(); bar.add_theme_stylebox_override("panel", TBFrame.bar(12, 4)); bar.position = Vector2(0, 0); bar.custom_minimum_size = Vector2(1280, 48); r.add_child(bar)
	var h := K.hbox(6); bar.add_child(h)
	h.add_child(K.title("Byzantium", 16, K.BRASS_LT))
	var sp := Control.new(); sp.custom_minimum_size = Vector2(24, 0); h.add_child(sp)
	h.add_child(K.chip("1 204", "coin", "neutral", true)); h.add_child(K.chip("+608", "", "pos", true)); h.add_child(K.chip("−42", "", "neg", true))
	h.add_child(K.chip("Low supply", "", "warn", true)); h.add_child(K.chip("Ally", "link", "info", true)); h.add_child(K.chip("Own", "", "own", true))
	var ib := K.IconBtn.new("globe", Callable(), 40, true); h.add_child(ib)
	var ib2 := K.IconBtn.new("gear", Callable(), 40, true); ib2.preview_state = "hover"; h.add_child(ib2)
	var ib3 := K.IconBtn.new("book", Callable(), 40, true); ib3.active = true; ib3.preview_state = "focus"; h.add_child(ib3)
	var land := ColorRect.new(); land.color = Color("8A93A3"); land.position = Vector2(0, 70); land.size = Vector2(680, 130); r.add_child(land)
	# plates by elevation
	for i in 3:
		var pl := PanelContainer.new(); pl.position = Vector2(24 + i * 220, 90); pl.custom_minimum_size = Vector2(190, 90)
		pl.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.c("paper_0"), TBTokens.c("rule"), 6, i, 16, 12))
		pl.add_child(K.label("Plate elevation %d" % i, 15)); r.add_child(pl)
	# tooltip / toast like plates on bar ground
	var tp := PanelContainer.new(); tp.position = Vector2(700, 90); tp.add_theme_stylebox_override("panel", TBFrame.plate(TBTokens.ca("bar_0", 0.96), TBTokens.c("rule_dark"), 4, 0, 12, 8))
	var tl := K.label("Tooltip: 12 400 gold, +608 per turn", 14, K.CREAM); tp.add_child(tl); r.add_child(tp)
	# seal
	for i in 4:
		var sc := Control.new(); sc.position = Vector2(24 + i * 120, 220); sc.custom_minimum_size = Vector2(80, 80); sc.size = Vector2(80, 80); r.add_child(sc)
		var st := TBFrame.seal(i == 1, i == 2, i == 3)
		sc.draw.connect(func(): sc.draw_style_box(st, Rect2(Vector2.ZERO, sc.size)); TBGlyph.draw(sc, "chevrons", Vector2(40, 36), 28.0, TBTokens.c("on_wax")))
	# hero sheet
	var hs := PanelContainer.new(); hs.position = Vector2(560, 190); hs.custom_minimum_size = Vector2(680, 0); hs.add_theme_stylebox_override("panel", TBFrame.hero())
	r.add_child(hs)
	var hv := K.vbox(10); hs.add_child(hv)
	hv.add_child(K.title("An embassy arrives", 22))
	hv.add_child(K.ornament())
	var body := K.label("The envoys of the Sultan ask for passage through your western provinces and offer a hundred talents of gold.", 15); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("font", K.body_i()); hv.add_child(body)
	hv.add_child(K.choice_card("Grant passage", "+100 gold, relations +10", func(): pass, true))
	hv.add_child(K.choice_card("Refuse", "Relations −10", func(): pass))
	# type
	var tv := K.vbox(4); tv.position = Vector2(24, 340); r.add_child(tv)
	tv.add_child(K.title("PANEL TITLE Cinzel 700", 22)); tv.add_child(K.num("12 400  −1.2M  +608", 16)); tv.add_child(K.delta("▲ +608", K.GREEN))
	tv.add_child(K.caps("Caption caps 12 px")); tv.add_child(K.label("Body Alegreya 500 at fifteen pixels", 15, K.CREAM))
	tv.add_child(K.title("Заголовок на кириллице", 22)); tv.add_child(K.label("Русский текст в теле: Alegreya 500", 15, K.CREAM)); tv.add_child(K.caps("Подпись"))
	tv.add_child(K.title("Oʻzbekcha: gʻalaba", 22))
	# ground check: paper chips and glyph row
	var gp := PanelContainer.new(); gp.position = Vector2(560, 560); gp.custom_minimum_size = Vector2(680, 0); r.add_child(gp)
	var gr := K.hbox(10); gp.add_child(gr)
	for g in ["coin", "men", "swords", "warning", "info", "link", "lock", "check", "filter", "supply", "revolt", "capital", "general_star", "tri_up", "tri_down", "arrowhead"]:
		gr.add_child(K.glyph(g, 24, K.TEXT))

func _glyphs(r: Control) -> void:
	var ids := ["coin", "men", "swords", "scroll", "book", "eye", "flag", "globe", "scales", "coins", "trophy", "lamp", "save", "gear", "crown", "skull", "pin", "flask", "hourglass", "chevrons", "back", "close", "shield", "dove", "star", "warning", "info", "link", "lock", "check", "filter", "supply", "revolt", "capital", "general_star", "tri_up", "tri_down", "arrowhead", "diamond"]
	var paper := ColorRect.new(); paper.color = TBTokens.c("paper_0"); paper.position = Vector2(0, 0); paper.size = Vector2(1280, 360); r.add_child(paper)
	var sizes := [16, 20, 24, 32]
	for gi in ids.size():
		var cx := 40.0 + (gi % 20) * 62.0
		var cy0 := 40.0 + (gi / 20) * 170.0
		for si in sizes.size():
			var holder := Control.new(); holder.position = Vector2(cx, cy0 + si * 38); holder.size = Vector2(40, 36); r.add_child(holder)
			var gid: String = ids[gi]; var sz: int = sizes[si]
			holder.draw.connect(func():
				var col: Color = TBTokens.c("ink_0") if gi < 20 or true else Color.WHITE
				if gid == "general_star": col = TBTokens.c("brass_lt")
				TBGlyph.draw(holder, gid, Vector2(20, 18), float(sz), col))
	var barr := ColorRect.new(); barr.color = TBTokens.c("bar_0"); barr.position = Vector2(0, 380); barr.size = Vector2(1280, 340); r.add_child(barr)
	for gi in ids.size():
		var cx := 40.0 + (gi % 20) * 62.0
		var cy0 := 400.0 + (gi / 20) * 160.0
		for si in 3:
			var holder := Control.new(); holder.position = Vector2(cx, cy0 + si * 44); holder.size = Vector2(40, 40); r.add_child(holder)
			var gid: String = ids[gi]; var sz: int = [20, 24, 32][si]
			holder.draw.connect(func():
				if si == 0: TBGlyph.draw(holder, gid, Vector2(20, 20), float(sz), TBTokens.c("cream"))
				else: TBGlyph.draw_filled(holder, gid, Vector2(20, 20), float(sz), TBTokens.c("brass_lt")))

func _modal_landscape(r: Control) -> void:
	var m := K.modal(r, "Budget", 520, "coins")
	m[1].add_child(K.section("Spending"))
	for i in 3:
		var rr := K.hbox(12); rr.add_child(K.label(["Army", "Navy", "Research"][i], 15)); var sl := K.slider(0, 100, 5, [60, 25, 40][i]); rr.add_child(sl); rr.add_child(K.num("%d%%" % [60, 25, 40][i], 14)); m[1].add_child(rr)
	m[1].add_child(K.row("Income", "+608", K.GREEN))
	m[1].add_child(K.meter_row("Stability", 42))
	m[2].add_child(K.button("Reset"))
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; m[2].add_child(sp)
	m[2].add_child(K.button("Cancel"))
	m[2].add_child(K.button("Apply", Callable(), true))

func _modal_hero(r: Control) -> void:
	var m := K.modal(r, "Ultimatum", 560, "scroll", true)
	var body := K.label("Rome demands the cession of Sicily within three turns, or war.", 15); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; m[1].add_child(body)
	m[1].add_child(K.choice_card("Accept", "Lose Sicily, peace for 10 turns", func(): pass))
	m[1].add_child(K.choice_card("Reject", "War with Rome", func(): pass, true))

func _modal_portrait(r: Control) -> void:
	var m := K.modal(r, "Settings", 440, "gear")
	m[1].add_child(K.section("Language"))
	m[1].add_child(K.segmented([["en", "English"], ["ru", "Русский"], ["uz", "Oʻzbekcha"]], "en", func(_i): pass))
	m[1].add_child(K.section("Text size"))
	m[1].add_child(K.segmented([["1", "100%"], ["2", "125%"], ["3", "150%"], ["4", "200%"]], "2", func(_i): pass))
	for i in 6: m[1].add_child(K.list_row("Option number %d" % i, "on", Callable()))
	m[2].add_child(K.button("Main menu"))
	var b := K.button("Back", Callable(), true); b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; m[2].add_child(b)

## one narrow column of the controls that carry text, to judge 200 % text (no clipping, cells grow in height)
func _scale_board(r: Control) -> void:
	var p := _panel(r, Vector2(12, 12), 536, "Text 200%")
	p.add_child(K.segmented([["1.0", "100%"], ["1.25", "125%"], ["1.5", "150%"], ["2.0", "200%"]], "2.0", func(_i): pass))
	p.add_child(K.segmented([["auto", "Auto"], ["low", "Low"], ["medium", "Medium"], ["high", "High"]], "medium", func(_i): pass))
	p.add_child(K.segmented([["off", "Off"], ["deuter", "Deuteranopia"], ["protan", "Protanopia"], ["tritan", "Tritanopia"]], "off", func(_i): pass))
	p.add_child(K.segmented([["a", "All"], ["b", "Earned"], ["c", "Locked"], ["d", "Wars"], ["e", "Diplomacy"]], "b", func(_i): pass, true))
	p.add_child(K.tabs([["a", "Saves"], ["b", "Settings"]], "b", func(_i): pass))
	p.add_child(K.toggle("Reduce motion (stops spinning, sliding and pulsing)", true))
	p.add_child(K.toggle("Large touch targets", false))
	p.add_child(K.slider_row("Music", 0, 100, 5, 80))
	p.add_child(K.list_row("Byzantium and a very long nation name", "1 204", Callable()))
	var sel := K.list_row("Selected row", "312", Callable()); sel.selected = true; p.add_child(sel)
	var br := K.hbox(8); br.add_child(K.button("Cancel")); br.add_child(K.button("Continue", Callable(), true)); p.add_child(br)
	var cr := K.hbox(6); cr.add_child(K.chip("Peace")); cr.add_child(K.chip("+608", "", "pos")); cr.add_child(K.chip("Low supply", "", "warn")); p.add_child(cr)
	p.add_child(K.command_card("swords", "Recruit levies", "+15 men this turn", "120", func(): pass))
	var ir := K.hbox(8); ir.add_child(K.icon_button("close", Callable())); ir.add_child(K.icon_button("gear", Callable())); p.add_child(ir)

func _init() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: OUT = ua[0]
	DirAccess.make_dir_recursive_absolute(OUT)
	TBI18n.load_lang("en")
	await _board("01_controls_paper", Vector2i(1280, 1000), _controls)
	await _board("02_furniture_hero_seal", Vector2i(1280, 720), _furniture)
	await _board("03_glyphs", Vector2i(1280, 720), _glyphs)
	await _board("04_modal_landscape", Vector2i(1280, 720), _modal_landscape)
	await _board("05_modal_hero", Vector2i(1280, 720), _modal_hero)
	await _board("06_modal_portrait", Vector2i(540, 960), _modal_portrait)
	await _board("07_controls_hc", Vector2i(1280, 1000), _controls, 1)
	await _board("08_furniture_hc", Vector2i(1280, 720), _furniture, 1)
	await _board("09_controls_hc_dark", Vector2i(1280, 1000), _controls, 2)
	await _board("10_furniture_hc_dark", Vector2i(1280, 720), _furniture, 2)
	await _board("11_text200_controls", Vector2i(560, 1900), _scale_board, 0, true, 2.0)
	await _board("12_text200_hc_dark", Vector2i(560, 1900), _scale_board, 2, true, 2.0)
	await _board("13_text150_portrait_modal", Vector2i(540, 960), _modal_portrait, 0, true, 1.5)
	# the game's look: the demo's kit (units = px) in normal, high contrast (light, dark) and at 150 % text
	K.serif = true; TBTokens.legacy = false; TBFrame.rounded = false; TBFrame.bezel = true
	await _board("14_bezel_kit", Vector2i(1280, 1180), KP.build)
	await _board("15_bezel_kit_hc", Vector2i(1280, 1180), KP.build, 1)
	await _board("16_bezel_kit_hc_dark", Vector2i(1280, 1180), KP.build, 2)
	await _board("17_bezel_kit_text150", Vector2i(1280, 1180), KP.build, 0, true, 1.5)
	TBFrame.bezel = false; K.serif = false
	TBTokens.mode = TBTokens.Mode.NORMAL
	K.text_scale = 1.0
	print("UI KIT SHEET written to ", OUT)
	quit()
