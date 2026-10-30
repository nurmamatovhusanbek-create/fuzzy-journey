extends SceneTree
## A scripted human plays a campaign through the real interface path (commands as the buttons send them, End Turn on its worker thread, screens opened as the rail opens them)
## and writes down what it meets: errors, commands that fail and why, what the advisor nags about, idle resources, the pace of the economy. Read the output, not a pass/fail.
## Usage: -s tests/playtest.gd -- <era> <nation code or name fragment> <turns> <w> <h> <out dir> [seed]
## Run it with a fresh XDG_DATA_HOME (and TB_DPR=2.66 TB_DPI=425 for an S22): the game reads and writes user://settings.cfg, and a text size or layout left there by an earlier run changes every screenshot.
var main: Control
var g: TBGame
var me := 0
var fails := {}                      # "cmd:err" -> count
var oks := {}                        # cmd -> count
var mismatch: Array = []             # can() and apply() that disagreed
var series: Array = []
var notes: Array = []                # things worth a look
var idle := {"gold": 0, "mp": 0, "dp": 0, "men": 0}
var shots := 0
var out_dir := ""

func _frames(n: int) -> void:
	for i in n: await process_frame

func act(c: Dictionary) -> Dictionary:
	var w := TBAsks.wrap(g, c.duplicate()); w["n"] = me
	var pre: Dictionary = g.can(w) if String(w["cmd"]) in ["move", "recruit", "hire", "build", "develop", "settle", "embassy", "declareWar", "peace", "ally", "nap", "trade", "marry", "breakPact", "ultimatum", "demolish"] else {"ok": true}
	var res: Dictionary = g.apply(w)
	var key := String(w["cmd"])
	if bool(res["ok"]): oks[key] = int(oks.get(key, 0)) + 1
	else:
		var fk := "%s:%s" % [key, String(res.get("err", "?"))]
		fails[fk] = int(fails.get(fk, 0)) + 1
	if bool(pre["ok"]) != bool(res["ok"]) and mismatch.size() < 12 and key != "ask":
		mismatch.append("%s can=%s(%s) apply=%s(%s) %s" % [key, pre["ok"], pre.get("reason", ""), res["ok"], res.get("err", ""), str(w)])
	main._after_change()
	return res

func neighbours_of_realm() -> Array:
	var seen := {}
	for p in g.owned(me):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			if g.nb_sea[i] != 0: continue
			var o: int = g.controller(g.nb[i])
			if o != 0 and o != me and o != g.rebel: seen[o] = true
	return seen.keys()

func shot(tag: String) -> void:
	await _frames(6)
	var dlg := 0; var names := []
	for c in main._overlay.get_children():
		if c.has_meta("tb_handle") and not c.is_queued_for_deletion():
			dlg += 1; names.append(str((c.get_meta("tb_handle") as TBPanel.Handle).title_label.text if (c.get_meta("tb_handle") as TBPanel.Handle).title_label != null else "?"))
	print("PLAYTEST shot ", tag, ": dialogs open ", dlg, " ", names, " hud visible ", main.hud.visible, " busy ", main._busy, " pending ", g.pending.size())
	root.get_viewport().get_texture().get_image().save_png("%s/play_%s.png" % [out_dir, tag])
	shots += 1

func open_screens(turn: int) -> void:
	# every rail screen at this point of the game: any script error shows up in the run's stderr
	for id in ["nations", "budget", "decisions", "advisor", "chronicle", "goals"]:
		main._clear_overlay()
		main.hud._screen(id)
		await _frames(8)
	var o: Array = neighbours_of_realm()
	if not o.is_empty():
		main._open_nations(int(o[0]))
		await _frames(8)
		if turn == 40: await shot("nations_t%d" % turn)
	main._clear_overlay()
	main._open_dossier(g.capital_of[me]) if main.has_method("_open_dossier") else null
	await _frames(6)
	main._clear_overlay()

