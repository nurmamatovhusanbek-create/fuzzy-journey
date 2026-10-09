extends SceneTree
## Flag review: every screen that draws a nation flag, in one era. Usage: -- <outdir> <era> <nation_code> [w] [h]
var _out := ""
func _shot(name: String) -> void:
	for i in 24: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/fl_%s.png" % [_out, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]; var era: String = a[1]; var code: String = a[2]
	var w: int = int(a[3]) if a.size() > 3 else 1280; var h: int = int(a[4]) if a.size() > 4 else 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main.cfg["era"] = era
	main._open_era_picker()
	await _shot("1_era_picker")
	main._clear_overlay()
	main._begin_pick(era, "normal")
	for i in 20: await process_frame
	var me: int = main.g.nat_code.find(code)
	main._pick_flow.select_nation(me, false)
	await _shot("2_pick_nation")
	main._start_game(me)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	for i in 20: await process_frame
	var g: TBGame = main.g
	main.map.fly_to(main.world.lon[g.capital_of[me]], main.world.lat[g.capital_of[me]], 1.2)
	for i in 30: await process_frame
	await _shot("3_hud_and_map")
	var other: int = main.g.nat_code.find("usa") if code != "usa" else main.g.nat_code.find("ussr")
	main._open_nations()
	await _shot("4_nations_list")
	main._clear_overlay(); main._open_nations(other)
	await _shot("5_nation_detail")
	main._clear_overlay(); main._open_nations(-1, "", "rank")
	await _shot("6_rankings_chart")
	TBNationsScreen.mem["table"] = true
	main._clear_overlay(); main._open_nations(-1, "", "rank")
	await _shot("7_rankings_table")
	main._clear_overlay()
	TBModals.briefing(main._overlay, g, func(): pass)
	await _shot("8_briefing")
	main._clear_overlay()
	g.winner = me; g.victory_kind = ""
	TBModals.game_over(main._overlay, g, func(): pass)
	await _shot("9_game_over")
	main._clear_overlay(); g.winner = 0
	var foreign: int = g.capital_of[other]
	main._select(foreign)
	await _shot("10_province_foreign")
	quit(0)
