## After you declare war (rules 4): the sheet that lets you call your allies in (docs/WAR_DESIGN.md section 11). Each ally that can be called is a row: its flag, its name with the chance it answers
## (a player is simply asked), and a switch. "Call allies (n)" sends one `callAlly` command per ally chosen; the AI answers at once, a human gets a prompt. The cost is shown before the call.
class_name TBCallSheet
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T

## the allies of `me` that can be asked to fight `enemy` now
static func callable_allies(g: TBGame, me: int, enemy: int) -> Array:
	var out: Array = []
	if g.rules < 4: return out
	for o in range(1, g.N1):
		if g.alive[o] != 0 and TBWar.call_why(g, me, o, enemy) == "": out.append(o)
	return out

static func open(parent: Control, g: TBGame, enemy: int, on_cmd: Callable) -> TBPanel.Handle:
	var me: int = g.human_id
	var allies: Array = callable_allies(g, me, enemy)
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("call_title", {"a": g.dname(enemy)}), "war", {"w": 560.0, "classic": true, "sub": T.call("call_sub", {"dp": D.DP_CALL})})
	var col := K.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.body.add_child(col)
	var chosen := {}
	var ui := {}
	if allies.is_empty():
		col.add_child(K.para_bz("[i]%s[/i]" % T.call("call_none"), 15.0, 1.3))
	for o in allies:
		var ally: int = int(o)
		var human: bool = g.human[ally] != 0
		var chance: float = TBWar.call_chance(g, ally, me, enemy)
		var row := Row.new(TBFlags.medal_of(g, ally), g.dname(ally), reasons(g, ally, me, enemy, human),
			T.call("call_ask_tag") if human else "%d%%" % int(roundf(chance * 100.0)),
			TBTokens.c("ink_1") if human else (TBTokens.c("pos") if chance >= 0.6 else (TBTokens.c("warn") if chance >= 0.45 else TBTokens.BZ_BAD)))
		row.pressed.connect(func() -> void:
			row.set_on(not row.on)
			if row.on: chosen[ally] = true
			else: chosen.erase(ally)
			(ui["refresh"] as Callable).call())
		col.add_child(row)
	var info := K.label("", 14, K.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; info.size_flags_horizontal = Control.SIZE_EXPAND_FILL; info.size_flags_vertical = Control.SIZE_SHRINK_CENTER; info.custom_minimum_size.x = 40
	var ok: Button = K.button("", func() -> void:
		for o2 in chosen.keys(): on_cmd.call({"cmd": "callAlly", "t": int(o2), "e": enemy})
		h.close(), true, false, "war")
	var later: Button = K.button(T.call("call_notnow"), func() -> void: h.close())
	ui["refresh"] = func() -> void:
		var n: int = chosen.size()
		var afford: bool = g.dp[me] + 0.0001 >= float(D.DP_CALL * n)
		info.text = T.call("call_chosen", {"n": n, "c": D.DP_CALL * n, "h": int(floor(g.dp[me]))})
		info.add_theme_color_override("font_color", TBTokens.c("neg") if not afford else K.DIM)
		(ok as TBBz.Btn).text = T.call("call_btn", {"n": n}); (ok as TBBz.Btn)._refit()
		ok.disabled = n == 0 or not afford
	(ui["refresh"] as Callable).call()
	if h.phone or K.text_scale >= 1.4:                         # no room beside the buttons: the count goes under the rows
		col.add_child(info)
		h.actions(later, ok)
	else:                                                      # `.row3`: the count on the left, Not now and Call on the right
		h.footer.add_child(info); h.footer.add_child(later); h.footer.add_child(ok)
	h.focus_target = later
	return h

## why an ally would (not) come, in the few words under its name
static func reasons(g: TBGame, o: int, t: int, e: int, human: bool) -> String:
	if human: return T.call("callr_human")
	var parts: Array = []
	for tm in TBWar.call_terms(g, o, t, e):
		var v: float = float(tm[1])
		match String(tm[0]):
			"trust": parts.append(T.call("callr_trust_hi" if v >= 0.3 else ("callr_trust_mid" if v >= 0.15 else "callr_trust_lo")))
			"border": parts.append(T.call("callr_border" if v > 0.0 else "callr_noborder"))
			"distance":
				if v <= -0.2: parts.append(T.call("callr_far"))
				elif v >= -0.1: parts.append(T.call("callr_near"))
			"weary":
				if v <= -0.06: parts.insert(0, T.call("callr_weary"))
	return " · ".join(parts)

## one ally (`.ally`): flag, its name in capitals with the reasons beneath, the chance as a plain figure. A tap chooses it: lit when chosen, dimmed when not.
class Row extends Button:
	var on := false
	var _flag: Control
	var _name: Label
	var _why: Label
	var _fig: Label
	var _fig_col: Color
	func _init(tex: Texture2D, name_text: String, why_text: String, fig_text: String, fig_col: Color) -> void:
		flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, maxf(56.0, TBKit.touch() + 8.0)); size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		_fig_col = fig_col
		var hb := TBKit.hbox(12); hb.set_anchors_preset(Control.PRESET_FULL_RECT); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.offset_left = 6.0; hb.offset_right = -6.0; add_child(hb)
		_flag = TBNationParts.FlagMedal.new(tex, 38.0); hb.add_child(_flag)
		var tc := TBKit.vbox(2); tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_name = TBBz.TLabel.new(TBKit.cinzel(700), 14.0, 0.1, 0.0, true)
		_name.text = name_text; _name.mouse_filter = Control.MOUSE_FILTER_IGNORE; (_name as TBBz.TLabel).wrap_ok = true; (_name as TBBz.TLabel).refit(); _name.custom_minimum_size.x = 40
		tc.add_child(_name)
		_why = TBKit.label(why_text, 13, TBKit.DIM); _why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; _why.mouse_filter = Control.MOUSE_FILTER_IGNORE; _why.custom_minimum_size.x = 40
		_why.visible = why_text != ""
		tc.add_child(_why)
		hb.add_child(tc)
		_fig = TBKit.label(fig_text, 17); _fig.add_theme_font_override("font", TBKit.body_b()); _fig.size_flags_vertical = Control.SIZE_SHRINK_CENTER; _fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(_fig)
		TBKit.a11y(self, "%s %s" % [name_text, fig_text], "button", why_text)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw); focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)
		set_on(false)
	func set_on(v: bool) -> void:
		on = v
		_flag.modulate = Color(Color.WHITE, 1.0 if on else 0.5)
		_name.add_theme_color_override("font_color", TBTokens.c("cream") if on else TBKit.DIM)
		_fig.add_theme_color_override("font_color", _fig_col if on else _fig_col.darkened(0.35))
		queue_redraw()
	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var hot: bool = is_hovered() or has_focus()
		if on: draw_rect(r, Color(TBTokens.c("brass"), 0.16))
		elif hot: draw_rect(r, TBTokens.ca("cream", 0.05))
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Color(TBTokens.c("rule"), 0.6), 1.0)
		if on: draw_rect(Rect2(0, 0, 3, size.y - 1), TBTokens.c("brass_lt"))
