## Effects switch (Off / Light / Full): every decorative effect added after the Bezel port asks here first. Off leaves the interface exactly as it was before the effect existed
## (no new motion, no new draws); Light keeps the short, cheap ones; Full adds the ambient and cinematic ones. Reduce motion (TBKit.motion_ok) still wins over everything.
## Effects never change game state. Usage: `TBFx.tween(node, {"modulate:a": 1.0}, 0.2)`, `if TBFx.on(TBFx.FULL): ...`
class_name TBFx
extends RefCounted

const OFF := 0
const LIGHT := 1
const FULL := 2
const NAMES := ["off", "light", "full"]

static var level := FULL

static func apply(cfg: Dictionary) -> void:
	var i: int = NAMES.find(String(cfg.get("fx", "full")))
	level = FULL if i < 0 else i

## the default for an install that has no choice yet: Full only where the map tier starts at high; low and medium (software renderers, integrated GPUs, few cores, phones) get Light
static func default_for(quality: String) -> String:
	return "full" if quality == "high" else "light"

## may an effect of this weight run? (the setting is at least `min_level`, and motion is not reduced)
static func on(min_level: int = LIGHT) -> bool:
	return level >= min_level and TBKit.motion_ok()

## seconds through the switch: 0.0 when the effect may not run
static func dur(seconds: float, min_level: int = LIGHT) -> float:
	return seconds if on(min_level) else 0.0

## Tween several properties of one node. When the effect may not run (or the node is not in the tree) the end values are set at once and null is returned.
## `from` (same keys) sets the start values first; `delay` waits before starting. Kill the returned tween to skip to the end with `TBFx.finish`.
static func tween(node: Node, props: Dictionary, seconds: float, min_level: int = LIGHT, from: Dictionary = {}, delay: float = 0.0, trans: int = Tween.TRANS_CUBIC, ease_kind: int = Tween.EASE_OUT) -> Tween:
	if not is_instance_valid(node): return null
	if not on(min_level) or not node.is_inside_tree():
		for k in props: node.set_indexed(NodePath(k), props[k])
		return null
	for k in from: node.set_indexed(NodePath(k), from[k])
	var tw := node.create_tween().set_trans(trans).set_ease(ease_kind).set_parallel(true)
	for k in props:
		var tp := tw.tween_property(node, NodePath(k), props[k], seconds)
		if delay > 0.0: tp.set_delay(delay)
	return tw

## a 0..1 progress driven over `seconds` that calls `step(t)` each frame and `done` at the end; with the effect off it calls step(1.0) then done at once. Returns the tween or null.
static func run(node: Node, seconds: float, step: Callable, done: Callable = Callable(), min_level: int = LIGHT, delay: float = 0.0) -> Tween:
	if not is_instance_valid(node): return null
	if not on(min_level) or not node.is_inside_tree():
		step.call(1.0)
		if done.is_valid(): done.call()
		return null
	var tw := node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if delay > 0.0: tw.tween_interval(delay)
	tw.tween_method(step, 0.0, 1.0, seconds)
	if done.is_valid(): tw.tween_callback(done)
	return tw

## smooth 0..1 ease (in-out cubic) for hand-written animations
static func smooth(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
