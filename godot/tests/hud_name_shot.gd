extends SceneTree
## The top-left name against the gauges: a long nation name breaks onto two lines and the gauges start where it ends. Usage: -s tests/hud_name_shot.gd -- <w> <h> <out.png> <era> <nation code or name fragment> [lang]
## With the word "expect" as the last argument it also checks that the name's box and the first gauge do not overlap.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var w := int(a[0]); var h := int(a[1])
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var lang: String = a[5] if a.size() > 5 and a[5] != "expect" else "en"
	main.cfg["lang"] = lang; TBI18n.load_lang(lang); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "medium"; main.cfg["fx"] = "off"
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick(a[3], "normal")
	var n := -1
	for k in range(1, main.g.N1):
		if main.g.alive[k] != 0 and (String(main.g.nat_code[k]) == a[4] or main.g.nat_name[k].to_lower().contains(a[4].to_lower())): n = k; break
	if n < 0: print("no such nation"); quit(1); return
	main._start_game(n)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png(a[2])
	var hud: TBHud = main.hud
	var nat: Control = hud._nat
	var bad := 0
	for k2 in ["gold", "man", "mp", "dp"]:
		var c: Control = hud._chips[k2]
		if c.visible and nat.get_global_rect().intersects(c.get_global_rect()): bad += 1; print("OVERLAP name box with ", k2)
	print("name '", main.g.dname(n), "' box ", nat.get_global_rect(), " lines ", (nat as TBHudParts.NationChip).name_lines(), " overlaps ", bad)
	var expect: bool = a.size() > 0 and a[a.size() - 1] == "expect"
	print("HUD_NAME OK" if bad == 0 else "HUD_NAME FAIL")
	quit(1 if (expect and bad > 0) else 0)
