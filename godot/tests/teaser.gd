extends SceneTree
## A short teaser: the globe, a dive to Europe in 1804, an army marching, two turns, the title. Records itself with Godot's movie writer:
##   tools/teaser.sh   (xvfb + --write-movie, then ffmpeg -> mp4 / gif)
## Every frame is advanced by this script (fixed fps), so the film does not depend on how fast the machine renders.
const FPS := 30
var main: Control
var f := 0
var f0 := 0
var black: ColorRect
var title_l: Control
var tag_l: Control
var card_a := 0.0
var fade_out_at := 1 << 30

func _init() -> void:
	var w := 1280; var h := 720
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	main = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "globe"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "high"; main.cfg["navpad"] = "off"; TBNavPad.setting = "off"
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	main._apply_quality(); main._update_ui_scale()
	main.map.set_mode(0)
	for i in 6: await process_frame
	# overlay: the fade and the title card
	var layer := CanvasLayer.new(); layer.layer = 100; root.add_child(layer)
	black = ColorRect.new(); black.color = Color(0, 0, 0, 1); black.set_anchors_preset(Control.PRESET_FULL_RECT); black.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(black)
	title_l = TBKit.title("TERRA BELLUM", 84, TBTokens.c("brass"), 0.28); title_l.modulate.a = 0.0
	tag_l = TBKit.title("A TURN-BASED CHRONICLE OF THE GLOBE", 22, TBTokens.c("ink_0"), 0.34); tag_l.modulate.a = 0.0
	var box := VBoxContainer.new(); box.set_anchors_preset(Control.PRESET_FULL_RECT); box.alignment = BoxContainer.ALIGNMENT_CENTER; box.add_theme_constant_override("separation", 26); box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in [title_l, tag_l]: (c as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER; box.add_child(c)
	layer.add_child(box)
	main.hud.modulate.a = 0.0
	f0 = Engine.get_process_frames()
	main.map.set_lens("political")
	var map: TBMapView = main.map
	# A: the whole globe turning in the dark
	await cam(100, [-1.9, 0.30, 0.78], [-0.55, 0.55, 1.25], 1.0)
	# B: the dive onto Europe
	await cam(120, [-0.55, 0.55, 1.25], [0.12, 0.82, 5.0], 1.0)
	# the interface arrives
	await hud_in(24)
	# C: a province of France is picked, a war breaks out, an army crosses the border, the turn ends
	var bas := -1
	for p in main.g.P:
		if main.world.name[p] == "Bas-Rhin": bas = p
	main.g.mp[fr] = 20.0; main.g.gold[fr] = 900.0
	var foe := -1; var tgt := -1
	for i in range(main.g.nb_off[bas], main.g.nb_off[bas + 1]):
		var q: int = main.g.nb[i]
		if main.g.nb_sea[i] == 0 and main.g.owner[q] != 0 and main.g.owner[q] != fr: foe = main.g.owner[q]; tgt = q; break
	main._select(bas)
	cam(150, [0.12, 0.82, 5.0], [0.15, 0.80, 7.2], 1.0)
	await wait(24)
	main._on_command({"cmd": "recruit", "p": bas, "amount": 40})
	main._on_command({"cmd": "hire", "p": bas, "amount": 60})
	await wait(20)
	main._on_move_requested(bas)
	await wait(34)
	if tgt >= 0:
		main.g.set_rel(fr, foe, 1)
		main.flow.hover(tgt)
	await wait(30)
	if tgt >= 0: main._on_command({"cmd": "move", "from": bas, "to": tgt, "troops": maxi(1, main.g.army[bas] - 1)})
	await wait(40)
	main._select(-1)
	for k in 2:
		main.end_turn()
		while main._busy: await tick()
		main.g.pending.clear(); main._clear_overlay(); main.hud.refresh()
		await wait(40)
	# D: out to the title
	fade_out_at = f
	await wait(26)
	for i in 24: card_a = float(i + 1) / 24.0; await tick()
	await wait(70)
	quit()

func smooth(t: float) -> float: return t * t * (3.0 - 2.0 * t)

func cam(frames: int, a: Array, b: Array, _unused: float) -> void:
	var map: TBMapView = main.map
	for i in frames:
		var e := smooth(float(i + 1) / float(frames))
		map.lon0 = lerpf(a[0], b[0], e); map.lat0 = lerpf(a[1], b[1], e); map.zoom = exp(lerpf(log(a[2]), log(b[2]), e))
		map._push_view()
		await tick()

func hud_in(frames: int) -> void:
	for i in frames:
		main.hud.modulate.a = smooth(float(i + 1) / float(frames))
		await tick()

func wait(frames: int) -> void:
	for i in frames: await tick()

func tick() -> void:
	await process_frame
	f = Engine.get_process_frames() - f0
	var a := 0.0
	if f < 24: a = 1.0 - float(f) / 24.0
	if f >= fade_out_at: a = clampf(float(f - fade_out_at) / 24.0, 0.0, 1.0)
	black.color.a = a
	for c in [title_l, tag_l]:
		(c as Control).modulate.a = card_a
	if main.map.labels != null: main.map.labels.modulate.a = clampf((main.map.zoom - 1.6) / 1.6, 0.0, 1.0)      # no name clutter on the far globe
