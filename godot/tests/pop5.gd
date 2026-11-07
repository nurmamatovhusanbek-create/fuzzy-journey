extends SceneTree
## Rules 5 people: every era starts from the real data at its scale (jittered), growth follows technology under a ceiling, a save keeps the scale. Usage: -s tests/pop5.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var eras := ["ancient", "roman", "medieval", "mongol", "timurid", "discovery", "gunpowder", "napoleonic", "victorian", "ww1", "ww2", "coldwar", "modern"]
	var sums := {}
	for e in eras:
		var pack := TBWorld.load_era("res://data", e) if e != "modern" else {}
		var g := TBGame.new(w, pack, {"seed": 7, "difficulty": "normal", "rules": 5})
		var tot := 0.0; var real := 0.0
		for p in g.P: tot += float(g.pop[p]); real += TBPopData.real(e, p)
		var want: float = real / float(g.scale)
		print("%-10s scale %2d:1 world %8.2f M game people (data %8.2f M)  real %7.1f M" % [e, g.scale, tot / 1e6, want / 1e6, tot * g.scale / 1e6])
		_check(g.scale == TBPopData.scale_for(e), "%s scale" % e)
		_check(absf(tot - want) / want < 0.05, "%s: the jitter averages out (%.1f%% off)" % [e, 100.0 * (tot - want) / want])
		sums[e] = tot
		# two games of the same era never hold the same figures
		if e == "ww1":
			var g2 := TBGame.new(w, pack, {"seed": 8, "difficulty": "normal", "rules": 5})
			var same := 0
			for p in g.P: if g.pop[p] == g2.pop[p]: same += 1
			_check(same < g.P / 20, "ww1 twice: different figures (%d of %d equal)" % [same, g.P])
	_check(float(sums["ww1"]) * 30.0 < float(sums["modern"]) * 30.0 * 0.3, "1914 holds a fraction of today's people")
	# growth: 100 turns of an AI-only Napoleonic world
	var pack := TBWorld.load_era("res://data", "napoleonic")
	var g := TBGame.new(w, pack, {"seed": 3, "difficulty": "normal", "rules": 5})
	var p0 := 0.0; for p in g.P: p0 += float(g.pop[p])
	var over := 0
	for t in 100: g.end_turn()
	var p1 := 0.0
	for p in g.P:
		p1 += float(g.pop[p])
		if g.pop[p] > g.pop_cap(p) * 1.3: over += 1
	print("napoleonic 100 turns (50 years): %.2f M -> %.2f M game people (%+.1f%%), %d provinces far above their ceiling" % [p0 / 1e6, p1 / 1e6, 100.0 * (p1 - p0) / p0, over])
	_check(p1 > p0 * 1.15 and p1 < p0 * 1.6, "50 years of growth (natural growth plus the AI's settlements) stay plausible")
	# a save keeps the scale and the rules
	var ok_save: bool = TBSave.save(g, "pop5test")
	var g3: TBGame = TBSave.load_game(w, "pop5test")
	_check(g3 != null and g3.rules == 5 and g3.scale == 20 and g3.pop[100] == g.pop[100], "save and load keep rules 5, the scale and the people")
	print("POP5 OK" if fails == 0 else "POP5 FAIL %d" % fails)
	quit(fails)
