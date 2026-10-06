## Screens and dialogs. Every container comes from TBPanel (Dialog / Drawer-Sheet / Wide panel-Page); this file holds the recipes:
##   merged screens   nations_screen (Nations + Statistics + Nation card), council (Advice + Goals), menu_hub (Saves, Settings, How to play, Honours)
##   drawers          budget, chronicle (Annals), council
##   panels           new_game (era, difficulty, players), decisions
##   dialogs          event / ultimatum (hero sheet), game over (hero sheet), briefing, tutorial, pass-device, confirm
class_name TBModals
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T
const ERAS := TBNewGame.ERAS
const ERA_YEAR := TBNewGame.ERA_YEAR
const CODEX := ["infamy", "cb", "ultimatum", "generals", "battle", "supply", "rulers", "doctrine", "trade", "realms", "victory"]

# ---- entry points used by main / HUD ------------------------------------------------------------------------------------------------------------
static func nations_screen(parent: Control, g: TBGame, opts: Dictionary = {}) -> TBPanel.Handle:
	return TBNationsScreen.open(parent, g, opts)

static func menu_hub(parent: Control, ctx: Dictionary) -> TBPanel.Handle:
	return TBMenuHub.open(parent, ctx)

static func new_game(parent: Control, opts: Dictionary) -> TBPanel.Handle:
	return TBNewGame.open(parent, opts)

## compatibility entry for the multiplayer room creator: era + difficulty only (no Players selector)
static func era_picker(parent: Control, difficulty: String, on_start: Callable, on_back: Callable) -> void:
	TBNewGame.open(parent, {"difficulty": difficulty, "mp": true, "next_label": T.call("create_room"), "on_back": on_back,
		"on_next": func(era: String, diff: String, _players: int): on_start.call(era, diff)})

static func confirm(parent: Control, title_text: String, text: String, confirm_label: String, on_yes: Callable, danger: bool = true) -> TBPanel.Handle:
	return TBPanel.confirm(parent, title_text, text, confirm_label, on_yes, danger)

# ---- effect text and chips ------------------------------------------------------------------------------------------------------------------
## "-40 gold · stability -8" summary of scheduled-event effects
static func fx_text(effects: Array) -> String:
	var parts: PackedStringArray = []
	for e in effects:
		var op := String(e.get("op", "")).trim_prefix("nation.")
		var d := float(e.get("delta", 0))
		if op == "dev": parts.append(T.call("fx_dev")); continue
		if d == 0.0 or not TBI18n.has_key("fx_" + op): continue
		var ds := "%+d" % int(d) if op != "combat" else "%+d%%" % int(d)
		parts.append(T.call("fx_" + op, {"d": ds.replace("-", "−"), "t": int(e.get("turns", 6))}))
	return " · ".join(parts)

## the same effects as chips [[text, glyph, tone]]. One rule everywhere (art bible 4.4): the glyph follows the SIGN of the number (up = +, down = U+2212),
## the colour follows meaning (good / bad). Infamy and upkeep are bad when they rise: they keep the up glyph in the negative colour.
static func fx_chips(effects: Array) -> Array:
	var out: Array = []
	for e in effects:
		var op := String(e.get("op", "")).trim_prefix("nation.")
		var d := float(e.get("delta", 0))
		if op == "dev": out.append([T.call("fx_dev"), "tri_up", "pos"]); continue
		if d == 0.0 or not TBI18n.has_key("fx_" + op): continue
		var ds := "%+d" % int(d) if op != "combat" else "%+d%%" % int(d)
		var txt: String = T.call("fx_" + op, {"d": ds.replace("-", "−"), "t": int(e.get("turns", 6))})
		out.append([txt, "tri_up" if d > 0.0 else "tri_down", delta_tone(d > 0.0, op == "infamy")])
	return out

## tone of a change: `up` = the number rises; `bad_when_up` = a rising number hurts (infamy)
static func delta_tone(up: bool, bad_when_up: bool = false) -> String:
	return "pos" if (up != bad_when_up) else "neg"

static var _minus_re: RegEx
## a hyphen-minus before a digit becomes the true minus U+2212
static func true_minus(t: String) -> String:
	if _minus_re == null:
		_minus_re = RegEx.new(); _minus_re.compile("(^|[\\s(])-(?=\\d)")
	return _minus_re.sub(t, "$1−", true)

## chips from a prose effect line ("−60 gold · +30 research"): split on the middle dot; the glyph follows the sign, the tone the meaning
static func chips_from_text(line: String) -> Array:
	var out: Array = []
	if line.strip_edges() == "": return out
	var inf: String = T.call("infamy").to_lower()
	for part in line.split(" · "):
		var p: String = true_minus(part.strip_edges())
		if p == "": continue
		var neg: bool = p.contains("−")
		var pos: bool = p.contains("+")
		if pos != neg:
			out.append([p, "tri_up" if pos else "tri_down", delta_tone(pos, p.to_lower().contains(inf))])
		else: out.append([p, "", "neutral"])
	return out

static func _loc(d: Variant) -> String:
	if d is Dictionary: return String(d.get(TBI18n.lang, d.get("en", "")))
	return String(d)

# =====================================================================================================================================================
# Budget (drawer / sheet): headline net/turn, four allocation sliders with their effect lines, presets; [Revert] [Done]
# =====================================================================================================================================================
const BUDGET_KEYS := ["tax", "goods", "research", "invest"]
const PRESETS := {"balanced": [50, 20, 15, 15], "war": [60, 10, 10, 20], "growth": [40, 20, 20, 20]}

static func _budget_set(g: TBGame, n: int, vals: Array) -> void:
	for pass_i in 4:
		for i in 4:
			if int(g.budget[n * 4 + i]) != int(vals[i]): g.apply({"cmd": "budget", "n": n, "key": BUDGET_KEYS[i], "val": int(vals[i])})

