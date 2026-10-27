extends SceneTree
## The title's motion: the bracket glides New game -> Continue, Continue is pressed and the globe dives into the game. Records with the movie writer (tools/title_dive.sh),
## and saves stills at chosen frames. Usage: -s tests/title_dive.gd -- <out dir> [globe|flat] [fx: off|light|full]
const FPS := 30
var main: Control
var out := ""
var shots := {}                 # frame -> name

func _frames(n: int) -> void:
	for i in n: await process_frame

func _snap(name: String) -> void:
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/dive_%s.png" % [out, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var view: String = a[1] if a.size() > 1 else "flat"
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	main = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = view; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "high"; main.cfg["navpad"] = "off"
	main.cfg["fx"] = a[2] if a.size() > 2 else "full"
	main._apply_a11y(); TBNavPad.setting = "off"
	main._begin_pick("napoleonic", "normal"); main._start_game(main.g.nat_code.find("france"))
	main.g.pending.clear(); main._clear_overlay()
	for t in 3: main.g.end_turn()
	TBSave.save(main.g, "auto")
	main._apply_quality(); main._update_ui_scale()
	await _frames(3)
	main.show_menu()
	await _frames(30)
	await _snap("01_title")
	# the bracket glides to New game, then back to Continue
	main._title_cur.get_parent().get_child(main._title_cur.get_index() + 2).grab_focus()
	await _frames(3); await _snap("02_glide_mid")
	await _frames(15); await _snap("03_new_game")
	main._title_cur.get_parent().get_child(main._title_cur.get_index() - 2).grab_focus()
	await _frames(20)
	await _snap("04_continue")
	main._title_cur.pressed.emit()
	for k in [4, 8, 12, 16, 20, 24, 28, 32, 36, 40, 46, 52, 60]:
		await _frames(4 if k == 4 else 4 if k <= 40 else 6 if k <= 52 else 8)
		await _snap("05_dive_%02d" % k)
	await _frames(40)
	await _snap("06_game")
	quit()
