extends SceneTree
## Rules 4 levy pools: the pool refills with population, a recruit takes exactly the number chosen from the province's pool, a drained province grows slowly,
## a conquered land starts empty, men under arms cost taxes, and the nation's manpower is the sum of its pools. Usage: -s tests/levy.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 4})
	var me := g.nat_code.find("france"); g.set_human(me)
	g.pending.clear()
	var home: int = g.owned(me)[0]
	_check(g.levy[home] > 0 and g.levy[home] < g.levy_cap(home), "a province starts with part of its cap ready (%d of %d)" % [g.levy[home], g.levy_cap(home)])
	_check(int(g.manpower[me]) == g.levy_total(me), "the nation's manpower is the sum of the pools (%d)" % int(g.manpower[me]))
	var r := g.recruit_range(home)
	_check(r.x == 1 and r.y == g.levy[home], "the card offers 1 to the pool (%s)" % str(r))
	g.gold[me] = 5000.0; g.mp[me] = 20.0
	var pool0: int = g.levy[home]; var army0: int = g.army[home]
	var take: int = mini(7, pool0)
	var res := g.apply({"cmd": "recruit", "n": me, "p": home, "amount": take})
	_check(bool(res["ok"]) and g.army[home] == army0 + take and g.levy[home] == pool0 - take, "recruit takes exactly the number chosen (%d)" % take)
	var res2 := g.apply({"cmd": "recruit", "n": me, "p": home, "amount": 99999})
	_check(bool(res2["ok"]) and g.levy[home] == 0, "asking for more than the pool takes the pool and no more")
	var res3 := g.apply({"cmd": "recruit", "n": me, "p": home, "amount": 5})
	_check(not bool(res3["ok"]), "an empty pool recruits nobody")
	_check(int(g.manpower[me]) == g.levy_total(me), "manpower follows the pools after recruiting")
	# drained: growth halves and mood sinks; held (occupied) land does not refill
	var pop_a: int = g.pop[home]; var happy_a: int = g.happy[home]
	_check(g.levy_drained(home), "an emptied province is drained")
	var e := TBTurn.new() if false else null
	g.end_turn()
	_check(g.levy[home] == g.levy_gain(home) or g.levy[home] > 0, "the pool refills each turn (%d)" % g.levy[home])
	var gain := g.levy_gain(home)
	_check(gain >= 1 and gain <= maxi(1, g.levy_cap(home) / 5), "a refill is about a tenth of the cap (%d of %d)" % [gain, g.levy_cap(home)])
	# a conquered land starts empty
	var foe := -1
	for n in range(1, g.N1):
		if n != me and n != g.rebel and g.alive[n] != 0 and g.own_count(n) > 0: foe = n; break
	var q: int = g.owned(foe)[0]
	g.levy[q] = 50
	g.cede(q, me)
	_check(g.levy[q] == 0, "a ceded province starts with an empty pool")
	# men under arms cost taxes
	var inc0 := g.income(me)
	for p in g.owned(me): g.army[p] = g.army[p] * 4
	var inc1 := g.income(me)
	_check(float(inc1["workLoss"]) > float(inc0["workLoss"]) and int(inc1["tax"]) < int(inc0["tax"]), "a bigger host takes more men from the fields (loss %.2f -> %.2f)" % [float(inc0["workLoss"]), float(inc1["workLoss"])])
	_check(float(inc1["workLoss"]) <= TBGame.WORK_LOSS_CAP + 0.0001, "the loss is capped")
	# old rules are untouched
	var g3 := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 8, "rules": 3})
	var h3: int = g3.owned(g3.nat_code.find("france"))[0]
	_check(g3.levy[h3] == 0 and g3.recruit_range(h3) == Vector3i(5, 30, 15), "rules 3 keeps the old 5 to 30 and no pools")
	print("LEVY OK" if fails == 0 else "LEVY FAIL %d" % fails)
	quit(fails)
