## The era picker on the title's ring (Path A3, docs/screens/newgame_mocks/a3a.png): New game turns the title into the era screen: the ring's thirteen years become buttons (click, or the arrow keys),
## the globe moves to the right and turns to a place typical of the chosen era, the left column shows the era (year, name, line, great powers, difficulty, players) and "Pick a nation".
## Wide landscape windows only (TBTitle layout wide) and cfg["era_ui"] == "ring"; everything else keeps the dialog (TBNewGame.open).
class_name TBEraRing
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

## where the globe looks for each era (lon, lat in degrees)
const VIEW := {"ancient": [38.0, 34.0], "roman": [14.0, 41.0], "medieval": [12.0, 48.0], "mongol": [75.0, 44.0], "timurid": [66.0, 38.0], "discovery": [-25.0, 28.0],
	"gunpowder": [45.0, 40.0], "napoleonic": [10.0, 47.0], "victorian": [5.0, 42.0], "ww1": [18.0, 48.0], "ww2": [24.0, 48.0], "coldwar": [30.0, 50.0], "modern": [10.0, 22.0]}

## the mood of each era: the colour of the title's atmosphere while it is chosen (F1)
static func tint(id: String) -> Color:
	match id:
		"ancient": return TBTokens.c("brass_lt")
		"roman": return TBTokens.BZ_NOTICE_BAD
		"medieval": return TBTokens.BZ_GOOD
		"mongol": return TBTokens.BZ_REL_WARM
		"timurid": return TBTokens.BZ_TAG_OWN
		"discovery": return TBTokens.BZ_RIM
		"gunpowder": return TBTokens.BZ_TAG_OWN
		"napoleonic": return TBTokens.BZ_INFO
		"victorian": return TBTokens.BZ_DIM
		"ww1": return TBTokens.BZ_BAD
		"ww2": return TBTokens.BZ_NEG_SOFT
		"coldwar": return TBTokens.BZ_GOOD
	return TBTokens.BZ_RIM

## opts: overlay (Control), orrery (TBTitleParts.Orrery), map (TBMapView), world, era, difficulty, players, on_next(era, diff, players), on_back(), hide (Array of nodes to hide while open)
static func open(opts: Dictionary) -> TBPanel.Handle:
	var overlay: Control = opts["overlay"]
	var orr: TBTitleParts.Orrery = opts["orrery"]
	var map: TBMapView = opts["map"]
	var world: TBWorld = opts["world"]
	var vs: Vector2 = overlay.size if overlay.size.x > 1.0 else overlay.get_viewport_rect().size
	var u: float = vs.y / 720.0
	var S := {"era": String(opts.get("era", "modern")), "diff": String(opts.get("difficulty", "normal")), "players": int(opts.get("players", 1))}
	if not TBNewGame.ERA_YEAR.has(S["era"]): S["era"] = "modern"
	var hide: Array = opts.get("hide", [])
	var h := TBPanel.Handle.new()
	h.kind = TBPanel.Kind.PANEL; h.form = "page"; h.modal = false; h.dismissable = true; h.bz = true
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_meta("tb_handle", h)
	h.root = root
	# the title's own column and tools step aside
	var was: Array = []
	for n in hide:
		if is_instance_valid(n): was.append([n, (n as CanvasItem).visible]); (n as CanvasItem).visible = false
	# the column
	var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.position = Vector2(44.0 * u, 40.0 * u); sc.size = Vector2(430.0 * u, vs.y - 80.0 * u)
	root.add_child(sc)
	var col := K.vbox(int(10.0 * u)); col.custom_minimum_size.x = 410.0 * u
	sc.add_child(col)
	var steps := TBMenuParts.Steps.new(0, false); steps.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(steps)
	var det := K.vbox(int(10.0 * u)); det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(det)
	var go := K.button(T.call("pick_nation_btn"), func():
		h.close()
		(opts["on_next"] as Callable).call(String(S["era"]), String(S["diff"]), int(S["players"])), true)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; go.custom_minimum_size.x = 360.0 * u
	var back := K.button(T.call("back"), func(): TBPanel.pop_handle(h))
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var show := func(id: String, animate: bool) -> void:
		S["era"] = id
		for c in det.get_children(): c.queue_free()
		var yl := K.num(TBNewGame.year_text(id), int(13.0 * u), TBTokens.c("smoke")); det.add_child(yl)
		var nl := K.title(T.call("era_" + id), int(34.0 * u), TBTokens.c("brass_lt")); nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nl.custom_minimum_size.x = 40
		det.add_child(nl)
		det.add_child(TBPanel.para(T.call("blurb_" + id), int(16.0 * u), TBTokens.c("cream")))
		det.add_child(TBPanel.section(T.call("great_powers")))
		TBNewGame.fill_settings(det, id, S, world, false)
		var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 10.0 * u); det.add_child(sp)
		orr.set_era(id, animate)
		orr.set_rim(tint(id), animate)
		if VIEW.has(id): map.fly_to(float(VIEW[id][0]), float(VIEW[id][1]))
	# the ring is the picker
	orr.interactive = true; orr.mouse_filter = Control.MOUSE_FILTER_STOP
	var picked := func(id: String): show.call(id, true)
	orr.era_clicked.connect(picked)
	var order: Array = TBNewGame.ERAS.duplicate()
	order.sort_custom(func(a: String, b: String) -> bool: return TBNewGame.ERA_YEAR[a] < TBNewGame.ERA_YEAR[b])
	h.on_back = func() -> bool: return false
	h.on_dismiss = opts.get("on_back", Callable())
	# arrow keys step the era (the screen owns Left / Right while it is open)
	var keys := EraKeys.new(); keys.order = order; keys.S = S; keys.show = show
	root.add_child(keys)
	col.add_child(go); col.add_child(back)
	overlay.add_child(root)
	# the globe moves to the right to make room for the column
	var dx: float = vs.x * 0.125
	var shift := func(t: float): map.offset_left = dx * t; map.offset_right = dx * t; orr.queue_redraw()
	TBFx.run(root, 0.4, shift, Callable(), TBFx.LIGHT)
	show.call(String(S["era"]), false)
	map.lon0 = deg_to_rad(float(VIEW[S["era"]][0])) if VIEW.has(S["era"]) else map.lon0
	map._push_view()
	root.tree_exiting.connect(func():
		if is_instance_valid(orr):
			orr.interactive = false; orr.mouse_filter = Control.MOUSE_FILTER_IGNORE; orr.hover_i = -1; orr.set_rim(TBTokens.BZ_RIM, false)
		if is_instance_valid(map): map.offset_left = 0.0; map.offset_right = 0.0
		for e in was: if is_instance_valid(e[0]): (e[0] as CanvasItem).visible = bool(e[1])
		if is_instance_valid(orr): orr.queue_redraw())
	if TBPanel.wants_focus(): go.grab_focus.call_deferred()
	return h

class EraKeys extends Node:
	var order: Array = []
	var S: Dictionary = {}
	var show: Callable
	func _input(e: InputEvent) -> void:
		if not (e is InputEventKey) or not e.pressed or e.echo: return
		var f := get_viewport().gui_get_focus_owner()
		if f is TBPanel.SegCell or f is LineEdit: return                                  # a segmented control keeps its own arrows
		var step := 0
		if e.is_action_pressed("ui_left") or e.keycode == KEY_LEFT: step = -1
		elif e.is_action_pressed("ui_right") or e.keycode == KEY_RIGHT: step = 1
		if step == 0: return
		var i: int = order.find(String(S["era"]))
		show.call(order[(i + step + order.size()) % order.size()], true)
		get_viewport().set_input_as_handled()
