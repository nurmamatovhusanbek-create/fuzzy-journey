## The Realm page: what the crest (your flag, top left) opens. Your own country as a ledger: standing, treasury and taxes, the court, treaties and wars.
## A movable window like the others; the rows that name a country open that country's card.
class_name TBRealmScreen
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T

static func _cap(txt: String, top: float = 14.0, bottom: float = 6.0) -> Control:
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", int(top)); m.add_theme_constant_override("margin_bottom", int(bottom))
	m.add_child(K.wrappable(K.caps(txt))); return m

static func _pad(c: Control, top: float = 0.0, bottom: float = 0.0) -> Control:
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", int(top)); m.add_theme_constant_override("margin_bottom", int(bottom))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL; m.add_child(c); return m

## The countries `n` has dealings with, group by group (allies, marriages, pacts, wars, vassals, trade partners, overlord): a flag-and-name button each, as in the Nations tab.
## `cap` > 0 shows that many per group and a "+N" chip for the rest. Returns whether any group was added.
static func add_relations(v: VBoxContainer, g: TBGame, n: int, on_nation: Callable, cap: int = 0) -> bool:
	var groups: Array = []
	for grp in [[T.call("allies"), 3], [T.call("rel_marriage"), 4], [T.call("rel_nap"), 2], [T.call("at_war_with"), 1]]:
		var arr: Array = []
		for o in range(1, g.N1):
			if g.alive[o] == 0 or o == n or o == g.rebel: continue
			if g.get_rel(n, o) == int(grp[1]): arr.append(o)
		groups.append([String(grp[0]), arr, 1 if int(grp[1]) == 1 else 0])
	var vassals: Array = []; var trade_p: Array = []
	for o in range(1, g.N1):
		if g.alive[o] == 0 or o == n or o == g.rebel: continue
		if g.overlord[o] == n: vassals.append(o)
		if g.rules >= 1 and TBTrade.has(g, n, o): trade_p.append(o)
	groups.append([T.call("vassals"), vassals, 0]); groups.append([T.call("trade_partners"), trade_p, 0])
	if g.overlord[n] != 0: groups.append([T.call("overlord"), [g.overlord[n]], 0])
	var any := false
	for grp in groups:
		var arr2: Array = _by_nearness(g, n, grp[1])
		if arr2.is_empty(): continue
		any = true
		v.add_child(_group_head(String(grp[0]), arr2.size(), int(grp[2]) == 1))
		var gr := GridContainer.new(); gr.columns = 1 if K.text_scale >= 1.4 else 2
		gr.add_theme_constant_override("h_separation", 16); gr.add_theme_constant_override("v_separation", 0); gr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(gr)
		var shown: int = mini(arr2.size(), cap if cap > 0 else GROUP_SHOW)
		var rows: Array = []
		for i in arr2.size():
			var oo: int = arr2[i]
			var row := RelRow.new(g, n, oo, int(grp[2]) == 1, func(): if on_nation.is_valid(): on_nation.call(oo))
			row.visible = i < shown
			gr.add_child(row); rows.append(row)
		var spacer: Control = null
		if gr.columns == 2:                                         # an odd last row leaves its neighbour's place empty, at the same width (a lone row would take the whole line)
			spacer = Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spacer.visible = shown % 2 == 1; gr.add_child(spacer)
		if arr2.size() > shown:
			var more := K.button(T.call("rel_more", {"k": arr2.size() - shown}), Callable(), false, true)
			more.pressed.connect(func() -> void:
				for rw in rows: (rw as Control).visible = true
				if spacer != null: spacer.visible = arr2.size() % 2 == 1
				more.queue_free())
			var mw := MarginContainer.new(); mw.add_theme_constant_override("margin_top", 6); mw.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN; mw.add_child(more); v.add_child(mw)
	return any

const GROUP_SHOW := 6

