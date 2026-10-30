extends SceneTree
## Looks over the start of every era for things that cannot be right: a nation without a capital (or with one it does not own), no ruler, an empty or repeated name, one nation holding most of the map,
## wars and alliances at the start, a tech level that does not fit the year. Prints a table and "ERA AUDIT OK" or the list of findings.
var findings := PackedStringArray()
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	print("%-11s %5s %5s %6s %6s %5s %5s %-120s %s" % ["era", "year", "nats", "owned", "neutr", "solo", "wars", "largest three (provinces)", "tech min/avg/max"])
	for id in ["ancient", "roman", "medieval", "mongol", "timurid", "discovery", "gunpowder", "napoleonic", "victorian", "ww1", "ww2", "coldwar"]:
		var era: Dictionary = TBWorld.load_era("res://data", id)
		var g := TBGame.new(w, era, {"seed": 1})
		var alive := 0; var solo := 0; var owned := 0; var wars := 0; var allies := 0
		var sizes: Array = []
		var tmin := 99.0; var tmax := -1.0; var tsum := 0.0
		var names := {}
		for n in range(1, g.N1):
			if g.alive[n] == 0 or n == g.rebel: continue
			var c := g.own_count(n)
			if c == 0: findings.append("%s: %s is alive with no province" % [id, g.dname(n)]); continue
			alive += 1; owned += c
			if c == 1: solo += 1
			sizes.append([c, g.dname(n)])
			var nm := g.dname(n)
			if nm.strip_edges() == "": findings.append("%s: nation %d has no name" % [id, n])
			elif names.has(nm): findings.append("%s: the name %s is used twice" % [id, nm])
			names[nm] = true
			var cap: int = g.capital_of[n]
			if cap < 0: findings.append("%s: %s has no capital" % [id, nm])
			elif g.owner[cap] != n: findings.append("%s: the capital of %s belongs to someone else" % [id, nm])
			if g.rules >= 1 and g.r_name[n] == "": findings.append("%s: %s has no ruler" % [id, nm])
			var t: float = g.tech_level[n]; tmin = minf(tmin, t); tmax = maxf(tmax, t); tsum += t
			for o in range(n + 1, g.N1):
				if g.get_rel(n, o) == TBData.REL_WAR: wars += 1
				elif g.get_rel(n, o) == TBData.REL_ALLY: allies += 1
		sizes.sort_custom(func(a, b): return a[0] > b[0])
		var top := ""
		for i in mini(6, sizes.size()): top += "%s %d, " % [sizes[i][1], sizes[i][0]]
		print("%-11s %5d %5d %6d %6d %5d %5d %-120s %.1f/%.1f/%.1f  allies %d" % [id, int(era.get("year", 0)), alive, owned, g.own_count(0), solo, wars, top.substr(0, 120), tmin, tsum / maxf(1.0, alive), tmax, allies])
		if sizes.size() > 0 and float(sizes[0][0]) > 0.30 * float(owned): findings.append("%s: %s holds %d%% of the owned land at the start" % [id, sizes[0][1], int(100.0 * float(sizes[0][0]) / float(owned))])
		if alive < 30: findings.append("%s: only %d nations at the start" % [id, alive])
		if solo > alive / 2: findings.append("%s: %d of %d nations have a single province" % [id, solo, alive])
	if findings.is_empty(): print("ERA AUDIT OK")
	else:
		for f in findings: print("FINDING: ", f)
		print("ERA AUDIT: %d findings" % findings.size())
	quit(findings.size())