func play_turn(t: int) -> void:
	# ---- events and offers
	for e in g.pending.duplicate():
		if int(e["n"]) != me: continue
		var pick := 0
		if String(e["kind"]) == "prop" and String(e.get("id", "")) == "ultimatum": pick = 1
		act({"cmd": "eventChoice", "uid": e["uid"], "i": pick})
	var inc: Dictionary = g.income(me)
	# ---- budget: a deficit raises taxes, a fat purse lowers them
	var tax: int = g.budget[me * 4]
	if float(inc["net"]) < 0.0 and tax < 70: act({"cmd": "budget", "key": "tax", "val": tax + 10})
	# ---- building and development
	var best := -1; var bsc := -1.0
	for p in g.owned(me):
		if g.occupier[p] != 0 or g.b_building[p] != 0: continue
		var sc: float = g.pop[p] + 20.0 * g.dev[p] + (100.0 if g.capital[p] != 0 else 0.0) - 25.0 * g.b_used(p)
		if sc > bsc: bsc = sc; best = p
	if best >= 0 and g.gold[me] > 150.0:
		for b in [TBData.B_FARM, TBData.B_MARKET, TBData.B_WORKSHOP, TBData.B_LIBRARY, TBData.B_PORT, TBData.B_FORTRESS, TBData.B_WATCHTOWER]:
			var cn := g.can({"cmd": "build", "n": me, "p": best, "b": b})
			if bool(cn["ok"]): act({"cmd": "build", "p": best, "b": b}); break
	if g.gold[me] > 350.0 and g.mp[me] >= 1.0:
		var dp := -1; var bf := 0.0
		for p in g.owned(me):
			if g.dev[p] >= 5: continue
			var fill: float = g.job_fill(p, g.dev[p] + 1)
			if fill >= 0.6 and fill > bf: bf = fill; dp = p
		if dp >= 0: act({"cmd": "develop", "p": dp})
	if g.manpower[me] >= 200.0 and g.mp[me] >= 1.0:                      # idle people go back to the land, where it is least settled
		var sv := -1; var sl := 100
		for p in g.owned(me):
			if g.occupier[p] == 0 and g.stab[p] < sl: sl = g.stab[p]; sv = p
		if sv >= 0 and sl < 95: act({"cmd": "settle", "p": sv})
	if g.dp[me] >= 6.0 and g.gold[me] >= 80.0:                           # idle envoys mend the worst grudge
		var wo := 0; var wg := 0
		for o in range(1, g.N1):
			if o != me and g.alive[o] != 0 and g.grudge[o * g.N1 + me] > wg and g.get_rel(me, o) != 1: wg = g.grudge[o * g.N1 + me]; wo = o
		if wo > 0: act({"cmd": "embassy", "t": wo})
	if t % 6 == 0:
		for d in TBDecisions.LIST:
			if g.gold[me] > 250.0 and g.mp[me] >= 2.0 and bool(g.can({"cmd": "decide", "n": me, "id": d["id"]}).get("ok", false)):
				act({"cmd": "decide", "id": d["id"]}); break
	# ---- diplomacy: pacts with neighbours, trade with the best partners
	var near: Array = neighbours_of_realm()
	if t % 2 == 0:
		for o in near:
			var rel: int = g.get_rel(me, o)
			if TBAsks.pending(g, me, o): continue
			if rel == TBData.REL_PEACE and g.grudge[o * g.N1 + me] < 15 and g.dp[me] >= 2.0: act({"cmd": "nap", "t": o}); break
			elif rel == TBData.REL_NAP and g.dp[me] >= 3.0 and g.grudge[o * g.N1 + me] < 15: act({"cmd": "ally", "t": o}); break
	if t % 3 == 1 and g.trade_cnt[me] < TBTrade.max_deals(g, me):
		var cands: Array = []
		for o in range(1, g.N1):
			if o == me or g.alive[o] == 0 or o == g.rebel or g.get_rel(me, o) == TBData.REL_WAR or TBTrade.has(g, me, o): continue
			if g.own_count(o) < 4 or TBAsks.pending(g, me, o): continue
			cands.append([TBTrade.yield_of(g, me, o), o])
		cands.sort_custom(func(a, b): return a[0] > b[0])
		for c in cands.slice(0, 2): act({"cmd": "trade", "t": c[1]})
	# ---- war and peace
	var enemies: Array = []
	for o in range(1, g.N1):
		if g.alive[o] != 0 and g.get_rel(me, o) == TBData.REL_WAR: enemies.append(o)
	if enemies.is_empty() and t >= 25 and t % 10 == 5 and g.dp[me] >= 3.0 and not near.is_empty():
		var weak := -1; var wp := 1.0e9
		for o in near:
			if g.friendly(me, o) or g.has_truce(me, o): continue
			var pw: float = TBDiplo.power(g, o)
			if pw < wp: wp = pw; weak = o
		if weak > 0 and TBDiplo.power(g, me) > wp * 1.6: act({"cmd": "declareWar", "t": weak})
	for o in enemies:
		var ws: int = g.war_score[me * g.N1 + o]
		if ws >= 25 and g.dp[me] >= 1.0: act({"cmd": "peace", "t": o, "kind": "cede"})
		elif g.war_turns[me * g.N1 + o] > 16 and g.dp[me] >= 1.0: act({"cmd": "peace", "t": o, "kind": "white"})
	# ---- armies: recruit while at war or thin, attack where the preview wins
	var army_total := 0
	for p in g.owned(me): army_total += g.army[p]
	if (not enemies.is_empty() or army_total < 12 * g.own_count(me)) and g.gold[me] > 120.0 and g.manpower[me] > 40.0:
		act({"cmd": "recruit", "p": g.capital_of[me] if g.capital_of[me] >= 0 else g.owned(me)[0], "amount": 20})
	if not enemies.is_empty():
		var moves := 0
		for p in g.owned(me):
			if g.army[p] < 6 or g.controller(p) != me or moves >= 6 or g.mp[me] < 1.0: continue
			for i in range(g.nb_off[p], g.nb_off[p + 1]):
				var q: int = g.nb[i]
				var c: int = g.controller(q)
				if c != 0 and c != me and enemies.has(g.owner[q]):
					var pv := g.combat_preview(me, p, q, 0)
					if bool(pv["win"]):
						act({"cmd": "move", "from": p, "to": q}); moves += 1
					break
	# ---- idle resources (what a player would feel as 'nothing to do')
	if g.gold[me] > 900.0: idle["gold"] += 1
	if g.mp[me] >= 6.0: idle["mp"] += 1
	if g.dp[me] >= 8.0: idle["dp"] += 1
	if g.manpower[me] > g.income(me)["manCap"] * 0.9: idle["men"] += 1

