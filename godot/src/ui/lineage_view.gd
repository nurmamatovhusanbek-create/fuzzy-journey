## "Your name in history": the Realm page's lineage section and the ceremony of a new name (TBLineage). The path of the line as flags, and the stages you could proclaim with what each asks for.
class_name TBLineageView
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

## one stage of the path: its flag, name and year; brass frame when it is the one you stand in, dim when it is still ahead
class Chip extends Control:
	var tex: Texture2D
	var label := ""
	var year := ""
	var state := 0                         # -1 behind, 0 now, 1 ahead
	func _init(t: Texture2D, nm: String, yr: String, st: int) -> void:
		tex = t; label = nm; year = yr; state = st
		custom_minimum_size = Vector2(138, 104); mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var a: float = 1.0 if state <= 0 else 0.55
		var fr := Rect2(Vector2((size.x - 60.0) * 0.5, 4.0), Vector2(60, 40))
		if tex != null: draw_texture_rect(tex, fr, false, Color(1, 1, 1, a))
		draw_rect(fr.grow(1.0), Color(TBTokens.c("brass_lt"), 0.95 if state == 0 else 0.35), false, 2.0 if state == 0 else 1.0)
		var f: Font = K.body_b()
		var fs := 13
		draw_multiline_string(f, Vector2(0.0, 62.0), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 2, Color(TBTokens.c("ink_0"), a))      # long names wrap to two lines, never cut
		var w2: float = f.get_string_size(year, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(f, Vector2((size.x - w2) * 0.5, 98.0), year, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(TBTokens.c("smoke"), a))

static func _regimes(regs: Array) -> String:
	var out := PackedStringArray()
	for r in regs: out.append(String(T.call("g_" + TBData.REGIME_ID[int(r)])))
	return " / ".join(out)

## the condition rows of a stage as text lines with a tick or a cross
static func condition_lines(g: TBGame, n: int, si: int) -> Array:
	var rows: Array = []
	for c in TBLineage.conditions(g, n, si):
		var ok: bool = bool(c["ok"])
		var txt := ""
		match String(c["key"]):
			"year": txt = String(T.call("lg_c_year", {"y": int(c["need"])}))
			"regime": txt = String(T.call("lg_c_regime", {"r": _regimes(c["need"])}))
			"core": txt = String(T.call("lg_c_core", {"h": int(c["have"]), "n": int(c["need"]), "t": (TBLineage.STAGES[si]["core"] as Array).size()}))
			"gold": txt = String(T.call("lg_c_gold", {"g": K.fmt(float(c["need"]))}))
			"moves": txt = String(T.call("lg_c_moves", {"m": int(c["need"])}))
		rows.append([ok, txt])
	return rows

## the section: the path, then up to two stages to proclaim. on_command(cmd) sends the order.
static func build(g: TBGame, me: int, on_command: Callable) -> Control:
	var col := K.vbox(8); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cur := TBLineage.current(g, me)
	if cur >= 0:
		var line := TBLineage.line_of(cur)
		var chips := HBoxContainer.new(); chips.add_theme_constant_override("separation", 4)
		for si in TBLineage.STAGES.size():
			var s: Dictionary = TBLineage.STAGES[si]
			if String(s["line"]) != line: continue
			var st := -1 if int(s["order"]) < int(TBLineage.STAGES[cur]["order"]) else (0 if si == cur else 1)
			chips.add_child(Chip.new(TBFlags.texture(String(s["id"]), g.color[me]), TBI18n.nation(String(s["name"])), str(int(s["year"])), st))
		var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.custom_minimum_size.y = 110; sc.add_child(chips); col.add_child(sc)
	var opts: Array = TBLineage.options(g, me)
	# the nearest stages first: the ones of your own line, by order, then the open ones
	opts.sort_custom(func(a: int, b: int) -> bool:
		var la: bool = TBLineage.line_of(a) == TBLineage.line_of(cur); var lb: bool = TBLineage.line_of(b) == TBLineage.line_of(cur)
		if la != lb: return la
		return int(TBLineage.STAGES[a]["order"]) < int(TBLineage.STAGES[b]["order"]))
	if opts.is_empty():
		col.add_child(K.para_bz(T.call("lg_none"), 15.0, 1.3))
	for si in opts.slice(0, 2):
		col.add_child(_card(g, me, si, on_command))
	return col

static func _card(g: TBGame, me: int, si: int, on_command: Callable) -> Control:
	var s: Dictionary = TBLineage.STAGES[si]
	var box := PanelContainer.new(); box.add_theme_stylebox_override("panel", TBBz.plate_box(8.0, false)); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	for sd in ["left", "right"]: pad.add_theme_constant_override("margin_" + sd, 14)
	for sd in ["top", "bottom"]: pad.add_theme_constant_override("margin_" + sd, 10)
	box.add_child(pad)
	var v := K.vbox(6); pad.add_child(v)
	var head := HBoxContainer.new(); head.add_theme_constant_override("separation", 12)
	var fl := TextureRect.new(); fl.texture = TBFlags.texture(String(s["id"]), g.color[me]); fl.custom_minimum_size = Vector2(54, 36); fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(fl)
	var ttl := K.title(String(T.call("lg_proclaim", {"n": TBI18n.nation(String(s["name"]))})), 17, TBTokens.c("ink_0"), 0.06, 20.0); ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ttl); v.add_child(head)
	var w: int = int(s["w"])
	v.add_child(K.para_bz(T.call("lg_gain", {"i": w * 2, "l": w * 4, "r": w * 3, "s": w, "d": w}), 14.0, 1.3))
	var cf := TBLineage.can_form(g, me, si)
	for row in condition_lines(g, me, si):
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 8)
		var mark := Label.new(); mark.text = "✓" if bool(row[0]) else "✗"; mark.add_theme_color_override("font_color", TBTokens.c("pos_bar") if bool(row[0]) else TBTokens.c("neg_bar")); mark.custom_minimum_size.x = 18
		var tx := K.label(String(row[1]), 14, TBTokens.c("ink_1") if bool(row[0]) else TBTokens.c("smoke")); tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(mark); line.add_child(tx); v.add_child(line)
	var btn := K.button(String(T.call("lg_do")), func(): on_command.call({"cmd": "form", "i": si}), true)
	btn.disabled = not bool(cf["ok"])
	if not bool(cf["ok"]): btn.tooltip_text = String(T.call("err_" + String(cf["reason"])))
	var br := HBoxContainer.new(); br.alignment = BoxContainer.ALIGNMENT_END; br.add_child(btn); v.add_child(br)
	return box

## the ceremony: the new flag and name, what it brings
static func ceremony(parent: Control, g: TBGame, me: int, old_name: String, claimed: int) -> TBPanel.Handle:
	var si := TBLineage.current(g, me)
	var s: Dictionary = TBLineage.STAGES[si]
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, String(T.call("lg_cer_title", {"n": g.dname(me)})), "crown", {"w": 520.0, "hero": true})
	var fl := TextureRect.new(); fl.texture = TBFlags.texture(String(s["id"]), g.color[me]); fl.custom_minimum_size = Vector2(240, 160); fl.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; fl.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	h.body.add_child(fl)
	h.body.add_child(K.para_bz(String(T.call("lg_cer_from", {"o": TBI18n.nation(old_name), "n": g.dname(me)})), 17.0, 1.4))
	var w: int = int(s["w"])
	h.body.add_child(K.para_bz(String(T.call("lg_gain", {"i": w * 2, "l": w * 4, "r": w * 3, "s": w, "d": w})), 15.0, 1.4))
	if claimed > 0: h.body.add_child(K.para_bz(String(T.call("lg_cer_claims", {"k": claimed})), 15.0, 1.4))
	h.body.add_child(K.button(String(T.call("lg_cer_ok")), func(): h.close(), true))
	return h
