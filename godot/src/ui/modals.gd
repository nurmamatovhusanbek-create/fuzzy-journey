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

## the demo's `budgetEff`: the effect line under each slider, with the game's real numbers
static func _bud_effect(g: TBGame, n: int, i: int, v: float) -> String:
	var inc := g.income(n)
	match i:
		0: return T.call("bud_tax_fx", {"g": int(inc["tax"])})
		1: return T.call("bud_goods_fx", {"h": int(clampf(50.0 + (v - 20.0) * 0.6 - maxf(0.0, g.budget[n * 4] - 50.0) * 0.5, 0.0, 100.0))})
		2: return T.call("bud_research_fx", {"r": "%.1f" % D.tech_gain(int(inc["pop"]), int(v))})
	return T.call("bud_invest_fx", {"p": "%.1f" % (v * 0.05)})

static func budget(parent: Control, g: TBGame, on_change: Callable) -> TBPanel.Handle:
	var n := g.human_id
	var h := TBPanel.open(parent, TBPanel.Kind.DRAWER, T.call("budget"), "treasury", {"w": 560, "h": 850})
	var start: Array = []
	for i in 4: start.append(int(g.budget[n * 4 + i]))
	var base_net: int = int(g.income(n)["net"])
	var rows: Array = []
	var sync_ref: Array = [Callable()]
	var net_slot := K.hbox(18)                                  # `#bsum`: the gauge, NET INCOME and the leader rows
	var sum_m := MarginContainer.new(); sum_m.add_theme_constant_override("margin_bottom", 6 if h.phone else 12); sum_m.add_child(net_slot)
	h.body.add_theme_constant_override("separation", 0)
	h.body.add_child(sum_m)
	var sync := func() -> void:
		var inc := g.income(n)
		var net: int = int(inc["net"])
		h.set_sub(T.call("bud_sub", {"n": K.signed(float(net))}))
		for c in net_slot.get_children(): c.queue_free()
		var gw := MarginContainer.new(); gw.add_theme_constant_override("margin_right", 8); gw.add_theme_constant_override("margin_bottom", 5); gw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		gw.add_child(K.gauge(24.0 if h.phone else 40.0, K.signed(float(net)), "" if h.phone else T.call("bud_per_turn").to_upper(), clampf(absf(float(net)) / maxf(1.0, float(inc["gold"])), 0.02, 1.0), TBTokens.c("pos") if net >= 0 else TBTokens.c("neg")))
		net_slot.add_child(gw)
		var lv := K.vbox(0); lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lv.add_child(K.wrappable(K.caps(T.call("income_net"))))
		var mt := MarginContainer.new(); mt.add_theme_constant_override("margin_top", 6)
		var items: Array = [[T.call("bud_taxes"), K.signed(float(inc["tax"])), 1], [T.call("bud_provinces"), K.signed(float(inc["production"])) if int(inc["production"]) != 0 else "0", 1 if int(inc["production"]) != 0 else 0]]
		if g.rules >= 1 and TBTrade.income(g, n) > 0: items.insert(1, [T.call("trade"), K.signed(float(TBTrade.income(g, n))), 1])
		items.append([T.call("tkr_upkeep"), K.signed(-float(inc["upkeep"])), -1 if int(inc["upkeep"]) != 0 else 0])
		items.append([T.call("tkr_admin"), K.signed(-float(inc["admin"])), -1 if int(inc["admin"]) != 0 else 0])
		if g.rules >= 1 and g.gold[n] > 0: items.append([T.call("infl_row"), K.signed(-g.gold[n] * g.infl), -1])
		if net != base_net: items.append([T.call("dv_total"), K.signed(float(net - base_net)), 1 if net > base_net else -1])
		mt.add_child(K.fxl(items, 2 if h.phone else 0)); lv.add_child(mt)
		net_slot.add_child(lv)
		for i in 4: (rows[i] as TBBzParts.SRow).set_value(float(g.budget[n * 4 + i]))
		on_change.call()
	var vsb: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var grid := GridContainer.new(); grid.columns = 2 if h.phone else 1
	grid.add_theme_constant_override("h_separation", 22); grid.add_theme_constant_override("v_separation", 10 if h.phone else 14)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(grid)
	for i in 4:
		var idx := i
		var r := K.srow(["tax", "happy", "research", "invest"][i], T.call(BUDGET_KEYS[i]), 0, 100, 5, g.budget[n * 4 + i],
			func(v: float): g.apply({"cmd": "budget", "n": n, "key": BUDGET_KEYS[idx], "val": int(v)}); (func(): if h.is_open(): (sync_ref[0] as Callable).call()).call(),
			Callable(), func(v: float) -> String: return _bud_effect(g, n, idx, v), 50.0 if i == 0 else -1.0)
		grid.add_child(r); rows.append(r)
	sync_ref[0] = sync
	var pre := K.hbox(10); pre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pm := MarginContainer.new(); pm.add_theme_constant_override("margin_top", 12); pm.add_child(pre); h.body.add_child(pm)
	pre.add_child(K.caps(T.call("preset")))
	var preset_seg := TBPanel.seg([["balanced", T.call("pre_balanced")], ["war", T.call("pre_war")], ["growth", T.call("pre_growth")]], "", func(id: String): _budget_set(g, n, PRESETS[id]); sync.call())
	preset_seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pre.add_child(preset_seg)
	var revert := K.button(T.call("revert"), func(): _budget_set(g, n, start); sync.call())
	var done := K.button(T.call("done"), func(): h.close(), true)
	h.actions(revert, done)
	sync.call()
	return h

