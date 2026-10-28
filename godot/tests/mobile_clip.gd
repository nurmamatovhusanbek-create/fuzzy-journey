extends SceneTree
## A short phone playthrough (landscape by default: the game is played sideways; "portrait" is the fallback layout) for the movie writer (tools/mobile_clip.sh): title -> New game -> nation pick -> Play (the begin-game dive) -> briefing -> select a province -> End turn.
## Taps are shown as small rings so the clip reads as touch. Usage: -s tests/mobile_clip.gd -- <out dir> [fx: off|light|full] [land|portrait]
var W := 1600
var H := 720                                                                 # a phone held sideways (2.2:1); the script run sets TB_DPR so it counts as one: the desktop interface on a 1000 unit stage
var main: Control
var out := ""

class Tap extends Control:
	var t := 0.0
	func _init(p: Vector2) -> void:
		position = p; mouse_filter = Control.MOUSE_FILTER_IGNORE; z_index = 200
	func _process(d: float) -> void:
		t += d
		if t > 0.5: queue_free()
		queue_redraw()
	func _draw() -> void:
		var k: float = t / 0.5
		draw_circle(Vector2.ZERO, 10.0 + 26.0 * k, Color(1, 0.93, 0.72, 0.38 * (1.0 - k)))
		draw_arc(Vector2.ZERO, 10.0 + 26.0 * k, 0, TAU, 40, Color(1, 0.93, 0.72, 0.9 * (1.0 - k)), 2.5)
		draw_circle(Vector2.ZERO, 5.0 * (1.0 - k) + 2.0, Color(1, 0.96, 0.85, 0.95 * (1.0 - k)))

func _frames(n: int) -> void:
	for i in n: await process_frame

func _tap_at(logical: Vector2) -> void:
	main.add_child(Tap.new(logical))

func _tap(c: Control) -> void:
	if c != null and is_instance_valid(c): _tap_at(c.get_global_rect().get_center())

func _find_button(node: Node, word: String) -> Button:
	if node is Button and (node as Button).is_visible_in_tree() and (node as Button).text.to_lower().contains(word): return node as Button
	for k in node.get_children():
		var r: Button = _find_button(k, word)
		if r != null: return r
	return null

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	if a.size() > 2 and a[2] == "portrait": W = 720; H = 1280
	DisplayServer.window_set_size(Vector2i(W, H)); root.size = Vector2i(W, H)
	main = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["view"] = "globe"; main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["quality"] = "high"; main.cfg["text_scale"] = 1.0
	main.cfg["fx"] = a[1] if a.size() > 1 else "full"
	main._apply_a11y(); main._update_ui_scale()
	await _frames(2)
	main.show_menu()
	await _frames(24)                                                          # the title
	var nb: Button = _find_button(main, "new")
	_tap(nb); await _frames(6)
	main._open_era_picker()
	await _frames(27)                                                          # the era dialog
	var nx: Button = _find_button(main, "nation")
	_tap(nx); await _frames(5)
	main._begin_pick("napoleonic", "normal")
	await _frames(18)                                                          # the nation-pick screen
	var g: TBGame = main.g
	var fr: int = g.nat_code.find("france")
	var pf: TBPickFlow = main._pick_flow
	for c in pf._rail_row.get_children():
		if c is TBPickFlow.RailChip and (c as TBPickFlow.RailChip).n == fr: _tap(c)
	await _frames(5)
	pf.select_nation(fr, true)
	await _frames(30)                                                          # the camera flies, the card opens
	_tap(_find_button(pf, "play"))
	await _frames(5)
	main._confirm_pick(fr)                                                     # Play: the begin-game dive
	await _frames(66)                                                          # dive, HUD fades in, the briefing opens and is read for a moment
	var top = TBPanel.top(main._overlay)
	if top != null: top.close()
	await _frames(8)
	_tap(main.hud._dock[0])                                                    # the dock: Nations
	await _frames(4)
	main._open_nations(fr)
	await _frames(44)                                                          # the Nations page
	var pg = TBPanel.top(main._overlay)
	if pg != null: pg.close()
	await _frames(12)
	_tap_at(main.hud.get_global_rect().position + main.hud.end_turn_rect().get_center())
	await _frames(5)
	main.end_turn()
	await _frames(56)                                                          # the turn passes
	print("CLIP_FRAMES done")
	quit()