static func budget(parent: Control, g: TBGame, on_change: Callable) -> TBPanel.Handle:
	var n := g.human_id
	var h := TBPanel.open(parent, TBPanel.Kind.DRAWER, T.call("budget"), "coins")
	var start: Array = []
	for i in 4: start.append(int(g.budget[n * 4 + i]))
	var base_net: int = int(g.income(n)["net"])
	var sliders: Array = []
	var vls: Array = []
	var fxs: Array = []
	var net_slot := K.hbox(6)
	h.body.add_child(net_slot)
	var preset_seg: Control
	var sync := func() -> void:
		var inc := g.income(n)
		var net: int = int(inc["net"])
		for c in net_slot.get_children(): c.queue_free()
		net_slot.add_child(K.chip("%s %s" % [T.call("income_net"), K.signed(net)], "coins", "pos" if net >= 0 else "neg"))
		if net != base_net: net_slot.add_child(K.chip(K.signed(net - base_net), "tri_up" if net > base_net else "tri_down", "pos" if net > base_net else "neg"))
		var tax: int = g.budget[n * 4]; var goods: int = g.budget[n * 4 + 1]; var res: int = g.budget[n * 4 + 2]; var inv: int = g.budget[n * 4 + 3]
		var happy_t: int = int(clampf(50.0 + (goods - 20) * 0.6 - maxf(0.0, tax - 50) * 0.5, 0.0, 100.0))
		var rsp: float = D.tech_gain(int(inc["pop"]), res)
		var lines: Array = [
			T.call("bud_tax_fx", {"g": int(inc["tax"])}),
			T.call("bud_goods_fx", {"h": happy_t}),
			T.call("bud_research_fx", {"r": "%.1f" % rsp}),
			T.call("bud_invest_fx", {"p": "%.1f" % (inv * 0.05)})]
		for i in 4:
			(sliders[i] as HSlider).set_value_no_signal(g.budget[n * 4 + i])
			(vls[i] as Label).text = "%d%%" % int(g.budget[n * 4 + i])
			(fxs[i] as Label).text = lines[i]
		on_change.call()
	var vsb: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var grid := GridContainer.new(); grid.columns = 2 if (TBPanel.is_short(vsb) and K.text_scale < 1.4) else 1
	grid.add_theme_constant_override("h_separation", 24); grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(grid)
	for i in 4:
		var idx := i
		var blk := K.vbox(2); blk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var head := K.hbox(8); head.add_child(K.title(T.call(BUDGET_KEYS[i]), 16, K.TEXT))
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; head.add_child(sp)
		var vl := K.num("", 16, K.TEXT); head.add_child(vl); vls.append(vl)
		blk.add_child(head)
		var row := K.hbox(6)
		var minus := K.button("−", func(): g.apply({"cmd": "budget", "n": n, "key": BUDGET_KEYS[idx], "val": maxi(0, int(g.budget[n * 4 + idx]) - 5)}); sync.call())
		minus.custom_minimum_size = Vector2(K.touch(), K.touch()); K.a11y(minus, "−5%", "button")
		var s := K.slider(0, 100, 1, g.budget[n * 4 + i], func(v: float): g.apply({"cmd": "budget", "n": n, "key": BUDGET_KEYS[idx], "val": int(v)}); sync.call())
		s.scrollable = false
		var plus := K.button("+", func(): g.apply({"cmd": "budget", "n": n, "key": BUDGET_KEYS[idx], "val": mini(100, int(g.budget[n * 4 + idx]) + 5)}); sync.call())
		plus.custom_minimum_size = Vector2(K.touch(), K.touch()); K.a11y(plus, "+5%", "button")
		row.add_child(minus); row.add_child(s); row.add_child(plus)
		blk.add_child(row); sliders.append(s)
		var fx := TBPanel.para("", 13, K.DIM); blk.add_child(fx); fxs.append(fx)
		grid.add_child(blk)
	h.body.add_child(TBPanel.section(T.call("preset")))
	preset_seg = TBPanel.seg([["balanced", T.call("pre_balanced")], ["war", T.call("pre_war")], ["growth", T.call("pre_growth")]], "", func(id: String): _budget_set(g, n, PRESETS[id]); sync.call())
	h.body.add_child(preset_seg)
	var revert := K.button(T.call("revert"), func(): _budget_set(g, n, start); sync.call())
	var done := K.button(T.call("done"), func(): h.close(), true)
	h.actions(revert, done)
	sync.call()
	return h

# =====================================================================================================================================================
# Decisions (wide panel / page): doctrine on the left, decisions grouped Active / Available / Unavailable on the right
# =====================================================================================================================================================
const DEC_GLYPH := {"mil_reform": "swords", "trade_fair": "scales", "centralize": "crown", "conscript": "men", "propaganda": "scroll", "patronage": "book", "fortify": "shield", "amnesty": "dove"}

static func _dec_reason(why: String) -> String:
	var key := "err_" + why
	return T.call(key) if TBI18n.has_key(key) else why

