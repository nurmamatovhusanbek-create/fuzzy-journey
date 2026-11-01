## The call to arms that reaches a human ally (rules 4, docs/WAR_DESIGN.md section 11): "{caller} calls you to arms", the flag of the country you would fight in the medallion,
## the reasons that weigh on the answer, how willing you are, and what refusing costs. Join / Stay out answer the pending prompt (eventChoice 0 / 1); the cross keeps it in the notice strip.
class_name TBCallPrompt
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

static func open(parent: Control, g: TBGame, e: Dictionary, on_choose: Callable, on_defer: Callable) -> TBPanel.Handle:
	var me: int = g.human_id
	var caller: int = int(e["from"]); var enemy: int = int(e["e"])
	var a: String = g.dname(caller); var en: String = g.dname(enemy)
	var chance: float = TBWar.call_chance(g, me, caller, enemy)
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("callp_title", {"a": a}), "war",
		{"w": 560.0, "medal": TBFlags.medal_of(g, enemy), "sub": T.call("callp_sub", {"e": en}), "dismissable": on_defer.is_valid(), "on_dismiss": on_defer})
	if h.bz: h.card.add_theme_stylebox_override("panel", TBBz.plate_box(12.0, true, TBWarParts.rust()))
	h.lead(T.call("callp_lead", {"a": a, "e": en}))
	var col := K.vbox(10); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.body.add_child(col)
	var names := {"trust": "callp_trust", "threat": "callp_threat", "border": "callp_border", "distance": "callp_far", "weary": "callp_weary"}
	var row := HFlowContainer.new(); row.add_theme_constant_override("h_separation", 6); row.add_theme_constant_override("v_separation", 6)
	row.alignment = FlowContainer.ALIGNMENT_CENTER; row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for tm in TBWar.call_terms(g, me, caller, enemy):
		var v: float = float(tm[1])
		if absf(v) < 0.06: continue
		row.add_child(K.chip_icon(T.call(names[String(tm[0])], {"a": a, "e": en}), "", "pos" if v > 0.0 else "neg"))
	col.add_child(row)
	col.add_child(Lean.new(chance, T.call("callp_will", {"p": int(roundf(chance * 100.0))})))
	var dl := K.label(T.call("callp_decline", {"a": a, "g": TBWar.CALL_SNUB_GRUDGE}), 15, K.DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; dl.custom_minimum_size.x = 40
	col.add_child(dl)
	var join: Button = K.button(T.call("callp_join"), func() -> void: h.close(); on_choose.call(0), true, false, "", "", "")
	var stay: Button = K.button(T.call("callp_stay"), func() -> void: h.close(); on_choose.call(1))
	h.actions(stay, join)
	h.focus_target = stay
	return h

## how willing you are: the share of the bar that is lit is the share of the call you would answer, written on it
class Lean extends Control:
	var share := 0.5
	var text := ""
	func _init(s: float, t: String) -> void:
		share = s; text = t
		custom_minimum_size = Vector2(0, 30); size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
		TBKit.a11y(self, t, "image")
	func _draw() -> void:
		var r := Rect2(0, 4, size.x, size.y - 8)
		draw_rect(r, TBTokens.BZ_TRACK_BG)
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x * share, r.size.y), Color(TBTokens.c("brass"), 0.85))
		draw_rect(r, TBTokens.BZ_TRACK_LINE, false, 1.0)
		var f := TBKit.body_b(); var fs: int = TBKit.fs(15)
		var ink: Rect2 = TBKit.ink_box(f, fs, text)
		draw_string(f, Vector2(size.x * 0.5 - ink.get_center().x, r.get_center().y - ink.get_center().y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, TBTokens.c("cream"))