# =====================================================================================================================================================
# Decrees (panel / page): the demo's `decreesBody`, a grid of engraved cards (2 columns, 3 on a phone); doctrine (game only) above it
# =====================================================================================================================================================
const DEC_GLYPH := {"mil_reform": "army", "trade_fair": "trade", "centralize": "decrees", "conscript": "people", "propaganda": "star", "patronage": "annals", "fortify": "fortify", "amnesty": "pact"}
## effect rows of each decree (i18n `dec_<id>_e1` / `_e2`), the tone of each: pos = good (teal), neg = bad (rust), "" = neutral note
const DEC_FX := {"mil_reform": ["pos"], "trade_fair": ["pos"], "centralize": ["pos"], "conscript": ["pos", "neg"], "propaganda": ["pos", "pos"], "patronage": ["pos"], "fortify": ["pos"], "amnesty": ["pos", ""]}

static func _dec_reason(why: String) -> String:
	var key := "err_" + why
	return T.call(key) if TBI18n.has_key(key) else why

static var _fxp_re: RegEx
static var _fxp_re2: RegEx
## the demo's `fxp`: "+8 army / turn" -> ["Army / turn", "+8", sign]; a leading or trailing figure, label capitalised
static func fx_item(txt: String, tone: String) -> Array:
	if _fxp_re == null:
		_fxp_re = RegEx.new(); _fxp_re.compile("^([+−-]?\\d[\\d.,]*%?)\\s+(.*)$")
		_fxp_re2 = RegEx.new(); _fxp_re2.compile("^(.*?)\\s*([+−-]\\d[\\d.,]*%?)$")
	var n := ""; var t := txt
	var m := _fxp_re.search(txt)
	if m != null: n = m.get_string(1).replace("-", "−"); t = m.get_string(2)
	else:
		m = _fxp_re2.search(txt)
		if m != null: t = m.get_string(1); n = m.get_string(2).replace("-", "−")
	if t != "": t = t.substr(0, 1).to_upper() + t.substr(1)
	return [t, n, 1 if tone == "pos" else (-1 if tone == "neg" else 0)]

## one decree card: ring + name, the effect rows, then the cost mark and Enact / In force
class DecisionRow extends PanelContainer:
	func _init(g: TBGame, i: int, me: int, on_enact: Callable) -> void:
		var d: Dictionary = TBDecisions.LIST[i]
		var id: String = d["id"]
		var active := TBDecisions.is_active(g, me, i)
		var why := TBDecisions.why_not(g, me, i)
		var locked: bool = why != "" and not active
		var reason: String = "" if active else TBModals._dec_reason(why)
		add_theme_stylebox_override("panel", TBBz.well_box(TBTokens.BZ_GOOD if active else TBTokens.BZ_WELL_LINE, 11.0, 11.0))
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tooltip_text = TBI18n.T("dec_%s_d" % id)
		var col := TBKit.vbox(8); add_child(col)
		var head := TBKit.hbox(10); col.add_child(head)
		head.add_child(TBKit.ring_icon(TBModals.DEC_GLYPH.get(id, "decrees"), 36, locked))
		var tt := TBKit.title(TBI18n.T("dec_" + id), 12, TBTokens.c("ink_0"), 0.08, 1.2)
		(tt as TBBz.TLabel).px = 12.5; (tt as TBBz.TLabel).refit()
		tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tt.size_flags_vertical = Control.SIZE_SHRINK_CENTER; tt.custom_minimum_size.x = 40
		head.add_child(tt)
		var items: Array = []
		var tones: Array = TBModals.DEC_FX.get(id, [])
		for k in tones.size():
			var key := "dec_%s_e%d" % [id, k + 1]
			if TBI18n.has_key(key): items.append(TBModals.fx_item(TBI18n.T(key), tones[k]))
		if not items.is_empty(): col.add_child(TBKit.fxl(items))
		if reason != "":                                  # a locked decree says why (the demo has no such state: a `.mk` rust mark)
			col.add_child(TBKit.mark(reason, "bad"))
		var sp := Control.new(); sp.size_flags_vertical = Control.SIZE_EXPAND_FILL; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE; col.add_child(sp)
		var foot := TBKit.hbox(8); col.add_child(foot)
		var cf := TBKit.hbox(10); cf.size_flags_vertical = Control.SIZE_SHRINK_CENTER; foot.add_child(cf)
		if active:
			var left := TBDecisions.turns_left(g, me, i)
			foot.add_child(TBKit.chip_icon(TBI18n.T("dec_forever") if left > 5000 else TBI18n.T("dec_left", {"n": left}), "check", "pos"))
		else:
			cf.add_child(TBKit.chip_icon(str(int(d["gold"])), "gold", "info" if g.gold[me] >= float(d["gold"]) else "neg"))
			cf.add_child(TBKit.chip_icon(str(int(d["mp"])), "army", "info" if g.mp[me] >= float(d["mp"]) else "neg"))
		var fs := Control.new(); fs.size_flags_horizontal = Control.SIZE_EXPAND_FILL; fs.mouse_filter = Control.MOUSE_FILTER_IGNORE; foot.add_child(fs); foot.move_child(fs, 1)
		if not active:
			var b := TBKit.button(TBI18n.T("dec_do"), on_enact, true, true)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if why != "": TBKit.disable(b, reason)
			foot.add_child(b)

