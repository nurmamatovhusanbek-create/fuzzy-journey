## Orders on the map (design/ux/command-card.md section 7): select an army -> targets light up -> tap / right-click / Tab a target ->
## on-map arrow + preview chip (attacks always preview) -> confirm by button, Enter, repeat tap or right-click again.
## This object owns the order state; the card and the map only render it. It never mutates the game: moves go through `do_move`
## (main -> TBGame.apply / mp.send_command).
class_name TBOrderFlow
extends RefCounted

const CC = preload("res://src/ui/cmd_card.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T

enum Mode { IDLE, ARMED, PREVIEW }

var g: TBGame
var map: TBMapView
var panel: TBProvincePanel
var host: Control                       # parent of the preview chip (main)
var do_move: Callable                   # (from: int, to: int) -> void ; main applies the move with the panel's share
var is_busy: Callable
var mode: int = Mode.IDLE
var src := -1                           # province whose army would march (the selected own army, or the chosen attacker)
var tgt := -1                           # previewed target
var explicit := false                   # "Move" pressed: own armies become targets too (merge)
var targets := PackedInt32Array()       # provinces lit on the map
var touch := false                      # the last pick came from a finger
var focus_p := -1                       # keyboard focus ring (Tab)
var _chip: TBPreviewCard
var _hover := -1

func _me() -> int: return g.human_id

func share() -> float: return panel.send_frac if panel != null else 1.0

## men a move from `from` sends, following the 25 / 50 / 75 / 100 % choice
## the fight a march would start, as far as the player may know it: an enemy province out of sight shows no defenders and no outcome (TBVision)
func _pv(q: int) -> Dictionary:
	var pv := g.combat_preview(_me(), src, q, troops_for(src))
	if g.rules >= 1 and not TBVision.sees(g, q):
		return {"unknown": true, "send": pv["send"], "defenders": -1, "win": false, "atk": 1.0, "dfn": 1.0, "hold": 0, "lost": 0, "enemy_lost": 0, "mp": pv.get("mp", 2)}
	return pv

static func _def_text(pv: Dictionary) -> String: return "?" if int(pv["defenders"]) < 0 else TBKit.fmt(int(pv["defenders"]))

func troops_for(from: int) -> int:
	var frac := share()
	if frac >= 0.999: return g.army[from] - 1
	return maxi(1, int(floor((g.army[from] - 1) * frac)))

# ---------------------------------------------------------------- queries
## what a move from the current source into q would be: {valid, kind, reason, preview (needs confirm), explicit_only}
func check(q: int, from: int = -2) -> Dictionary:
	var s := src if from == -2 else from
	var out := {"valid": false, "kind": "", "reason": "notadjacent", "preview": false, "explicit_only": false}
	if s < 0 or q < 0 or q == s: return out
	var chk := g.move_check(_me(), s, q)
	if chk == "!notadjacent" and g.rules >= 1:                          # not a neighbour: a march over our land, allies' land and ports (TBMarch)
		var pl := TBMarch.plan(g, _me(), s, q)
		if not bool(pl["ok"]):
			out["reason"] = String(pl["err"]); return out
		out["valid"] = true; out["kind"] = String(pl["kind"]); out["reason"] = ""; out["far"] = true
		var way: PackedInt32Array = pl["path"]
		out["via"] = way.slice(1, way.size() - 1)
		out["preview"] = pl["kind"] == "attack" and (g.army[q] > 0 or g.controller(q) != 0)
		out["explicit_only"] = true                                     # a march is ordered with Move (or a right click), never by a stray tap
		return out
	if chk.begins_with("!"):
		out["reason"] = chk.substr(1); return out
	out["valid"] = true; out["kind"] = chk; out["reason"] = ""
	out["preview"] = chk == "attack" and (g.army[q] > 0 or g.controller(q) != 0)
	out["explicit_only"] = chk == "move" and g.army[q] > 1
	return out

func _candidates(s: int) -> PackedInt32Array:
	var t := PackedInt32Array()
	if s < 0: return t
	for e in range(g.nb_off[s], g.nb_off[s + 1]):
		if g.nb_sea[e] != 0 and g.building[s] != TBData.B_PORT: continue
		t.append(g.nb[e])
	return t

func compute_targets() -> PackedInt32Array:
	var t := PackedInt32Array()
	if src < 0: return t
	if explicit and g.rules >= 1:                                       # Move pressed: every province the army can reach with the move points it has
		var far: Dictionary = TBMarch.targets(g, _me(), src, g.mp[_me()])
		for q in far: t.append(int(q))
		return t
	for q in _candidates(src):
		var c := check(q)
		if not c["valid"]: continue
		if c["explicit_only"] and not explicit: continue
		t.append(q)
	return t

## nearest-first list for Tab
func _by_distance(list: PackedInt32Array, from: int) -> Array:
	var w := g.world
	var arr: Array = []
	for q in list: arr.append(q)
	arr.sort_custom(func(a: int, b: int) -> bool:
		var da := TBGame.gc_dist(w.lon[from], w.lat[from], w.lon[a], w.lat[a])
		var db := TBGame.gc_dist(w.lon[from], w.lat[from], w.lon[b], w.lat[b])
		return a < b if da == db else da < db)
	return arr

## the attacker the card suggests for an enemy province: the strongest adjacent own army that could attack it
func best_source(target: int) -> int:
	var best := -1
	for e in range(g.nb_off[target], g.nb_off[target + 1]):
		var q: int = g.nb[e]
		if g.controller(q) != _me() or g.army[q] <= 1: continue
		if not check(target, q)["valid"] or str(check(target, q)["kind"]) != "attack": continue
		if best < 0 or g.army[q] > g.army[best]: best = q
	return best

# ---------------------------------------------------------------- state changes
func clear() -> void:
	mode = Mode.IDLE; src = -1; tgt = -1; explicit = false; targets = PackedInt32Array(); focus_p = -1
	_sync_map()
	_hide_chip()

## the selection changed (or the state under it): derive the armed source and light the targets
func on_select(p: int) -> void:
	tgt = -1; explicit = false; focus_p = -1
	src = -1
	if g != null and p >= 0 and g.controller(p) == _me() and g.army[p] > 1: src = p
	mode = Mode.ARMED if src >= 0 else Mode.IDLE
	targets = compute_targets()
	_sync_map(); _hide_chip()

## the world changed under an open order (after a command, an AI event): recompute, keep what is still valid
func refresh() -> void:
	if g == null: return
	if src >= 0 and (g.controller(src) != _me() or g.army[src] <= 1):
		var keep := panel.p if panel != null else -1
		clear()
		if keep >= 0: on_select(keep)
		return
	targets = compute_targets()
	if mode == Mode.PREVIEW and tgt >= 0:
		if not check(tgt)["valid"]: tgt = -1; mode = Mode.ARMED if src >= 0 else Mode.IDLE; _hide_chip()
		else: _show_preview()
	_sync_map()

func arm(p: int) -> void:                    # the Move verb / M
	if g.controller(p) != _me() or g.army[p] <= 1: return
	src = p; explicit = true; mode = Mode.ARMED; tgt = -1
	targets = compute_targets()
	_sync_map(); _hide_chip()
	if panel != null: panel.rebuild()

func disarm() -> void:
	explicit = false; tgt = -1
	mode = Mode.ARMED if src >= 0 else Mode.IDLE
	targets = compute_targets()
	_sync_map(); _hide_chip()
	if panel != null: panel.rebuild()

## open the preview for src -> q (attacks and keyboard choices); never sends anything
func preview_to(q: int, from: int = -1) -> void:
	if from >= 0: src = from
	if src < 0: return
	var c := check(q)
	if not c["valid"]:
		if panel != null: panel.reject(c["reason"])
		return
	tgt = q; mode = Mode.PREVIEW
	_show_preview(); _sync_map()
	if panel != null: panel.rebuild()

func cancel() -> void:
	if mode != Mode.PREVIEW: return
	tgt = -1
	mode = Mode.ARMED if src >= 0 else Mode.IDLE
	if panel != null and panel.p >= 0 and src >= 0 and src != panel.p and not explicit and g.controller(panel.p) != _me():
		pass                                                # an attacker chosen for an enemy province stays chosen
	targets = compute_targets()
	_hide_chip(); _sync_map()
	if panel != null: panel.rebuild()

func confirm() -> void:
	if mode != Mode.PREVIEW or tgt < 0 or src < 0: return
	var from := src; var to := tgt
	tgt = -1; mode = Mode.IDLE; explicit = false
	_hide_chip()
	do_move.call(from, to)

func share_changed() -> void:
	if mode == Mode.PREVIEW: _show_preview()
	elif src >= 0 and _hover >= 0: hover(_hover)

## a tap / click on province q. Returns true when the pick was an order action (main must not select q).
func pick(q: int, secondary: bool, from_touch: bool) -> bool:
	touch = from_touch
	if is_busy.is_valid() and is_busy.call(): return true
	if q < 0: return false
	if mode == Mode.PREVIEW:
		if q == tgt: confirm(); return true                      # repeat tap / click on the target confirms
		if q == src and not secondary: cancel(); return true     # tap the source: back to armed
		if secondary or touch or explicit:
			var c0 := check(q)
			if c0["valid"]: _order(q); return true
			if secondary: panel.reject(c0["reason"]); return true
		cancel()
		return false
	if src < 0:
		# an enemy province is selected: tapping an own army next to it picks the attacker (the card shows "From ...")
		if panel != null and panel.p >= 0 and q != panel.p and g.controller(q) == _me() and g.army[q] > 1 and g.controller(panel.p) != _me():
			var ca := check(panel.p, q)
			if ca["valid"] and ca["kind"] == "attack": panel.set_attacker(q); return true
		return false
	if q == src: return false
	var c := check(q)
	if secondary:
		if c["valid"]: _order(q)
		else: panel.reject(c["reason"])
		return true
	if explicit:
		if c["valid"]: _order(q); return true
		return false
	if touch and c["valid"] and not c["explicit_only"]:           # touch: a lit target is an order
		_order(q); return true
	return false

func _order(q: int) -> void:
	var c := check(q)
	if not c["valid"]: panel.reject(c["reason"]); return
	if c["preview"]: preview_to(q); return
	do_move.call(src, q)

# ---------------------------------------------------------------- keyboard
## Tab / Shift+Tab: nothing armed -> own armies; armed or previewing -> valid targets nearest first
func cycle(dir: int) -> void:
	if g == null or g.human_id == 0: return
	if src >= 0:
		var list := _by_distance(targets if not targets.is_empty() else compute_targets(), src)
		if list.is_empty(): return
		var i := list.find(tgt)
		i = (i + dir + list.size()) % list.size() if i >= 0 else (0 if dir > 0 else list.size() - 1)
		preview_to(list[i])
		return
	var armies: Array = []
	for p in g.P:
		if g.owner[p] == _me() and g.controller(p) == _me() and g.army[p] > 1: armies.append(p)
	if armies.is_empty(): return
	armies.sort_custom(func(a: int, b: int) -> bool: return g.army[a] > g.army[b] if g.army[a] != g.army[b] else a < b)
	var j := armies.find(focus_p)
	j = (j + dir + armies.size()) % armies.size() if j >= 0 else (0 if dir > 0 else armies.size() - 1)
	focus_p = armies[j]
	map.focus_province = focus_p
	map.fly_to(g.world.lon[focus_p], g.world.lat[focus_p])
	map.labels.queue_redraw()

# ---------------------------------------------------------------- hover (mouse): dashed arrow + result line, no commitment
func hover(q: int) -> void:
	_hover = q
	if mode == Mode.PREVIEW or src < 0 or g == null:
		return
	var c := check(q)
	map.mouse_default_cursor_shape = Control.CURSOR_CROSS if (q >= 0 and c["valid"] and c["kind"] == "attack") else Control.CURSOR_ARROW
	if q >= 0 and c["valid"]:
		var lab := ""
		if c["kind"] == "attack":
			var pv := _pv(q)
			lab = "%s : %s" % [TBKit.fmt(int(pv["send"])), _def_text(pv)]
		map.labels.set_order(src, q, c["kind"] == "attack", true, lab, true, c.get("via", PackedInt32Array()))
	else:
		map.labels.clear_order()

## the one-line outcome of attacking q from the current source, for the tooltip
func hover_result(q: int) -> Dictionary:
	if src < 0 or g == null: return {}
	var c := check(q)
	if not c["valid"] or c["kind"] != "attack": return {}
	return _pv(q)

# ---------------------------------------------------------------- map + chip plumbing
func _sync_map() -> void:
	if map == null: return
	if mode == Mode.PREVIEW and tgt >= 0:
		map.set_targets(PackedInt32Array([tgt]))
	else:
		map.set_targets(targets)
	map.dim_others = (mode == Mode.PREVIEW) or (src >= 0 and not targets.is_empty()) or explicit
	if mode == Mode.PREVIEW and tgt >= 0:
		var c := check(tgt)
		var lab := ""
		if c["kind"] == "attack":
			var pv := _pv(tgt)
			lab = "%s : %s" % [TBKit.fmt(int(pv["send"])), _def_text(pv)]
		map.labels.set_order(src, tgt, c["kind"] == "attack", true, lab, false, c.get("via", PackedInt32Array()))
	elif _hover < 0 or mode != Mode.ARMED:
		map.labels.clear_order()
	map.focus_province = focus_p

func _show_preview() -> void:
	if tgt < 0 or src < 0: return
	var c := check(tgt)
	if not c["valid"]: return
	if _chip == null or not is_instance_valid(_chip):
		_chip = TBPreviewCard.new()
		_chip.confirmed.connect(func(): confirm())
		_chip.cancelled.connect(func(): cancel())
		host.add_child(_chip)
		_chip.minimum_size_changed.connect(_place_chip)
		if map != null and not map.view_changed.is_connected(_place_chip): map.view_changed.connect(_place_chip)
	var info := {}
	if c["kind"] == "attack": info = _pv(tgt)
	var cost := g.can({"cmd": "move", "from": src, "to": tgt, "troops": troops_for(src)})
	_chip.setup(TBI18n.place(g.world.name[tgt]), c["kind"], info, int(cost["moves"]), troops_for(src))
	_chip.visible = true
	_place_chip()
	_place_chip.call_deferred()

func _hide_chip() -> void:
	if _chip != null and is_instance_valid(_chip): _chip.visible = false

func _place_chip() -> void:
	if _chip == null or not is_instance_valid(_chip) or not _chip.visible or tgt < 0 or g == null: return
	var pt := map.project(g.world.lon[tgt], g.world.lat[tgt])
	var t := Vector2(pt.x, pt.y)
	_chip.reset_size()
	var sz := _chip.size
	var vp := host.size
	var x: float = t.x + 60.0                                   # the demo's rule: right of the target, flipped to its left when it does not fit
	if x + sz.x > vp.x - 28.0: x = t.x - 60.0 - sz.x
	var y: float = clampf(t.y - sz.y * 0.5, 150.0, maxf(150.0, vp.y - sz.y - 120.0))
	var best := Vector2(x, y).floor()
	_chip.position = best

## the order as the command card shows it (read-only): the chip owns Cancel / Attack, the card only explains.
## {mode: "idle"|"armed"|"preview", src, tgt, kind, send, moves, win, hold, lost, atk, dfn, defenders}
func summary() -> Dictionary:
	var out := {"mode": ["idle", "armed", "preview"][mode], "src": src, "tgt": tgt, "kind": "", "send": 0, "moves": 0, "win": false, "hold": 0, "lost": 0, "atk": 0.0, "dfn": 0.0, "defenders": 0}
	if mode != Mode.PREVIEW or tgt < 0 or src < 0 or g == null: return out
	var c := check(tgt)
	out["kind"] = c["kind"]; out["send"] = troops_for(src)
	out["moves"] = int(g.can({"cmd": "move", "from": src, "to": tgt, "troops": troops_for(src)})["moves"])
	if c["kind"] == "attack":
		var pv := _pv(tgt)
		for k in ["win", "hold", "lost", "atk", "dfn", "defenders"]: out[k] = pv.get(k, out[k])
	return out

func is_previewing() -> bool: return mode == Mode.PREVIEW

