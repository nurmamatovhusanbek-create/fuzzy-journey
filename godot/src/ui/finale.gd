## The game-over finale (Path B7, docs/screens/popup_mocks/sheet_C_finale.png): a full-screen sheet with the nation's medal, the headline, the standing counted up and the milestones of
## the game written out one by one. Same data as the old result dialog (no new state, nothing saved); same two buttons. Motion through TBFx: Full runs the 3 s sequence, Light fades
## everything in at once, Off shows it complete. Phones, short windows and large text keep the old dialog (TBModals.game_over decides).
class_name TBFinale
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

## the medal: laurel (victory) or a broken ring (defeat) around the flag
class Medal extends Control:
	var g: TBGame
	var won := true
	var u := 1.0
	func _init(game: TBGame, is_won: bool, scale_u: float) -> void:
		g = game; won = is_won; u = scale_u
		custom_minimum_size = Vector2(190, 190) * u; mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var c := size * 0.5
		draw_set_transform(c, 0.0, Vector2(u, u)); c = Vector2.ZERO
		var tone: Color = TBTokens.c("brass_lt") if won else TBTokens.BZ_DIM2
		draw_arc(c, 88.0, 0.0, TAU, 96, TBTokens.with_a(tone, 0.9), 1.6, true)
		if won:
			draw_arc(c, 80.0, 0.0, TAU, 96, TBTokens.with_a(TBTokens.BZ_LO, 0.9), 1.0, true)
			for side in [-1.0, 1.0]:                                           # two laurel branches
				for i in 9:
					var t: float = float(i) / 8.0
					var a: float = lerpf(2.55, 0.85, t) * (1.0 if side < 0 else 1.0)
					var p := c + Vector2(side * cos(a) * 86.0, sin(a) * 86.0)
					var d := Vector2(side * -sin(a), -cos(a))
					draw_line(p, p + (d * 12.0).rotated(side * 0.6), TBTokens.with_a(tone, 0.85), 2.0, true)
					draw_line(p, p + (d * 12.0).rotated(-side * 0.6) , TBTokens.with_a(tone, 0.55), 2.0, true)
		else:
			for i in 24:                                                       # a ring of dashes with a gap at the top: the broken seal
				var a0: float = -PI * 0.5 + 0.25 + float(i) * (TAU - 0.5) / 24.0
				draw_arc(c, 80.0, a0, a0 + 0.1, 4, TBTokens.with_a(tone, 0.6), 1.2, true)
		var tex: Texture2D = TBFlags.medal_of(g, g.human_id)
		if tex != null:
			TBFlags.draw_medal(self, tex, c, 56.0)
			if not won: draw_circle(c, 56.0, TBTokens.with_a(TBTokens.BZ_SHADOW, 0.55))
			draw_arc(c, 56.0, 0.0, TAU, 64, TBTokens.with_a(tone, 0.95), 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## a number that counts up
class Stat extends VBoxContainer:
	var target := 0.0
	var prefix := ""
	var label: Label
	var shown := 0.0:
		set(v):
			shown = v
			if label != null: label.text = prefix + K.fmt(roundf(shown))
	func _init(value: float, caption: String, col: Color, pre: String, u: float) -> void:
		target = value; prefix = pre
		add_theme_constant_override("separation", int(6.0 * u))
		alignment = BoxContainer.ALIGNMENT_CENTER
		label = K.num(prefix + K.fmt(value), int(40.0 * u), col)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		var cap := K.caps(caption, int(11.0 * u), TBTokens.c("smoke")); cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(cap)

## a soft coloured glow behind everything
class Glow extends Control:
	var col := Color.WHITE
	func _init(c: Color) -> void:
		col = c; set_anchors_preset(Control.PRESET_FULL_RECT); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.32)
		for k in 10: draw_circle(c, maxf(size.x, size.y) * (0.62 - k * 0.055), TBTokens.with_a(col, 0.045))

static func _milestones(g: TBGame) -> Array:
	var me: int = g.human_id
	var keep: Array = []
	for e in g.log:
		var k := String(e.get("kind", ""))
		if not (k in ["war", "peace", "ally", "vassal", "ceded", "annexed", "eliminated", "union", "independence"]): continue
		if not TBChron.involves(e, me): continue
		var t: String = TBChron.text(g, e)
		if t != "": keep.append([int(e.get("turn", 0)), t])
	if keep.size() <= 4: return keep
	var out: Array = []
	for i in 4: out.append(keep[int(roundf(float(i) * float(keep.size() - 1) / 3.0))])
	return out

