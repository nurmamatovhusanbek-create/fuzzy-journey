extends SceneTree
## The 20 s trailer-teaser, recorded from the real game with Godot's movie writer (tools/trailer.sh: xvfb + --write-movie frame.png, then ffmpeg grade + the score from tools/trailer_score.py).
## 600 frames at 30 fps = 36 beats at 108 bpm; every cut and hit sits on that grid (beat k is frame k * 16.667). Nothing here runs in the game: it only drives it.
##
##   0 - 60    black, "1804"
##  60 - 160   the globe turns in the dark (EMPIRES RISE)
## 160 - 250   the dive onto Europe (ALLIANCES BREAK)
## 250 - 333   the interface arrives, Bas-Rhin is picked, the war card, the seal is pressed
## 333 - 400   the War moment (impact on beat 20), a shake
## 400 - 440   the army's order arrow
## 440 - 500   the montage: hard cuts on half beats across lenses and both map modes, four words
## 500 - 533   the era ring turns through the eras
## 533 - 600   title hit, TERRA BELLUM
const FPS := 30
const W := 1920
const H := 1080
var main: Control
var map: TBMapView
var f := 0
var f0 := 0
var layer: CanvasLayer
var black: ColorRect
var flash: ColorRect
var scrim: TextureRect
var cards: Array = []                     # {c: Control, a: int, b: int, y: float, punch: bool}
var flashes: Array = []                   # [frame, strength]
var rule: ColorRect
var rule_w := 0.0
var fr_id := 0
var foe := -1
var tgt := -1
var bas := -1
var war_handle
var seal
var shake_until := -1

func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
func ease_io(t: float) -> float: return smooth(t)
func beat_f(k: float) -> int: return int(round(k * 16.6667))

func _find_seal(n: Node) -> Node:
	if n is TBWarParts.Seal: return n
	for c in n.get_children():
		var r := _find_seal(c)
		if r != null: return r
	return null

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(W, H)); root.size = Vector2i(W, H)
	main = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "globe"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true
	main.cfg["quality"] = "high"; main.cfg["fx"] = "full"; main.cfg["navpad"] = "off"; TBNavPad.setting = "off"; TBFx.apply(main.cfg)
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick("napoleonic", "normal")
	fr_id = main.g.nat_code.find("france")
	main._start_game(fr_id)
	main.g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	main.map.set_mode(0)
	map = main.map
	for i in 8: await process_frame
	_build_overlay()
	main.hud.modulate.a = 0.0
	map.set_lens("political")
	for p in main.g.P:
		if main.world.name[p] == "Bas-Rhin": bas = p
	main.g.mp[fr_id] = 20.0; main.g.gold[fr_id] = 900.0; main.g.dp[fr_id] = 20.0
	for i in range(main.g.nb_off[bas], main.g.nb_off[bas + 1]):
		var q: int = main.g.nb[i]
		if main.g.nb_sea[i] == 0 and main.g.owner[q] != 0 and main.g.owner[q] != fr_id: foe = main.g.owner[q]; tgt = q; break
	f0 = Engine.get_process_frames()
	print("TRAILER_F0 ", f0)
	for fr in 600:
		_drive(fr)
		await _tick()
	print("TRAILER_FRAMES ", f)
	quit()

# ------------------------------------------------------------------ overlay: fade, flash, text cards, scrim
func _build_overlay() -> void:
	layer = CanvasLayer.new(); layer.layer = 100; root.add_child(layer)
	var gr := Gradient.new(); gr.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.62), Color(0, 0, 0, 0)]); gr.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var gt := GradientTexture2D.new(); gt.gradient = gr; gt.fill_from = Vector2(0.5, 0.0); gt.fill_to = Vector2(0.5, 1.0); gt.width = 4; gt.height = 256
	scrim = TextureRect.new(); scrim.texture = gt; scrim.stretch_mode = TextureRect.STRETCH_SCALE; scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.position = Vector2(0, H * 0.5 - 180); scrim.size = Vector2(W, 360); scrim.modulate.a = 0.0; layer.add_child(scrim)
	black = ColorRect.new(); black.color = Color(0, 0, 0, 1); black.set_anchors_preset(Control.PRESET_FULL_RECT); black.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(black)
	flash = ColorRect.new(); flash.color = Color(1.0, 0.96, 0.88, 0.0); flash.set_anchors_preset(Control.PRESET_FULL_RECT); flash.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(flash)
	rule = ColorRect.new(); rule.color = TBTokens.c("brass"); rule.size = Vector2(0, 2); rule.mouse_filter = Control.MOUSE_FILTER_IGNORE; layer.add_child(rule)
	# the text cards (Cinzel, tracked): frame in, frame out, vertical position (fraction of the height), size
	_card("1804", 150, 0.5, 14, 62, false, 0.32)
	_card("EMPIRES RISE", 74, 0.5, 78, 152, false, 0.30)
	_card("ALLIANCES BREAK", 74, 0.5, 176, 246, false, 0.30)
	_card("DIPLOMACY.", 130, 0.5, 456, 464, true, 0.10)
	_card("WAR.", 130, 0.5, 464, 472, true, 0.10)
	_card("TRADE.", 130, 0.5, 472, 480, true, 0.10)
	_card("INTRIGUE.", 130, 0.5, 480, 488, true, 0.10)
	_card("EVERY ERA.", 40, 0.88, 514, 533, false, 0.34)
	_card("TERRA BELLUM", 128, 0.44, 541, 600, false, 0.26)
	_card("A TURN-BASED CHRONICLE OF THE GLOBE", 24, 0.585, 557, 600, false, 0.38)
	_card("THIRTEEN ERAS  ·  ONE GLOBE", 19, 0.64, 569, 600, false, 0.42)