class DecisionRow extends PanelContainer:
	func _init(g: TBGame, i: int, me: int, on_enact: Callable) -> void:
		var d: Dictionary = TBDecisions.LIST[i]
		var active := TBDecisions.is_active(g, me, i)
		var why := TBDecisions.why_not(g, me, i)
		var reason: String = "" if active else TBModals._dec_reason(why)
		add_theme_stylebox_override("panel", TBKit.card_style("disabled" if (why != "" and not active) else "normal", false, false))
		var row := TBKit.hbox(12); add_child(row)
		var tile := Control.new(); tile.custom_minimum_size = Vector2(32, 32); tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN; tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ts := TBFrame.plate(TBTokens.c("paper_0"), TBTokens.c("hair"), 2, 0, 0, 0)
		var gid: String = TBModals.DEC_GLYPH.get(d["id"], "scroll")
		tile.draw.connect(func():
			tile.draw_style_box(ts, Rect2(Vector2.ZERO, tile.size))
			TBGlyph.draw(tile, gid, (tile.size * 0.5).round(), 20.0, TBTokens.c("ink_0")))
		row.add_child(tile)
		var col := TBKit.vbox(3); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(col)
		var tt := TBKit.title(TBI18n.T("dec_" + String(d["id"])), 15, TBTokens.c("oxblood") if active else TBTokens.c("ink_0"))
		tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tt.custom_minimum_size.x = 40
		col.add_child(tt)
		col.add_child(TBPanel.para(TBI18n.T("dec_%s_d" % d["id"]), 13, TBTokens.c("ink_1")))
		var cf := TBPanel.flow(6)
		if active:
			var left := TBDecisions.turns_left(g, me, i)
			cf.add_child(TBKit.chip(TBI18n.T("dec_forever") if left > 5000 else TBI18n.T("dec_left", {"n": left}), "check", "pos"))
		else:
			cf.add_child(TBKit.chip(str(int(d["gold"])), "coin", "neutral" if g.gold[me] >= float(d["gold"]) else "neg"))
			cf.add_child(TBKit.chip(str(int(d["mp"])), "swords", "neutral" if g.mp[me] >= float(d["mp"]) else "neg"))
		col.add_child(cf)
		if reason != "":
			var rr := TBKit.hbox(4); rr.add_child(TBKit.glyph("lock", 14, TBTokens.c("neg")))
			var rl := TBPanel.para(reason, 13, TBTokens.c("neg")); rr.add_child(rl); col.add_child(rr)
		if not active:
			var b := TBKit.button(TBI18n.T("dec_do"), on_enact)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if why != "": TBKit.disable(b, reason)
			row.add_child(b)