static func decisions(parent: Control, g: TBGame, on_cmd: Callable) -> TBPanel.Handle:
	var me := g.human_id
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("dk_decisions"), "decrees", {"w": 740 if K.is_phone(parent) else 900, "h": 540, "sub": T.call("dec_sub", {"n": int(g.dp[me])})})
	var body: VBoxContainer = h.body
	# ---- doctrine (game rules >= 1)
	if g.rules >= 1:
		body.add_child(K.caps(T.call("doctrine")))
		body.add_child(K.para_bz(T.call("doctrine_hint", {"c": TBDoctrine.cost(g, me)}), 16.0, 1.3))
		var items: Array = []
		for di in range(1, TBDoctrine.IDS.size()): items.append([TBDoctrine.IDS[di], T.call("doc_" + TBDoctrine.IDS[di])])
		var cur_id: String = TBDoctrine.IDS[g.doctrine[me]] if g.doctrine[me] != 0 else ""
		var fx_slot := K.vbox(0)
		var say := func(txt: String, col: Color) -> void:
			for c in fx_slot.get_children(): c.queue_free()
			fx_slot.add_child(K.para_bz(txt, 16.0, 1.3, col))
		var DS := {"sel": cur_id}
		var adopt_slot := K.hbox(0); adopt_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var refresh_adopt := func() -> void:                                        # choosing a doctrine only selects it: the player adopts it with the button
			for c in adopt_slot.get_children(): c.queue_free()
			var sid: String = DS["sel"]
			if sid == "": return
			var cost: int = TBDoctrine.cost(g, me)
			var same: bool = sid == cur_id
			var ab := K.button(T.call("doc_in_force") if same else T.call("doc_adopt"), func():
				if same or g.dp[me] < cost: return
				on_cmd.call({"cmd": "doctrine", "id": sid})
				h.close(), true, true, "", "" if same else "%d ✉" % cost)
			if same: K.disable(ab, "")
			elif g.dp[me] < cost: K.disable(ab, T.call("err_dp"))
			var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			adopt_slot.add_child(sp); adopt_slot.add_child(ab)
		var seg := TBPanel.seg(items, cur_id, func(id: String):
			DS["sel"] = id
			say.call(T.call("doc_%s_d" % id), TBTokens.c("brass_lt"))
			refresh_adopt.call())
		var sm := MarginContainer.new(); sm.add_theme_constant_override("margin_top", 8); sm.add_theme_constant_override("margin_bottom", 8); sm.add_child(seg)
		body.add_child(sm)
		say.call(T.call("doc_%s_d" % cur_id) if cur_id != "" else T.call("doc_none"), TBTokens.c("brass_lt"))
		body.add_child(fx_slot)
		body.add_child(adopt_slot); refresh_adopt.call()
		var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 16); gap.mouse_filter = Control.MOUSE_FILTER_IGNORE; body.add_child(gap)
	# ---- the decrees, in the game's order (the card carries the state: teal rule = in force, rust mark = why not)
	var grid := GridContainer.new(); grid.columns = 3                                  # three columns on desktop too (a 900 wide panel): the whole list fits without scrolling
	grid.add_theme_constant_override("h_separation", 10); grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	for i in TBDecisions.LIST.size():
		var i2: int = i
		grid.add_child(DecisionRow.new(g, i2, me, func(): on_cmd.call({"cmd": "decide", "id": String(TBDecisions.LIST[i2]["id"])}); h.close()))
	var vsd: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size            # fewer columns when the rows do not fit side by side
	var cell_w := 0.0
	for k in grid.get_children(): cell_w = maxf(cell_w, (k as Control).get_combined_minimum_size().x)
	grid.columns = clampi(int((minf(740.0 if h.phone else 900.0, vsd.x - 12.0) - 40.0 + 10.0) / (cell_w + 10.0)), 1, grid.columns)
	return h

