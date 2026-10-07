extends SceneTree
## HUD screenshots: idle / alerts / lens / chip popover / realm sheet / End Turn hint / busy / drawer / hot-seat at one window size.
## Usage: xvfb-run ... --path godot -s tests/hud_shots.gd -- <outdir> <w> <h> [lang]     (env TB_NOANIM=1; TB_UI_SCALE / TB_SAFE emulate a phone)
func _shot(main: Control, dir: String, tag: String) -> void:
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/hud_%s.png" % [dir, tag])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var w: int = int(a[1]); var h: int = int(a[2])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var lang: String = a[3] if a.size() > 3 else "en"
	main.cfg["lang"] = lang; TBI18n.load_lang(lang); main.cfg["ui"] = "normal"
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	main.hud.set_seal_pulse(false)
	for i in 3: await process_frame
	main._update_ui_scale()
	for i in 4: await process_frame
	var tag := "%dx%d" % [w, h]
	print("window ", root.size, " scale ", root.content_scale_size, " vp ", root.get_visible_rect().size, " main ", main.size, " hud ", main.hud.size, " prof ", main.hud._prof, " img ", root.get_viewport().get_texture().get_image().get_size())
	g.gold[fr] = 4585.0; g.manpower[fr] = 90.0
	main.hud.refresh()
	await _shot(main, dir, tag + "_1idle")
	# ---- alerts: war, unrest, two offers, an event, a toast
	var pr: int = g.nat_code.find("prussia"); var au: int = g.nat_code.find("russian_empire")
	g.set_rel(fr, au, 1)
	var own := g.owned(fr)
	for k in mini(3, own.size()): if g.capital[own[k]] == 0: g.stab[own[k]] = 10
	g.ev_uid += 1; g.pending.append({"uid": g.ev_uid, "n": fr, "kind": "prop", "id": "ally", "from": pr, "icon": "", "cat": "", "count": 2})
	g.ev_uid += 1; g.pending.append({"uid": g.ev_uid, "n": fr, "kind": "prop", "id": "trade", "from": g.nat_code.find("spain"), "icon": "", "cat": "", "count": 2})
	g.log.append({"turn": g.turn - 1, "kind": "war", "a": au, "b": fr})
	main.hud.refresh()
	main.hud.toast("Saved")
	await _shot(main, dir, tag + "_2alerts")
	# ---- lens popover (economic) from the lens control
	main.hud.set_lens_legend("economic"); main.map.set_lens("economic")
	await _shot(main, dir, tag + "_3lens_set")
	main.hud._open_lens_pop(main.hud._tab_maps)
	await _shot(main, dir, tag + "_4lenspop")
	main.hud._close_pop(); main.hud.set_lens_legend("political"); main.map.set_lens("political")
	main.hud._pin_chip("gold")
	await _shot(main, dir, tag + "_5chip")
	main.hud._close_pop()
	main.hud._open_realm()
	await _shot(main, dir, tag + "_6realm")
	main.hud.close_realm()
	main.hud._open_drawer()
	await _shot(main, dir, tag + "_7drawer")
	main.hud._close_pop()
	# an offer chip expanded inline
	main.hud._ticker.expand_offer(main.hud._entries[2]["key"] if main.hud._entries.size() > 2 else "")
	await _shot(main, dir, tag + "_8expand")
	main.hud._seal_pressed()                          # first press: hint (offers pending)
	await _shot(main, dir, tag + "_9hint")
	main.hud.set_busy(true)
	await _shot(main, dir, tag + "_10busy")
	main.hud.set_busy(false)
	# ---- hot-seat
	g.pending.clear(); g.set_rel(fr, au, 0)
	g.add_human(pr)
	main.hud.seat_tag = "P1"
	main.hud.refresh()
	await _shot(main, dir, tag + "_11hotseat")
	# ---- bar stress: long numbers, caution states
	g.humans()
	quit(0)
