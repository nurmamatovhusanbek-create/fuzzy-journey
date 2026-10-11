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
		groups.append([String(grp[0]), arr])
	var vassals: Array = []; var trade_p: Array = []
	for o in range(1, g.N1):
		if g.alive[o] == 0 or o == n or o == g.rebel: continue
		if g.overlord[o] == n: vassals.append(o)
		if g.rules >= 1 and TBTrade.has(g, n, o): trade_p.append(o)
	groups.append([T.call("vassals"), vassals]); groups.append([T.call("trade_partners"), trade_p])
	if g.overlord[n] != 0: groups.append([T.call("overlord"), [g.overlord[n]]])
	var any := false
	for grp in groups:
		var arr2: Array = grp[1]
		if arr2.is_empty(): continue
		any = true
		v.add_child(_cap(String(grp[0]), 14.0, 6.0))
		var fw := TBPanel.flow(6); v.add_child(fw)
		var shown: int = arr2.size() if cap <= 0 else mini(cap, arr2.size())
		for i in shown:
			var oo: int = arr2[i]
			fw.add_child(TBPanel.nation_button(g, oo, func(): if on_nation.is_valid(): on_nation.call(oo)))
		if arr2.size() > shown: fw.add_child(K.chip("+%d" % (arr2.size() - shown), "", "neutral"))
	return any

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
	# ---- progress toward the victories (the three nearest)
	if g.rules >= 1:
		var prog: Dictionary = TBTurn.victory_progress(g, me)
		var ids: Array = TBTurn.VICTORY_IDS.duplicate()
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
		court.append([T.call("infamy"), "%.0f%s" % [g.infamy[me], ("  " + T.call("coalition")) if g.coalition[me] != 0 else ""], -1 if g.infamy[me] >= 12.0 else 0])
	body.add_child(_cap(T.call("realm_court"), 14.0, 6.0))
	body.add_child(K.fxl(court, 2))
	# ---- treaties and wars: a country per button (flag and name), opening its card
	var any_rel := add_relations(body, g, me, on_nation, 0)
	if not any_rel:
		body.add_child(_cap(T.call("realm_treaties"), 14.0, 6.0))
		body.add_child(K.para_bz(T.call("realm_no_treaties"), 16.0, 1.3))
	return h