# =====================================================================================================================================================
# Annals (drawer / sheet): filter chips, rows grouped by turn, whole row jumps to the map, "Older" instead of a silent cap
# =====================================================================================================================================================
static func chronicle(parent: Control, g: TBGame, on_goto: Callable, feed: Array = []) -> TBPanel.Handle:
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("dk_chronicle"), "annals", {"w": 560, "h": 660, "sub": T.call("annals_sub")})
	var S := {"cat": "mine", "limit": 40}
	var mirror := Label.new()                                    # text mirror of the toasts and alerts of this session (A11Y-SR-003): for screen readers, not drawn
	var lines := PackedStringArray()
	for line in feed.slice(maxi(0, feed.size() - 6)): lines.append(line if line is String else String((line as Dictionary).get("text", line)))
	mirror.text = "\n".join(lines); mirror.visible = false; h.body.add_child(mirror)
	var list_slot := K.vbox(0); list_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var draw := func() -> void:
		for c in list_slot.get_children(): c.queue_free()
		var holder := TBBzScreens.TimelineHolder.new()
		var col := K.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; holder.add_child(col)
		var shown := 0
		var total := 0
		for i in range(g.log.size() - 1, -1, -1):
			var e: Dictionary = g.log[i]
			var cat := TBChron.category(e)
			if S["cat"] == "mine" and not TBChron.involves(e, g.human_id): continue
			if S["cat"] in ["war", "diplo", "events"] and cat != S["cat"]: continue
			var tx := TBChron.text(g, e)
			if tx == "": continue
			total += 1
			if shown >= int(S["limit"]): continue
			var jump := Callable()
			if e.has("p") and int(e["p"]) >= 0:
				var pp: int = e["p"]
				jump = func(): h.close(); on_goto.call(pp)
			var ik: Array = TBBzScreens.chron_kind(String(e["kind"]))
			col.add_child(TBBzScreens.TimelineItem.new(String(ik[0]), TBBzScreens.date_str(g, int(e["turn"])), T.call(String(ik[1])), tx, jump))
			shown += 1
		if total == 0:
			list_slot.add_child(TBPanel.empty_state("annals", T.call("chron_empty"), T.call("chron_empty_why"), T.call("chron_all") if S["cat"] == "mine" else "", func(): S["cat"] = "events"; (S["draw"] as Callable).call()))
			return
		list_slot.add_child(holder)
		if total > shown:
			var older := K.button(T.call("older"), func(): S["limit"] = int(S["limit"]) + 60; (S["draw"] as Callable).call(), false, true)
			older.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			list_slot.add_child(older)
	S["draw"] = draw
	var tabs := K.tabs([["mine", T.call("an_t_all")], ["war", T.call("an_t_war")], ["diplo", T.call("an_t_dip")], ["events", T.call("an_t_ev")]], "mine", func(id: String):
		S["cat"] = id; S["limit"] = 40; draw.call())
	var tsc := ScrollContainer.new(); tsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; tsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tsc.get_h_scroll_bar().modulate.a = 0.0; tsc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tsc.add_child(tabs)      # four tabs in a narrow card scroll sideways instead of widening it
	h.body.add_child(tsc)
	var lm := MarginContainer.new(); lm.add_theme_constant_override("margin_top", 3); lm.add_child(list_slot); h.body.add_child(lm)
	draw.call()
	return h

# =====================================================================================================================================================
# Council (the ministers' advice) and Goals (what the realm strives for): two screens, as in the demo
# =====================================================================================================================================================
## alert id -> [icon, minister key, button key, screen to open or "map"]
const MINISTERS := {
	"threat": ["army", "min_army", "min_show_map", "map"], "occupied": ["army", "min_army", "min_show_map", "map"], "capital_lost": ["army", "min_army", "min_show_map", "map"],
	"war_winning": ["army", "min_army", "min_open_nations", "nations"], "war_declared": ["army", "min_army", "min_open_nations", "nations"], "idle_men": ["army", "min_army", "min_show_map", "map"],
	"no_general": ["army", "min_army", "", ""], "attrition": ["army", "min_army", "min_show_map", "map"], "idle_mp": ["army", "min_army", "", ""], "ult_chance": ["army", "min_army", "min_open_nations", "nations"],
	"coalition": ["pact", "min_foreign", "min_open_nations", "nations"], "infamy": ["pact", "min_foreign", "min_open_nations", "nations"], "peacetime": ["pact", "min_foreign", "min_open_nations", "nations"], "no_trade": ["pact", "min_foreign", "min_open_nations", "nations"],
	"bankrupt": ["treasury", "min_treasury", "min_open_budget", "budget"], "low_treasury": ["treasury", "min_treasury", "min_open_budget", "budget"], "idle_gold": ["treasury", "min_treasury", "min_open_budget", "budget"], "no_research": ["treasury", "min_treasury", "min_open_budget", "budget"],
	"unrest": ["spy", "min_police", "min_open_decrees", "decrees"]}

static func council(parent: Control, g: TBGame, on_goto: Callable, tab: String = "", on_screen: Callable = Callable()) -> TBPanel.Handle:
	if tab == "goals": return goals(parent, g)
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("council"), "council", {"w": 600, "h": 560, "sub": T.call("council_sub")})
	var al := TBAdvisor.alerts(g, g.human_id)
	if al.is_empty():
		h.body.add_child(TBPanel.empty_state("council", T.call("al_quiet"), T.call("al_quiet_why"))); return h
	al.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["sev"]) > int(b["sev"]))
	for a in al:
		var id: String = String(a["id"])
		var m: Array = MINISTERS.get(id, ["info", "min_police", "", ""])
		var quote: String = T.call("al_" + id, {"k": int(a["k"]), "r": "%.1f" % (int(a["k"]) / 10.0), "a": g.dname(int(a["n"])) if int(a["n"]) > 0 else ""})
		var btn := ""
		var cb := Callable()
		if String(m[3]) == "map" and int(a["p"]) >= 0:
			var pp: int = a["p"]
			btn = T.call(String(m[2])); cb = func(): h.close(); on_goto.call(pp)
		elif String(m[3]) != "map" and String(m[3]) != "" and on_screen.is_valid():
			var sc: String = String(m[3])
			btn = T.call(String(m[2])); cb = func(): h.close(); on_screen.call(sc)
		h.body.add_child(TBBzScreens.minister_row(String(m[0]), T.call(String(m[1])), T.call(String(m[1]) + "_r"), quote, btn, cb))
	return h

