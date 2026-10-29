## Finger scrolling for every list in the interface. A row under the finger takes the touch for itself (a press that waits for its release), so the list never saw the drag; this node watches
## the raw touch events, and a mostly vertical drag that starts over a scrollable list scrolls that list with the finger (and keeps scrolling a little after the finger lifts). The press the
## drag began on is cancelled, so lifting the finger does not press the row. A tap, a horizontal drag (sliders) and the map are left alone.
class_name TBTouchScroll
extends Node

const START_PX := 12.0                 # physical pixels of movement before a drag counts as a scroll (compared in logical units)
const FLING_DECAY := 0.93              # per frame at 60 fps
var root_ctl: Control                  # the interface root searched for lists

var _sc: ScrollContainer = null
var _start := Vector2.ZERO             # logical
var _total := Vector2.ZERO
var _active := false
var _vel := 0.0                        # logical units per second
var _fling := 0.0
var _last_ms := 0
var _fingers := 0

func _scale() -> float: return maxf(0.1, get_viewport().get_final_transform().get_scale().x)

## the topmost list that can scroll vertically and holds the point (logical coordinates)
func _find(n: Node, pt: Vector2, best: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible: return
	if n is ScrollContainer:
		var s := n as ScrollContainer
		if s.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and s.get_global_rect().has_point(pt) and s.get_v_scroll_bar().max_value > s.get_v_scroll_bar().page + 2.0:
			best[0] = s
	for k in n.get_children(): _find(k, pt, best)

func _cancel_press() -> void:
	# the finger has become a scroll: tell whatever holds the emulated mouse press that the pointer left, so its release is not a click
	var mv := InputEventMouseMotion.new()
	mv.position = Vector2(-4000.0, -4000.0); mv.global_position = mv.position; mv.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(mv)

func _input(e: InputEvent) -> void:
	if root_ctl == null: return
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_fingers += 1
			if _fingers > 1: _sc = null; _active = false; return
			_fling = 0.0
			var pt: Vector2 = t.position                                  # events arrive in the interface's own (logical) coordinates
			var best: Array = [null]
			_find(root_ctl, pt, best)
			_sc = best[0]; _start = t.position; _total = Vector2.ZERO; _active = false; _vel = 0.0; _last_ms = Time.get_ticks_msec()
		else:
			_fingers = maxi(0, _fingers - 1)
			if _sc != null and _active:
				get_viewport().set_input_as_handled()
				_fling = _vel if absf(_vel) > 60.0 and Time.get_ticks_msec() - _last_ms < 120 else 0.0
			else: _fling = 0.0
			_sc = null; _active = false
	elif e is InputEventScreenDrag and _sc != null and is_instance_valid(_sc):
		var d := e as InputEventScreenDrag
		_total += d.relative
		if not _active:
			if absf(_total.y) >= START_PX / _scale() and absf(_total.y) > absf(_total.x) * 1.2:
				_active = true
				_fling_sc = _sc
				_cancel_press()
			else: return
		var dy: float = d.relative.y
		_sc.scroll_vertical = int(clampf(float(_sc.scroll_vertical) - dy, 0.0, _sc.get_v_scroll_bar().max_value))
		var now := Time.get_ticks_msec()
		var dt: float = maxf(0.004, float(now - _last_ms) / 1000.0)
		_vel = lerpf(_vel, -dy / dt, 0.5); _last_ms = now
		get_viewport().set_input_as_handled()
	elif e is InputEventScreenDrag and _fingers > 1:
		_sc = null; _active = false

func _process(delta: float) -> void:
	if absf(_fling) < 8.0: _fling = 0.0; return
	if _sc != null: _fling = 0.0; return
	var last: ScrollContainer = null
	# the fling continues on the list it began on (kept while it is still shown)
	if is_instance_valid(_fling_sc) and _fling_sc.is_visible_in_tree(): last = _fling_sc
	if last == null: _fling = 0.0; return
	last.scroll_vertical = int(clampf(float(last.scroll_vertical) + _fling * delta, 0.0, last.get_v_scroll_bar().max_value))
	_fling *= pow(FLING_DECAY, delta * 60.0)

var _fling_sc: ScrollContainer = null