static func decisions(parent: Control, g: TBGame, on_cmd: Callable) -> TBPanel.Handle:
	var me := g.human_id
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var portrait := TBPanel.is_portrait(vs)
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("decisions"), "scales", {"scroll": portrait, "padded": portrait})
	var wide: bool = not portrait
	var left: Control; var right: Control
	var lv: VBoxContainer; var rv: VBoxContainer
	if wide:
		var split := K.hbox(0); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.body.add_child(split)
		var cols: Array = []
		for k in 2:
			var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.follow_focus = true; sc.scroll_deadzone = 12
			sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var mg := MarginContainer.new(); mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mg.add_theme_constant_override("margin_left", h.pad if k == 0 else 16); mg.add_theme_constant_override("margin_right", 16 if k == 0 else h.pad)
			mg.add_theme_constant_override("margin_top", 12); mg.add_theme_constant_override("margin_bottom", 12)
			var v := K.vbox(10); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mg.add_child(v); sc.add_child(mg)
			cols.append([sc, v])
		(cols[0][0] as Control).custom_minimum_size = Vector2(330, 0)
		(cols[1][0] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(cols[0][0])
		var vr := ColorRect.new(); vr.color = TBTokens.c("hair"); vr.custom_minimum_size = Vector2(1, 0); split.add_child(vr)
		split.add_child(cols[1][0])
		lv = cols[0][1]; rv = cols[1][1]
	else:
		lv = h.body; rv = h.body
	# ---- doctrine
	if g.rules >= 1:
		lv.add_child(TBPanel.section(T.call("doctrine")))
		lv.add_child(TBPanel.para(T.call("doctrine_hint", {"c": TBDoctrine.cost(g, me)}), 13, K.DIM))
		var items: Array = []
		for di in range(1, TBDoctrine.IDS.size()): items.append([TBDoctrine.IDS[di], T.call("doc_" + TBDoctrine.IDS[di])])
		var cur_id: String = TBDoctrine.IDS[g.doctrine[me]] if g.doctrine[me] != 0 else ""
		var fx := TBPanel.para("", 13, K.GOLD2)
		var shown := {"id": cur_id}
		var seg := TBPanel.seg(items, cur_id, func(id: String):
			if id == String(shown["id"]): return
			if g.dp[me] < TBDoctrine.cost(g, me):
				fx.text = T.call("err_dp"); fx.add_theme_color_override("font_color", K.RED)
				return
			on_cmd.call({"cmd": "doctrine", "id": id})
			h.close())
		lv.add_child(seg)
		fx.text = T.call("doc_%s_d" % cur_id) if cur_id != "" else T.call("doc_none")
		lv.add_child(fx)
		for it in items:
			lv.add_child(TBPanel.para("%s: %s" % [it[1], T.call("doc_%s_d" % it[0])], 13, K.DIM))
	# ---- decisions grouped
	var groups := {"active": [], "avail": [], "locked": []}
	for i in TBDecisions.LIST.size():
		if TBDecisions.is_active(g, me, i): groups["active"].append(i)
		elif TBDecisions.why_not(g, me, i) == "": groups["avail"].append(i)
		else: groups["locked"].append(i)
	if not wide: rv.add_child(K.hair())
	for gk in ["active", "avail", "locked"]:
		var arr: Array = groups[gk]
		if arr.is_empty(): continue
		rv.add_child(TBPanel.section("%s  (%d)" % [T.call("dec_g_" + gk), arr.size()]))
		for idx in arr:
			var i2: int = idx
			rv.add_child(DecisionRow.new(g, i2, me, func(): on_cmd.call({"cmd": "decide", "id": String(TBDecisions.LIST[i2]["id"])}); h.close()))
	return h

# =====================================================================================================================================================
# Annals (drawer / sheet): filter chips, rows grouped by turn, whole row jumps to the map, "Older" instead of a silent cap
# =====================================================================================================================================================
static func chronicle(parent: Control, g: TBGame, on_goto: Callable, feed: Array = []) -> TBPanel.Handle:
	var h := TBPanel.open(parent, TBPanel.Kind.DRAWER, T.call("dk_chronicle"), "book")
	var S := {"cat": "mine", "limit": 40}
	if not feed.is_empty():                      # text mirror of the toasts and alerts of this session (A11Y-SR-003): readable, selectable, screen-reader friendly
		h.body.add_child(TBPanel.section(T.call("recent_notices")))
		for line in feed.slice(maxi(0, feed.size() - 6)):
			var t: String = line if line is String else String((line as Dictionary).get("text", line))
			h.body.add_child(TBPanel.para(t, 14, K.TEXT))
	var chips := TBPanel.flow(6); h.body.add_child(chips)
	var list := K.vbox(0); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(list)
	var cbs := {}
	var draw := func() -> void:
		for c in list.get_children(): c.queue_free()
		var shown := 0
		var total := 0
		var last_turn := -1
		for i in range(g.log.size() - 1, -1, -1):
			var e: Dictionary = g.log[i]
			var cat := TBChron.category(e)
			if S["cat"] == "mine" and not TBChron.involves(e, g.human_id): continue
			if S["cat"] in ["war", "diplo", "events"] and cat != S["cat"]: continue
			var tx := TBChron.text(g, e)
			if tx == "": continue
			total += 1
			if shown >= int(S["limit"]): continue
			var tn: int = int(e["turn"])
			if tn != last_turn:
				last_turn = tn
				var sec := TBPanel.section("%s %d · %s" % [T.call("turn"), tn, TBChron.date(g, tn)])
				sec.add_theme_constant_override("separation", 8)
				var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_top", 8); pad.add_child(sec); list.add_child(pad)
			var bad := TBChron.is_bad(e, g.human_id)
			var jump := Callable()
			if e.has("p") and int(e["p"]) >= 0:
				var pp: int = e["p"]
				jump = func(): h.close(); on_goto.call(pp)
			var egl: String = TBChron.glyph(e)
			if egl == "" and bad: egl = "warning"
			list.add_child(TBPanel.entry(tx, egl, TBTokens.c("neg") if bad else TBTokens.c("ink_0"), jump, TBTokens.c("neg") if bad else TBTokens.c("ink_1"), "pin" if jump.is_valid() else ""))
			shown += 1
		if total == 0:
			list.add_child(TBPanel.empty_state("book", T.call("chron_empty"), T.call("chron_empty_why"), T.call("chron_all") if S["cat"] == "mine" else "", func(): S["cat"] = "all"; for k in cbs: (cbs[k] as TBPanel.ChipBtn).set_on(k == "all"); (S["draw"] as Callable).call()))
		elif total > shown:
			list.add_child(TBPanel.para(T.call("showing_n", {"a": shown, "b": total}), 13, K.DIM))
			var older := K.button(T.call("older"), func(): S["limit"] = int(S["limit"]) + 60; (S["draw"] as Callable).call())
			list.add_child(older)
	S["draw"] = draw
	for c in TBChron.CATS:
		var cid: String = c
		var cb := TBPanel.chip_button(T.call("chron_" + cid), cid == String(S["cat"]), func():
			S["cat"] = cid; S["limit"] = 40
			for k in cbs: (cbs[k] as TBPanel.ChipBtn).set_on(k == cid)
			draw.call())
		chips.add_child(cb); cbs[cid] = cb
	draw.call()
	return h

# =====================================================================================================================================================
# Council = Advice + Goals (drawer / sheet, two tabs)
# =====================================================================================================================================================
static var _council_tab := "advice"
static var _goals_all := false

static func council(parent: Control, g: TBGame, on_goto: Callable, tab: String = "") -> TBPanel.Handle:
	var h := TBPanel.open(parent, TBPanel.Kind.DRAWER, T.call("council"), "lamp")
	if tab != "": _council_tab = tab
	var render := func() -> void:
		for c in h.body.get_children(): c.queue_free()
		if _council_tab == "goals": _goals_tab(h, g)
		else: _advice_tab(h, g, on_goto)
	var al := TBAdvisor.alerts(g, g.human_id)
	var crisis := 0
	for a in al:
		if int(a["sev"]) == 2: crisis += 1
	h.set_tabs(K.tabs([["advice", T.call("council_advice") + ((" (%d)" % al.size()) if not al.is_empty() else "")], ["goals", T.call("dk_goals")]], _council_tab, func(id: String): _council_tab = id; render.call()))
	render.call()
	return h

static func _advice_tab(h: TBPanel.Handle, g: TBGame, on_goto: Callable) -> void:
	var al := TBAdvisor.alerts(g, g.human_id)
	if al.is_empty():
		h.body.add_child(TBPanel.empty_state("lamp", T.call("al_quiet"), T.call("al_quiet_why"))); return
	al.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["sev"]) > int(b["sev"]))
	var last_sev := -1
	for a in al:
		var sev: int = a["sev"]
		if sev != last_sev:
			last_sev = sev
			h.body.add_child(TBPanel.section(T.call("sev_" + str(sev))))
		var glyph_id: String = "warning" if sev >= 1 else "diamond"
		var gcol: Color = K.RED if sev == 2 else (TBTokens.c("warn") if sev == 1 else K.GOLD)
		var tx: String = T.call("al_" + String(a["id"]), {"k": int(a["k"]), "r": "%.1f" % (int(a["k"]) / 10.0)})
		var jump := Callable()
		if int(a["p"]) >= 0:
			var pp: int = a["p"]
			jump = func(): h.close(); on_goto.call(pp)
		var e := TBPanel.entry(tx, glyph_id, K.TEXT, jump, gcol, "pin" if jump.is_valid() else "")
		h.body.add_child(e)