func _card(text: String, size: int, y: float, a: int, b: int, punch: bool, em: float) -> void:
	var c := TBKit.title(text, size, TBTokens.c("brass_lt") if size >= 100 else TBTokens.c("cream"), em)
	c.modulate.a = 0.0; c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(c)
	cards.append({"c": c, "a": a, "b": b, "y": y, "punch": punch, "text": text})

func _layout_cards() -> void:
	var scrim_a := 0.0
	for d in cards:
		var c: Control = d["c"]
		var a: int = d["a"]; var b: int = d["b"]
		var fin := smooth(float(f - a) / 10.0)
		var fout := 1.0 - smooth(float(f - (b - 10)) / 10.0)
		if bool(d["punch"]): fin = smooth(float(f - a) / 2.0); fout = 1.0 - smooth(float(f - (b - 2)) / 2.0)
		var al: float = clampf(fin * fout, 0.0, 1.0)
		c.modulate.a = al
		var sz: Vector2 = c.get_combined_minimum_size()
		c.size = sz
		var drift := (1.0 - fin) * 14.0
		var sc := 1.0
		if bool(d["punch"]): sc = 1.0 + 0.10 * (1.0 - smooth(float(f - a) / 7.0))
		elif String(d["text"]) == "TERRA BELLUM": sc = 1.0 + 0.05 * (1.0 - smooth(float(f - a) / 40.0))
		c.pivot_offset = sz * 0.5; c.scale = Vector2(sc, sc)
		c.position = Vector2((W - sz.x) * 0.5, float(d["y"]) * H - sz.y * 0.5 + drift)
		if al > 0.01 and (f >= 60 and f < 250) and not bool(d["punch"]): scrim_a = maxf(scrim_a, al)
		if al > 0.01 and bool(d["punch"]): scrim_a = maxf(scrim_a, al * 0.8)
	scrim.modulate.a = scrim_a
	# the gold rule under the title
	var ra: float = smooth(float(f - 545) / 22.0)
	rule_w = 460.0 * ra
	rule.size = Vector2(rule_w, 2.0); rule.position = Vector2((W - rule_w) * 0.5, H * 0.535)
	rule.modulate.a = clampf(1.0 - float(f - 590) / 10.0, 0.0, 1.0)

