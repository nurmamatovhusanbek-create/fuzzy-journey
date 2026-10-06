extends SceneTree
## title screen exactly as a player first sees it. Usage: -- <outdir> [w h]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	root.size = Vector2i(int(a[1]) if a.size() > 2 else 1280, int(a[2]) if a.size() > 2 else 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/menu_fresh.png" % a[0])
	quit(0)