static func _goals_tab(h: TBPanel.Handle, g: TBGame) -> void:
	var prog := TBTurn.victory_progress(g, g.human_id)
	var ids: Array = TBTurn.VICTORY_IDS.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool: return float(prog[a]) > float(prog[b]))
	var shown: Array = ids if _goals_all else ids.slice(0, 3)
	for id in shown:
		var pct: float = prog[id]
		var col: Color = TBTokens.c("pos") if pct >= 0.9 else (TBTokens.c("brass_ink") if pct >= 0.4 else K.STEEL)
		var hb := K.hbox(6)
		var gtl := K.title(T.call("vc_" + id), 16, K.GOLD2 if pct >= 0.9 else K.TEXT)
		gtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; gtl.custom_minimum_size.x = 40; gtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(gtl); hb.add_child(K.Leader.new()); hb.add_child(K.num("%d%%" % int(pct * 100.0), 15, col))
		h.body.add_child(hb)
		h.body.add_child(TBPanel.para(T.call("vc_" + id + "_d"), 13, K.DIM))
		h.body.add_child(K.Meter.new(pct * 100.0, col))
		var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 6); h.body.add_child(gap)
	if ids.size() > 3:
		var tg := K.button(T.call("goals_less") if _goals_all else T.call("goals_all"), func(): _goals_all = not _goals_all; for c in h.body.get_children(): c.queue_free(); _goals_tab(h, g))
		h.body.add_child(tg)
	var nearest: Array = []
	for i in TBRealms.count():
		if g.realm_done.size() != g.N1 * TBRealms.count() or g.realm_done[g.human_id * TBRealms.count() + i] != 0: continue
		var sh := TBRealms.share(g, g.human_id, i)
		if sh >= 0.25: nearest.append([sh, i])
	nearest.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if not nearest.is_empty():
		h.body.add_child(TBPanel.section(T.call("realms_title")))
		for k in mini(3, nearest.size()):
			var hb2 := K.hbox(6); hb2.add_child(K.label(T.call("realm_" + String(TBRealms.LIST[nearest[k][1]][0])), 14)); hb2.add_child(K.Leader.new()); hb2.add_child(K.num("%d%%" % int(nearest[k][0] * 100.0), 14, K.GOLD2))
			h.body.add_child(hb2); h.body.add_child(K.Meter.new(nearest[k][0] * 100.0, K.GOLD2))

# =====================================================================================================================================================
# Briefing (start of a campaign): who you are, who borders you, what to do first. Wide dialog: facts left, neighbours and advice right.
# =====================================================================================================================================================
static func briefing(parent: Control, g: TBGame, on_done: Callable) -> TBPanel.Handle:
	var me := g.human_id
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, g.dname(me), "flag", {"wide": true, "on_dismiss": on_done})
	var year := g.year
	var sub := ("%d BC" % -year) if year < 0 else ("%d AD" % year)
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var wide: bool = not TBPanel.is_portrait(vs) and vs.x >= 720.0 and K.text_scale < 1.4
	h.body.add_child(K.caps(sub + " · " + T.call("era_" + g.era_id) if TBI18n.has_key("era_" + g.era_id) else sub, 12, K.GOLD))
	var host: BoxContainer = BoxContainer.new(); host.vertical = not wide
	host.add_theme_constant_override("separation", 24 if wide else 12); host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(host)
	var lcol := K.vbox(8); lcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL; host.add_child(lcol)
	var rcol := K.vbox(8); rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL; host.add_child(rcol)
	if g.rules >= 1 and g.r_name[me] != "":
		var hb := K.hbox(12)
		hb.add_child(TBPortrait.new().setup(g, me, 72))
		var rc := K.vbox(2); rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rc.add_child(TBPanel.para("%s %s" % [T.call(TBRulers.title_key(g, me)), TBRulers.display_name(g, me)], 16, K.GOLD2))
		rc.add_child(TBPanel.para(T.call("ruler_age", {"a": TBRulers.age(g, me)}), 13, K.DIM))
		var tr: String = TBRulers.TRAITS[g.r_trait[me]]
		if tr != "none": rc.add_child(TBPanel.para("%s: %s" % [T.call("rtr_" + tr), T.call("rtr_%s_d" % tr)], 13, K.DIM))
		hb.add_child(rc); lcol.add_child(hb)
	var army := 0
	for p in g.owned(me): army += g.army[p]
	var figs := TBPanel.flow(6)                                      # the three figures in one row, not three ledger lines (m-10)
	figs.add_child(K.chip("%s %d" % [T.call("lands"), g.own_count(me)], "flag", "own"))
	figs.add_child(K.chip("%s %s" % [T.call("total_army"), K.fmt(army)], "swords", "neutral"))
	figs.add_child(K.chip("%s %s" % [T.call("gold"), K.fmt(g.gold[me])], "coins", "neutral"))
	lcol.add_child(figs)
	var shared := TBNationsScreen.land_neighbours(g, me)
	var order := shared.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return shared[a] > shared[b])
	if not order.is_empty():
		rcol.add_child(TBPanel.section(T.call("neighbours")))
		for i in mini(4, order.size()):
			var o: int = order[i]
			var oa := 0
			for p in g.owned(o): oa += g.army[p]
			var ratio := float(oa) / maxf(1.0, army)
			var tag: String = T.call("brief_stronger") if ratio > 1.3 else (T.call("brief_weaker") if ratio < 0.75 else T.call("brief_equal"))
			var rowb := K.hbox(8); rowb.add_child(TBFlags.chip(g, o, 0.6)); var nl := K.label(g.dname(o), 14); nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; nl.custom_minimum_size.x = 40; rowb.add_child(nl)
			rowb.add_child(K.chip(tag, "warning" if ratio > 1.3 else ("check" if ratio < 0.75 else "diamond"), "neg" if ratio > 1.3 else ("pos" if ratio < 0.75 else "neutral")))      # comparison, not a delta: no up / down triangles
			rcol.add_child(rowb)
	var al := TBAdvisor.alerts(g, me)
	if not al.is_empty():
		lcol.add_child(TBPanel.section(T.call("advisor")))
		for i in mini(2, al.size()):
			lcol.add_child(TBPanel.para(T.call("al_" + String(al[i]["id"]), {"k": int(al[i]["k"]), "r": "%.1f" % (int(al[i]["k"]) / 10.0)}), 13, K.TEXT))
	var go := K.button(T.call("brief_begin"), func(): h.close(); on_done.call(), true)
	h.actions(null, go)
	return h

