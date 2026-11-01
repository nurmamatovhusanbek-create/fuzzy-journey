extends SceneTree
## Rules 4 diplomacy has a logic: a court deals with countries it knows of (a neighbour, one inside its sphere, one it already has ties with), proposes only what fits (an alliance needs a shared
## concern), and a pact asked of a far court is weighed down by the distance. Usage: -s tests/diplo_logic.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "discovery"), {"seed": 8, "rules": 4})
	var me := g.nat_code.find("timurid_emirates"); g.set_human(me); g.pending.clear()
	var far := g.nat_code.find("beothuk")
	_check(me > 0 and far > 0, "the two nations exist (%d, %d)" % [me, far])
	print("distance Timurids-Beothuk %.2f, sphere %.2f / %.2f" % [TBDiplo.capital_dist(g, me, far), TBDiplo.sphere(g, me), TBDiplo.sphere(g, far)])
	_check(TBDiplo.contact(g, me, far) == "none", "a country across the world is not in contact (%s)" % TBDiplo.contact(g, me, far))
	_check(TBDiplo.offer_fit(g, far, me, "nap") == 0.0 and TBDiplo.offer_fit(g, far, me, "ally") == 0.0, "so it never offers a pact or an alliance")
	var nb := -1
	for p in g.owned(me):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var o: int = g.owner[g.nb[i]]
			if o > 0 and o != me and o != g.rebel: nb = o; break
		if nb > 0: break
	_check(nb > 0 and TBDiplo.contact(g, me, nb) == "border", "a neighbour is in contact (border)")
	_check(TBDiplo.offer_fit(g, nb, me, "nap") == 1.0, "and a neighbour's pact is the likeliest offer")
	# a pact asked of the far court is weighed down
	var v_far := TBDipView.pact(g, far, me, TBData.REL_ALLY)
	var has_far := false
	for tm in v_far["terms"]: if String(tm[0]) == "dv_far": has_far = true
	_check(has_far and int(roundf(TBDipView.meter(v_far))) < 25, "an alliance asked of a far court shows the distance and a low chance (%d %%)" % int(roundf(TBDipView.meter(v_far))))
	# a long run of offers to the human: every one comes from a court in contact, and alliances only with a concern in common
	var seen := 0; var bad := 0; var bad_ally := 0
	for k in 3000:
		g.pending.clear(); g.offer_cd.fill(-99)
		TBDiplo.offers_turn(g)
		for e in g.pending:
			if String(e["kind"]) != "prop" or not ["nap", "ally", "trade", "marry"].has(String(e["id"])): continue
			seen += 1
			var from: int = int(e["from"])
			if TBDiplo.contact(g, from, me) == "none": bad += 1
			if String(e["id"]) == "ally" and not TBDiplo.shared_concern(g, from, me) and TBDiplo.contact(g, from, me) != "border": bad_ally += 1
	print("offers seen %d, out of contact %d, alliances without a concern %d" % [seen, bad, bad_ally])
	_check(seen >= 5, "the courts do write to the player (%d offers)" % seen)
	_check(bad == 0, "no offer comes from a court out of contact (%d)" % bad)
	_check(bad_ally == 0, "no alliance is offered from afar without a concern in common (%d)" % bad_ally)
	# what the player asks of a court with no contact is refused outright, with the reason (commands and previews)
	g.dp[me] = 20.0; g.mp[me] = 20.0; g.gold[me] = 5000.0
	for k in ["nap", "ally", "marry", "trade"]:
		var rr := g.apply({"cmd": k, "n": me, "t": far})
		_check(not bool(rr["ok"]) and String(rr.get("err", "")) == "nocontact", "%s to a court with no contact: refused as nocontact (%s)" % [k, str(rr.get("err", "ok"))])
		var pv := g.can({"cmd": k, "n": me, "t": far})
		_check(not bool(pv["ok"]) and String(pv.get("reason", "")) == "nocontact", "the preview says so for %s (%s)" % [k, str(pv.get("reason", ""))])
	# a royal marriage needs a near court: a far one in the sphere is refused as toofar
	var far_in := -1
	for o in range(1, g.N1):
		if o != me and g.alive[o] != 0 and o != g.rebel and TBDiplo.contact(g, me, o) == "far" and TBDiplo.can_marry_ignoring_distance(g, me, o): far_in = o; break
	if far_in > 0:
		var rm := g.apply({"cmd": "marry", "n": me, "t": far_in})
		_check(not bool(rm["ok"]) and String(rm.get("err", "")) == "toofar", "a marriage with a far court in the sphere is refused as toofar (%s)" % str(rm.get("err", "ok")))
	# the old rules are untouched
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "discovery"), {"seed": 8, "rules": 3})
	var m3 := g3.nat_code.find("timurid_emirates"); g3.set_human(m3)
	var terms3: Array = TBDiplo.pact_terms(g3, g3.nat_code.find("beothuk"), m3, TBData.REL_ALLY)
	var far3 := false
	for tm in terms3: if String(tm[0]) == "dv_far": far3 = true
	_check(not far3, "rules 3 has no distance term")
	print("DIPLO_LOGIC OK" if fails == 0 else "DIPLO_LOGIC FAIL %d" % fails)
	quit(fails)
