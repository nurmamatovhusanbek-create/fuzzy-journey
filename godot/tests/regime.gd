extends SceneTree
## Reform of the government: cost, era gate, cooldown, stability and estates, what it opens, the AI, saves, and the road Empire -> USSR. Usage: -s tests/regime.gd (run with timeout)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5, "rules": 5})
	var ru := g.nat_code.find("russian_empire"); g.set_human(ru); g.pending.clear()
	_check(g.regime[ru] == 4, "the Russian Empire starts as an empire")
	g.gold[ru] = 1e9; g.mp[ru] = 10.0
	var communism := 6; var republic := 3
	print("era of Russia: ", g.era[ru], " communism needs ", TBData.REGIMES[communism]["sinceEra"])
	_check(String(TBRegimes.can_reform(g, ru, communism)["reason"]) == "reg_era", "communism before its time (1804) is refused")
	_check(String(TBRegimes.can_reform(g, ru, 4)["reason"]) == "reg_same", "it already is an empire")
	_check(String(TBRegimes.can_reform(g, ru, 8)["reason"]) == "unknown", "a horde is not a reform")
	var cf := TBRegimes.can_reform(g, ru, republic)
	_check(bool(cf["ok"]) and int(cf["gold"]) > 0, "a republic is possible (%s)" % str(cf))
	var opens: Array = TBRegimes.opens(g, ru, republic)
	var names: Array = []
	for si in opens: names.append(String(TBLineage.STAGES[si]["id"]))
	print("a republic would open: ", names)
	_check(names.has("russia"), "a republic opens Russia")
	var stab0 := 0; for p in g.owned(ru): stab0 += g.stab[p]
	var gold0: float = g.gold[ru]; var mer0 := TBEstates.loyalty(g, ru, 2); var army0 := TBEstates.loyalty(g, ru, 3)
	var r := g.apply({"cmd": "regime", "n": ru, "r": republic})
	_check(bool(r.get("ok", false)), "apply accepts it (%s)" % str(r))
	_check(g.regime[ru] == republic and g.gold[ru] < gold0 and g.reg_last[ru] == g.turn, "the government changed, paid, and dated")
	var stab1 := 0; for p in g.owned(ru): stab1 += g.stab[p]
	_check(stab1 < stab0, "the land is shaken (%d -> %d)" % [stab0, stab1])
	_check(TBEstates.loyalty(g, ru, 2) > mer0 and TBEstates.loyalty(g, ru, 3) < army0, "the merchants are pleased and the army, which led the empire, is not")
	_check(String(TBRegimes.can_reform(g, ru, 5)["reason"]) == "reg_recent" or g.era[ru] < int(TBData.REGIMES[5]["sinceEra"]), "a second reform at once is refused")
	g.turn += TBRegimes.REFORM_COOLDOWN; g.year = 1925
	g.regime[ru] = 4
	g.era[ru] = maxi(g.era[ru], 3)
	_check(bool(TBRegimes.can_reform(g, ru, communism)["ok"]), "after the cooldown, in an age that allows it, communism is possible")
	var log_ok := false
	for e in g.log: if String(e.get("kind", "")) == "reform": log_ok = true
	_check(log_ok, "the chronicle records it")
	# the road: empire -> communism opens the USSR in 1925
	g.year = 1925
	var ussr := TBLineage.index_of("ussr")
	_check(String(TBLineage.can_form(g, ru, ussr)["reason"]) == "form_regime", "as an empire it cannot proclaim the USSR")
	_check(TBRegimes.opens(g, ru, communism).has(ussr), "communism would open the USSR")
	_check(bool(g.apply({"cmd": "regime", "n": ru, "r": communism}).get("ok", false)), "the reform to communism goes through")
	_check(String(TBLineage.can_form(g, ru, ussr)["reason"]) != "form_regime", "now the government is no longer the obstacle")
	# the AI: a state that has the year and the land but the wrong government reforms by itself
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5, "rules": 5})
	var fr := g2.nat_code.find("france"); g2.set_human(fr); g2.pending.clear()
	var ai := g2.nat_code.find("russian_empire")
	g2.year = 1925; g2.era[ai] = 3; g2.gold[ai] = 1e9; g2.mp[ai] = 10.0
	var core: Array = TBLineage.STAGES[ussr]["core"]
	for i in core.size(): g2.set_owner(int(core[i]), ai)
	var did := false
	for t in 8:
		g2.turn += 1
		TBRegimes.ai_step(g2, ai)
		if g2.regime[ai] != 4: did = true; break
	print("AI regime after the loop: ", TBData.REGIME_ID[g2.regime[ai]])
	_check(g2.regime[ai] == 6, "toward the strongest name, the USSR: communism")
	_check(did, "the AI reforms toward a name of its line when the land and the year are there")
	# saves keep the date of the reform
	var d := TBSave.snapshot(g)
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5, "rules": 5})
	TBSave.restore(g3, d)
	_check(g3.reg_last == g.reg_last and g3.regime == g.regime, "a restored game keeps the reform")
	print("REGIME OK" if fails == 0 else "REGIME FAIL %d" % fails)
	quit(fails)
