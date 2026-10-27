## A retained bitmap cache for the static pieces of the HUD (medallions, rail tabs, the date dial, the End Turn dial, the lens bar...).
## A piece like the End Turn dial is ~2,000 canvas commands (every tick mark, every glyph); Godot replays all of them on every frame the screen redraws, which on a weak
## CPU / ANGLE is most of the cost of a frame in which only the map moved. A piece that has not redrawn for a few frames is drawn once into a small transparent viewport
## and shown as ONE textured quad (aligned to whole screen pixels, so the picture is the same one); the moment it draws again (hover, a new figure, a resize) it goes
## back to drawing itself, and it is baked again once it is quiet. Nothing is rasterised differently: the viewport renders the piece's own retained commands.
##
## How: the viewport shares the root's 2D world and renders only canvas layer L_BAKE; while a piece is baked it (and its children) sit on layer L_HIDE, which the root
## does not draw. The piece stays in the tree, keeps its input and its state, and its `draw` signal tells us when it changes.
class_name TBBake
extends Node

const BAKE_BITS := 12                 # layers 3..14: one per bake in flight, so a viewport sees only its own piece
const L_BAKE := ((1 << BAKE_BITS) - 1) << 2      # every bake layer: the ancestors carry all of them
const L_HIDE := 1 << 19
const QUIET := 18                    # frames a piece must go without drawing before it is baked
const PER_FRAME := 2                 # bakes started per frame (no hitch)
const MARGIN := 24.0                 # logical px of overdraw (glows, shadows) kept round the piece
static var enabled: bool = OS.get_environment("TB_NOBAKE") == ""
static var _inst: TBBake
static var _mat: CanvasItemMaterial

class Entry:
	var c: Control
	var st := 0                      # 0 drawing itself, 1 being baked, 2 baked
	var last := 0                    # frame of the last draw
	var wait := 0
	var vp: SubViewport
	var tr: TextureRect
	var sig := ""
	var xo := Vector2.ZERO
	var bit := 0                     # the layer this piece sits on while it is baked

var _free: Array = []
var _entries: Array[Entry] = []
var _hosts: Array = []
var _known := {}
var _frame := 0
var baked_count := 0

static func _ensure(tree: SceneTree) -> void:
	if _inst == null or not is_instance_valid(_inst):
		_inst = TBBake.new()
		_inst.name = "TBBake"
		tree.root.add_child.call_deferred(_inst)

static func attach(c: Control) -> void:
	if not enabled or c == null: return
	_ensure(c.get_tree())
	_inst._add.call_deferred(c)

## keep an eye on the direct children of `host` (the HUD): every leaf control drawn by an inner class of the HUD (the medallions, tabs and dials; not the classes with a file of
## their own, like the minimap and the alert ticker) is attached as soon as it exists
static func watch(host: Node) -> void:
	if not enabled or host == null: return
	_ensure(host.get_tree())
	_inst._hosts.append(host)

static func baked() -> int:
	if _inst == null or not is_instance_valid(_inst): return 0
	var n := 0
	for e in _inst._entries: if e.st == 2: n += 1
	return n

## every piece draws itself again (tests, and when the cache is switched off)
static func flush() -> void:
	if _inst == null or not is_instance_valid(_inst): return
	for e in _inst._entries: _inst._live(e)

func _ready() -> void:
	get_tree().root.canvas_cull_mask = 0xFFFFFFFF & ~L_HIDE
	get_tree().root.size_changed.connect(flush)
	for k in BAKE_BITS: _free.append(1 << (2 + k))
	if _mat == null:
		_mat = CanvasItemMaterial.new(); _mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA

func _add(c: Control) -> void:
	if not is_instance_valid(c): return
	for e in _entries: if e.c == c: return
	var e := Entry.new(); e.c = c; e.last = _frame
	_entries.append(e)
	var up: Node = c.get_parent()                                   # a layer test culls a whole branch: every ancestor must let the bake viewport through (they draw nothing there)
	while up is CanvasItem:
		(up as CanvasItem).visibility_layer |= L_BAKE
		up = up.get_parent()
	c.draw.connect(func(): _drew(e))
	c.item_rect_changed.connect(func(): if e.st != 0: _live(e))
	c.tree_exiting.connect(func(): _drop(e))

func _drop(e: Entry) -> void:
	_entries.erase(e)
	if e.vp != null and is_instance_valid(e.vp): e.vp.queue_free()
	if e.tr != null and is_instance_valid(e.tr): e.tr.queue_free()

func _drew(e: Entry) -> void:
	e.last = _frame
	if e.st != 0: _live(e)

func _items(c: Node, e: Entry, out: Array) -> void:
	if c is CanvasItem and c != e.tr: out.append(c)
	for k in c.get_children(): _items(k, e, out)

func _set_layer(e: Entry, layer: int) -> void:
	var l: Array = []
	_items(e.c, e, l)
	for it in l: (it as CanvasItem).visibility_layer = layer

func _live(e: Entry) -> void:
	if e.st == 0 or not is_instance_valid(e.c): return
	_set_layer(e, 1)
	if e.tr != null: e.tr.visible = false
	if e.vp != null: e.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if e.bit != 0: _free.append(e.bit); e.bit = 0
	e.st = 0; e.last = _frame
	baked_count = maxi(0, baked_count - 1)

