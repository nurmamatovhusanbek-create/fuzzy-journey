extends SceneTree
## Bezel parity shots: the same France-1804 states the HTML demo shows (docs/ui_variants/shoot_bezel.mjs), at the same window size.
## Usage: -s tests/parity.gd -- <outdir> <w> <h> [state,...]      states: map nations budget decrees council annals goals menu select
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var w: int = int(a[1]); var h: int = int(a[2])
	var states: PackedStringArray = (a[3] if a.size() > 3 else "map,nations,budget,decrees,council,annals,goals,menu").split(",")
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "flat"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	main._update_ui_scale()
	for i in 8: await process_frame
	main.map.fly_to(9.5, 46.0, 5.3)                     # Europe, like the demo's framing
	for i in 30: await process_frame
	for s in states:
		main._clear_overlay(); main._select(-1)
		match s:
			"nations": main._open_nations()
			"asks":                                      # a trade charter on its way to Spain: its button reads Proposed / next turn, the others wait
				var sp4: int = main.g.nat_code.find("spain")
				main.g.dp[fr] = 9.0
				main.g.asks.clear()
				main.g.apply({"cmd": "ask", "n": fr, "kind": "trade", "t": sp4})
				main._open_nations(sp4)
			"ans":                                       # a court accepted, another declined: flag notices stay until tapped
				var sp3: int = main.g.nat_code.find("spain")
				var au5: int = main.g.nat_code.find("austrian_empire")
				main.g.log.append({"turn": main.g.turn, "kind": "ans", "a": fr, "b": au5, "what": "nap", "op": "", "ok": false})
				main.g.log.append({"turn": main.g.turn, "kind": "ans", "a": fr, "b": sp3, "what": "ally", "op": "", "ok": true})
				main.hud.refresh()
			"realm": main._open_realm_page()
			"budget": main._open_budget()
			"decrees": main._open_decisions()
			"council":
				main.g.gold[fr] = 5.0
				for q in main.g.owned(fr).slice(0, 4):
					if main.g.capital[q] == 0: main.g.stab[q] = 10
				main._open_council()
			"annals":
				var au2: int = main.g.nat_code.find("austrian_empire")
				var sp2: int = main.g.nat_code.find("spain")
				var uk2: int = main.g.nat_code.find("united_kingdom")
				main.g.log.append({"turn": 0, "kind": "war", "a": au2, "b": fr})
				main.g.log.append({"turn": 0, "kind": "ally", "a": sp2, "b": fr})
				main.g.log.append({"turn": 0, "kind": "trade", "a": fr, "b": uk2})
				main.g.log.append({"turn": 0, "kind": "bankrupt", "a": fr})
				main.g.log.append({"turn": 0, "kind": "era", "a": fr, "k": 1})
				main._open_annals()
			"goals": main._open_council("goals")
			"menu": main._open_game_menu()
			"event":
				var au: int = main.g.nat_code.find("austria")
				var pr := -1
				for p in main.g.P:
					if main.g.owner[p] == main.g.human_id: pr = p; break
				TBModals.event_prompt(main._overlay, {"uid": 901, "n": main.g.human_id, "kind": "prop", "id": "ultimatum", "from": au, "p": pr}, func(_i): pass, main.g, Callable())
			"lens": main.hud._pick_lens("diplomatic")
			"tip":
				main.hud._tip_show(main.hud._chips["gold"], main.hud._tip_chip("gold"))
			"world":
				main.map.zoom = 0.5; main.map.lat0 = 0.3; main.map.lon0 = 0.3; main.map.zoom_by(1.0)
			"war":
				var au3: int = main.g.nat_code.find("austrian_empire")
				TBModals.war_confirm(main._overlay, main.g, au3, func(): pass)
			"battle":
				TBModals.battle_report(main._overlay, {"win": true, "name": "Swabia", "claimed": true, "my_loss": 14, "foe_loss": 38, "left": 30})
			"event2":
				TBModals.event_prompt(main._overlay, {"uid": 902, "n": main.g.human_id, "kind": "rand", "id": "plague", "cat": "CRISIS", "count": 2}, func(_i): pass, main.g, func(): pass)
			"move", "preview":
				for p in main.g.P:
					if main.world.name[p] == "Bas-Rhin":
						main._select(p)
						main._on_move_requested(p)
						if s == "preview":
							for i in range(main.g.nb_off[p], main.g.nb_off[p + 1]):
								var q: int = main.g.nb[i]
								if main.g.owner[q] != main.g.human_id and main.g.owner[q] != 0:
									main.g.set_rel(main.g.human_id, main.g.owner[q], 1)
									main.flow.preview_to(q); break
			"tip2":
				for p in main.g.P:
					if main.world.name[p] == "Bas-Rhin":
						main._select(p)
				for i in 10: await process_frame
				main.ring._hover = 0
				main.ring._tip_show(0)
			"map", "select", "dossier":
				for p in main.g.P:
					if main.world.name[p] == "Bas-Rhin":
						main._select(p)
						if s == "dossier": main._open_dossier(p)
		for i in 14: await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/gd_%s.png" % [dir, s])
		if OS.get_environment("TB_DUMP") != "":
			_dump(main._overlay, 0)
		print("shot ", s, " logical ", root.content_scale_size)
	quit(0)

func _dump(n: Node, d: int) -> void:
	if n is Control and (n as Control).visible and d > 0:
		var c: Control = n
		var gp := c.global_position
		var t: String = ""
		if "text" in c: t = String(c.get("text")).substr(0, 22)
		print("  ".repeat(mini(d, 14)), c.get_class(), "/", c.get_script().get_global_name() if c.get_script() != null else "", " | ", snappedf(gp.x, 0.1), " | ", snappedf(gp.y, 0.1), " | ", snappedf(c.size.x, 0.1), " | ", snappedf(c.size.y, 0.1), " | ", t)
	for ch in n.get_children(): _dump(ch, d + 1)
