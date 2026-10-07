## Map hover tooltip (art bible 5.3 / 7.5): a dark furniture plate with at most four lines: flag + place, owner and relation
## (icon + word, never colour alone), army and terrain, and in an armed state the attack outcome.
class_name TBMapTip
extends PanelContainer

const CC = preload("res://src/ui/cmd_card.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T

var _flag: TextureRect
var _name: Label
var _rel: Label
var _army: Label
var _note: Label
var _lens: Label
var _rel_glyph: Control
var _glyph_id := ""
var _glyph_tok := "foreign_bar"

func _init() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	var box := CC.plate("bar_0", "rule_dark", TBTokens.CUT)
	box.fill_a = 0.96
	box.set_content_margin_all(8)
	add_theme_stylebox_override("panel", box)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 2)
	add_child(v)
	var top := HBoxContainer.new(); top.add_theme_constant_override("separation", 6); v.add_child(top)
	_flag = TextureRect.new(); _flag.custom_minimum_size = Vector2(24, 16); _flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _flag.stretch_mode = TextureRect.STRETCH_SCALE
	_flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_flag)
	_name = _lab("brass_lt", TBKit.body_b()); top.add_child(_name)
	var rel := HBoxContainer.new(); rel.add_theme_constant_override("separation", 4); v.add_child(rel)
	_rel_glyph = Control.new(); _rel_glyph.custom_minimum_size = Vector2(14, 16); _rel_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rel_glyph.draw.connect(func(): if _glyph_id != "": CC.glyph(_rel_glyph, _glyph_id, _rel_glyph.size * 0.5, 13.0, CC.tk(_glyph_tok), 1.4))
	rel.add_child(_rel_glyph)
	_rel = _lab("cream", TBKit.body()); rel.add_child(_rel)
	_army = _lab("cream", TBKit.body()); v.add_child(_army)
	_lens = _lab("smoke", TBKit.body()); v.add_child(_lens)
	_note = _lab("cream", TBKit.body_b()); v.add_child(_note)

func _lab(tok: String, f: Font) -> Label:
	var l := CC.label("", 14, tok, f)
	return l

func show_for(g: TBGame, p: int, flow: TBOrderFlow) -> void:
	var o := g.owner[p]
	var me := g.human_id
	_name.text = TBI18n.place(g.world.name[p])
	_flag.visible = o != 0
	if o != 0: _flag.texture = TBFlags.texture(g.nat_code[o], g.color[o])
	_glyph_id = ""; _glyph_tok = "foreign_bar"
	if o == 0: _rel.text = T.call("neutral")
	elif o == me: _rel.text = "%s · %s" % [g.dname(o), T.call("cc_tag_own")]
	else:
		var r := g.get_rel(me, o)
		var words := ["rel_peace", "cc_tag_war", "rel_nap", "rel_ally", "rel_marriage"]
		_rel.text = "%s · %s" % [g.dname(o), T.call(words[clampi(r, 0, 4)])]
		if r == D.REL_WAR: _glyph_id = "swords"; _glyph_tok = "neg_bar"
		elif r == D.REL_ALLY or r == D.REL_NAP: _glyph_id = "link"; _glyph_tok = "info_bar"
	_rel_glyph.visible = _glyph_id != ""
	_rel_glyph.queue_redraw()
	_army.text = "%s %s · %s" % [T.call("army"), TBKit.fmt(g.army[p]), T.call("t_" + D.TERRAIN_ID[g.terrain[p]])]
	var lt: String = flow.map.lenses.describe(p) if (flow != null and flow.map != null and flow.map.lenses != null) else ""
	_lens.visible = lt != ""; _lens.text = lt                     # the active lens value in words (colour is never the only carrier)
	_note.visible = false
	var pv: Dictionary = flow.hover_result(p) if flow != null else {}
	if not pv.is_empty():
		_note.visible = true
		_note.text = T.call("cc_hover_win", {"k": int(pv.get("hold", 0))}) if pv.get("win", false) else T.call("cc_hover_lose", {"a": int(pv.get("lost", 0))})
		_note.add_theme_color_override("font_color", CC.tk("pos_bar") if pv.get("win", false) else CC.tk("neg_bar"))
	if not visible and TBKit.motion_ok():
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.1)
	visible = true
	reset_size()
