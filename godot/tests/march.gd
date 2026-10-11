extends SceneTree
## Marching to any reachable province (TBMarch) and the fog of war (TBVision).
const D = preload("res://src/engine/data.gd")
var fails := 0
func _ck(c: bool, m: String) -> void:
	if not c: fails += 1; print("FAIL: ", m)

func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var era := TBWorld.load_era("res://data", "napoleonic")
	var g := TBGame.new(w, era, {"seed": 3})
	var n: int = g.nat_code.find("france")
	g.set_human(n)
	g.mp[n] = 12.0
	# find a held province with an army and a held province two or three steps away
	var src := -1; var far := -1
	for p in g.owned(n):
		if g.army[p] > 10: src = p; break
	var r := TBMarch.reach(g, n, src, 12.0)
	for q in r:
		if r[q].size() == 2 and int(r[q][0]) >= 3 and g.controller(q) == n: far = q; break
	print("src ", src, " far ", far, " reach size ", r.size())
	_ck(src >= 0 and far >= 0, "an army and a far held province exist")
	var adj := g.sea_edge(src, far)
	_ck(adj < 0, "the far province is not a neighbour")
	var pl := TBMarch.plan(g, n, src, far)
	print("plan ", pl)
	_ck(bool(pl["ok"]) and String(pl["kind"]) == "move" and float(pl["mp"]) >= 3.0 and (pl["path"] as PackedInt32Array).size() >= 4, "a march over our own land is planned (mp %.0f, %d steps)" % [float(pl["mp"]), (pl["path"] as PackedInt32Array).size()])
	# the real command moves the men at once and charges the points
	var a0 := g.army[src]; var f0 := g.army[far]; var mp0 := g.mp[n]
	var rr := g.apply({"cmd": "move", "n": n, "from": src, "to": far, "troops": a0 - 1})
	print("apply ", rr)
	_ck(bool(rr["ok"]) and g.army[far] == f0 + a0 - 1 and g.army[src] == 1, "the whole army arrives (%d -> %d)" % [f0, g.army[far]])
	_ck(absf((mp0 - g.mp[n]) - float(pl["mp"])) < 0.01, "the cost is the path's move points")
	# a march costing more than the turn allows is refused
	g.mp[n] = 1.0
	var back := g.apply({"cmd": "move", "n": n, "from": far, "to": src, "troops": 0})
	_ck(not bool(back["ok"]) and String(back["err"]) == "mp", "too few move points: refused (%s)" % str(back))
	# can() agrees with apply()
	g.mp[n] = 12.0
	var cn := g.can({"cmd": "move", "n": n, "from": far, "to": src, "troops": 0})
	_ck(bool(cn["ok"]) and int(cn["moves"]) == int(ceil(float(TBMarch.plan(g, n, far, src)["mp"]))), "can() reports the march's points")
	# an enemy province two steps beyond our border: a march ends in an attack, costing one point more at the end
	var foe := -1; var from2 := -1
	for p in g.owned(n):
		if g.army[p] < 3: continue
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			if g.nb_sea[i] == 0 and g.controller(q) != n and g.owner[q] != 0: foe = q; from2 = p; break
		if foe >= 0: break
	if foe >= 0:
		var o: int = g.owner[foe]
		g.set_rel(n, o, D.REL_WAR)
		var pl2 := TBMarch.plan(g, n, from2, foe)
		_ck(bool(pl2["ok"]) and String(pl2["kind"]) == "attack" and float(pl2["mp"]) == float(D.MP_ATTACK), "a neighbour attack still costs %d" % D.MP_ATTACK)
	# rules 0 never marches
	var g0 := TBGame.new(w, era, {"seed": 3, "rules": 0}); g0.set_human(n); g0.mp[n] = 12.0
	_ck(not bool(TBMarch.plan(g0, n, src, far)["ok"]), "rules 0: no marches")
	# ---- vision
	var gv := TBGame.new(w, era, {"seed": 3})
	gv.set_human(n)
	var foreign := -1; var near_p := -1; var deep_p := -1
	TBVision.sync(gv)
	for p in gv.P:
		var o2: int = gv.owner[p]
		if o2 == 0 or o2 == n or gv.army[p] <= 0 or gv.friendly(n, o2): continue
		if TBVision.nation_seen(gv, n, o2): continue
		if TBVision.sees_fast(gv, p):
			if near_p < 0: near_p = p
		elif deep_p < 0: deep_p = p
	print("near ", near_p, " deep ", deep_p)
	_ck(near_p >= 0 and deep_p >= 0, "some foreign armies are in view (next to our land), some are not")
	# a spy report shows a whole nation for a while
	var od: int = gv.owner[deep_p]
	gv.see_until[n * gv.N1 + od] = gv.turn + TBVision.SPY_TURNS
	TBVision.sync(gv)
	_ck(TBVision.sees_fast(gv, deep_p), "a spy report shows its armies")
	gv.see_until[n * gv.N1 + od] = 0
	# an ally is always in view
	gv.set_rel(n, od, D.REL_ALLY)
	_ck(TBVision.sees(gv, deep_p), "an ally's armies are in view")
	gv.set_rel(n, od, D.REL_PEACE)
	_ck(not TBVision.sees(gv, deep_p), "…and hidden again when the treaty ends")
	# a watchtower widens the sight
	var mine_far := -1
	var dd := 0
	for p in gv.owned(n):
		dd += 1
		if gv.building[p] == 0 and dd > 3: mine_far = p
	var seen_before := 0
	for p in gv.P: seen_before += 1 if TBVision.sees_fast(gv, p) else 0
	gv.building[mine_far] = D.B_WATCHTOWER
	TBVision.sync(gv)
	var seen_after := 0
	for p in gv.P: seen_after += 1 if TBVision.sees_fast(gv, p) else 0
	_ck(seen_after > seen_before, "a watchtower widens the sight (%d -> %d provinces)" % [seen_before, seen_after])
	# spies write the report
	gv.intel[n] = 30.0
	var t0 := od
	gv.set_rel(n, t0, D.REL_PEACE)
	var got := false
	for k in 40:
		gv.intel[n] = 30.0
		var rs := gv.apply({"cmd": "spy", "n": n, "t": t0, "op": "steal"})
		if bool(rs.get("success", false)): got = true; break
	_ck(got and gv.see_until[n * gv.N1 + t0] > gv.turn, "a successful spy operation opens a report")
	print("MARCH ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
