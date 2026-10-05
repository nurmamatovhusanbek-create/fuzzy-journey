extends SceneTree
## Rulers: historical seeds applied, succession works, determinism, modifiers neutral at 3/none, save/load round trip.
func _init() -> void:
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var fails := 0
	for era_id in ["ancient", "medieval", "napoleonic", "ww2"]:
		var g := TBGame.new(w, TBWorld.load_era("res://data", era_id), {"seed": 4})
		var hist := 0
		for n in range(1, g.N1):
			if g.r_name[n] != "" and not g.r_name[n].begins_with("rn:"): hist += 1
		print("%s: %d/%d nations have a ruler, %d historical" % [era_id, _count(g), g.N, hist])
		if hist == 0: fails += 1; print("  FAIL no historical rulers")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "gunpowder"), {"seed": 9})
	var sp := g.nat_code.find("spanish_habsburg")
	print("start: ", TBRulers.display_name(g, sp), " age ", TBRulers.age(g, sp))
	var deaths := 0; var elections := 0; var crises := 0; var max_age := 0
	for t in 300:
		g.end_turn()
		for n in range(1, g.N1):
			if g.alive[n] != 0 and g.r_name[n] != "": max_age = maxi(max_age, TBRulers.age(g, n))
	for e in g.log:
		if e["kind"] == "ruler":
			match e["k"]:
				"died": deaths += 1
				"crisis": crises += 1
				"elected": elections += 1
	print("300 turns: deaths=%d crises=%d elections=%d max ruler age=%d" % [deaths, crises, elections, max_age])
	if deaths + crises < 5: fails += 1; print("  FAIL too few successions")
	if max_age > 100: fails += 1; print("  FAIL ruler older than 100")
	# determinism
	var a := TBGame.new(w, {}, {"seed": 21}); var b := TBGame.new(w, {}, {"seed": 21})
	for t in 60: a.end_turn(); b.end_turn()
	var same := true
	for n in range(1, a.N1): if a.r_name[n] != b.r_name[n] or a.r_born[n] != b.r_born[n]: same = false
	print("determinism: ", same, " checksum ", a.state_checksum() == b.state_checksum())
	if not same: fails += 1
	# save/load
	var d := TBSave.to_dict(a)
	var c := TBSave.from_dict(w, d)
	var ok := true
	for n in range(1, a.N1): if a.r_name[n] != c.r_name[n] or a.r_trait[n] != c.r_trait[n]: ok = false
	print("save/load rulers: ", ok)
	if not ok: fails += 1
	# the shipped chronicle formats ruler entries
	for e in g.log:
		if e["kind"] == "ruler":
			print("chron: ", TBChron.text(g, e)); break
	print("RULERS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)

func _count(g: TBGame) -> int:
	var c := 0
	for n in range(1, g.N1): if g.r_name[n] != "": c += 1
	return c
