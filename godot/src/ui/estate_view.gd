## The Realm page's "Estates of the realm": the four orders, how much weight each has, how loyal it is, what it gives (or costs) now, and the button to court it.
class_name TBEstateView
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

## what an estate gives now, as text: "levy +2.1%, stability +0.8"
static func fx_text(g: TBGame, n: int, e: int) -> String:
	var s := TBEstates.strength(g, n, e)
	var parts := PackedStringArray()
	match e:
		0: parts.append(_f("levy", 8.0 * s)); parts.append(_f("stab", 2.0 * s, true))
		1: parts.append(_f("stab", 3.0 * s, true)); parts.append(_f("research", -3.0 * s))
		2: parts.append(_f("income", 6.0 * s))
		3: parts.append(_f("levy", 6.0 * s))
	return ", ".join(parts)

static func _f(key: String, v: float, plain: bool = false) -> String:
	var r: String = ("%.1f" % absf(v)) if absf(v) >= 0.05 else "0"
	var sg := "+" if v > 0.05 else ("−" if v < -0.05 else "")
	return String(T.call("es_f_" + key, {"v": sg + r}))

## why the loyalty moves: the terms the engine adds up (TBEstates.target_terms), one per line with its sign
static func why_text(g: TBGame, n: int, e: int) -> String:
	var lines := PackedStringArray([String(T.call("es_t_head", {"t": int(round(TBEstates.target(g, n, e))), "l": int(round(TBEstates.loyalty(g, n, e)))}))])
	for term in TBEstates.target_terms(g, n, e):
		var v: float = float(term[1])
		if String(term[0]) != "base" and absf(v) < 0.05: continue
		var shown: String = ("%d" % int(round(v))) if String(term[0]) == "base" else (("+" if v > 0.0 else "−") + "%.1f" % absf(v))
		lines.append("%s  %s" % [String(T.call("es_t_" + String(term[0]))), shown])
	return "\n".join(lines)

static func build(g: TBGame, me: int, on_command: Callable) -> Control:
	var col := K.vbox(4); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TBEstates.ensure()
	for e in TBEstates.COUNT:
		var cf := TBEstates.can_court(g, me, e)
		var btn := K.button(String(T.call("es_court")), func(): on_command.call({"cmd": "court", "e": e}), bool(cf["ok"]), true, "", K.fmt(float(cf["gold"])))
		btn.disabled = not bool(cf["ok"])
		btn.custom_minimum_size.x = 130
		btn.tooltip_text = String(T.call("es_priv", {"n": TBEstates.privileges(g, me, e)})) + ("" if bool(cf["ok"]) else "\n" + (String(T.call("err_" + String(cf["reason"]))) if TBI18n.has_key("err_" + String(cf["reason"])) else String(cf["reason"])))
		var l := TBEstates.loyalty(g, me, e)
		var angry := l < TBEstates.LOW
		var cap := String(T.call("es_loy", {"l": int(round(l)), "w": int(round(TBEstates.share(g, me, e) * 100.0))}))
		var row: Control = TBInfoRow.make(String(TBEstates.ICON[e]), "neg" if angry else "brass_lt", String(T.call("est_" + String(TBEstates.IDS[e]))), String(T.call("es_gives", {"f": fx_text(g, me, e)})),
			[{"frac": l / 100.0, "tone": "neg" if angry else "brass_lt", "thick": true, "mark": TBEstates.LOW / 100.0}, {"frac": TBEstates.share(g, me, e), "tone": "smoke", "alpha": 0.7}], cap, btn)
		row.tooltip_text = why_text(g, me, e); row.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(row)
	return col