## where the piece is on screen: [px origin, px per logical unit], or an empty array when it cannot be baked now
func _rect(c: Control) -> Rect2:
	if c.has_meta("bake_rect"): return (c.get_meta("bake_rect") as Callable).call()
	return Rect2(Vector2.ZERO, c.size)

func _place(e: Entry) -> Array:
	var c := e.c
	var rc := _rect(c)
	if not c.is_visible_in_tree() or rc.size.x < 2.0 or rc.size.y < 2.0: return []
	if c.modulate != Color.WHITE or c.self_modulate != Color.WHITE: return []
	var p: Node = c.get_parent()
	while p is CanvasItem:
		if (p as CanvasItem).modulate != Color.WHITE or (p as CanvasItem).self_modulate != Color.WHITE: return []
		p = p.get_parent()
	var x: Transform2D = c.get_viewport().get_final_transform() * c.get_global_transform_with_canvas()
	if absf(x.x.y) > 0.001 or absf(x.y.x) > 0.001: return []
	return [x.origin, Vector2(x.x.x, x.y.y)]

func _scan() -> void:
	for h in _hosts:
		if not is_instance_valid(h): continue
		for k in (h as Node).get_children():
			if not (k is Control) or _known.has(k.get_instance_id()): continue
			_known[k.get_instance_id()] = true
			var sc: Script = k.get_script()
			if k.get_child_count() == 0 and (sc == null or String(sc.resource_path) == "" or String(sc.resource_path).contains("::")) and k.get_class() == "Control":
				_add(k)

var _ft := Transform2D()

func _process(_d: float) -> void:
	_frame += 1
	var ft: Transform2D = get_tree().root.get_final_transform()
	if ft != _ft:                                                    # the window or the interface scale changed: the bitmaps are for another scale
		_ft = ft; flush()
	if _frame % 20 == 1: _scan()
	var started := 0
	for e in _entries:
		if not is_instance_valid(e.c): continue
		if e.st == 0:
			if _frame - e.last >= QUIET and started < PER_FRAME and _start(e): started += 1
		elif e.st == 1:
			e.wait -= 1
			if e.wait <= 0: _finish(e)
		elif e.c.modulate != Color.WHITE or e.c.self_modulate != Color.WHITE:     # a fade of the piece itself: it is a sibling of its picture, so the picture would not follow
			_live(e)
		elif _frame % 30 == e.c.get_instance_id() % 30:                    # still where it was baked, at the same scale?
			var pl := _place(e)
			if pl.is_empty() or "%s|%s" % [pl[0], pl[1]] != e.sig: _live(e)

func _start(e: Entry) -> bool:
	if _free.is_empty(): return false
	var pl := _place(e)
	if pl.is_empty(): return false
	var o: Vector2 = pl[0]; var s: Vector2 = pl[1]
	var c := e.c
	var rc := _rect(c)
	var left := floorf(o.x + (rc.position.x - MARGIN) * s.x); var top := floorf(o.y + (rc.position.y - MARGIN) * s.y)
	var right := ceilf(o.x + (rc.end.x + MARGIN) * s.x); var bottom := ceilf(o.y + (rc.end.y + MARGIN) * s.y)
	var vs := Vector2i(int(right - left), int(bottom - top))
	if vs.x < 4 or vs.y < 4 or vs.x > 4096 or vs.y > 4096: return false
	if e.vp == null:
		e.vp = SubViewport.new()
		e.vp.transparent_bg = true; e.vp.disable_3d = true; e.vp.gui_disable_input = true
		e.vp.world_2d = get_tree().root.world_2d
		add_child(e.vp)
		e.tr = TextureRect.new()
		e.tr.mouse_filter = Control.MOUSE_FILTER_IGNORE; e.tr.focus_mode = Control.FOCUS_NONE
		e.tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; e.tr.stretch_mode = TextureRect.STRETCH_SCALE
		e.tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		e.tr.material = _mat; e.tr.visible = false
		var par: Node = c.get_parent()                                   # a sibling, not a child: a branch on the hidden layer is culled with everything under it
		par.add_child(e.tr); par.move_child(e.tr, c.get_index())
		c.visibility_changed.connect(func(): if e.st == 2: e.tr.visible = c.visible)
	e.vp.size = vs
	var g: Vector2 = c.get_global_transform_with_canvas().origin
	e.vp.canvas_transform = Transform2D(Vector2(s.x, 0.0), Vector2(0.0, s.y), (o - Vector2(left, top)) - Vector2(s.x * g.x, s.y * g.y))
	e.xo = Vector2(left, top) - o
	e.sig = "%s|%s" % [o, s]
	e.bit = _free.pop_back()
	e.vp.canvas_cull_mask = e.bit
	_set_layer(e, e.bit)
	e.vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	e.st = 1; e.wait = 3
	return true

func c_pos(e: Entry) -> Vector2: return e.c.position

func _finish(e: Entry) -> void:
	var pl := _place(e)
	if pl.is_empty() or "%s|%s" % [pl[0], pl[1]] != e.sig:
		_live(e); return
	var s: Vector2 = pl[1]
	e.tr.texture = e.vp.get_texture()
	e.tr.position = c_pos(e) + e.xo / s
	e.tr.modulate = Color.WHITE
	e.tr.size = Vector2(e.vp.size) / s
	e.tr.visible = e.c.visible
	_set_layer(e, L_HIDE)
	if e.bit != 0: _free.append(e.bit); e.bit = 0
	e.st = 2
	baked_count += 1
