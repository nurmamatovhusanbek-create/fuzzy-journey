extends SceneTree
## Saves made by release 1.0.0 (rules 2, turn 41; tests/fixtures/save_v100_*.tbs) still load with the current code and play on for 100 turns without NaN, dead nations owning land or a failed round trip.
## Usage: -s tests/old_saves.gd   (prints OLD_SAVES OK)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var bad := 0
	for era in ["ancient", "napoleonic", "modern"]:
		var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/save_v100_%s.tbs" % era)
		if bytes.is_empty(): print("OLD_SAVES FAIL missing fixture ", era); bad += 1; continue
		var slot: String = "fxv100" + era
		var f := FileAccess.open(TBSave.path_for(slot), FileAccess.WRITE); f.store_buffer(bytes); f.close()
		var g: TBGame = TBSave.load_game(w, slot)
		if g == null: print("OLD_SAVES FAIL load ", era); bad += 1; continue
		if g.rules != 2 or g.turn != 41: print("OLD_SAVES FAIL unexpected rules/turn ", era, " ", g.rules, " ", g.turn); bad += 1
		for t in 100:
			g.end_turn()
			for pe in g.pending:                                                          # events added after the save was made must not fire years late
				if String(pe.get("kind", "")) != "sched": continue
				for ev in TBEvents.scheduled_for(g.era_id):
					if ev["id"] == pe["id"] and g.year - int(ev["trigger"]["year"]) >= 3: print("OLD_SAVES FAIL stale event ", pe["id"], " in year ", g.year); bad += 1
			g.pending.clear()
		var issues := ""
		for n in range(1, g.N1):
			if is_nan(g.gold[n]) or is_inf(g.gold[n]) or is_nan(g.tech_level[n]): issues += " nan:%d" % n
			if g.alive[n] == 0 and g.own_count(n) > 0 and n != g.rebel: issues += " deadowns:%d" % n
		var rt: String = "rt" + slot
		if not TBSave.save(g, rt): issues += " save"
		var g2: TBGame = TBSave.load_game(w, rt)
		if g2 == null or g2.turn != g.turn or g2.rules != g.rules: issues += " roundtrip"
		DirAccess.remove_absolute(TBSave.path_for(slot)); DirAccess.remove_absolute(TBSave.path_for(rt))
		print("old save %-10s turn %d%s" % [era, g.turn, issues if issues != "" else " ok"])
		if issues != "": bad += 1
	print("OLD_SAVES ", "OK" if bad == 0 else "FAIL")
	quit(1 if bad > 0 else 0)
