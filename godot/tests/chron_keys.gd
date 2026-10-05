extends SceneTree
## Every log kind renders to real text (no raw i18n keys leak) in EN and RU; advisor alerts too.
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var fails := 0
	var kinds := {}
	for era in ["", "medieval", "ww1"]:
		var g := TBGame.new(w, TBWorld.load_era("res://data", era) if era != "" else {}, {"seed": 2})
		var h := 0
		for k in range(1, g.N1): if k != g.rebel and g.own_count(k) >= 10: h = k; break
		g.set_human(h)
		g.dp[h] = 30; g.gold[h] = 3000
		for t in 120:
			if g.alive[h] != 0 and t % 4 == 0:
				for o in range(1, g.N1):
					if o != h and g.alive[o] != 0 and o != g.rebel: g.apply({"cmd": "trade", "n": h, "t": o}); g.apply({"cmd": "marry", "n": h, "t": o}); break
			g.end_turn()
			for e in g.pending.duplicate(): g.apply({"cmd": "eventChoice", "n": h, "uid": e["uid"], "i": 0})
		for lang in ["en", "ru", "uz"]:
			TBI18n.load_lang(lang)
			for e in g.log:
				kinds[e["kind"]] = true
				var tx := TBChron.text(g, e)
				if tx.begins_with("e_") or tx.begins_with("al_") or tx.begins_with("ev_") or tx.begins_with("cb_") or tx.contains(" e_") :
					print("LEAK ", lang, " ", e["kind"], " -> ", tx); fails += 1
			for a in TBAdvisor.alerts(g, h):
				var tx2: String = TBI18n.T("al_" + String(a["id"]))
				if tx2 == "al_" + String(a["id"]): print("MISSING alert text ", a["id"]); fails += 1
	print("log kinds seen: ", kinds.keys())
	print("CHRON_KEYS ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(1 if fails > 0 else 0)
