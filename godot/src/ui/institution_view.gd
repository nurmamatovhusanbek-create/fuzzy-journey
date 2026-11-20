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
		var id := String(TBInstitutions.LIST[i]["id"])
		var have := TBInstitutions.embraced(g, me, i)
		var cf := TBInstitutions.can_embrace(g, me, i)
		var sh := TBInstitutions.share(g, me, i)
		var ws := float(g.inst_share[i]) if i < g.inst_share.size() else 0.0
		var btn := K.button(String(T.call("in_embraced")) if have else String(T.call("in_embrace")), func(): on_command.call({"cmd": "embrace", "i": i}), not have and bool(cf["ok"]), true, "", "" if have else K.fmt(float(cf["gold"])))
		btn.disabled = have or not bool(cf["ok"])
		btn.custom_minimum_size.x = 130
		btn.tooltip_text = String(T.call("in_fx", {"f": fx_text(i)})) + ("" if have or bool(cf["ok"]) else "\n" + String(T.call("err_" + String(cf["reason"])) if TBI18n.has_key("err_" + String(cf["reason"])) else String(cf["reason"])))
		var tone := "ink_0" if sh >= TBInstitutions.EMBRACE_SHARE else "smoke"
		var cap := "%s · %s" % [T.call("in_yours", {"a": int(round(sh * 100.0))}), T.call("in_world", {"w": int(round(ws * 100.0))})]
		col.add_child(TBInfoRow.make(String(ICON.get(id, "info")), tone, String(T.call("inst_" + id)), String(T.call("inst_" + id + "_d")),
			[{"frac": sh, "tone": "brass_lt", "thick": true, "mark": TBInstitutions.EMBRACE_SHARE}, {"frac": ws, "tone": "smoke", "alpha": 0.7}], cap, btn))
	if not held.is_empty():
		var names: Array = []
		for i in held: names.append(String(T.call("inst_" + String(TBInstitutions.LIST[i]["id"]))))
		col.add_child(K.para_bz(String(T.call("in_held", {"l": ", ".join(names)})), 13.0, 1.3))
	if next >= 0: col.add_child(K.para_bz(String(T.call("in_next", {"n": T.call("inst_" + String(TBInstitutions.LIST[next]["id"])), "y": int(TBInstitutions.LIST[next]["year"])})), 13.0, 1.3))
	return col
