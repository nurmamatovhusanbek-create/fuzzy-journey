extends SceneTree
func _shot(name: String) -> void:
	await process_frame; await process_frame; await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
var _out := ""
func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	TBModals.codex(main._overlay)
	await _shot("codex")
	quit(0)
