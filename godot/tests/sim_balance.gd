extends SceneTree
## Balance probe: an all-AI game from an era's start, one JSON line per run.
##   godot --headless --path godot -s tests/sim_balance.gd -- <era|modern> <seed> <turns> [difficulty]
## Reports who wins and when, how concentrated power gets, wars / peaces, gold and army inflation, rebels, neutral land, runtime, and any engine invariant that breaks.
func _inv(g: TBGame, bad: Dictionary) -> void:
	for p in g.P:
		if g.army[p] < 0 or g.army[p] > 65000: bad["army"] = int(bad.get("army", 0)) + 1
		if g.stab[p] > 100 or g.happy[p] > 100: bad["stab_happy"] = int(bad.get("stab_happy", 0)) + 1
		if g.owner[p] < 0 or g.owner[p] >= g.N1: bad["owner"] = int(bad.get("owner", 0)) + 1
	for n in range(1, g.N1):
		if is_nan(g.gold[n]) or is_inf(g.gold[n]): bad["gold_nan"] = int(bad.get("gold_nan", 0)) + 1
		if g.gold[n] < 0.0: bad["gold_neg"] = int(bad.get("gold_neg", 0)) + 1
		if g.manpower[n] < 0.0 or is_nan(g.manpower[n]): bad["manpower"] = int(bad.get("manpower", 0)) + 1
		if g.infamy[n] < 0.0 or g.infamy[n] > 100.0: bad["infamy"] = int(bad.get("infamy", 0)) + 1
		if g.alive[n] != 0 and g.r_name[n] == "" and n != g.rebel: bad["no_ruler"] = int(bad.get("no_ruler", 0)) + 1
		if g.alive[n] == 0 and g.own_count(n) > 0: bad["dead_owns"] = int(bad.get("dead_owns", 0)) + 1

func _init() -> void:
	TBI18n.load_lang("en")
	var a := OS.get_cmdline_user_args()
	var era_id: String = a[0] if a.size() > 0 else "napoleonic"
	var seed_v: int = int(a[1]) if a.size() > 1 else 1
	var turns: int = int(a[2]) if a.size() > 2 else 200
	var diff: String = a[3] if a.size() > 3 else "normal"
	var w := TBWorld.load_from("res://data")
	var era := TBWorld.load_era("res://data", era_id) if era_id != "modern" else {}
	var t0 := Time.get_ticks_msec()
	var g := TBGame.new(w, era, {"seed": seed_v, "difficulty": diff})
	var alive0 := 0
	for n in range(1, g.N1):
		if g.alive[n] != 0 and n != g.rebel: alive0 += 1
	var bad := {}
	var series: Array = []
	var end_t := 0
	var first_win := {}                       # victory id -> [turn, nation] the first time any nation would have met it (AIs do not trigger victory themselves)
	var best := {}                            # victory id -> best progress ever seen
	for t in range(1, turns + 1):
		g.end_turn()
		end_t = t
		if t % 10 == 0:
			_inv(g, bad)
			if g.rules >= 1:
				for n in range(1, g.N1):
					if g.alive[n] == 0 or n == g.rebel: continue
					var pr: Dictionary = TBTurn.victory_progress(g, n)
					for id in TBTurn.VICTORY_IDS:
						var v: float = float(pr[id])
						if id == "technological" and g.tech_level[n] < 5.0: v = minf(v, 0.99)
						best[id] = maxf(float(best.get(id, 0.0)), v)
						if v >= 1.0 and not first_win.has(id): first_win[id] = [t, g.dname(n)]
		if t % 25 == 0 or t == turns or g.over:
			var sizes: Array = []; var gold_sum := 0.0; var gold_max := 0.0; var army_sum := 0; var alive := 0; var at_war := 0
			for n in range(1, g.N1):
				if g.alive[n] == 0 or n == g.rebel: continue
				alive += 1; sizes.append(g.own_count(n)); gold_sum += g.gold[n]; gold_max = maxf(gold_max, g.gold[n])
				if g.war_cnt[n] > 0: at_war += 1
			for p in g.P: army_sum += g.army[p]
			sizes.sort(); sizes.reverse()
			var owned := 0.0; var hhi := 0.0
			for s in sizes: owned += float(s)
			for s in sizes: hhi += pow(float(s) / maxf(1.0, owned), 2.0)
			series.append({"t": t, "alive": alive, "top": sizes.slice(0, 3), "hhi": snappedf(hhi, 0.001), "war": at_war, "gold_avg": int(gold_sum / maxf(1.0, alive)), "gold_max": int(gold_max), "army": army_sum, "rebel": g.own_count(g.rebel), "neutral": g.own_count(0)})
		if g.over: break
	_inv(g, bad)
	var wars := 0; var peaces := 0; var conq := 0
	for e in g.log:
		match String(e["kind"]):
			"war": wars += 1
			"peace": peaces += 1
			"occupied": conq += 1
	var out := {"era": era_id, "seed": seed_v, "diff": diff, "turns": end_t, "over": g.over, "winner": g.dname(g.winner) if g.winner > 0 else "", "kind": g.victory_kind, "alive0": alive0,
		"series": series, "first_win": first_win, "best": best, "wars": wars, "peaces": peaces, "occupied": conq, "ms": Time.get_ticks_msec() - t0, "bad": bad}
	print("SIM ", JSON.stringify(out))
	quit(0)
