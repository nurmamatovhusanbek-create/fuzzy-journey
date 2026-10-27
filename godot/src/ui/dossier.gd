## The province dossier (b_demo.html dossierBody): a 420 unit panel docked right, three gauges (population, stability, happiness), the buildings as tiles,
## and the ledger. Opened from the tag card's "Dossier" link; a building tile builds it.
class_name TBDossier
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T

## `.cap` with the dossier's own size: 9.5 under the gauges
static func _cap(txt: String, px: float, col: Color = Color.TRANSPARENT) -> Control:
	var c := K.caps(txt, 10, col); (c as TBBz.TLabel).px = px; (c as TBBz.TLabel).refit(); return c

class BuildTile extends Control:
	signal pressed
	var built := false
	var building := false
	var label := ""
	var sub := ""
	var icon := ""
	var enabled := true
	var _hover := false
	func _init(ic: String, l: String, s: String, is_built: bool, is_building: bool, ok: bool) -> void:
		icon = ic; label = l; sub = s; built = is_built; building = is_building; enabled = ok
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		custom_minimum_size = Vector2(0, 2.0 + 9.0 + 22.0 + 4.0 + 14.0 + 17.0 + 9.0)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ok and not built else Control.CURSOR_ARROW
		mouse_entered.connect(func(): _hover = true; queue_redraw()); mouse_exited.connect(func(): _hover = false; queue_redraw())
	func _draw() -> void:
		var ci := get_canvas_item()
		var w := size.x; var h := size.y
		draw_rect(Rect2(0, 0, w, h), TBTokens.BZ_WELL)
		var edge: Color = TBTokens.BZ_BRASS_EDGE if built else TBTokens.BZ_TRACK_LINE
		if built or building:
			draw_rect(Rect2(0.5, 0.5, w - 1.0, h - 1.0), edge, false, 1.0)
		else:
			var d := 3.0
			for seg in [[Vector2(0.5, 0.5), Vector2(w - 0.5, 0.5)], [Vector2(0.5, h - 0.5), Vector2(w - 0.5, h - 0.5)], [Vector2(0.5, 0.5), Vector2(0.5, h - 0.5)], [Vector2(w - 0.5, 0.5), Vector2(w - 0.5, h - 0.5)]]:
				var a: Vector2 = seg[0]; var b: Vector2 = seg[1]
				var len := a.distance_to(b); var dir := (b - a) / len
				var t := 0.0
				while t < len:
					draw_line(a + dir * t, a + dir * minf(t + d, len), edge if not _hover else TBTokens.c("brass"), 1.0); t += d * 2.0
		var col: Color = TBTokens.c("brass_lt") if built else TBTokens.BZ_DIM2
		if not enabled and not built: col = TBTokens.with_a(col, 0.5)
		TBBzIcons.draw(self, icon, Vector2(w * 0.5, 1.0 + 9.0 + 11.0), 22.0, col)
		var fc: Font = TBKit.cinzel(700); var fi: Font = TBKit.alegreya(400, true)
		var up: String = label.to_upper() if TBI18n.lang != "ru" else label
		var lw: float = TBBz.tw(fc, up, 10.5, 10.5 * 0.14) - 10.5 * 0.14
		TBBz.text(ci, fc, Vector2((w - lw) * 0.5, 1.0 + 9.0 + 22.0 + 4.0 + 10.0), up, 10.5, col, 10.5 * 0.14)
		var sw: float = TBBz.tw(fi, sub, 13.0)
		TBBz.text(ci, fi, Vector2((w - sw) * 0.5, 1.0 + 9.0 + 22.0 + 4.0 + 14.0 + 11.0), sub, 13.0, col)
	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed and enabled and not built and not building:
			pressed.emit(); accept_event()

