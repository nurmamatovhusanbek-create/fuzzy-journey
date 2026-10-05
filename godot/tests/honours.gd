extends SceneTree
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var fails := 0
	TBI18n.load_lang("en")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 8})
	var a := g.nat_code.find("france"); g.set_human(a)
	var cfg := {"honours": {}}
	for it in TBHonours.LIST:
		for k in ["honour_" + it[0], "honour_" + it[0] + "_d"]:
			if not TBI18n.has_key(k): print("missing ", k); fails += 1
	for lang in ["en", "ru", "uz"]:
		TBI18n.load_lang(lang)
		for id in TBModals.CODEX:
			for k in ["codex_%s_t" % id, "codex_%s_b" % id]:
				if not TBI18n.has_key(k): print("missing ", lang, " ", k); fails += 1
		for it in TBHonours.LIST:
			if not TBI18n.has_key("honour_" + it[0]): print("missing ", lang, " honour_", it[0]); fails += 1
	TBI18n.load_lang("en")
	var fresh := TBHonours.record(g, cfg, TBHonours.on_state(g))
	print("turn 0 earned: ", fresh)
	g.gold[a] = 6000
	fresh = TBHonours.record(g, cfg, TBHonours.on_state(g))
	if not "treasure" in fresh: fails += 1
	if TBHonours.record(g, cfg, TBHonours.on_state(g)).size() != 0: fails += 1     # never twice
	var e := {"kind": "occupied", "a": a, "b": 3, "p": 1}
	if not "first_blood" in TBHonours.on_log(g, e): fails += 1
	for t in 150:
		g.end_turn()
		for en in g.log: TBHonours.record(g, cfg, TBHonours.on_log(g, en))
		TBHonours.record(g, cfg, TBHonours.on_state(g))
	print("after 150 turns: ", cfg["honours"].keys())
	if not cfg["honours"].has("veteran"): fails += 1
	print("HONOURS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
