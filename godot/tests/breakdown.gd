extends SceneTree
## The sums behind the numbers: the stability tooltip lists exactly the terms the engine adds, the people tooltip the factors of the growth. Usage: -s tests/breakdown.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 5})
	var n: int = g.nat_code.find("france")
	var p: int = g.capital_of[n]
	var reg: Dictionary = TBData.REGIMES[g.regime[n]]
	var weary: float = TBWar.weary(g, n)
	var pt := TBTurn.stab_parts(g, n, weary, g.at_war(n), int(reg["stabCeil"]), g.own_count(n))
	var sum := 0.0
	for k in pt: sum += float(pt[k])
	_check(is_equal_approx(clampf(sum, 10.0, float(reg["stabCeil"])), TBTurn.stab_target(g, n, weary, g.at_war(n), int(reg["stabCeil"]), g.own_count(n))), "the listed terms add up to the engine's target")
	var s := TBBreakdown.stability(g, p)
	print(s)
	_check(s.contains("Government ceiling") and s.contains("drifting toward"), "the stability tooltip names the ceiling and the target")
	g.budget[n * 4] = 80
	var s2 := TBBreakdown.stability(g, p)
	_check(s2.contains("Taxes (80%)"), "a high tax rate shows as a term")
	var t := TBBreakdown.people(g, p)
	print(t)
	_check(t.contains("real") and t.contains("Room left") and t.contains("Change this turn"), "the people tooltip shows the scale, the room and the change")
	var gp := TBTurn.growth_parts(g, p)
	var by_hand := int(round(float(g.pop[p]) * float(gp["year_rate"]) * 0.5 * float(gp["mood"]) * float(gp["order"]) * float(gp["farm"]) * float(gp["room"])))
	_check(by_hand == int(gp["growth"]), "the listed factors multiply to the growth")
	var g4 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 4, "difficulty": "normal", "rules": 4})
	_check(TBBreakdown.people(g4, 10).begins_with("Population:"), "rules 4 keeps its plain tooltip")
	print("BREAKDOWN OK" if fails == 0 else "BREAKDOWN FAIL %d" % fails)
	quit(fails)
