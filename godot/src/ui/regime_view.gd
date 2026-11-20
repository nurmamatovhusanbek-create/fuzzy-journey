## The Realm page's "Form of government": the forms open to the nation's era, what each means (income, stability, the order it leans on), the names it would open, and the Reform button.
class_name TBRegimeView
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

static func summary(r: int) -> String:
	var reg: Dictionary = TBData.REGIMES[r]
	var top := TBRegimes._top_estate(String(TBData.REGIME_ID[r]))
	var inc := int(round(float(reg["incMul"]) * 100.0))
	return String(T.call("rg_d" if inc != 100 else "rg_d1", {"i": inc, "s": int(reg["stabCeil"]), "e": T.call("est_" + String(TBEstates.IDS[top]))}))

static func build(g: TBGame, me: int, on_command: Callable) -> Control:
	var col := K.vbox(4); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for r in TBRegimes.TARGETS:
		if g.regime[me] != r and String(TBRegimes.can_reform(g, me, r)["reason"]) == "reg_era": continue
		var have: bool = g.regime[me] == r
		var cf := TBRegimes.can_reform(g, me, r)
		var btn := K.button(String(T.call("rg_now")) if have else String(T.call("rg_reform")), func(): on_command.call({"cmd": "regime", "r": r}), not have and bool(cf["ok"]), true, "", "" if have else K.fmt(float(cf["gold"])))
		btn.disabled = have or not bool(cf["ok"])
		btn.custom_minimum_size.x = 130
		btn.tooltip_text = "" if have or bool(cf["ok"]) else (String(T.call("err_" + String(cf["reason"]))) if TBI18n.has_key("err_" + String(cf["reason"])) else String(cf["reason"]))
		var desc := summary(r)
		var op: Array = TBRegimes.opens(g, me, r)
		if not op.is_empty():
			var names := PackedStringArray()
			for si in op: names.append(TBI18n.nation(String(TBLineage.STAGES[si]["name"])))
			desc += "\n" + String(T.call("rg_opens", {"n": ", ".join(names)}))
		col.add_child(TBInfoRow.make("scales", "brass_lt" if have else "ink_0", String(T.call("g_" + String(TBData.REGIME_ID[r]))), desc, [], "", btn))
	return col