static func goals(parent: Control, g: TBGame) -> TBPanel.Handle:
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("dk_goals"), "goals", {"w": 660, "h": 400, "sub": T.call("goals_sub")})
	var me := g.human_id
	var prog := TBTurn.victory_progress(g, me)
	var ids: Array = TBTurn.VICTORY_IDS.duplicate()
	ids.sort_custom(func(a: String, b: String) -> bool: return float(prog[a]) > float(prog[b]))
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 12); grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(grid)
	var vp := parent.get_viewport()
	if vp != null and vp.get_visible_rect().size.x < 560.0: grid.columns = 1       # two cards need ~330 px: one column on a narrow window
	var own: int = g.own_count(me)
	var alive_others := 0; var allies := 0
	for o in range(1, g.N1):
		if o == me or g.alive[o] == 0 or o == g.rebel: continue
		alive_others += 1
		if g.get_rel(me, o) == TBData.REL_ALLY: allies += 1
	for id in ids:
		var a: Variant; var b: Variant
		match id:
			"domination": a = own; b = int(ceil(g.P * TBTurn.DOMINATION_SHARE))
			"economic": a = int(float(g.income(me)["gold"]) / maxf(1.0, g.world_y) * 100.0); b = int(roundf(g.econ_goal * 100.0))
			"technological": a = "%.1f" % g.tech_level[me]; b = "%.1f" % (g.tech_second if g.tech_level[me] >= g.tech_top else g.tech_top)
			"diplomatic": a = allies; b = int(maxf(TBTurn.DIPLOMATIC_ALLIES, ceilf(alive_others * TBTurn.DIPLOMATIC_SHARE)))
			_: a = own; b = g.P - g.own_count(0)
		grid.add_child(TBBzScreens.GoalCard.new(T.call("vc_" + String(id)), T.call("vcs_" + String(id), {"a": a, "b": b}), float(prog[id]), T.call("vc_%s_d" % String(id), {"s": int(roundf(g.econ_goal * 100.0))})))
	for i in TBRealms.count():
		if g.realm_done.size() != g.N1 * TBRealms.count() or g.realm_done[me * TBRealms.count() + i] != 0: continue
		var sh := TBRealms.share(g, me, i)
		if sh >= 0.25: grid.add_child(TBBzScreens.GoalCard.new(T.call("realm_" + String(TBRealms.LIST[i][0])), T.call("realms_title"), sh))
	return h

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
			lcol.add_child(TBPanel.para(T.call("al_" + String(al[i]["id"]), {"k": int(al[i]["k"]), "r": "%.1f" % (int(al[i]["k"]) / 10.0), "a": g.dname(int(al[i]["n"])) if int(al[i]["n"]) > 0 else ""}), 13, K.TEXT))
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

## `eventBody` medallion: a 96 unit instrument ring shown at 76 (bezelSvg(48,48,44,36)) with the category icon (34, stroke 1.5) in its face
class EventMedal extends Control:
	var glyph := "warn"
	var col := Color.WHITE
	var gsize := 34.0
	func _init(g: String, c: Color, px: float = 76.0, gs: float = 34.0) -> void:
		glyph = g; col = c; gsize = gs; custom_minimum_size = Vector2(px, px); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; size_flags_vertical = Control.SIZE_SHRINK_CENTER
	func _draw() -> void:
		var k: float = size.x / 96.0
		var c := size * 0.5
		TBBezel.ring(self, c, 44.0 * k, 36, TBTokens.BZ_FACE, true, false, k)
		TBGlyph.draw_ic(self, glyph, c, gsize, col, 1.5)

## kicker colour / icon of an event category (the demo's ultimatum is bad-toned; boons are brass)
const CAT_IC := {"military": "war", "crisis": "warn", "domestic": "crown", "trade": "trade", "enlightenment": "research", "diplomacy": "envoys", "disaster": "warn", "golden age": "star"}
const CAT_BAD := ["military", "crisis", "disaster"]

## the icon of a choice's ring: what its first effect touches
static func choice_icon(effects_text: String, fallback: String = "check") -> String:
	var t: String = effects_text.to_lower()
	var keys := [["gold", "gold"], ["coin", "gold"], ["manpower", "people"], ["population", "people"], ["army", "army"], ["armies", "army"], ["troop", "army"], ["stability", "happy"], ["happiness", "happy"],
		["infamy", "crown"], ["prestige", "crown"], ["research", "research"], ["intel", "spy"], ["diplomacy", "envoys"], ["relation", "envoys"], ["trade", "trade"], ["move point", "move"], ["develops", "build"]]
	var best := 1 << 30
	var ic := fallback
	for kv in keys:
		var i: int = t.find(String(kv[0]))
		if i >= 0 and i < best:
			best = i; ic = String(kv[1])
	return ic

