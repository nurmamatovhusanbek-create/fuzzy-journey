extends SceneTree
# Renders the GPU map under Xvfb/llvmpipe and saves PNGs:
#   xvfb-run -a godot --path godot --rendering-driver opengl3 -s tests/screenshot.gd -- /tmp/out
var out_dir := "/tmp"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: out_dir = args[0]
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 7})
	for i in 25: g.end_turn()
	g.set_human(g.owner[1000])
	var win := root
	win.size = Vector2i(1280, 720)
	var mv := TBMapView.new()
	mv.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.add_child(mv)
	mv.setup(g)
	await process_frame
	mv.size = Vector2(1280, 720)
	mv._push_view()
	var cap := g.capital_of[g.human_id]
	mv.fly_to(w.lon[cap], w.lat[cap], 2.4)
	await process_frame
	await process_frame
	var t0 := Time.get_ticks_msec()
	await process_frame
	await process_frame
	_shot(out_dir + "/globe.png")
	mv.select(g.owned(g.human_id)[0]); mv.set_lens("military")
	await process_frame; await process_frame
	_shot(out_dir + "/military.png")
	mv.set_lens("political"); mv.zoom = 1.0; mv.lon0 = 0.3; mv.lat0 = 0.4; mv._push_view()
	await process_frame; await process_frame
	_shot(out_dir + "/world.png")
	mv.set_mode(1); mv.fly_to(20.0, 20.0, mv.zoom)
	await process_frame; await process_frame
	_shot(out_dir + "/flat.png")
	print("pick test: ", mv.pick_at(Vector2(640, 360)), " renderer: ", RenderingServer.get_video_adapter_name())
	quit()

func _shot(path: String) -> void:
	var img := root.get_viewport().get_texture().get_image()
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
