extends SceneTree
## Capitals stand where the nations' historical capitals were (rules >= 1); every era's nations, how many the table covers.
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var fails := 0
	var want := {"napoleonic": {"france": "Île-de-France", "uk": "London", "spain": "Madrid", "prussia": "Berlin", "russian_empire": "Saint"}}
	for era_id in ["napoleonic", "victorian", "ww1", "ww2", "coldwar", "gunpowder", "medieval"]:
		var era := TBWorld.load_era("res://data", era_id)
		var g := TBGame.new(w, era, {"seed": 3})
		var known := 0; var total := 0; var missing := PackedStringArray()
		for n in range(1, g.N1):
			if g.alive[n] == 0: continue
			total += 1
			if TBCapitals.pick(g, n) >= 0: known += 1
			elif missing.size() < 8: missing.append(g.nat_code[n])
		print(era_id, ": ", known, " of ", total, " capitals from the table; e.g. fallback: ", missing)
		if era_id == "napoleonic":
			for nm in ["france", "uk", "spain", "prussia", "russian_empire", "ottoman_empire", "austrian_empire"]:
				var n: int = g.nat_code.find(nm)
				var cp: int = g.capital_of[n]
				print("  ", nm, " -> ", w.name[cp] if cp >= 0 else "none", " (", snappedf(w.lon[cp], 0.1) if cp >= 0 else 0, ",", snappedf(w.lat[cp], 0.1) if cp >= 0 else 0, ")")
				if cp < 0: fails += 1
	print("CAPITALS ", "OK" if fails == 0 else "FAIL")
	quit(1 if fails > 0 else 0)
