## The Realm page: what the crest (your flag, top left) opens. Your own country as a ledger: standing, treasury and taxes, the court, treaties and wars.
## A movable window like the others; the rows that name a country open that country's card, the buttons go to Budget / Decrees / Council.
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

## opts: on_nation(n), on_screen(id: "budget" | "decrees" | "council")
static func open(parent: Control, g: TBGame, opts: Dictionary = {}) -> TBPanel.Handle:
	var me: int = g.human_id
	var on_nation: Callable = opts.get("on_nation", Callable())
	var on_screen: Callable = opts.get("on_screen", Callable())
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
		court.append([T.call("infamy"), "%.0f%s" % [g.infamy[me], ("  " + T.call("coalition")) if g.coalition[me] != 0 else ""], -1 if g.infamy[me] >= 12.0 else 0])
	body.add_child(_cap(T.call("realm_court"), 14.0, 6.0))
	body.add_child(K.fxl(court, 2))
	# ---- treaties and wars: a country per button, opening its card
	var groups: Array = [[T.call("allies"), 3], [T.call("rel_marriage"), 4], [T.call("rel_nap"), 2], [T.call("at_war_with"), 1]]
	var any_rel := false
	for grp in groups:
		var arr: Array = []
		for o in range(1, g.N1):
			if g.alive[o] == 0 or o == me or o == g.rebel: continue
			if g.get_rel(me, o) == int(grp[1]): arr.append(o)
		if arr.is_empty(): continue
		any_rel = true
		body.add_child(_cap(String(grp[0]), 14.0, 6.0))
		var fw := TBPanel.flow(6); body.add_child(fw)
		for o in arr:
			var oo: int = o
			fw.add_child(TBPanel.nation_button(g, oo, func(): if on_nation.is_valid(): on_nation.call(oo)))
	var vassals: Array = []; var trade_p: Array = []
	for o in range(1, g.N1):
		if g.alive[o] == 0 or o == me or o == g.rebel: continue
		if g.overlord[o] == me: vassals.append(o)
		if g.rules >= 1 and TBTrade.has(g, me, o): trade_p.append(o)
	for grp2 in [[T.call("vassals"), vassals], [T.call("trade_partners"), trade_p]]:
		var arr2: Array = grp2[1]
		if arr2.is_empty(): continue
		any_rel = true
		body.add_child(_cap(String(grp2[0]), 14.0, 6.0))
		var fw2 := TBPanel.flow(6); body.add_child(fw2)
		for o2 in arr2:
			var o3: int = o2
			fw2.add_child(TBPanel.nation_button(g, o3, func(): if on_nation.is_valid(): on_nation.call(o3)))
	if g.overlord[me] != 0:
		any_rel = true
		body.add_child(_cap(T.call("overlord"), 14.0, 6.0))
		var fw3 := TBPanel.flow(6); body.add_child(fw3)
		var ov: int = g.overlord[me]
		fw3.add_child(TBPanel.nation_button(g, ov, func(): if on_nation.is_valid(): on_nation.call(ov)))
	if not any_rel:
		body.add_child(_cap(T.call("realm_treaties"), 14.0, 6.0))
		body.add_child(K.para_bz(T.call("realm_no_treaties"), 16.0, 1.3))
	# ---- where to go from here
	var go := K.hbox(8); go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for sc in [["budget", T.call("budget"), "treasury"], ["decrees", T.call("dk_decisions"), "decrees"], ["council", T.call("realm_council"), "council"]]:
		var sid: String = sc[0]
		var b: Button = K.button(String(sc[1]), func(): if on_screen.is_valid(): on_screen.call(sid), false, false, String(sc[2]))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.add_child(b)
	body.add_child(_pad(go, 18.0, 0.0))
	return h