func record(t: int) -> void:
	var inc := g.income(me)
	var stab := 0.0; var happy := 0.0
	for p in g.owned(me): stab += g.stab[p]; happy += g.happy[p]
	var n := maxf(1.0, float(g.own_count(me)))
	var allies := 0; var wars := 0
	for o in range(1, g.N1):
		if o == me or g.alive[o] == 0: continue
		var r := g.get_rel(me, o)
		if r == TBData.REL_ALLY: allies += 1
		if r == TBData.REL_WAR: wars += 1
	var army := 0
	for p in g.owned(me): army += g.army[p]
	var alerts: Array = TBAdvisor.alerts(g, me)
	var aid: PackedStringArray = []
	for a in alerts: aid.append(String(a["id"]))
	series.append({"t": t, "year": g.year, "prov": g.own_count(me), "gold": int(g.gold[me]), "net": int(inc["net"]), "gross": int(inc["gold"]), "men": int(g.manpower[me]), "army": army,
		"stab": int(stab / n), "happy": int(happy / n), "tech": snappedf(g.tech_level[me], 0.01), "allies": allies, "wars": wars, "deals": g.trade_cnt[me], "infamy": int(g.infamy[me]),
		"dp": snappedf(g.dp[me], 0.1), "mp": snappedf(g.mp[me], 0.1), "alerts": ",".join(aid), "world_y": int(g.world_y)})

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var era: String = a[0]; var who: String = a[1]; var turns := int(a[2]); var w := int(a[3]); var h := int(a[4]); out_dir = a[5]
	var seed_v: int = int(a[6]) if a.size() > 6 else 1
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	main = load("res://src/ui/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.cfg["lang"] = "en"; TBI18n.load_lang("en"); main.cfg["seal_seen"] = true; main.cfg["tutorial"] = true; main.cfg["fx"] = "off"; main.cfg["quality"] = "medium"
	main._apply_quality(); main._update_ui_scale()
	main._begin_pick(era, "normal")
	g = main.g
	for n in range(1, g.N1):
		if g.alive[n] != 0 and (String(g.nat_code[n]) == who or g.nat_name[n].to_lower().contains(who.to_lower())): me = n; break
	if me == 0: print("PLAYTEST no such nation"); quit(1); return
	main._start_game(me)
	g = main.g
	g.pending.clear(); main._clear_overlay(); main._select(-1)
	main.hud.set_seal_pulse(false)
	await _frames(200)                                                            # the start-up dive settles
	print("PLAYTEST start: ", g.dname(me), " ", era, " provinces ", g.own_count(me), " gold ", int(g.gold[me]), " rules ", g.rules)
	await shot("t001")
	var t0 := Time.get_ticks_msec()
	var slow := 0
	for t in range(1, turns + 1):
		if g.over: print("PLAYTEST game over at turn ", t, " kind ", g.victory_kind, " winner ", g.dname(g.winner) if g.winner > 0 else "-"); break
		if g.alive[me] == 0: print("PLAYTEST defeated at turn ", t); break
		play_turn(t)
		if t % 10 == 0 or t == 1: record(t)
		if t in [10, 40, 80]: await open_screens(t)
		if t in [25, 60, 100]: await shot("t%03d" % t)
		var ts := Time.get_ticks_msec()
		main.end_turn()
		var guard := 0
		while main._busy and guard < 600: await create_timer(0.05).timeout; guard += 1
		var dt := Time.get_ticks_msec() - ts
		if dt > 1500: slow += 1
		await _frames(2)
	await shot("end")
	record(g.turn)
	print("PLAYTEST SERIES")
	for s in series: print("  ", JSON.stringify(s))
	print("PLAYTEST COMMANDS OK ", JSON.stringify(oks))
	var fk: Array = fails.keys(); fk.sort_custom(func(x, y): return int(fails[x]) > int(fails[y]))
	print("PLAYTEST COMMANDS FAILED")
	for k in fk.slice(0, 25): print("  ", k, " x", fails[k])
	print("PLAYTEST can/apply mismatches: ", mismatch.size())
	for m in mismatch: print("  ", m)
	print("PLAYTEST idle turns: ", JSON.stringify(idle), " slow turns (>1.5 s): ", slow, " total s ", (Time.get_ticks_msec() - t0) / 1000)
	var kinds := {}
	for e in g.log: kinds[e["kind"]] = int(kinds.get(e["kind"], 0)) + 1
	print("PLAYTEST log kinds: ", JSON.stringify(kinds))
	print("PLAYTEST victory progress: ", JSON.stringify(TBTurn.victory_progress(g, me)))
	print("PLAYTEST done")
	quit()