## countries with the nearest first (border, near, far, none), then the larger army; rules < 4 keeps the order as it is
static func _by_nearness(g: TBGame, n: int, ids: Array) -> Array:
	if g.rules < 4: return ids
	var out: Array = ids.duplicate()
	var rank := {"border": 0, "near": 1, "far": 2, "none": 3}
	out.sort_custom(func(a: int, b: int) -> bool:
		var ra: int = rank[TBDiplo.contact(g, n, a)]; var rb: int = rank[TBDiplo.contact(g, n, b)]
		if ra != rb: return ra < rb
		return a < b)
	return out

## a group's header: its name, a count in a small round tag, a hairline; wars in the rust colour
static func _group_head(title: String, count: int, war: bool) -> Control:
	var hb := K.hbox(10); hb.custom_minimum_size = Vector2(0, 28)
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", 10); m.add_child(hb)
	var cap := K.caps(title, 12, TBTokens.BZ_BAD_TXT if war else K.GOLD); cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(cap)
	var cnt := K.label(str(count), 13, TBTokens.c("cream")); cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pc := PanelContainer.new(); pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new(); sb.bg_color = TBTokens.BZ_WELL; sb.border_color = TBTokens.BZ_WELL_LINE; sb.set_border_width_all(1); sb.set_corner_radius_all(10)
	sb.content_margin_left = 7; sb.content_margin_right = 7; sb.content_margin_top = 1; sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb); pc.add_child(cnt); hb.add_child(pc)
	var line := ColorRect.new(); line.color = TBTokens.BZ_WELL_LINE; line.custom_minimum_size = Vector2(0, 1); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL; line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(line)
	return m

## one country: its flag, its name in capitals (two lines at most), and how near it is (rules >= 4); a tap opens its card
class RelRow extends Button:
	func _init(g: TBGame, me: int, o: int, war: bool, cb: Callable) -> void:
		flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, maxf(38.0, TBKit.touch())); size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		var hb := TBKit.hbox(10); hb.set_anchors_preset(Control.PRESET_FULL_RECT); hb.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(hb)
		var fl := TBNationParts.FlagMedal.new(TBFlags.medal_of(g, o), 28.0); hb.add_child(fl)
		var nm := TBBz.TLabel.new(TBKit.cinzel(700), 12.0, 0.06, 0.0, true)
		nm.text = g.dname(o); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER; nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(nm as TBBz.TLabel).wrap_ok = true; (nm as TBBz.TLabel).refit(); nm.custom_minimum_size.x = 40
		nm.add_theme_color_override("font_color", TBTokens.c("cream"))
		hb.add_child(nm)
		var ct := ""
		if g.rules >= 4:
			var c := TBDiplo.contact(g, me, o)
			ct = TBI18n.T("contact_" + c)
			var lb := TBKit.label(ct, 13, TBTokens.BZ_GOOD if c == "border" else (TBTokens.BZ_BAD_TXT if c == "none" else K.DIM))
			lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; lb.mouse_filter = Control.MOUSE_FILTER_IGNORE; hb.add_child(lb)
		TBKit.a11y(self, "%s %s" % [g.dname(o), ct], "button")
		pressed.connect(cb)
		mouse_entered.connect(queue_redraw); mouse_exited.connect(queue_redraw); focus_entered.connect(queue_redraw); focus_exited.connect(queue_redraw)
	func _draw() -> void:
		if is_hovered() or has_focus(): draw_rect(Rect2(Vector2.ZERO, size), TBTokens.ca("cream", 0.05))
		draw_line(Vector2(0, size.y - 0.5), Vector2(size.x, size.y - 0.5), Color(TBTokens.c("rule"), 0.6), 1.0)

