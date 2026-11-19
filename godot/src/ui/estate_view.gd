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

class Row extends Control:
	var g: TBGame
	var me := 0
	var e := 0
	func _init(game: TBGame, n: int, i: int) -> void:
		g = game; me = n; e = i; custom_minimum_size = Vector2(0, 60); mouse_filter = Control.MOUSE_FILTER_IGNORE; size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var id := String(TBEstates.IDS[e])
		var l := TBEstates.loyalty(g, me, e)
		var sh := TBEstates.share(g, me, e)
		var angry := l < TBEstates.LOW
		var col: Color = TBTokens.c("neg") if angry else TBTokens.c("brass_lt")
		TBBzIcons.draw(self, String(TBEstates.ICON[e]), Vector2(20, 22), 26.0, col)
		draw_string(K.body_b(), Vector2(44, 17), String(TBEstateView.T.call("est_" + id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(TBTokens.c("ink_0")))
		var sm: Font = K.body()
		var gives := String(TBEstateView.T.call("es_gives", {"f": TBEstateView.fx_text(g, me, e)}))
		draw_string(sm, Vector2(44, 34), gives, HORIZONTAL_ALIGNMENT_LEFT, size.x - 160.0, 12, Color(TBTokens.c("smoke")))
		var bx := 44.0; var bw: float = maxf(80.0, size.x - 340.0)
		draw_rect(Rect2(bx, 44, bw, 5), Color(TBTokens.c("hair")))
		draw_rect(Rect2(bx, 44, bw * clampf(l / 100.0, 0.0, 1.0), 5), Color(col))
		draw_rect(Rect2(bx + bw * TBEstates.LOW / 100.0 - 0.5, 41, 1.5, 11), Color(TBTokens.c("smoke"), 0.8))        # the line below which it petitions
		draw_rect(Rect2(bx, 52, bw, 2), Color(TBTokens.c("hair")))
		draw_rect(Rect2(bx, 52, bw * clampf(sh, 0.0, 1.0), 2), Color(TBTokens.c("smoke"), 0.7))
		var lab := String(TBEstateView.T.call("es_loy", {"l": int(round(l)), "w": int(round(sh * 100.0))}))
		draw_string(sm, Vector2(bx + bw + 8, 52), lab, HORIZONTAL_ALIGNMENT_LEFT, size.x - bw - bx - 12.0, 11, Color(TBTokens.c("smoke")))

static func build(g: TBGame, me: int, on_command: Callable) -> Control:
	var col := K.vbox(4); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	TBEstates.ensure()
	for e in TBEstates.COUNT:
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 8); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(Row.new(g, me, e))
		var cf := TBEstates.can_court(g, me, e)
		var btn := K.button(String(T.call("es_court")), func(): on_command.call({"cmd": "court", "e": e}), bool(cf["ok"]), true, "", K.fmt(float(cf["gold"])))
		btn.disabled = not bool(cf["ok"])
		btn.custom_minimum_size.x = 130
		btn.tooltip_text = String(T.call("es_priv", {"n": TBEstates.privileges(g, me, e)})) + ("" if bool(cf["ok"]) else "\n" + (String(T.call("err_" + String(cf["reason"]))) if TBI18n.has_key("err_" + String(cf["reason"])) else String(cf["reason"])))
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(btn)
		col.add_child(line)
	return col