# =====================================================================================================================================================
# Tutorial: 7 short steps in a small dialog. Skip leaves the whole first-turn intro (tutorial AND briefing) in one tap.
# =====================================================================================================================================================
static func tutorial(parent: Control, on_done: Callable, on_skip: Callable = Callable()) -> TBPanel.Handle:
	var step := [1]
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("tut_title"), "book", {"width": 460})
	var title := K.title("", 18, K.TEXT)
	var body := TBPanel.para("", 15)
	var pips := K.Pips.new(1, 7); pips.custom_minimum_size = Vector2(7 * 14, 18)
	h.body.add_child(pips); h.body.add_child(title); h.body.add_child(body)
	var skip_cb: Callable = on_skip if on_skip.is_valid() else on_done
	var skip := K.button(T.call("tut_skip_intro") if on_skip.is_valid() else T.call("tut_skip"), func(): h.close(); skip_cb.call())
	var next := K.button(T.call("tut_next"), Callable(), true)
	h.actions(skip, next)
	h.on_dismiss = skip_cb                               # Esc / X also skip the whole intro
	var draw := func():
		title.text = T.call("tut_%d_t" % step[0]); body.text = T.call("tut_%d_b" % step[0])
		pips.n = step[0]; pips.queue_redraw()
		next.text = T.call("tut_done") if step[0] == 7 else T.call("tut_next")
	next.pressed.connect(func():
		if step[0] >= 7: h.close(); on_done.call(); return
		step[0] += 1; draw.call())
	draw.call()
	return h

## the first-turn sequence of a new campaign: tutorial (first game only) then the briefing; Skip on the tutorial (or Esc) skips both
static func first_turn(parent: Control, g: TBGame, show_tutorial: bool) -> void:
	if show_tutorial: tutorial(parent, func(): briefing(parent, g, func(): pass), func(): pass)
	else: briefing(parent, g, func(): pass)

# =====================================================================================================================================================
# Event / ultimatum prompt: the hero sheet. Narrative left (scrolls), the choice cards right and PINNED (beneath the narrative in a single column), so
# an answer is always on screen. "Decide later" (not for ultimatums) leaves an Event chip in the HUD ticker. Unanswered: Back, Esc and backdrop are swallowed.
# =====================================================================================================================================================
const CAT_GLYPH := {"military": "swords", "crisis": "warning", "domestic": "crown", "trade": "coins", "enlightenment": "book", "diplomacy": "dove", "disaster": "warning", "golden age": "trophy"}

## tertiary text button ("Decide later"): flat, underlined on hover / focus, hourglass glyph
class LinkBtn extends Button:
	var glyph := "hourglass"
	func _init(t: String, cb: Callable, g: String = "hourglass") -> void:
		text = t; glyph = g; flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, TBKit.touch())
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]: add_theme_stylebox_override(st, TBFrame.plate(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 30, 6, false, 0))
		add_theme_stylebox_override("focus", TBFrame.focus(false, 0, 2))
		for fc in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]: add_theme_color_override(fc, TBTokens.c("ink_1"))
		add_theme_font_override("font", TBKit.body_b()); add_theme_font_size_override("font_size", TBKit.fs(14))
		alignment = HORIZONTAL_ALIGNMENT_LEFT
		autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if cb.is_valid(): pressed.connect(cb)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw)
	func _draw() -> void:
		TBGlyph.draw(self, glyph, Vector2(14, roundf(size.y * 0.5)), 16.0, TBTokens.c("ink_1"))
		if is_hovered() or has_focus(): draw_rect(Rect2(30, size.y - 8, size.x - 38, 1), TBTokens.c("ink_1"))