## opts: on_nation(n)
static func open(parent: Control, g: TBGame, opts: Dictionary = {}) -> TBPanel.Handle:
	var me: int = g.human_id
	var on_nation: Callable = opts.get("on_nation", Callable())
	var sub: String = (T.call(TBRulers.title_key(g, me)) + " " + TBRulers.display_name(g, me)) if (g.rules >= 1 and g.r_name[me] != "") else T.call("era_name_%d" % g.era[me])
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, g.dname(me), "crown", {"w": 760, "h": 900, "sub": sub, "key": "realm"})
	var body: VBoxContainer = h.body
	body.add_theme_constant_override("separation", 0)
	var st := TBNationsScreen.compute(g)
	var inc: Dictionary = g.income(me)
	var bd: Dictionary = TBAdvisor.breakdown(g, me, inc)
	# ---- three figures
	var cells := K.hbox(8); cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.add_child(TBNationParts.StatCell.new("army", K.fmt(float(st["army"][me])), T.call("cap_army")))
	cells.add_child(TBNationParts.StatCell.new("gold", "%s  %s" % [K.fmt(g.gold[me]), K.signed(float(inc["net"]))], T.call("gold")))
	cells.add_child(TBNationParts.StatCell.new("flag", str(int(st["prov"][me])), T.call("lands")))
	body.add_child(_pad(cells, 0.0, 6.0))
	# ---- standing
	var stab_sum := 0; var happy_sum := 0; var n_own := 0
	for p in g.owned(me):
		stab_sum += g.stab[p]; happy_sum += g.happy[p]; n_own += 1
	var standing: Array = [
		[T.call("lands"), "%d · #%d" % [int(st["prov"][me]), int(st["rank_p"].get(me, 0))], 0],
		[T.call("total_army"), "%s · #%d" % [K.fmt(float(st["army"][me])), int(st["rank_a"].get(me, 0))], 0],
		[T.call("tech"), "%s %.1f · #%d" % [T.call("era_name_%d" % g.era[me]), g.tech_level[me], int(st["rank_t"].get(me, 0))], 0],
		[T.call("stability"), "%d%%" % (int(round(float(stab_sum) / maxf(1.0, float(n_own))))), 0],
		[T.call("happiness"), "%d%%" % (int(round(float(happy_sum) / maxf(1.0, float(n_own))))), 0]]
	body.add_child(_cap(T.call("realm_standing"), 10.0, 6.0))
	body.add_child(K.fxl(standing, 2))
	# ---- people (rules 5): the size in real terms, growth, how much of the land's room is used, soldiers, the levy pool
	if g.rules >= 5:
		var pop_sum := 0; var cap_sum := 0; var grow_sum := 0.0; var army_sum := 0; var lev_a := 0; var lev_b := 0
		for p in g.owned(me):
			pop_sum += g.pop[p]; cap_sum += g.pop_cap(p); army_sum += g.army[p]
			grow_sum += float(TBTurn.growth_parts(g, p)["growth"])
			lev_a += mini(g.levy[p], g.levy_cap(p)); lev_b += g.levy_cap(p)
		var per_year: float = grow_sum * 2.0 / maxf(1.0, float(pop_sum)) * 100.0
		var ppl: Array = [
			[T.call("rp_total"), T.call("rp_total_v", {"g": K.fmt(float(pop_sum)), "r": K.fmt(float(pop_sum) * float(g.scale)), "s": g.scale}), 0],
			[T.call("rp_growth"), T.call("rp_growth_v", {"v": "%+.2f" % per_year}), 1 if per_year > 0.05 else (-1 if per_year < -0.05 else 0)],
			[T.call("rp_room"), T.call("rp_room_v", {"v": int(round(100.0 * float(pop_sum) / maxf(1.0, float(cap_sum))))}), 0],
			[T.call("rp_army_share"), T.call("rp_army_v", {"v": "%.2f" % (100.0 * float(army_sum) / maxf(1.0, float(pop_sum)))}), 0],
			[T.call("rp_levy"), "%s / %s" % [K.fmt(float(lev_a)), K.fmt(float(lev_b))], 0]]
		body.add_child(_cap(T.call("realm_people"), 14.0, 6.0))
		body.add_child(K.fxl(ppl, 2))
	# ---- progress toward the victories (the three nearest)
	if g.rules >= 1:
		var prog: Dictionary = TBTurn.victory_progress(g, me)
		var ids: Array = TBTurn.win_ids(g).duplicate()
		ids.sort_custom(func(a: String, b: String) -> bool: return float(prog[a]) > float(prog[b]))
		var pr_rows: Array = []
		for i in mini(4, ids.size()): pr_rows.append([T.call("vc_" + String(ids[i])), "%d%%" % int(roundf(float(prog[ids[i]]) * 100.0)), 0])
		body.add_child(_cap(T.call("realm_progress"), 14.0, 6.0))
		body.add_child(K.fxl(pr_rows, 2))
	# ---- treasury: taxes and the rest, then how the budget is split
	var money: Array = [[T.call("bud_taxes"), K.signed(float(inc["tax"])), 1]]
	if g.rules >= 1 and TBTrade.income(g, me) > 0: money.append([T.call("trade"), K.signed(float(TBTrade.income(g, me))), 1])
	money.append([T.call("bud_provinces"), K.signed(float(inc["production"])), 1 if int(inc["production"]) > 0 else 0])
	money.append([T.call("realm_upkeep"), K.signed(-float(inc["upkeep"])), -1])
	money.append([T.call("realm_admin"), K.signed(-float(inc["admin"])), -1])
	money.append([T.call("income_net"), K.signed(float(inc["net"])), 1 if int(inc["net"]) >= 0 else -1])
	body.add_child(_cap(T.call("realm_treasury"), 14.0, 6.0))
	body.add_child(K.fxl(money, 2))
	var split: Array = []
	for i in 4: split.append([T.call(["budget_tax", "budget_goods", "budget_research", "budget_invest"][i]), "%d%%" % int(g.budget[me * 4 + i]), 0])
	body.add_child(_cap(T.call("realm_split"), 14.0, 6.0))
	body.add_child(K.fxl(split, 2))
	# ---- the court
	var court: Array = [[T.call("govt"), T.call("g_" + TBData.REGIME_ID[g.regime[me]]), 0],
		[T.call("dp"), "%d  (+%.1f)" % [int(g.dp[me]), float(bd["dp_gain"])], 0],
		[T.call("mp"), "%d  (+%.1f)" % [int(g.mp[me]), float(bd["mp_gain"])], 0],
		[T.call("manpower"), "%s  (+%s)" % [K.fmt(g.manpower[me]), K.fmt(float(bd["man_gain"]))], 0]]
	if g.rules >= 1:
		if g.r_name[me] != "": court.append([T.call("skill_adm") + " / " + T.call("skill_dip") + " / " + T.call("skill_mil"), "%d / %d / %d" % [g.r_adm[me], g.r_dip[me], g.r_mil[me]], 0])
		court.append([T.call("doctrine"), T.call("doc_" + TBDoctrine.IDS[g.doctrine[me]]) if g.doctrine[me] != 0 else T.call("doc_none_short"), 0])
		if g.rules >= 4: court.append([T.call("spy_guard"), T.call("spy_guard_v", {"p": int(roundf(TBSpy.guard(g, me) * 100.0)), "t": TBSpy.towers(g, me)}), 0])
		court.append([T.call("infamy"), "%.0f%s" % [g.infamy[me], ("  " + T.call("coalition")) if g.coalition[me] != 0 else ""], -1 if g.infamy[me] >= 12.0 else 0])
	body.add_child(_cap(T.call("realm_court"), 14.0, 6.0))
	body.add_child(K.fxl(court, 2))
	# ---- treaties and wars: a country per button (flag and name), opening its card
	var any_rel := add_relations(body, g, me, on_nation, 0)
	if not any_rel:
		body.add_child(_cap(T.call("realm_treaties"), 14.0, 6.0))
		body.add_child(K.para_bz(T.call("realm_no_treaties"), 16.0, 1.3))
	return h
