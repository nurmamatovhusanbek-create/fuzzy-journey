extends SceneTree
func _init() -> void:
	var v: String = OS.get_cmdline_user_args()[0]
	var x: TBHud = null
	if v == "load":
		var main: Control = load("res://src/ui/main.tscn").instantiate()
		root.add_child(main)
	await process_frame
	await process_frame
	print("T5 done ", v, x)
	quit()
