extends SceneTree
## One notched button at every width from 250 to 270: the plate must have all four chamfers at each. Usage: -s tests/btn_widths.gd -- <out png>
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DisplayServer.window_set_size(Vector2i(900, 700)); root.size = Vector2i(900, 700)
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 10: await process_frame
	main._clear_overlay()
	var host := Control.new(); host.position = Vector2(20, 20); host.size = Vector2(860, 660)
	var bg := ColorRect.new(); bg.color = Color(0.08, 0.06, 0.04); bg.size = Vector2(900, 700); main.add_child(bg); main.add_child(host)
	for i in 11:
		var b: Button = TBKit.button("Pact", Callable(), false, false, "pact", "61%")
		b.position = Vector2(10 + (i % 2) * 300, 10 + (i / 2) * 44); b.size = Vector2(250 + i * 2, 32)
		b.custom_minimum_size = Vector2(0, 32)
		host.add_child(b)
		b.set_deferred("size", Vector2(250 + i * 2, 32))
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	quit()
