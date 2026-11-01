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
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("call_title", {"a": g.dname(enemy)}), "war", {"w": 560.0, "classic": true})
	if h.bz: h.card.add_theme_stylebox_override("panel", TBBz.plate_box(12.0, true, TBWarParts.rust()))
	var col := K.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.body.add_child(col)
	col.add_child(K.para_bz(T.call("call_sub", {"dp": D.DP_CALL}), 16.0, 1.35))
	var chosen := {}
	var ui := {}
	var rows := K.vbox(0); rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if allies.is_empty():
		col.add_child(K.para_bz("[i]%s[/i]" % T.call("call_none"), 15.0, 1.3))
	for o in allies:
		var ally: int = int(o)
		var human: bool = g.human[ally] != 0
		var pct: int = int(roundf(TBWar.call_chance(g, ally, me, enemy) * 100.0))
		var label: String = T.call("call_human", {"a": g.dname(ally)}) if human else T.call("call_row", {"a": g.dname(ally), "p": pct})
		var line := K.hbox(10); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(TBNationParts.FlagMedal.new(TBFlags.medal_of(g, ally), 34.0))
		var tg := K.toggle(label, false, func(on: bool) -> void:
			if on: chosen[ally] = true
			else: chosen.erase(ally)
			(ui["refresh"] as Callable).call(), 0.0)
		tg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(tg)
		rows.add_child(line)
	col.add_child(rows)
	var info := K.label("", 14, K.DIM)
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
	col.add_child(info)
	(ui["refresh"] as Callable).call()
	h.actions(later, ok)
	h.focus_target = later
	return h