## one choice row (`.row` with an inline #100d0a fill and a 1 unit inset edge, padding 9 12): ring 36, Cinzel 13 title, effect leader rows beneath
static func event_choice(icon: String, title_text: String, chips: Array, cb: Callable, advised: bool = false) -> Control:
	var rb := K.row_box(12.0, 9.0, cb)
	rb.fill = TBTokens.BZ_WELL; rb.edge = TBTokens.c("brass") if advised else TBTokens.BZ_WELL_LINE; rb.wash = false
	var hb := K.hbox(14); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; rb.add_child(hb)
	var ri: Control = K.ring_icon(icon, 36); ri.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(ri)
	var col := K.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; col.size_flags_vertical = Control.SIZE_SHRINK_CENTER; col.mouse_filter = Control.MOUSE_FILTER_IGNORE; hb.add_child(col)
	var tl := TBBz.TLabel.new(K.cinzel(700), 13.0, 0.1, 0.0, true)
	tl.text = title_text; tl.add_theme_color_override("font_color", TBTokens.BZ_IVORY)
	tl.wrap_ok = true; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tl.refit(); tl.custom_minimum_size.x = 40             # after refit (which sets the one-line width): the title may wrap on a narrow screen
	col.add_child(tl)
	if not chips.is_empty():
		_gap(col, 4)
		for c in chips:
			var fr: Control = K.fx_row(String(c[0]), String(c[2]) if c.size() > 2 else "neutral"); fr.mouse_filter = Control.MOUSE_FILTER_IGNORE; col.add_child(fr)
		_gap(col, 2)                                       # `.fxl{margin:2px 0}`: the bottom margin stays inside the row
	K.a11y(rb, title_text, "button", " · ".join(chips.map(func(c): return String(c[0]))))
	return rb

static func _gap(v: Control, px: float) -> void:
	var g := Control.new(); g.custom_minimum_size = Vector2(0, px); g.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(g)

## the "Declare war on X?" modal (B3): a rust-edged card, the two flags face to face, the effect ledger, Cancel + the hold-to-declare **seal**; after the command the
## "War" moment plays (Full / Light) and the map turns to the front. The hold rule is the old one: 0.6 s, or Enter twice.
static func war_confirm(parent: Control, g: TBGame, n: int, on_yes: Callable) -> TBPanel.Handle:
	var me: int = g.human_id
	var phone: bool = K.is_phone(parent)
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("confirm_war_t", {"a": g.dname(n)}), "war", {"w": 540.0 if phone else 520.0})
	if h.bz: h.card.add_theme_stylebox_override("panel", TBBz.plate_box(12.0, true, TBWarParts.rust()))
	var cbk := TBDiplo.cb(g, me, n)
	var dp: int = int(D.DP_WAR)
	var body: String = T.call("war_body_cb", {"cb": T.call("cb_" + cbk), "dp": dp}) if cbk != "" else T.call("war_body_nocb", {"dp": dp})
	var col := K.vbox(0); col.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.body.add_child(col)
	col.add_child(K.para_bz(body, 17.0, 1.4))
	col.add_child(TBWarParts.FaceOff.new(g, me, n))
	var rows: Array = [[T.call("war_fx_env"), "−%d" % dp, -1]]
	var was: int = g.get_rel(me, n)
	rows.append([T.call("war_fx_grudge"), "+%d" % (80 if was == D.REL_ALLY else (60 if was == D.REL_NAP else 40)), -1])
	rows.append([T.call("war_fx_inf"), "+%d" % int(TBDiplo.NO_CB_INFAMY) if cbk == "" else T.call("war_fx_none"), -1 if cbk == "" else 0])
	if TBTrade.has(g, me, n): rows.append([T.call("war_fx_trade"), T.call("war_fx_ends"), 0])
	col.add_child(K.fxl(rows))
	var cancel := K.button(T.call("cancel"), func(): h.close())
	var seal := TBWarParts.Seal.new(T.call("war_hold"))
	var veil0: Color = h.backdrop.color if h.backdrop != null else Color.TRANSPARENT
	seal.progress.connect(func(f: float):                                                     # holding: the veil warms toward rust, the edge of the screen reddens
		if h.backdrop != null and TBFx.on(TBFx.LIGHT) and h.is_open(): h.backdrop.color = veil0.lerp(TBTokens.with_a(TBWarParts.rust().darkened(0.55), 0.7), f * 0.55))
	seal.confirmed.connect(func():
		TBAudio.cue("stamp")
		var main_node: Node = parent.get_parent()
		h.close(); on_yes.call()
		if TBFx.on(TBFx.LIGHT) and is_instance_valid(parent):
			if main_node != null and main_node.has_method("_fly_to_nation"): main_node.call("_fly_to_nation", n)
			var mo := TBWarParts.Moment.new(g, me, n, TBFx.on(TBFx.FULL)); parent.add_child(mo); mo.play())
	h.actions(cancel, seal)
	h.focus_target = cancel
	if TBPanel.wants_focus(): cancel.grab_focus.call_deferred()
	return h

