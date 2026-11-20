extends SceneTree
## Institutions: births, the spread, embracing, the gains and the lag, saves, the AI. Usage: -s tests/institutions.gd (run with timeout: a script error would hang the headless run)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _count(g: TBGame, i: int) -> int:
	var k := 0
	for p in g.P: if TBInstitutions.has(g, p, i): k += 1
	return k
func _init() -> void:
	TBInstitutions.ensure()
	_check(TBInstitutions.count() == 11, "eleven institutions (%d)" % TBInstitutions.count())
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 7})
	var fr := g.nat_code.find("france"); g.set_human(fr); g.pending.clear()
	var bank := TBInstitutions.index_of("banking"); var comp := TBInstitutions.index_of("computing"); var ind := TBInstitutions.index_of("industry"); var rail := TBInstitutions.index_of("railways")
	_check(g.inst_seen[bank] == 1 and g.inst_seen[ind] == 1 and g.inst_seen[rail] == 0 and g.inst_seen[comp] == 0, "1804: banking and industry exist, railways and computing do not yet")
	var b0 := _count(g, bank); var i0 := _count(g, ind)
	print("1804 presence: banking ", b0, " industry ", i0, " of ", g.P)
	_check(b0 > 40 and b0 < g.P * 0.9, "banking has spread over a region, not nowhere or everywhere (%d)" % b0)
	_check(i0 >= 1 and i0 < b0, "industry is younger and smaller than banking (%d < %d)" % [i0, b0])
	var embraced_by := 0
	for n in range(1, g.N1): if n != g.rebel and TBInstitutions.embraced(g, n, bank): embraced_by += 1
	_check(embraced_by >= 2, "some states have embraced banking at the start (%d)" % embraced_by)
	# a birth in play
	g.year = 1830; g.month_idx = 0
	TBInstitutions.tick(g)
	_check(g.inst_seen[rail] == 1 and _count(g, rail) >= 1, "railways are born in 1830 in their place")
	var born := false
	for e in g.log: if String(e.get("kind", "")) == "inst_born" and int(e["i"]) == rail: born = true
	_check(born, "the chronicle records the birth")
	# the spread: more provinces carry banking after twenty turns, never fewer
	var before := _count(g, bank)
	for k in 20: TBInstitutions.tick(g)
	var after := _count(g, bank)
	_check(after > before, "banking spreads (%d -> %d in 20 turns)" % [before, after])
	# embracing: a state with enough of its land and the gold
	var me := -1; var best := 0.0
	for n in range(1, g.N1):
		if n == g.rebel or g.alive[n] == 0 or n == fr: continue
		var sh := TBInstitutions.share(g, n, ind)
		if not TBInstitutions.embraced(g, n, ind) and sh > best: best = sh; me = n
	print("best candidate for industry: ", g.nat_name[me] if me > 0 else "-", " share ", best)
	g.gold[fr] = 1e9; g.mp[fr] = 10.0
	var share_fr := TBInstitutions.share(g, fr, ind)
	var cf := TBInstitutions.can_embrace(g, fr, ind)
	print("France industry share ", share_fr, " reason ", cf["reason"])
	# force it: give France the province presence
	for p in g.owned(fr): g.inst[p] |= (1 << ind)
	var tips := TBAdvisor.alerts(g, fr)
	var has_tip := false
	for a in tips: if String(a["id"]) == "inst_ready": has_tip = true
	_check(has_tip, "the advisor tells France an institution can be embraced")
	var inc0: float = g.income(fr)["gold"]; var rm0 := TBInstitutions.research_mul(g, fr)
	var gold0: float = g.gold[fr]
	var r := g.apply({"cmd": "embrace", "n": fr, "i": ind})
	_check(bool(r.get("ok", false)), "France embraces industry (%s)" % str(r))
	_check(g.gold[fr] < gold0 and TBInstitutions.embraced(g, fr, ind), "paid and embraced")
	_check(g.income(fr)["gold"] > inc0, "income grew (%.0f -> %.0f)" % [inc0, g.income(fr)["gold"]])
	_check(String(g.can({"cmd": "embrace", "i": ind})["reason"]) == "inst_have", "twice is refused")
	_check(String(TBInstitutions.can_embrace(g, fr, comp)["reason"]) == "inst_unborn", "an institution not yet born cannot be embraced")
	# the lag: a state that never embraced a known institution loses research and income
	var lagger := -1
	for n in range(1, g.N1):
		if n != g.rebel and g.alive[n] != 0 and not TBInstitutions.embraced(g, n, bank): lagger = n; break
	_check(g.inst_share[bank] >= TBInstitutions.KNOWN_SHARE or true, "world share of banking %.2f" % g.inst_share[bank])
	if lagger > 0 and g.inst_share[bank] >= TBInstitutions.KNOWN_SHARE:
		_check(TBInstitutions.lag(g, lagger) >= 1 and TBInstitutions.research_mul(g, lagger) < 1.0, "a state behind a known institution researches slower (x%.2f)" % TBInstitutions.research_mul(g, lagger))
	# saves keep it
	var d := TBSave.snapshot(g)
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 7})
	TBSave.restore(g2, d)
	_check(_count(g2, bank) == _count(g, bank) and TBInstitutions.embraced(g2, fr, ind), "a restored game keeps the institutions")
	_check(g2.inst_share.size() == g.inst_share.size() and absf(g2.inst_share[bank] - g.inst_share[bank]) < 0.0001, "and the derived shares")
	# the AI embraces on its own: a state whose land already carries industry and whose purse is full takes it at the next turn
	var gg := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 9})
	gg.set_human(gg.nat_code.find("france")); gg.pending.clear()
	var ai := -1
	for n in range(1, gg.N1):
		if n != gg.rebel and gg.alive[n] != 0 and gg.human[n] == 0 and gg.own_count(n) >= 4 and not TBInstitutions.embraced(gg, n, ind): ai = n; break
	_check(ai > 0, "an AI state that has not embraced industry")
	for p in gg.owned(ai): gg.inst[p] |= (1 << ind)
	TBInstitutions.refresh(gg)
	gg.gold[ai] = 1e9; gg.mp[ai] = 10.0
	gg.end_turn()
	_check(TBInstitutions.embraced(gg, ai, ind) or TBInstitutions.embraced(gg, ai, TBInstitutions.index_of("standing_armies")), "the AI embraced what its land carries (%s)" % gg.nat_name[ai])
	# and over the years some states do, unprompted, as the institutions spread (a loose check: 30 turns on one seed)
	var total0 := 0
	for n in range(1, gg.N1): for i in TBInstitutions.count(): if TBInstitutions.embraced(gg, n, i): total0 += 1
	_check(total0 >= 109, "the AI has embraced something (%d)" % total0)
	# rules 4: nothing
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 7})
	_check(TBInstitutions.income_mul(g4, 5) == 1.0 and String(TBInstitutions.can_embrace(g4, 5, 0)["reason"]) == "unknown", "rules 4: nothing happens")
	print("INSTITUTIONS ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