static func open(parent: Control, g: TBGame, on_menu: Callable) -> TBPanel.Handle:
	var me: int = g.human_id
	var won: bool = g.winner == me
	var sub: String = T.call("e_victory", {"a": g.dname(g.winner)}) if won else T.call("e_defeat")
	if won and g.victory_kind != "": sub = "%s — %s" % [T.call("vc_" + g.victory_kind), g.dname(g.winner)]
	elif g.winner != 0 and not won: sub = T.call("e_lost_to", {"a": g.dname(g.winner)})
	# the standing: provinces now, the peak, the rank among the living, the turn
	var rows: Array = []
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		rows.append([g.own_count(n), n])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var rank := 0
	for i in rows.size():
		if rows[i][1] == me: rank = i + 1
	var peak := 0
	for pt in TBStats.series(g, me, "p"): peak = maxi(peak, int(pt[1]))
	peak = maxi(peak, g.own_count(me))
	var tone: Color = TBTokens.c("brass_lt") if won else TBTokens.c("smoke")
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var u: float = clampf(vs.y / 720.0, 1.0, 2.2)
	var h := TBPanel.Handle.new()
	h.kind = TBPanel.Kind.DIALOG; h.form = "dialog"; h.modal = true; h.dismissable = false; h.bz = true
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_meta("tb_handle", h); root.set_meta("tb_modal", true); root.z_index = TBTokens.Z_MODAL
	h.root = root
	var bd := ColorRect.new(); bd.set_anchors_preset(Control.PRESET_FULL_RECT); bd.color = TBTokens.ca("table", 0.94); bd.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bd); h.backdrop = bd
	root.add_child(Glow.new(TBTokens.c("brass_lt") if won else TBTokens.BZ_NOTICE_BAD))
	var sc := ScrollContainer.new(); sc.set_anchors_preset(Control.PRESET_FULL_RECT); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(sc)
	var cc := CenterContainer.new(); cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(cc)
	var v := K.vbox(int(14.0 * u)); v.custom_minimum_size.x = 640.0 * u
	cc.add_child(v)
	var sections: Array = []                                           # [node, start of its appearance 0..1]
	var medal := Medal.new(g, won, u); v.add_child(medal); sections.append([medal, 0.04])
	var head := K.title(T.call("go_won") if won else T.call("go_lost"), int(70.0 * u), tone, 0.2); head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(head); sections.append([head, 0.18])
	var subl := TBPanel.para(sub, int(19.0 * u), TBTokens.c("cream").lerp(tone, 0.2)); subl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(subl); sections.append([subl, 0.28])
	var orn := K.ornament(); orn.col = TBTokens.with_a(tone, 0.7); v.add_child(orn); sections.append([orn, 0.34])
	var stats := HBoxContainer.new(); stats.alignment = BoxContainer.ALIGNMENT_CENTER; stats.add_theme_constant_override("separation", int(56.0 * u))
	var stat_nodes: Array = []
	var ink: Color = TBTokens.c("cream") if won else TBTokens.c("smoke")
	for s in [[float(g.own_count(me)), T.call("lands")], [float(peak), T.call("go_peak")], [float(rank), T.call("go_rank")], [float(g.turn), T.call("turn")]]:
		var st := Stat.new(float(s[0]), String(s[1]), ink, "#" if String(s[1]) == T.call("go_rank") else "", u)
		stats.add_child(st); stat_nodes.append(st)
	v.add_child(stats); sections.append([stats, 0.40])
	var chron := K.vbox(0); chron.custom_minimum_size.x = 600.0 * u; chron.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ms: Array = _milestones(g)
	var lines: Array = []
	for m in ms:
		var row := K.hbox(int(18.0 * u))
		var yr := TBChron.date(g, int(m[0]))
		var yl := K.caps(yr, int(13.0 * u), TBTokens.c("brass_lt")); yl.custom_minimum_size.x = 96.0 * u; row.add_child(yl)
		var tl := K.label(String(m[1]), int(17.0 * u), TBTokens.c("cream")); tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.custom_minimum_size.x = 40
		row.add_child(tl)
		chron.add_child(row); chron.add_child(K.hair()); lines.append(row); sections.append([row, 0.60 + 0.06 * float(lines.size() - 1)])
	if not ms.is_empty(): v.add_child(chron)
	# the two buttons of the old result: view the final map (hides the sheet, a chip brings it back) and the main menu
	var chip_back: Array = [null]
	var view := K.button(T.call("go_view_map"), func():
		root.visible = false
		var b := K.button(T.call("go_show_result"), func():
			root.visible = true
			if is_instance_valid(chip_back[0]): (chip_back[0] as Control).queue_free(), true)
		b.set_anchors_preset(Control.PRESET_CENTER_TOP); b.offset_top = float(TBPanel.DRAWER_TOP) + 8.0; b.grow_horizontal = Control.GROW_DIRECTION_BOTH
		parent.add_child(b); chip_back[0] = b)
	var menu := K.button(T.call("main_menu"), func(): h.close(); on_menu.call(), true)
	var btns := HBoxContainer.new(); btns.alignment = BoxContainer.ALIGNMENT_CENTER; btns.add_theme_constant_override("separation", 14)
	btns.add_child(view); btns.add_child(menu)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 8); v.add_child(gap)
	v.add_child(btns); sections.append([btns, 0.84])
	parent.add_child(root)
	h.focus_target = menu
	if TBPanel.wants_focus(): menu.grab_focus.call_deferred()
	# ---- the sequence
	var step := func(t: float):
		bd.color.a = 0.94 * TBFx.smooth(t / 0.18)
		for sec in sections:
			if is_instance_valid(sec[0]): (sec[0] as CanvasItem).modulate.a = TBFx.smooth((t - float(sec[1])) / 0.10)
		head.pivot_offset = head.size * 0.5
		head.scale = Vector2.ONE * lerpf(1.12, 1.0, TBFx.smooth((t - 0.18) / 0.16))
		for st in stat_nodes: (st as Stat).shown = (st as Stat).target * TBFx.smooth((t - 0.40) / 0.30)
	if TBFx.on(TBFx.FULL):
		step.call(0.0)
		var tw := TBFx.run(root, 3.4, step, Callable(), TBFx.FULL)
		root.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and tw != null and tw.is_valid(): tw.kill(); step.call(1.0))
		bd.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and tw != null and tw.is_valid(): tw.kill(); step.call(1.0))
	elif TBFx.on(TBFx.LIGHT):
		root.modulate.a = 0.0
		TBFx.tween(root, {"modulate:a": 1.0}, 0.4, TBFx.LIGHT)
	return h