## the demo's battle report (`battleBody`): result medallion, kicker, "Battle of X", a line of flavour and the ledger; one "Onward" button
## r = {win, name, my_loss, foe_loss, claimed (bool), left (men that hold the province)}
static func battle_report(parent: Control, r: Dictionary) -> TBPanel.Handle:
	var win: bool = r["win"]
	var phone: bool = K.is_phone(parent)
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("br_title"), "attack", {"w": 480.0 if phone else 460.0})
	var box := K.vbox(0); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.body.add_child(box)
	if r.has("my0") and r.has("g") and not h.short and not h.phone and K.text_scale < 1.5:                      # B4: the armies face to face
		var gg: TBGame = r["g"]
		TBAudio.cue("gain" if win else "loss")
		var bars := TBBattleParts.Bars.new(gg, r)
		box.add_child(bars); _gap(box, 10)
		var rib := TBBattleParts.Ribbon.new(gg, win, T.call("br_victory" if win else "br_defeat"))
		box.add_child(rib); _gap(box, 10)
		box.add_child(K.para_bz("[i]%s[/i]" % T.call("br_won" if win else "br_lost"), 16.0, 1.3)); _gap(box, 8)
		var cf := TBPanel.flow(8)
		cf.add_child(K.chip("%s %s" % [T.call("br_left"), str(int(r["left"]))], "flag", "neutral"))
		if r["claimed"]: cf.add_child(K.chip(T.call("br_claimed") + " +1", "check", "pos"))
		box.add_child(cf)
		bars.t = 0.0; rib.t = 0.0
		TBFx.run(bars, 1.0, func(v: float): bars.t = v; bars.queue_redraw(), Callable(), TBFx.FULL, 0.4)
		TBFx.run(rib, 0.5, func(v: float): rib.t = v; rib.queue_redraw(), Callable(), TBFx.FULL, 1.2)
		var onward2 := K.button(T.call("br_onward"), func(): h.close(), true)
		h.actions(onward2, null)
		h.focus_target = onward2
		if TBPanel.wants_focus(): onward2.grab_focus.call_deferred()
		return h
	var tone: Color = TBTokens.BZ_GOOD if win else TBTokens.BZ_BAD
	var top := K.hbox(16); top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(EventMedal.new("crown" if win else "skull", tone, 84.0, 36.0))
	var tc := K.vbox(3); tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kk := K.caps(T.call("br_victory" if win else "br_defeat"), 11, tone); (kk as TBBz.TLabel).wrap_ok = true; kk.custom_minimum_size.x = 40; kk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.add_child(kk)
	var tl := K.title(T.call("br_of", {"p": r["name"]}), 20, TBTokens.BZ_IVORY, 0.06, 20.0 * 1.15); (tl as TBBz.TLabel).wrap_ok = true; tl.custom_minimum_size.x = 40; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.add_child(tl)
	tc.add_child(K.para_bz("[i]%s[/i]" % T.call("br_won" if win else "br_lost"), 16.0, 1.3))
	top.add_child(tc)
	box.add_child(top); _gap(box, 7)
	var rows: Array = [[T.call("br_my"), "−%d" % int(r["my_loss"])], [T.call("br_foe"), "−%d" % int(r["foe_loss"])]]
	rows.append([T.call("br_claimed"), "+1" if r["claimed"] else "0"])
	rows.append([T.call("br_left"), str(int(r["left"]))])
	box.add_child(K.tbl(rows, true))
	var onward := K.button(T.call("br_onward"), func(): h.close(), true)
	h.actions(onward, null)
	h.focus_target = onward
	if TBPanel.wants_focus(): onward.grab_focus.call_deferred()
	return h

