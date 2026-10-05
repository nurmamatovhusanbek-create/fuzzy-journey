extends SceneTree
## Scheduled historical events: data integrity (EN+RU, valid ops) and that they fire in play for every era.
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var fails := 0
	var total := 0; var with_choices := 0
	for era_id in ["ancient", "roman", "medieval", "mongol", "timurid", "discovery", "gunpowder", "napoleonic", "victorian", "ww1", "ww2", "coldwar", "modern"]:
		var evs := TBEvents.scheduled_for(era_id)
		for e in evs:
			total += 1
			for k in ["title", "flavor"]:
				if String(e[k].get("en", "")) == "" or String(e[k].get("ru", "")) == "": print("MISSING text ", e["id"], " ", k); fails += 1
			for c in e.get("choices", []):
				with_choices += 1
				if String(c["label"].get("en", "")) == "" or String(c["label"].get("ru", "")) == "": print("MISSING label ", e["id"]); fails += 1
				for fx in c["effects"]:
					if not String(fx["op"]).begins_with("nation."): print("BAD op ", e["id"], fx); fails += 1
				if TBModals.fx_text(c["effects"]) == "" and c["effects"].size() > 0: print("fx_text empty ", e["id"]); fails += 1
		# play it: a human nation that has an event + 60 turns
		var g := TBGame.new(w, TBWorld.load_era("res://data", era_id) if era_id != "modern" else {}, {"seed": 5})
		var n := 1
		for k in range(1, g.N1):
			if k != g.rebel and g.alive[k] != 0 and g.own_count(k) > 10: n = k; break
		g.set_human(n)
		var fired := 0; var prompts := 0; var applied := 0
		for t in 100:
			g.end_turn()
			for p in g.pending.duplicate():
				prompts += 1
				var r := g.apply({"cmd": "eventChoice", "n": p["n"], "uid": p["uid"], "i": 0})
				if r["ok"]: applied += 1
		for e in g.log: if e["kind"] == "event": fired += 1
		print("%-10s %2d events defined | fired in 100 turns: %2d | human prompts %2d (applied %d)" % [era_id, evs.size(), fired, prompts, applied])
		if fired == 0: fails += 1
	print("total %d events, %d with choices" % [total, with_choices])
	print("HIST_EVENTS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