static func event_prompt(parent: Control, e: Dictionary, on_choose: Callable, g: TBGame = null, on_defer: Callable = Callable()) -> TBPanel.Handle:
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var wide: bool = not TBPanel.is_portrait(vs) and vs.x >= 720.0 and K.text_scale < 1.4
	var short: bool = vs.y < 480.0
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, "", "", {"hero": true, "wide": true, "dismissable": false, "split": true, "split_wide": wide})
	var nar: VBoxContainer = h.body
	var cho: VBoxContainer = h.pinned
	var gpx: int = 28 if short else 32
	var can_defer: bool = on_defer.is_valid() and not (e["kind"] == "prop" and e["id"] == "ultimatum")
	var finish := func() -> void:
		if can_defer:
			var later := LinkBtn.new(T.call("decide_later"), func(): h.close(); on_defer.call())
			later.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			K.a11y(later, T.call("decide_later"), "button", T.call("decide_later_d"))
			cho.add_child(later)
	# header block: glyph + kicker on one line when short
	var head_row := K.hbox(10)
	nar.add_child(head_row)
	if e["kind"] == "prop":
		var ult: bool = e["id"] == "ultimatum"
		var from_n: int = int(e["from"])
		var from_name: String = g.dname(from_n) if g != null else ""
		var gl := K.glyph("swords" if ult else ("dove" if e["id"] == "peace" else "scroll"), gpx, TBTokens.c("oxblood")); gl.custom_minimum_size = Vector2(gpx + 8, gpx + 8); gl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		head_row.add_child(gl)
		var kk := K.caps(T.call("ev_ultimatum") if ult else T.call("ev_proposal"), 12, K.GOLD); kk.size_flags_vertical = Control.SIZE_SHRINK_CENTER; head_row.add_child(kk)
		var tl := K.title(T.call("prop_ult_title" if ult else "prop_title", {"a": from_name}), 22 if short else 24); tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.custom_minimum_size.x = 40; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nar.add_child(tl)
		if not short: nar.add_child(K.ornament())
		var place: String = TBI18n.place(g.world.name[int(e["p"])]) if ult and g != null else ""
		var fl := TBPanel.para(T.call("prop_" + String(e["id"]), {"a": from_name, "p": place}), 15); fl.add_theme_font_override("font", K.body_i()); nar.add_child(fl)
		if ult and g != null:
			var mine: int = int(TBDiplo.power(g, g.human_id)); var theirs: int = int(TBDiplo.power(g, from_n))
			var cf := TBPanel.flow(6); cf.add_child(K.chip("%s %s" % [T.call("strength_theirs"), K.fmt(theirs)], "swords", "neg" if theirs > mine else "neutral")); cf.add_child(K.chip("%s %s" % [T.call("strength_yours"), K.fmt(mine)], "shield", "neutral"))
			nar.add_child(cf)
		var yes_chips: Array = [[T.call("ev_yield_lost", {"p": place}), "tri_down", "neg"]] if ult and place != "" else []
		var yes := TBPanel.card("", T.call("mp_yield") if ult else T.call("mp_accept"), "", yes_chips, func(): h.close(); on_choose.call(0), "", false, true)
		var no_chips: Array = [[T.call("ev_defy_war", {"a": from_name}), "swords", "neg"]] if ult else []
		var no := TBPanel.card("", T.call("mp_defy") if ult else T.call("mp_decline"), T.call("mp_defy_d") if ult else "", no_chips, func(): h.close(); on_choose.call(1), "", false, true)
		cho.add_child(yes); cho.add_child(no)
		finish.call()
		return h
	var rand: bool = e["kind"] == "rand"
	var id: String = e["id"]
	var title: String = T.call("ev_%s_t" % id) if rand else _loc(e.get("title", {}))
	var flavor: String = T.call("ev_%s_f" % id) if rand else _loc(e.get("flavor", {}))
	var cat_raw: String = String(e.get("cat", "")).to_lower()
	var icon_id: String = String(e.get("icon", ""))
	var gid: String = icon_id if (icon_id != "" and TBGlyph.G.has(icon_id)) else String(CAT_GLYPH.get(cat_raw, "globe" if (not rand and e.get("world", false)) else "scroll"))
	var gl2 := K.glyph(gid, gpx, TBTokens.c("oxblood")); gl2.custom_minimum_size = Vector2(gpx + 8, gpx + 8); gl2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	head_row.add_child(gl2)
	var cat_key := "evcat_" + cat_raw.replace(" ", "_")
	var kicker: String = T.call("ev_worldwide") if (not rand and e.get("world", false)) else (T.call("ev_event") if not rand else (T.call(cat_key) if TBI18n.has_key(cat_key) else String(e.get("cat", ""))))
	if kicker != "":
		var kk2 := K.caps(kicker, 12, K.GOLD); kk2.size_flags_vertical = Control.SIZE_SHRINK_CENTER; head_row.add_child(kk2)
	var tl2 := K.title(title, 22 if short else 24); tl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl2.custom_minimum_size.x = 40; tl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nar.add_child(tl2)
	if not short: nar.add_child(K.ornament())
	var fl2 := TBPanel.para(flavor, 15); fl2.add_theme_font_override("font", K.body_i()); nar.add_child(fl2)
	var count: int = e["count"]
	var labels: Array = e.get("labels", [])
	for i in count:
		var ttl: String; var chips: Array = []
		if rand: ttl = T.call("ev_%s_c%d" % [id, i]); chips = chips_from_text(T.call("ev_%s_d%d" % [id, i]))
		elif i < labels.size():
			ttl = _loc(labels[i])
			var fx: Array = e.get("fx", [])
			if i < fx.size(): chips = fx_chips(fx[i])
		else: ttl = T.call("ev_ack")
		var idx := i
		cho.add_child(TBPanel.card("", ttl, "", chips, func(): h.close(); on_choose.call(idx), "", false, true))
	finish.call()
	return h

