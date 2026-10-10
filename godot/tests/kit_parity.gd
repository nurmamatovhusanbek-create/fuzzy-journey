extends SceneTree
## Bezel kit parity sheet: the Godot twin of docs/ui_variants/src/b_kitparity.html (render the demo side with docs/ui_variants/shoot_kit.mjs).
## 1 logical unit = 1 pixel, window 1280 x 1180; the same specimens at the same coordinates. Compare with tools/kit_cmp.py.
##   TB_NOANIM=1 xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 -s tests/kit_parity.gd -- /tmp/par3/kit_gd.png [mode]
const K = preload("res://src/ui/ui_kit.gd")
const W := 1280
const H := 1180

static func place(parent: Control, c: Control, x: float, y: float, w: float = 0.0) -> void:
	c.position = Vector2(x, y)
	if w > 0.0: c.custom_minimum_size.x = w; c.size.x = w
	parent.add_child(c)

static func row(sep: int, kids: Array) -> HBoxContainer:
	var h := K.hbox(sep)
	for k in kids: h.add_child(k)
	return h

## builds every specimen into `r` (a Control 1280 x 1180)
static func build(r: Control) -> void:
	var hd := TBPanel.open(r, TBPanel.Kind.DRAWER, "Budget", "treasury", {"w": 560, "sub": "Net income +629 gold per turn", "pos": Vector2(24, 25), "no_anim": true})
	var bt1 := K.button("Revert"); var bt2 := K.button("Done", Callable(), true)
	hd.actions(bt1, bt2)
	hd.body.add_child(Control.new())
	var b1 := K.button("Secondary"); var b2 := K.button("Primary", Callable(), true); var b3 := K.danger("Danger", Callable(), ""); var b4 := K.button("Small", Callable(), false, true)
	var b5 := K.button("Disabled"); b5.disabled = true
	place(r, row(14, [b1, b2, b3, b4, b5]), 640, 24 + 0)
	var h1 := K.button("Hover"); h1.preview_state = "hover"
	var h2 := K.button("Hover", Callable(), true); h2.preview_state = "hover"
	var h3 := K.danger("Hover", Callable(), ""); h3.preview_state = "hover"
	var h4 := K.button("Active"); h4.preview_state = "pressed"
	var h5 := K.button("Disabled", Callable(), true); h5.disabled = true
	place(r, row(14, [h1, h2, h3, h4, h5]), 640, 76)
	var i1 := K.button("With icon", Callable(), false, false, "recruit", "8 g")
	var i2 := K.danger("Attack", Callable(), "attack"); i2.kbd = "↵"; i2._refit()
	var i3 := K.button("Sm", Callable(), false, true, "close")
	place(r, row(14, [i1, i2, i3]), 640, 128)

func _init() -> void:
	var out: String = "/tmp/par3/kit_gd.png"
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0: out = ua[0]
	TBTokens.legacy = false; K.serif = true; TBFrame.rounded = false; TBFrame.bezel = true
	TBI18n.load_lang("en")
	var vp := SubViewport.new(); vp.size = Vector2i(W, H); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var r := Control.new(); r.set_anchors_preset(Control.PRESET_FULL_RECT); r.theme = K.theme(); vp.add_child(r)
	var bg := ColorRect.new(); bg.color = TBTokens.c("table"); bg.set_anchors_preset(Control.PRESET_FULL_RECT); r.add_child(bg)
	await process_frame
	build(r)
	for i in 8: await process_frame
	vp.get_texture().get_image().save_png(out)
	if "--dump" in ua: _dump(r, "")
	print("KIT PARITY written to ", out)
	quit()

## prints the global rect of every Button / Label under n (compare with docs/ui_variants/measure_kit.mjs)
func _dump(n: Node, ind: String) -> void:
	for c in n.get_children():
		if c is Button or c is Label:
			var cc := c as Control
			print("DUMP %s\t%s\t%.2f\t%.2f\t%.2f\t%.2f" % [c.get_class(), String(c.get("text")).substr(0, 18), cc.global_position.x, cc.global_position.y, cc.size.x, cc.size.y])
		_dump(c, ind + " ")
