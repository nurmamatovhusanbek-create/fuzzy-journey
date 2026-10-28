extends SceneTree
## Repro for the exit abort of scripted runs (exit code 134, 'corrupted size vs. prev_size'): the typed reference to a UI class in this -s script plus loading main.tscn.
## `-- load` aborts with --rendering-driver opengl3; `-- none` or an untyped variable does not. See docs/POLISH_TRACKER.md ("Why the test runs abort at exit"). Not part of the suite.
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
