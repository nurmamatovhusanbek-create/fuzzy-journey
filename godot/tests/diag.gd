extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, {}, {"seed": 11})
	for i in 150: g.end_turn()
	var rows: Array = []
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		var army := 0
		for p in g.owned(n): army += g.army[p]
		var inc := g.income(n)
		rows.append([g.gold[n], n, g.mp[n], g.manpower[n], army, g.own_count(n), inc["net"], inc["upkeep"], g.era[n], g.war_cnt[n]])
	rows.sort(); rows.reverse()
	for r in rows.slice(0, 8): print("gold=%d n=%d mp=%.1f man=%d army=%d lands=%d net=%d upkeep=%d era=%d wars=%d" % r)
	var rich := 0; var med: Array = []
	for r in rows: med.append(r[0]); if r[0] > 500: rich += 1
	med.sort()
	print("median gold ", med[med.size() / 2], " nations>500: ", rich, "/", rows.size())
	quit()
