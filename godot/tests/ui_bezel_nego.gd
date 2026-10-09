extends SceneTree
## Bezel look: a foreign nation card (disposition, why, verdict chips) and the negotiation dial. Usage: -- <outdir> <w> <h>
var _out := ""
func _shot(name: String, frames: int = 16) -> void:
	for i in frames: await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/bn_%s.png" % [_out, name])

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0]
	DisplayServer.window_set_size(Vector2i(int(a[1]), int(a[2]))); root.size = Vector2i(int(a[1]), int(a[2]))
	var main: Control = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	for i in 20: await process_frame
	main._begin_pick("napoleonic", "normal")
	var fr: int = main.g.nat_code.find("france")
	main._start_game(fr)
	var g: TBGame = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.cfg["seal_seen"] = true
	g.dp[fr] = 12.0
	for i in 20: await process_frame
	var sp: int = g.nat_code.find("spain")
	main._open_nations(sp)
	await _shot("card")
	var cards: Array = []
	_walk(main, cards)
	print("cards: ", cards.size())
	for c in cards:
		if "NON" in str(c.get_meta("title", "")).to_upper() or c.get_child_count() > 0:
			pass
	if cards.size() > 0:
		(cards[0] as Control).call("_fire")
	await create_timer(0.6).timeout
	await _shot("dial", 2)
	await create_timer(1.6).timeout
	await _shot("dial_end", 2)
	await create_timer(1.5).timeout
	await _shot("after", 4)
	quit(0)

func _walk(n: Node, out: Array) -> void:
	if n is PanelContainer and n.has_method("_fire"): out.append(n)
	for c in n.get_children(): _walk(c, out)
