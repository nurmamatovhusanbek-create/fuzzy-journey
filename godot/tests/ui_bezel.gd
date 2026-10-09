extends SceneTree
## Bezel look: HUD states for review. Usage: -- <outdir> <w> <h>
var _out := ""
func _shot(name: String) -> void:
	for i in 14: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/bz_%s.png" % [_out, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	DisplayServer.window_set_size(Vector2i(int(a[1]), int(a[2]))); root.size = Vector2i(int(a[1]), int(a[2]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	for i in 20: await process_frame
	main.map.fly_to(main.world.lon[main.g.capital_of[fr]], main.world.lat[main.g.capital_of[fr]], 1.6)
	main.hud.toast("Envoy sent to Madrid (+7)")
	main.hud.toast("Austrian cavalry seen near Strasbourg.", true)
	await _shot("map")
	main._select(main.g.capital_of[fr])
	await _shot("sel")
	# routes: pact with Spain, trade with the Ottomans, war with Austria
	var sp: int = main.g.nat_code.find("spain"); var ot: int = main.g.nat_code.find("ottoman_empire"); var au: int = main.g.nat_code.find("austrian_empire")
	print("caps: spain ", sp, " ", main.g.world.name[main.g.capital_of[sp]], " ", main.g.world.lon[main.g.capital_of[sp]], " ", main.g.world.lat[main.g.capital_of[sp]], " france ", main.g.world.name[main.g.capital_of[fr]])
	main.g.set_rel(fr, sp, TBData.REL_ALLY)
	if ot > 0: TBTrade.set_deal(main.g, fr, ot, true)
	if au > 0: main.g.set_rel(fr, au, TBData.REL_WAR)
	main.map.fly_to(10.0, 46.0, 2.6)
	await create_timer(1.8).timeout
	await _shot("routes")
	main._select(-1)
	main.hud._tip_show(main.hud._chips["gold"], main.hud._tip_chip("gold"))
	await _shot("tip_gold")
	main.hud._tip_hide()
	main.hud._tip_show(main.hud._chips["dp"], main.hud._tip_chip("dp"))
	await _shot("tip_dp")
	quit(0)
