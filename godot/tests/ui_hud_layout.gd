extends SceneTree
## HUD + command card layout assertions at one size and text scale: the card never touches the End Turn footprint (>= 16 u gap),
## nothing leaves the screen, the bar controls do not overlap, hit areas are >= 48. Screenshots to <outdir>.
## Usage: -- <outdir> <w> <h> [text_scale] [lang]     (units = 1 px per logical unit; TB_NOANIM=1)
var fails := 0
func _check(cond: bool, what: String) -> void:
	if not cond:
		print("FAIL: ", what); fails += 1

func _shot(out: String, tag: String) -> void:
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/hl_%s.png" % [out, tag])

func _walk(n: Node, acc: Array) -> void:
	for c in n.get_children():
		if c is Control and (c as Control).is_visible_in_tree(): acc.append(c)
		if c is ScrollContainer: continue                       # scrolled content is clipped by design
		_walk(c, acc)

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var w := int(a[1]); var h := int(a[2])
	var ts: float = float(a[3]) if a.size() > 3 else 1.0
	var lang: String = a[4] if a.size() > 4 else "en"
	var tag := "%dx%d_s%d_%s" % [w, h, int(ts * 100.0), lang]
	root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(w, h)
	await process_frame; await process_frame
	main.cfg["lang"] = lang; TBI18n.load_lang(lang); main.cfg["tutorial"] = true
	main.cfg["text_scale"] = ts
	main._apply_a11y()
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay()
	root.size_changed.disconnect(main._update_ui_scale)
	root.content_scale_size = Vector2i(w, h)
	for i in 3: await process_frame
	main.hud.layout_for(main.size); main.panel.layout_for(main.size)
	var g: TBGame = main.g
	g.gold[fr] = 45850.0; g.manpower[fr] = 2000.0; g.mp[fr] = 12.0; g.dp[fr] = 8
	main.hud.refresh()
	var own := -1; var enemy_p := -1
	for p in g.owned(fr):
		if g.army[p] > 1 and own < 0 and g.capital[p] == 0: own = p
	g.army[own] = 33
	var peace_p := -1
	for e in range(g.nb_off[own], g.nb_off[own + 1]):
		var q: int = g.nb[e]
		if g.owner[q] != 0 and g.owner[q] != fr and g.nb_sea[e] == 0: peace_p = q
	var cases := {"idle": -1, "own": own, "foreign": peace_p}
	for k in cases:
		main._select(int(cases[k]))
		for i in 4: await process_frame
		var hud: TBHud = main.hud
		var vp := Vector2(w, h)
		var et: Rect2 = hud.end_turn_rect()
		_check(et.position.x >= 0.0 and et.end.x <= vp.x + 0.5 and et.end.y <= vp.y + 0.5, "%s %s: End Turn inside the screen %s" % [tag, k, et])
		if main.panel.visible:
			var cr: Rect2 = main.panel.get_global_rect()
			_check(cr.position.x >= -0.5 and cr.end.x <= vp.x + 0.5 and cr.position.y >= -0.5 and cr.end.y <= vp.y + 0.5, "%s %s: card inside the screen %s" % [tag, k, cr])
			_check(not cr.grow(15.0).intersects(et) or cr.end.x + 15.9 <= et.position.x, "%s %s: card %s keeps 16 u from End Turn %s" % [tag, k, cr, et])
		# controls of the HUD stay on screen; the bar's controls do not overlap each other
		var all: Array = []
		_walk(hud, all)
		for c in all:
			var r: Rect2 = (c as Control).get_global_rect()
			if r.size.x < 2.0 or r.size.y < 2.0: continue
			if c is TBAlertTicker or c.get_parent() is TBAlertTicker or c is PanelContainer: continue
			_check(r.position.x >= -1.0 and r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0 and r.position.y >= -1.0, "%s %s: %s %s off screen" % [tag, k, c.get_class(), r])
		var bar_kids: Array = []
		for c in hud.get_children():
			if c is TBHudParts.Chip or c is TBHudParts.NationChip or c is TBHudParts.IconBtn:
				if (c as Control).visible and (c as Control).position.y < hud.ribbon_height(): bar_kids.append(c)
		for i in bar_kids.size():
			for j in range(i + 1, bar_kids.size()):
				var ri := Rect2((bar_kids[i] as Control).position, (bar_kids[i] as Control).size)
				var rj := Rect2((bar_kids[j] as Control).position, (bar_kids[j] as Control).size)
				_check(not ri.intersects(rj), "%s %s: bar controls overlap %s %s" % [tag, k, ri, rj])
		for c in hud.get_children():       # hit areas >= 48 (the Hit base expands small visuals)
			if c is TBHudParts.Hit and (c as Control).visible:
				var hr: Rect2 = (c as TBHudParts.Hit).hit_rect() if c.has_method("hit_rect") else Rect2(Vector2.ZERO, (c as Control).size)
				if c is TBHudParts.Seal: continue
				_check(hr.size.x >= 47.9 and hr.size.y >= 47.9, "%s %s: hit area %s < 48" % [tag, k, hr.size])
		await _shot(out, "%s_%s" % [tag, k])
	main.hud._open_menu(main.hud._dock_more if main.hud._dock_more.visible else main.hud._menu_btn, true)
	await _shot(out, tag + "_more")
	main.hud._close_pop()
	main.hud._seal_pressed()
	main.hud.set_busy(true)
	await _shot(out, tag + "_busy")
	if fails > 0: push_error("UI_HUD_LAYOUT FAIL %s" % tag)
	print("UI_HUD_LAYOUT ", "OK" if fails == 0 else "FAIL", " ", tag)
	quit(1 if fails > 0 else 0)
