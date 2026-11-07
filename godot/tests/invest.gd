extends SceneTree
## Rules 4 investment: the budget fills a progress bar in each province (same speed on average as the old die), a level is gained when it is full, returns shrink as economy runs past what the
## people can work, development waits for workers, a hand-made development restarts the bar, and rules < 4 keep the die. Usage: -s tests/invest.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var me := g.nat_code.find("france"); g.set_human(me); g.pending.clear()
	var p: int = g.owned(me)[0]
	g.pop[p] = 400; g.econ[p] = 1; g.dev[p] = 1; g.inv_e[p] = 0.0; g.inv_d[p] = 0.0
	_check(TBInvest.econ_eff(g, p) == 1.0, "within its people the efficiency is 1")
	# progress accumulates and a level is gained when the bar fills
	var e0: int = g.econ[p]
	var steps := 0
	while g.econ[p] == e0 and steps < 5000: TBInvest.step(g, p, 0.05, 5); steps += 1
	print("steps for one economy level at rate 0.05: ", steps)
	_check(steps >= 19 and steps <= 21, "20 turns at 0.05 a turn fill the bar (%d)" % steps)
	_check(g.inv_e[p] < 0.2, "the bar restarts after the level (%.2f)" % g.inv_e[p])
	# half way: progress shows
	g.inv_e[p] = 0.5
	_check(absf(float(TBInvest.progress(g, p)["econ"]) - 0.5) < 0.001, "the player sees the progress (0.5)")
	# returns shrink past the potential
	g.pop[p] = 70; g.econ[p] = 4
	var pot := TBInvest.econ_potential(g, p)
	var eff := TBInvest.econ_eff(g, p)
	print("potential %.2f, econ 4 -> efficiency %.2f" % [pot, eff])
	_check(pot <= 2.01 and eff < 0.3, "a small people with a big economy: money buys little (%.2f)" % eff)
	g.econ[p] = 5; g.inv_e[p] = 0.4
	TBInvest.step(g, p, 0.05, 5)
	_check(g.inv_e[p] == 0.0, "a full economy keeps no bar")
	# development waits for workers
	g.pop[p] = 20; g.dev[p] = 3; g.inv_d[p] = 0.0
	var wait := TBInvest.dev_eff(g, p, 5)
	print("dev eff with few people: ", wait)
	_check(wait == 0.0 or g.rules < 2, "no workers, no development progress (%.1f)" % wait)
	# a hand-made development restarts the slow bar
	g.pop[p] = 600; g.dev[p] = 1; g.inv_d[p] = 0.7; g.gold[me] = 5000.0; g.mp[me] = 10.0; g.tech_level[me] = 3.0
	var r := g.apply({"cmd": "develop", "n": me, "p": p, "k": 1})
	if bool(r["ok"]):
		if g.rules >= 4: for i in 4: TBTurn.end_turn(g)                              # a project: the level arrives when the work ends
		_check(g.inv_d[p] < 0.2, "after the hand-made level the slow bar starts again (%.2f)" % g.inv_d[p])
	# a save keeps the bars
	g.inv_e[p] = 0.37
	var d: Dictionary = TBSave.to_dict(g)
	var g2: TBGame = TBSave.from_dict(w, d)
	_check(g2 != null and absf(g2.inv_e[p] - 0.37) < 0.001, "a save keeps the progress")
	# the old rules keep the die
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	_check(g3.inv_e.size() == g3.P, "the arrays exist everywhere (empty)")
	print("INVEST OK" if fails == 0 else "INVEST FAIL %d" % fails)
	quit(fails)