static func open(parent: Control, g: TBGame, p: int, on_cmd: Callable) -> TBPanel.Handle:
	var me: int = g.human_id
	var o: int = g.owner[p]
	var oname: String = g.dname(o) if o != 0 else T.call("cc_tag_unclaimed")
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, TBI18n.place(g.world.name[p]), "terrain", {"w": 420, "h": 560, "dock": "right", "sub": "%s · %s" % [T.call("dossier_sub"), oname]})
	var ph: bool = K.is_phone(parent)
	var body: VBoxContainer = h.body
	body.add_theme_constant_override("separation", 0)
	# the three gauges, spread evenly
	var maxpop := 1
	for q in g.P: maxpop = maxi(maxpop, g.pop[q])
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gs := [[T.call("pop_cap"), K.fmt(float(g.pop[p])), float(g.pop[p]) / float(maxpop), TBTokens.c("brass")],
		[T.call("stability"), "%d%%" % g.stab[p], g.stab[p] / 100.0, TBTokens.BZ_GOOD], [T.call("happiness"), "%d%%" % g.happy[p], g.happy[p] / 100.0, TBTokens.c("brass")]]
	for it in gs:
		var cell := VBoxContainer.new(); cell.add_theme_constant_override("separation", 0); cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gg := K.gauge(28.0 if ph else 34.0, String(it[1]), "", float(it[2]), it[3]); gg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; cell.add_child(gg)
		var cp := _cap(String(it[0]), 9.5); cp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; cell.add_child(cp)
		row.add_child(cell)
	var rm := MarginContainer.new(); rm.add_theme_constant_override("margin_bottom", 8); rm.add_child(row); body.add_child(rm)
	# buildings
	var bm := MarginContainer.new(); bm.add_theme_constant_override("margin_top", 0); bm.add_theme_constant_override("margin_bottom", 6); bm.add_child(_cap(T.call("dossier_buildings"), 11.0)); body.add_child(bm)
	var grid := GridContainer.new(); grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8); grid.add_theme_constant_override("v_separation", 8); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var icons := {"fortress": "fortify", "armory": "build", "port": "ship", "market": "treasury", "watchtower": "terrain", "supplycamp": "recruit", "library": "annals", "farm": "people", "workshop": "gear"}
	var order: Array = []                                      # the demo shows three tiles: what stands here first, then what can be built next (the Build verb lists them all)
	for i in D.BUILDINGS.size():
		if g.bl(p, i + 1) > 0 or g.b_building[p] == i + 1: order.append(i)
	for i in D.BUILDINGS.size():
		if order.size() >= 3: break
		if not order.has(i) and o == me and bool(g.can({"cmd": "build", "p": p, "b": i + 1})["ok"]): order.append(i)
	for i in D.BUILDINGS.size():
		if order.size() >= 3: break
		if not order.has(i): order.append(i)
	for i in order.slice(0, 3):
		var bid: String = String(D.BUILDINGS[i]["id"])
		var is_built: bool = g.bl(p, i + 1) > 0
		var is_busy: bool = g.b_building[p] == i + 1
		var cn: Dictionary = g.can({"cmd": "build", "p": p, "b": i + 1}) if (o == me and not is_built) else {"ok": false}
		var sub: String = (T.call("dossier_built") if g.bl(p, i + 1) <= 1 else "%s %d" % [T.call("dossier_built"), g.bl(p, i + 1)]) if is_built else (("%d" % g.b_turns[p]) if is_busy else T.call("dossier_build"))
		var tile := BuildTile.new(String(icons.get(bid, "build")), T.call("b_" + bid), sub, is_built, is_busy, bool(cn["ok"]))
		var bi: int = i + 1
		tile.pressed.connect(func(): h.close(); on_cmd.call({"cmd": "build", "p": p, "b": bi}))
		grid.add_child(tile)
	# ledger
	var lm := MarginContainer.new(); lm.add_theme_constant_override("margin_top", 12); lm.add_theme_constant_override("margin_bottom", 2); lm.add_child(_cap(T.call("dossier_ledger"), 11.0)); body.add_child(lm)
	var seen: bool = TBVision.sees(g, p)
	var rows: Array = [[T.call("army"), str(g.army[p]) if seen else "?"], [T.call("ins_defense"), str(g.defense[p]) if seen else "?"], [T.call("dev"), str(g.dev[p])], [T.call("econ"), str(g.econ[p])],
		[T.call("terrain"), T.call("t_" + D.TERRAIN_ID[g.terrain[p]])]]
	if g.rules >= 1:
		rows.append([T.call("supply"), str(g.supply_limit(p))])
		if g.attrition(p) > 0: rows.append([T.call("attrition"), str(g.attrition(p)), "neg"])
		if g.gen[p] != 0: rows.append([T.call("general"), TBGenerals.display_name(g, p)])
	if g.occupier[p] != 0: rows.append([T.call("cc_occupation"), T.call("occupied_by", {"nation": g.dname(g.occupier[p])}), "neg"])
	body.add_child(K.ledger(rows))
	return h
