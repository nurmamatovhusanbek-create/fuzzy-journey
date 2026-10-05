extends SceneTree
func _init() -> void:
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._begin_pick("napoleonic", "normal")
	main._start_game(main.g.nat_code.find("france"))
	main._copy_diagnostics()
	var txt := FileAccess.get_file_as_string("user://diagnostics.txt")
	print(txt)
	print("DIAG ", "OK" if txt.contains("game: era=napoleonic") and txt.contains("gpu=") else "FAIL")
	quit(0 if txt.contains("game: era=napoleonic") else 1)