static func event_prompt(parent: Control, e: Dictionary, on_choose: Callable, g: TBGame = null, on_defer: Callable = Callable()) -> TBPanel.Handle:
	var can_defer: bool = on_defer.is_valid() and not (e["kind"] == "prop" and e["id"] == "ultimatum")
	var phone: bool = K.is_phone(parent)
	var turn: int = g.turn if g != null else 0
	var opts := {"w": 600.0 if phone else 520.0, "dismissable": can_defer, "sub": ("%s %d" % [T.call("turn"), turn]) if turn > 0 else ""}
	if can_defer: opts["on_dismiss"] = on_defer
	var h := TBPanel.open(parent, TBPanel.Kind.DIALOG, T.call("ev_event"), "warn", opts)
	var box := K.vbox(0); box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.body.add_child(box)
	var kicker := ""
	var title := ""
	var flavor := ""
	var icon := "warn"
	var bad := true
	var choices: Array = []                        # [icon, title, chips, index]
	var after: Control = null
	if e["kind"] == "prop":
		var ult: bool = e["id"] == "ultimatum"
		var from_n: int = int(e["from"])
		var from_name: String = g.dname(from_n) if g != null else ""
		kicker = "%s · %s" % [T.call("ev_ultimatum") if ult else T.call("ev_proposal"), from_name]
		title = T.call("prop_ult_title" if ult else "prop_title", {"a": from_name})
		var place: String = TBI18n.place(g.world.name[int(e["p"])]) if ult and g != null else ""
		flavor = T.call("prop_" + String(e["id"]), {"a": from_name, "p": place})
		icon = "warn" if ult else ("pact" if e["id"] != "peace" else "flag")
		bad = ult
		if ult and g != null:
			var mine: int = int(TBDiplo.power(g, g.human_id))
			var theirs: int = int(TBDiplo.power(g, from_n))
			after = TBEventBand.Versus.new(theirs, mine, T.call("strength_theirs"), T.call("strength_yours"))
		var yes_chips: Array = [[T.call("ev_yield_lost", {"p": place}), "tri_down", "neg"]] if ult and place != "" else []
		var no_chips: Array = [[T.call("ev_defy_war", {"a": from_name}), "swords", "neg"]] if ult else []
		choices.append(["flag" if ult else "check", T.call("mp_yield") if ult else T.call("mp_accept"), yes_chips, 0])
		choices.append(["war" if ult else "close", T.call("mp_defy") if ult else T.call("mp_decline"), no_chips, 1])
	else:
		var rand: bool = e["kind"] == "rand"
		var id: String = e["id"]
		title = T.call("ev_%s_t" % id) if rand else _loc(e.get("title", {}))
		flavor = T.call("ev_%s_f" % id) if rand else _loc(e.get("flavor", {}))
		var cat_raw: String = String(e.get("cat", "")).to_lower()
		var icon_id: String = String(e.get("icon", ""))
		icon = icon_id if (icon_id != "" and TBGlyph.ic_name(icon_id) != "") else String(CAT_IC.get(cat_raw, "star" if (not rand and e.get("world", false)) else "warn"))
		bad = cat_raw in CAT_BAD or (cat_raw == "" and icon == "warn")
		var cat_key := "evcat_" + cat_raw.replace(" ", "_")
		kicker = T.call("ev_worldwide") if (not rand and e.get("world", false)) else (T.call("ev_event") if not rand else (T.call(cat_key) if TBI18n.has_key(cat_key) else String(e.get("cat", ""))))
		var labels: Array = e.get("labels", [])
		for i in int(e["count"]):
			var ttl: String
			var chips: Array = []
			if rand:
				ttl = T.call("ev_%s_c%d" % [id, i]); chips = chips_from_text(T.call("ev_%s_d%d" % [id, i]))
			elif i < labels.size():
				ttl = _loc(labels[i])
				var fx: Array = e.get("fx", [])
				if i < fx.size(): chips = fx_chips(fx[i])
			else: ttl = T.call("ev_ack")
			var raw: String = " ".join(chips.map(func(c): return String(c[0])))
			choices.append([choice_icon(raw, "check" if chips.is_empty() else "move"), ttl, chips, i])
	# ---- header block: the class band (B2) or the medallion, then kicker + title
	var use_band: bool = not h.short and not h.phone and K.text_scale < 1.5
	if use_band:
		var tone_cat: String = "" if e["kind"] == "prop" else String(e.get("cat", ""))
		box.add_child(TBEventBand.new(icon, TBEventBand.tone_of(tone_cat, bad))); _gap(box, 14)
	var top := K.hbox(14); top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not use_band: top.add_child(EventMedal.new(icon, TBTokens.BZ_BAD if bad else TBTokens.c("brass_lt")))
	var tc := K.vbox(3); tc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kk := K.caps(kicker, 11, TBTokens.BZ_BAD if bad else TBTokens.c("brass_lt")); (kk as TBBz.TLabel).wrap_ok = true; kk.custom_minimum_size.x = 40; kk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.add_child(kk)
	var tl := K.title(title, 19, TBTokens.BZ_IVORY, 0.06, 19.0 * 1.15); (tl as TBBz.TLabel).wrap_ok = true; tl.custom_minimum_size.x = 40; tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tc.add_child(tl)
	top.add_child(tc)
	box.add_child(top); _gap(box, 10)
	box.add_child(K.para_bz(flavor, 17.0, 1.4)); _gap(box, 12)
	if after != null:
		box.add_child(after); _gap(box, 12)
	var cv := K.vbox(6); cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(cv)
	var first: Control = null
	for c in choices:
		var idx: int = int(c[3])
		var row := event_choice(String(c[0]), String(c[1]), c[2], func(): h.close(); on_choose.call(idx))
		cv.add_child(row)
		if first == null: first = row
	if can_defer:
		_gap(box, 6)
		var later := LinkBtn.new(T.call("decide_later"), func(): h.close(); on_defer.call())
		later.autowrap_mode = TextServer.AUTOWRAP_OFF
		K.a11y(later, T.call("decide_later"), "button", T.call("decide_later_d"))
		box.add_child(later)
	if first != null: h.focus_target = first
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
	if TBFrame.bezel and vs.y >= 560.0 and vs.x >= vs.y and K.text_scale < 1.5 and not K.is_phone(parent): return TBFinale.open(parent, g, on_menu)        # B7: the full-screen finale
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