# =====================================================================================================================================================
# Game over: hero sheet with the wax stamp, headline, key numbers and the top five standings
# =====================================================================================================================================================
static func game_over(parent: Control, g: TBGame, on_menu: Callable) -> TBPanel.Handle:
	var won: bool = g.winner == g.human_id
	var sub: String = T.call("e_victory", {"a": g.dname(g.winner)}) if won else T.call("e_defeat")
	if won and g.victory_kind != "": sub = "%s — %s" % [T.call("vc_" + g.victory_kind), g.dname(g.winner)]
	elif g.winner != 0 and not won: sub = T.call("e_lost_to", {"a": g.dname(g.winner)})
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var wide: bool = not TBPanel.is_portrait(vs) and vs.x >= 720.0 and K.text_scale < 1.4
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, "", "", {"hero": true, "wide": true, "dismissable": false})
	var host: BoxContainer = BoxContainer.new(); host.vertical = not wide
	host.add_theme_constant_override("separation", 24); host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(host)
	var lcol := K.vbox(10); lcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL; host.add_child(lcol)
	var rcol := K.vbox(6); rcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL; host.add_child(rcol)
	# stamp: the one wax object of this screen (flat plate, no ring)
	var short: bool = vs.y < 480.0
	var stamp := Control.new(); stamp.custom_minimum_size = Vector2(48, 48) if short else Vector2(72, 72); stamp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var sp := TBFrame.plate(TBTokens.c("wax"), TBTokens.c("wax_rim"), 6, 1, 0, 0, false, 2)
	stamp.draw.connect(func():
		stamp.draw_style_box(sp, Rect2(Vector2.ZERO, stamp.size))
		TBGlyph.draw(stamp, "trophy" if won else "skull", (stamp.size * 0.5).round(), 28.0 if short else 36.0, TBTokens.c("on_wax")))
	lcol.add_child(stamp)
	var head := K.title(T.call("go_won") if won else T.call("go_lost"), 28 if short else 34, TBTokens.c("brass_ink") if won else TBTokens.c("neg"))
	lcol.add_child(head)
	if not short: lcol.add_child(K.ornament())
	lcol.add_child(TBPanel.para(sub, 15))
	var rows: Array = []
	var army_of := {}
	for p in g.P:
		var o: int = g.owner[p]
		if o > 0: army_of[o] = int(army_of.get(o, 0)) + g.army[p]
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		rows.append([g.own_count(n), n, int(army_of.get(n, 0))])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var rank := 0
	for i in rows.size():
		if rows[i][1] == g.human_id: rank = i + 1
	var peak := 0
	for pt in TBStats.series(g, g.human_id, "p"): peak = maxi(peak, int(pt[1]))
	peak = maxi(peak, g.own_count(g.human_id))
	var kn := TBPanel.flow(6)
	kn.add_child(K.chip("%s %d" % [T.call("turn"), g.turn], "hourglass", "neutral"))
	kn.add_child(K.chip("%s %d" % [T.call("go_peak"), peak], "flag", "neutral"))
	kn.add_child(K.chip("%s %d" % [T.call("go_rank"), rank], "trophy", "own"))
	lcol.add_child(kn)
	rcol.add_child(TBPanel.section(T.call("go_final")))
	var shown: Array = rows.slice(0, 5)
	var me_in := false
	for r in shown: if r[1] == g.human_id: me_in = true
	if not me_in:
		for r in rows: if r[1] == g.human_id: shown.append(r)
	for r in shown:
		var rk: int = rows.find(r) + 1
		var is_me: bool = r[1] == g.human_id
		var row := K.hbox(10); row.custom_minimum_size = Vector2(0, 30 if short else 36)
		var rkl := K.num("%d" % rk, 15, K.GOLD2 if is_me else K.DIM); rkl.custom_minimum_size = Vector2(26, 0); row.add_child(rkl)
		row.add_child(TBFlags.chip(g, r[1], 0.7))
		var nm := K.label(g.dname(r[1]), 15, K.GOLD2 if is_me else K.TEXT); nm.add_theme_font_override("font", K.body_b()); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; nm.custom_minimum_size.x = 40; row.add_child(nm)
		if is_me: row.add_child(K.chip(T.call("you"), "", "own"))
		row.add_child(K.num("%d" % r[0], 15, K.TEXT)); row.add_child(K.glyph_label("swords", K.fmt(float(r[2])), K.DIM, 12))
		rcol.add_child(row)
		rcol.add_child(K.hair())
	# footer: [View final map] hides the sheet and leaves a chip to bring it back; [Main menu] is the primary
	var chip_back: Array = [null]
	var view := K.button(T.call("go_view_map"), func():
		h.root.visible = false
		var b := K.button(T.call("go_show_result"), func():
			h.root.visible = true
			if is_instance_valid(chip_back[0]): (chip_back[0] as Control).queue_free(), true)
		b.set_anchors_preset(Control.PRESET_CENTER_TOP); b.offset_top = float(TBPanel.DRAWER_TOP) + 8.0; b.grow_horizontal = Control.GROW_DIRECTION_BOTH       # below the top bar (m-07)
		parent.add_child(b); chip_back[0] = b)
	var menu := K.button(T.call("main_menu"), func(): h.close(); on_menu.call(), true)
	h.actions(view, menu)
	return h

# =====================================================================================================================================================
# Pass-the-device curtain (hot-seat): opaque, swallows Back, one tap reveals
# =====================================================================================================================================================
static func pass_device(parent: Control, g: TBGame, n: int, on_ready: Callable) -> TBPanel.Handle:
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, "", "", {"width": 420, "dismissable": false, "opaque": true})
	var seat: int = g.humans().find(n)
	var hb := K.hbox(8); hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_child(K.color_chip(TBPickFlow.HOT_COLORS[seat % TBPickFlow.HOT_COLORS.size()]))
	hb.add_child(K.caps("%s %d" % [T.call("hot_seat_n"), seat + 1], 12, K.GOLD))
	h.body.add_child(hb)
	var cp := K.caps(T.call("hot_pass"), 12, K.DIM); cp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h.body.add_child(cp)
	var fl := TBFlags.chip(g, n, 1.8); fl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER; h.body.add_child(fl)
	var nl := K.title(g.dname(n), 24); nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nl.custom_minimum_size.x = 40; h.body.add_child(nl)
	var tl := K.label("%s %d · %s" % [T.call("turn"), g.turn, TBChron.date(g, g.turn)], 14, K.DIM); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; h.body.add_child(tl)
	var rb := K.button(T.call("hot_ready"), func(): h.close(); on_ready.call(), true)
	h.actions(null, rb)
	h.focus_target = rb
	return h
