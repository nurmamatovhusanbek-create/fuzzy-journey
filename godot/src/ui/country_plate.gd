## The country plate: at country level a tap on a country's land gives its plate (the army and the district are not asked for yet): the flag, the name, the ruler, three facts
## (provinces, army, income: the army stays "?" until agents have looked) and what can be done with it: its card, diplomacy, trade; for your own country the realm, the budget and the decrees.
## Standing is not in the plate: it is the stars under each capital on the map (TBStanding). Opens beside the capital, inside the screen, clear of the HUD.
class_name TBCountryPlate
extends PanelContainer

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

signal act(what: String, nation: int)
signal closed

var _g: TBGame
var _n := 0
var _env: Dictionary = {}

## a bordered fact: one line of text centred in a box that is always as wide as the text plus its air
class Fact extends Control:
	var txt := ""
	var dim := false
	func _init(t: String, is_dim: bool = false) -> void:
		txt = t; dim = is_dim
		var f: Font = TBKit.body_i() if is_dim else TBKit.body()
		custom_minimum_size = Vector2(ceilf(f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(TBKit.fsf(14.0))).x) + 28.0, 30.0)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL; mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), TBTokens.BZ_WELL)
		draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), TBTokens.BZ_WELL_LINE, false, 1.0)
		var f: Font = TBKit.body_i() if dim else TBKit.body()
		TBBuildPicker.ctext(self, txt, size * 0.5, f, int(TBKit.fsf(14.0)), TBTokens.BZ_DIM if dim else TBTokens.BZ_IVORY)

func setup(g: TBGame, n: int, anchor: Vector2, env: Dictionary) -> void:
	_g = g; _n = n; _env = env
	top_level = true; z_index = 58
	custom_minimum_size.x = minf(400.0 if not TBKit.is_phone(self) else 340.0, get_viewport_rect().size.x - 16.0)          # never wider than a portrait phone
	add_theme_stylebox_override("panel", TBBz.plate_box(10.0, true))
	var m := MarginContainer.new()
	for side in ["left", "right"]: m.add_theme_constant_override("margin_" + side, 24)
	m.add_theme_constant_override("margin_top", 22); m.add_theme_constant_override("margin_bottom", 24)
	add_child(m)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 20)
	m.add_child(v)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 18)
	var medal := TBNationParts.FlagMedal.new(TBFlags.medal_of(g, n), 64.0)
	top.add_child(medal)
	var tv := VBoxContainer.new(); tv.add_theme_constant_override("separation", 6); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nl: Label = K.wrappable(K.title(g.dname(n), 19, TBTokens.c("ink_0"), 0.06, 19.0 * 1.15))
	tv.add_child(nl)
	if g.rules >= 1 and g.r_name[n] != "":
		tv.add_child(K.para_bz("[i]%s %s[/i]" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)], 15.0, 1.25))
	top.add_child(tv)
	v.add_child(top)
	var facts := HBoxContainer.new(); facts.add_theme_constant_override("separation", 10)
	var prov := 0
	for p in g.P: if g.owner[p] == n: prov += 1
	facts.add_child(Fact.new(T.call("cp_provinces", {"n": prov})))
	var own: bool = n == g.human_id
	var seen: bool = own or TBVision.nation_seen(g, g.human_id, n)               # a friend, a pact, or a report from their court (the Survey operation) shows the army
	if seen:
		var men := 0
		for p in g.P: if g.controller(p) == n: men += g.army[p]
		facts.add_child(Fact.new(T.call("cp_men", {"n": K.fmt(float(men))})))
	else:
		facts.add_child(Fact.new(T.call("cp_army_hidden"), true))
	var inc: int = int(g.income(n)["gold"])
	facts.add_child(Fact.new(T.call("cp_gold", {"n": ("+%d" % inc) if inc >= 0 else str(inc)})))
	v.add_child(facts)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
	var acts: Array = [["realm", "cp_realm"], ["budget", "cp_budget"], ["decrees", "cp_decrees"]] if own else [["nation", "cp_nation"], ["diplo", "cp_diplo"], ["trade", "cp_trade"]]
	for a in acts:
		var key: String = a[0]
		var b: Button = K.button(T.call(String(a[1])), func(): act.emit(key, n); queue_free(); closed.emit(), false, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	v.add_child(row)
	_place(anchor)
	_place.bind(anchor).call_deferred()

## beside the capital (right of it, then left), inside the screen, clear of the HUD
func _place(anchor: Vector2) -> void:
	if not is_inside_tree(): return
	reset_size(); size = get_combined_minimum_size()
	var vp: Vector2 = get_viewport_rect().size
	var bounds: Rect2 = _env.get("bounds", Rect2(Vector2.ZERO, vp))
	var lo := bounds.position + Vector2(8, 8)
	var hi := bounds.end - size - Vector2(8, 8)
	var y: float = clampf(anchor.y - size.y * 0.5, lo.y, maxf(lo.y, hi.y))
	var x: float = anchor.x + 34.0
	if x + size.x > bounds.end.x - 8.0: x = anchor.x - 34.0 - size.x
	var r := Rect2(Vector2(x, y), size)
	for k in _env.get("keep", []):
		if (k as Rect2).intersects(r):
			var up: float = (k as Rect2).position.y - size.y - 6.0
			var dn: float = (k as Rect2).end.y + 6.0
			if up >= lo.y: r.position.y = up
			elif dn <= hi.y: r.position.y = dn
	position = Vector2(clampf(r.position.x, lo.x, maxf(lo.x, hi.x)), clampf(r.position.y, lo.y, maxf(lo.y, hi.y))).floor()

func _input(e: InputEvent) -> void:
	if not visible: return
	if e is InputEventMouseButton and e.pressed:
		if not get_global_rect().has_point(e.position): closed.emit(); queue_free()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		closed.emit(); queue_free(); get_viewport().set_input_as_handled()