# ------------------------------------------------------------------ the driver
func _drive(fr: int) -> void:
	var g: TBGame = main.g
	g.pending.clear()
	# ---- S1: the globe in the dark (the camera is set every frame; before 60 it is just dark)
	if fr < 160:
		var t := float(fr) / 160.0
		_cam(-2.7 + 1.7 * ease_io(t), 0.22 + 0.30 * ease_io(t), exp(lerpf(log(0.62), log(1.18), ease_io(t))))
	elif fr < 250:                                                     # S2: the dive
		var t2 := float(fr - 160) / 90.0
		_cam(lerpf(-1.0, 0.12, ease_io(t2)), lerpf(0.52, 0.82, ease_io(t2)), exp(lerpf(log(1.18), log(5.3), ease_io(t2))))
	elif fr < 333:                                                     # S3a: closing on Bas-Rhin
		var t3 := float(fr - 250) / 83.0
		_cam(0.12 + 0.03 * t3 + 0.002 * sin(fr * 0.21), 0.82 - 0.02 * t3, 5.3 + 1.8 * smooth(t3))
	elif fr < 440:                                                     # S3b / S3c: the war and the march
		var t4 := float(fr - 333) / 107.0
		var sh := Vector2.ZERO
		if fr < shake_until or (fr >= 333 and fr < 351):
			var k := 1.0 - float(fr - 333) / 18.0
			sh = Vector2(sin(fr * 3.1), cos(fr * 4.3)) * 0.006 * maxf(k, 0.0)
		_cam(0.15 + 0.012 * t4 + sh.x, 0.80 + 0.004 * t4 + sh.y, 7.1 + 1.4 * smooth(t4))
	# the HUD arrives
	if fr >= 248 and fr < 272: main.hud.modulate.a = smooth(float(fr - 248) / 24.0)
	if fr == 252:
		main._on_command({"cmd": "recruit", "p": bas, "amount": 40})
		main._on_command({"cmd": "hire", "p": bas, "amount": 60})
	if fr == 268: main._select(bas)
	if fr == 286 and foe >= 0:
		war_handle = TBModals.war_confirm(main._overlay, g, foe, func(): g.set_rel(fr_id, foe, 1))
	if fr == 296 and war_handle != null and war_handle.is_open(): seal = _find_seal(war_handle.root)
	if seal != null and fr >= 300 and fr < 333:
		seal.progress.emit(clampf(float(fr - 300) / 30.0, 0.0, 0.95))
	if fr == 333 and seal != null:
		seal.progress.emit(0.0); seal.confirmed.emit(); flashes.append([333, 0.55]); shake_until = 351
	# S3c: the order arrow
	if fr == 396:
		main._select(bas); main._on_move_requested(bas)
	if fr == 408 and tgt >= 0: main.flow.hover(tgt)
	if fr == 424 and tgt >= 0: main._on_command({"cmd": "move", "from": bas, "to": tgt, "troops": maxi(1, g.army[bas] - 1)})
	# ---- S4: the montage, a hard cut every half beat from frame 440
	if fr >= 440 and fr < 500:
		var i: int = (fr - 440) / 8
		var within: int = (fr - 440) % 8
		if within == 0: _montage_cut(i)
		_montage_push(i, within)
	# ---- S5: the era ring
	if fr == 500:
		flashes.append([500, 0.9])
		main.cfg["view"] = "globe"
		main.show_menu()
	if fr == 504: main._open_era_picker()
	if fr == 512 or fr == 519 or fr == 526: _key(KEY_RIGHT)
	if fr == 533: flashes.append([533, 1.0])

var _mont := [
	{"mode": 1, "lens": "political", "lon": 0.10, "lat": 0.80, "z": 3.0, "flat": true},
	{"mode": 0, "lens": "military", "lon": -0.20, "lat": 0.62, "z": 3.4, "flat": false},
	{"mode": 1, "lens": "diplomatic", "lon": 1.20, "lat": 0.50, "z": 1.7, "flat": true},
	{"mode": 0, "lens": "wars", "lon": 0.60, "lat": 0.90, "z": 2.6, "flat": false},
	{"mode": 1, "lens": "economic", "lon": -0.90, "lat": 0.50, "z": 2.3, "flat": true},
	{"mode": 0, "lens": "political", "lon": 0.04, "lat": 0.82, "z": 9.0, "flat": false},
	{"mode": 1, "lens": "stability", "lon": 1.90, "lat": 0.60, "z": 1.3, "flat": true},
	{"mode": 0, "lens": "terrain", "lon": -0.30, "lat": 0.45, "z": 1.9, "flat": false},
]
var _cur := {}
func _montage_cut(i: int) -> void:
	main._clear_overlay(); main._select(-1)
	_cur = _mont[i % _mont.size()]
	map.set_mode(int(_cur["mode"]))
	map.set_lens(String(_cur["lens"])); main.hud.set_lens_legend(String(_cur["lens"]))
	flashes.append([f if f > 0 else 440 + i * 8, 0.45])
	main.hud.modulate.a = 1.0
func _montage_push(i: int, within: int) -> void:
	if _cur.is_empty(): return
	var z: float = float(_cur["z"]) * (map.flat_fit() if bool(_cur["flat"]) else 1.0)
	z *= 1.0 + 0.07 * float(within) / 8.0
	_cam(float(_cur["lon"]) + 0.01 * within, float(_cur["lat"]), z)

func _cam(lon: float, lat: float, z: float) -> void:
	map.lon0 = lon; map.lat0 = lat; map.zoom = z
	map._push_view()

func _key(code: Key) -> void:
	var ev := InputEventKey.new(); ev.pressed = true; ev.keycode = code; ev.physical_keycode = code
	Input.parse_input_event(ev)

func _tick() -> void:
	await process_frame
	f = Engine.get_process_frames() - f0
	# black: dark open, the globe fades up from frame 40, the title cut at 533 is hard (the hit)
	var a := 0.0
	if f < 40: a = 1.0
	elif f < 84: a = 1.0 - smooth(float(f - 40) / 44.0)
	if f >= 533: a = 1.0
	black.color.a = a
	var fl := 0.0
	for e in flashes:
		var age: int = f - int(e[0])
		if age >= 0 and age < 8: fl = maxf(fl, float(e[1]) * (1.0 - float(age) / 8.0))
	flash.color.a = fl
	_layout_cards()
	if map.labels != null: map.labels.modulate.a = clampf((map.zoom - 1.6) / 1.6, 0.0, 1.0)
