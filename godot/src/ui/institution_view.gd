## The Realm page's "Institutions of the age": each institution that exists, how much of your land and of the world carries it, what embracing gives, and the button; the next one still to come.
class_name TBInstitutionView
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
static var ICON := {"banking": "treasury", "printing": "annals", "navigation": "port", "standing_armies": "host", "joint_stock": "trade", "enlightenment": "lamp", "industry": "workshop", "railways": "supply", "electricity": "research", "welfare": "people", "computing": "settings"}

static func fx_text(i: int) -> String:
	var parts := PackedStringArray()
	var fx: Dictionary = TBInstitutions.LIST[i]["fx"]
	for key in ["income", "research", "levy", "pop", "stab"]:
		if not fx.has(key): continue
		var v: float = float(fx[key])
		parts.append(String(T.call("in_fx_" + key, {"v": ("%d" % int(round(v * 100.0))) if key != "stab" else ("%.1f" % v if v != floorf(v) else "%d" % int(v))})))
	return ", ".join(parts)

class Row extends Control:
	var g: TBGame
	var me := 0
	var idx := 0
	func _init(game: TBGame, n: int, i: int) -> void:
		g = game; me = n; idx = i; custom_minimum_size = Vector2(0, 60); mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var id := String(TBInstitutions.LIST[idx]["id"])
		var have := TBInstitutions.embraced(g, me, idx)
		var sh := TBInstitutions.share(g, me, idx)
		var ws := float(g.inst_share[idx]) if idx < g.inst_share.size() else 0.0
		var col: Color = TBTokens.c("brass_lt") if have else (TBTokens.c("ink_0") if sh >= TBInstitutions.EMBRACE_SHARE else TBTokens.c("smoke"))
		TBBzIcons.draw(self, String(TBInstitutionView.ICON.get(id, "info")), Vector2(20, 22), 26.0, col)
		var f: Font = K.body_b()
		draw_string(f, Vector2(44, 17), String(TBI18n.T.call("inst_" + id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col))
		var sm: Font = K.body()
		draw_string(sm, Vector2(44, 34), String(TBI18n.T.call("inst_" + id + "_d")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 160.0, 12, Color(TBTokens.c("smoke")))
		# the two bars: your land (brass) and the world (grey), as thin rules
		var bx := 44.0; var bw: float = maxf(80.0, size.x - 340.0)
		draw_rect(Rect2(bx, 44, bw, 4), Color(TBTokens.c("hair")))
		draw_rect(Rect2(bx, 44, bw * clampf(sh, 0.0, 1.0), 4), Color(TBTokens.c("brass_lt")))
		draw_rect(Rect2(bx, 51, bw, 3), Color(TBTokens.c("hair")))
		draw_rect(Rect2(bx, 51, bw * clampf(ws, 0.0, 1.0), 3), Color(TBTokens.c("smoke"), 0.7))
		var lab := "%s · %s" % [T_.call("in_yours", {"a": int(round(sh * 100.0))}), T_.call("in_world", {"w": int(round(ws * 100.0))})]
		draw_string(sm, Vector2(bx + bw + 8, 52), lab, HORIZONTAL_ALIGNMENT_LEFT, size.x - bw - bx - 12.0, 11, Color(TBTokens.c("smoke")))
	static var T_: Callable = TBI18n.T

static func build(g: TBGame, me: int, on_command: Callable) -> Control:
	var col := K.vbox(4); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TBInstitutions.ensure()
	var behind: int = TBInstitutions.lag(g, me)
	if behind > 0: col.add_child(K.para_bz(String(T.call("in_behind")), 14.0, 1.3))
	var next := -1
	var held: Array = []
	for i in TBInstitutions.count():
		if g.inst_seen[i] == 0:
			if next < 0 or int(TBInstitutions.LIST[i]["year"]) < int(TBInstitutions.LIST[next]["year"]): next = i
			continue
		if TBInstitutions.embraced(g, me, i):                                   # what you already carry folds into one line: the page leads with choices, not with a ledger of finished things
			held.append(i); continue
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 8); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row := Row.new(g, me, i); line.add_child(row)
		var have := TBInstitutions.embraced(g, me, i)
		var cf := TBInstitutions.can_embrace(g, me, i)
		var btn := K.button(String(T.call("in_embraced")) if have else String(T.call("in_embrace")), func(): on_command.call({"cmd": "embrace", "i": i}), not have and bool(cf["ok"]), true, "", "" if have else K.fmt(float(cf["gold"])))
		btn.disabled = have or not bool(cf["ok"])
		btn.custom_minimum_size.x = 130
		btn.tooltip_text = String(T.call("in_fx", {"f": fx_text(i)})) + ("" if have or bool(cf["ok"]) else "\n" + String(T.call("err_" + String(cf["reason"])) if TBI18n.has_key("err_" + String(cf["reason"])) else String(cf["reason"])))
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(btn)
		col.add_child(line)
	if not held.is_empty():
		var names: Array = []
		for i in held: names.append(String(T.call("inst_" + String(TBInstitutions.LIST[i]["id"]))))
		col.add_child(K.para_bz(String(T.call("in_held", {"l": ", ".join(names)})), 13.0, 1.3))
	if next >= 0: col.add_child(K.para_bz(String(T.call("in_next", {"n": T.call("inst_" + String(TBInstitutions.LIST[next]["id"])), "y": int(TBInstitutions.LIST[next]["year"])})), 13.0, 1.3))
	return col
