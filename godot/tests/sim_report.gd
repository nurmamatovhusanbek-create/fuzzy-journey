extends SceneTree
# Balance report: godot --headless --path godot -s tests/sim_report.gd -- <seed> <turns> [era]
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var seed_v := int(a[0]) if a.size() > 0 else 11
	var turns := int(a[1]) if a.size() > 1 else 300
	var era_id := a[2] if a.size() > 2 else ""
	var w := TBWorld.load_from("res://data")
	var era := TBWorld.load_era("res://data", era_id) if era_id != "" else {}
	var g := TBGame.new(w, era, {"seed": seed_v})
	var wars_declared := 0; var peaces := 0
	for t in range(1, turns + 1):
		g.end_turn()
		if t % 50 == 0 or t == turns:
			var sizes: Array = []; var at_war := 0; var gold := 0.0; var alive := 0
			for n in range(1, g.N1):
				if g.alive[n] == 0 or n == g.rebel: continue
				alive += 1; sizes.append(g.own_count(n)); gold += g.gold[n]
				if g.war_cnt[n] > 0: at_war += 1
			sizes.sort(); sizes.reverse()
			var neutral := g.own_count(0)
			var wd := 0; var pc := 0
			for e in g.log:
				if e["kind"] == "war": wd += 1
				elif e["kind"] == "peace": pc += 1
			print("t=%3d alive=%d top=%s rebelProv=%d neutral=%d atWar=%d avgGold=%d wars=%d peaces=%d" % [t, alive, str(sizes.slice(0, 5)), g.own_count(g.rebel), neutral, at_war, int(gold / maxf(1, alive)), wd, pc])
	quit()
