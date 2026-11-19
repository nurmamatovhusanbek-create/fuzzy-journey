extends SceneTree
## Lineages: the data, the conditions, forming a new identity (name, tag, claims, bonus), the AI, saves. Usage: -s tests/lineage.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	TBLineage.ensure()
	_check(TBLineage.STAGES.size() >= 20, "the lineage data is loaded (%d stages)" % TBLineage.STAGES.size())
	var eras := {}
	for s in TBLineage.STAGES:
		_check((s["core"] as Array).size() >= 2, "stage %s has a core" % s["id"])
		_check((s["regimes"] as Array).size() > 0 and int(s["w"]) >= 1 and int(s["w"]) <= 3, "stage %s has regimes and a weight" % s["id"])
		for p in s["core"]: _check(int(p) >= 0 and int(p) < 1788, "core province in range"); break
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5, "rules": 5})
	var ru := g.nat_code.find("russian_empire"); g.set_human(ru); g.pending.clear()
	_check(TBLineage.current(g, ru) == TBLineage.index_of("russian_empire"), "Russia in 1804 stands in the Russian Empire stage")
	var opts: Array = TBLineage.options(g, ru)
	var ids: Array = []
	for si in opts: ids.append(String(TBLineage.STAGES[si]["id"]))
	print("Russian Empire may form: ", ids)
	_check(ids.has("russia") and ids.has("ussr") and not ids.has("russian_empire") and not ids.has("tsardom_of_muscovy"), "the next steps of the line are open, the old ones are not")
	_check(not ids.has("russian_federation"), "the Federation is not open to the Empire (only to the USSR or Russia)")
	var ussr := TBLineage.index_of("ussr")
	# conditions fail for the right reasons
	g.year = 1804
	_check(String(TBLineage.can_form(g, ru, ussr)["reason"]) == "form_year", "1804: too early for the USSR")
	g.year = 1925; g.regime[ru] = 4
	_check(String(TBLineage.can_form(g, ru, ussr)["reason"]) == "form_regime", "an empire cannot proclaim the USSR")
	g.regime[ru] = 6
	g.gold[ru] = 1e9; g.mp[ru] = 10.0
	var held0 := TBLineage.core_held(g, ru, ussr)
	_check(String(TBLineage.can_form(g, ru, ussr)["reason"]) == "form_core" or held0 >= TBLineage.core_need(ussr), "without the land it is refused (%d of %d)" % [held0, TBLineage.core_need(ussr)])
	# give the land: every province of the USSR core except three, which a neighbour holds
	var neighbour := -1
	for n in range(1, g.N1): if n != ru and n != g.rebel and g.alive[n] != 0: neighbour = n; break
	var core: Array = TBLineage.STAGES[ussr]["core"]
	for i in core.size(): g.set_owner(int(core[i]), ru if i >= 3 else neighbour)
	var cf := TBLineage.can_form(g, ru, ussr)
	_check(bool(cf["ok"]), "with land, government, year and gold it can be formed (%s %s)" % [cf["reason"], str(TBLineage.conditions(g, ru, ussr))])
	var ftip := false
	for a in TBAdvisor.alerts(g, ru): if String(a["id"]) == "form_ready" and int(a["k"]) == ussr: ftip = true
	_check(ftip, "the advisor tells Russia the USSR can be proclaimed")
	var inc0: float = g.income(ru)["gold"]; var lev0: int = g.levy_cap(core[5])
	var dp0: float = g.dp[ru]; var gold0: float = g.gold[ru]; var mp0: float = g.mp[ru]
	var r := g.apply({"cmd": "form", "n": ru, "i": ussr})
	_check(bool(r.get("ok", false)), "apply accepts it")
	_check(g.nat_code[ru] == "ussr" and g.nat_name[ru] == "USSR", "the nation is now the USSR (%s)" % g.nat_name[ru])
	_check(TBLineage.current(g, ru) == ussr, "its stage is the USSR")
	_check(g.gold[ru] < gold0 and is_equal_approx(mp0 - g.mp[ru], float(TBLineage.MP_COST)), "the proclamation was paid in gold and moves")
	_check(g.dp[ru] == dp0 + 3.0, "envoys +3 for a weight-3 stage")
	_check(g.claim[int(core[0])] == ru and g.claim[int(core[1])] == ru, "claims on the core the neighbour holds")
	_check(g.core[int(core[10])] == ru, "own core land is home land")
	_check(TBDiplo.cb(g, ru, neighbour) in ["claim", "reclaim"], "a casus belli against the holder (%s)" % TBDiplo.cb(g, ru, neighbour))
	_check(g.income(ru)["gold"] >= inc0, "the bonus does not cost income")
	_check(TBLineage.income_mul(g, ru) > 1.0 and TBLineage.stab_add(g, ru) == 3.0, "a lasting bonus (income x%.2f, stability +%d)" % [TBLineage.income_mul(g, ru), int(TBLineage.stab_add(g, ru))])
	var last: Dictionary = g.log[g.log.size() - 1]
	_check(String(last["kind"]) == "formed" and int(last["a"]) == ru, "the chronicle records it")
	var opts2: Array = TBLineage.options(g, ru); var ids2: Array = []
	for si in opts2: ids2.append(String(TBLineage.STAGES[si]["id"]))
	_check(ids2.has("russian_federation") and not ids2.has("russia"), "now the Federation is open and the old Russia is not (%s)" % str(ids2))
	# saves keep it
	var d := TBSave.snapshot(g)
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5, "rules": 5})
	TBSave.restore(g2, d)
	_check(g2.nat_code[ru] == "ussr" and g2.stage[ru] == ussr + 1 and g2.claim[int(core[0])] == ru, "a restored game keeps the new identity and the claims")
	# rules 4 knows nothing of it
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5, "rules": 4})
	_check(TBLineage.options(g4, g4.nat_code.find("russian_empire")).is_empty(), "rules 4: no lineages")
	# the AI forms when it can
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 5, "rules": 5})
	var pr := g3.nat_code.find("prussia"); g3.set_human(g3.nat_code.find("france")); g3.pending.clear()
	g3.year = 1880; g3.regime[pr] = 4; g3.gold[pr] = 1e9; g3.mp[pr] = 10.0
	var ge := TBLineage.index_of("german_empire")
	var gcore: Array = TBLineage.STAGES[ge]["core"]
	for i in gcore.size(): g3.set_owner(int(gcore[i]), pr)
	var tries := 0
	while g3.nat_code[pr] == "prussia" and tries < 8: g3.turn += 1; TBLineage.ai_step(g3, pr); tries += 1
	_check(g3.nat_code[pr] == "german_empire", "the AI proclaims the German Empire when it holds the land (%s)" % g3.nat_code[pr])
	print("LINEAGE ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
