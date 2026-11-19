extends SceneTree
## Estates: influence, loyalty drifting to a target, the gains and losses, courting, the AI, events, saves. Usage: -s tests/estates.gd (run with timeout)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	TBEstates.ensure()
	_check(TBEstates.IDS == ["nobility", "clergy", "merchants", "army"], "four estates")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 7, "rules": 5})
	var fr := g.nat_code.find("france"); g.set_human(fr); g.pending.clear()
	var sum := 0.0
	for e in 4: sum += TBEstates.share(g, fr, e)
	_check(absf(sum - 1.0) < 0.001, "shares add up to one (%f)" % sum)
	var ok_start := true
	for n in range(1, g.N1):
		if n == g.rebel: continue
		for e in 4: if TBEstates.loyalty(g, n, e) < 0.0 or TBEstates.loyalty(g, n, e) > 100.0: ok_start = false
	_check(ok_start, "loyalty starts inside 0..100")
	# governments differ: a monarchy leans on its nobles, a republic on its merchants
	var mon := -1; var rep := -1
	for n in range(1, g.N1):
		if n == g.rebel or g.alive[n] == 0: continue
		if String(TBData.REGIME_ID[g.regime[n]]) == "monarchy" and mon < 0: mon = n
		if String(TBData.REGIME_ID[g.regime[n]]) == "republic" and rep < 0: rep = n
	if mon > 0 and rep > 0:
		_check(TBEstates.share(g, mon, 0) > TBEstates.share(g, rep, 0), "a monarchy gives the nobility more weight than a republic")
		_check(TBEstates.share(g, rep, 2) > TBEstates.share(g, mon, 2), "a republic gives the merchants more weight than a monarchy")
	# institutions move the target
	var ind := TBInstitutions.index_of("industry")
	g.inst_ok[fr] &= ~(1 << ind)
	var nob0 := TBEstates.target(g, fr, 0); var mer0 := TBEstates.target(g, fr, 2)
	g.inst_ok[fr] |= (1 << ind)
	_check(TBEstates.target(g, fr, 0) < nob0 and TBEstates.target(g, fr, 2) > mer0, "embracing industry sours the nobles and pleases the merchants")
	# loyalty drifts toward its target
	g.est_loy[fr * 4 + 2] = 10.0
	var t := TBEstates.target(g, fr, 2)
	TBEstates.tick(g)
	var l1 := TBEstates.loyalty(g, fr, 2)
	_check(l1 > 10.0 and l1 < t, "loyalty moves toward the target (10 -> %.1f, target %.1f)" % [l1, t])
	# the gains and losses
	g.est_loy[fr * 4 + 2] = 100.0
	var inc_hi: float = g.income(fr)["gold"]
	g.est_loy[fr * 4 + 2] = 0.0
	var inc_lo: float = g.income(fr)["gold"]
	_check(inc_hi > inc_lo * 1.03, "loyal merchants pay more than angry ones (%d vs %d)" % [int(inc_hi), int(inc_lo)])
	g.est_loy[fr * 4 + 0] = 100.0; var lv_hi := TBEstates.levy_mul(g, fr); var st_hi := TBEstates.stab_add(g, fr)
	g.est_loy[fr * 4 + 0] = 0.0; var lv_lo := TBEstates.levy_mul(g, fr); var st_lo := TBEstates.stab_add(g, fr)
	_check(lv_hi > lv_lo and st_hi > st_lo, "loyal nobles raise levies and steady the land")
	g.est_loy[fr * 4 + 1] = 100.0; var rs_hi := TBEstates.research_mul(g, fr)
	g.est_loy[fr * 4 + 1] = 0.0; var rs_lo := TBEstates.research_mul(g, fr)
	_check(rs_hi < rs_lo, "a devout court studies less")
	var pt := TBTurn.stab_parts(g, fr, 0.0, false, 100, g.own_count(fr))
	_check(pt.has("estates"), "stability lists the estates")
	# courting
	for e in 4: g.est_loy[fr * 4 + e] = 50.0; g.est_priv[fr * 4 + e] = 0
	g.gold[fr] = 1e9; g.mp[fr] = 10.0
	var cf := TBEstates.can_court(g, fr, 0)
	_check(bool(cf["ok"]) and int(cf["gold"]) > 0, "courting the nobility is possible (%s)" % str(cf))
	var gold0: float = g.gold[fr]; var oth0 := TBEstates.target(g, fr, 1); var own0 := TBEstates.target(g, fr, 0)
	var r := g.apply({"cmd": "court", "n": fr, "e": 0})
	_check(bool(r.get("ok", false)), "apply accepts it (%s)" % str(r))
	_check(g.gold[fr] < gold0 and TBEstates.privileges(g, fr, 0) == 1 and TBEstates.loyalty(g, fr, 0) >= 60.0, "paid, privileged, content")
	_check(TBEstates.target(g, fr, 0) > own0 and TBEstates.target(g, fr, 1) < oth0, "the privilege lifts its estate's target and lowers the others'")
	var c2 := TBEstates.cost(g, fr, 0)
	_check(c2 > int(cf["gold"]), "the next privilege costs more")
	g.est_priv[fr * 4] = 3
	_check(String(TBEstates.can_court(g, fr, 0)["reason"]) == "est_max", "three privileges at most")
	g.gold[fr] = 0.0
	_check(String(TBEstates.can_court(g, fr, 1)["reason"]) == "gold", "refused without gold")
	# the AI courts its angriest estate
	var ai := -1
	for n in range(1, g.N1): if n != fr and n != g.rebel and g.alive[n] != 0 and g.human[n] == 0 and g.own_count(n) >= 4: ai = n; break
	g.est_loy[ai * 4 + 3] = 10.0; g.gold[ai] = 1e9; g.mp[ai] = 10.0
	TBEstates.ai_step(g, ai)
	_check(TBEstates.privileges(g, ai, 3) == 1, "the AI courts the army when it is angry")
	# events
	TBEvents._load()
	var by_id := {}
	for ev in TBEvents._random: by_id[String(ev["id"])] = ev
	for id in ["nobles_petition", "clergy_sermons", "merchants_demand", "officers_grumble"]:
		_check(by_id.has(id), "event %s exists" % id)
		var cond: Array = []
		for c in by_id[id]["cond"]: if not c.has("chance"): cond.append(c)
		var e: int = ["nobles_petition", "clergy_sermons", "merchants_demand", "officers_grumble"].find(id)
		g.est_loy[fr * 4 + e] = 60.0
		_check(not TBEvents._conds_ok(g, fr, cond), "%s: not while the estate is content" % id)
		g.est_loy[fr * 4 + e] = 20.0
		_check(TBEvents._conds_ok(g, fr, cond), "%s: when the estate is angry" % id)
		g.gold[fr] = 1e9
		TBEvents.apply_effects(g, fr, by_id[id]["choices"][0]["effects"])
		_check(TBEstates.loyalty(g, fr, e) > 30.0, "%s: the first choice appeases (%.0f)" % [id, TBEstates.loyalty(g, fr, e)])
	# saves
	var d := TBSave.snapshot(g)
	var g2 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 7, "rules": 5})
	TBSave.restore(g2, d)
	_check(g2.est_loy == g.est_loy and g2.est_priv == g.est_priv, "a restored game keeps loyalty and privileges")
	# some turns on: nothing leaves 0..100 and every nation keeps its four estates
	var gg := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 3, "rules": 5})
	gg.set_human(gg.nat_code.find("france")); gg.pending.clear()
	for i in 20: gg.end_turn()
	var span_ok := true; var angry := 0; var n_all := 0
	for n in range(1, gg.N1):
		if n == gg.rebel or gg.alive[n] == 0: continue
		for e in 4:
			var l := TBEstates.loyalty(gg, n, e)
			if l < 0.0 or l > 100.0: span_ok = false
			if l < TBEstates.LOW: angry += 1
			n_all += 1
	_check(span_ok, "loyalty stays in range for 20 turns")
	print("after 20 turns: ", angry, " of ", n_all, " estates below ", TBEstates.LOW)
	_check(angry < n_all / 2, "most estates are not in revolt (%d of %d)" % [angry, n_all])
	print("ESTATES OK" if fails == 0 else "ESTATES FAIL %d" % fails)
	quit(fails)
