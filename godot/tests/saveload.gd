extends SceneTree
# Save/load round trip must continue bit-identically (proves every state field is serialized).
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var failed := 0
	for cfg in [["", 3], ["roman", 5], ["ww2", 9]]:
		var era := TBWorld.load_era("res://data", cfg[0]) if cfg[0] != "" else {}
		var g := TBGame.new(w, era, {"seed": cfg[1]})
		var hp := 0
		for p in g.P: if g.owner[p] != 0: hp = p; break
		g.set_human(g.owner[hp])
		for i in 25:
			g.end_turn()
			for e in g.pending.duplicate(): g.apply({"cmd": "eventChoice", "n": e["n"], "uid": e["uid"], "i": 0})
		g.apply({"cmd": "recruit", "n": g.human_id, "p": g.owned(g.human_id)[0], "amount": 15})
		TBSave.save(g, "test")
		var h := TBSave.load_game(w, "test")
		var ok := h != null and h.state_checksum() == g.state_checksum()
		for i in 25:
			g.end_turn(); h.end_turn()
			for e in g.pending.duplicate(): g.apply({"cmd": "eventChoice", "n": e["n"], "uid": e["uid"], "i": 0})
			for e in h.pending.duplicate(): h.apply({"cmd": "eventChoice", "n": e["n"], "uid": e["uid"], "i": 0})
			if g.state_checksum() != h.state_checksum():
				ok = false; print("  diverged at +", i + 1); break
		print("%-8s roundtrip %s (turn %d, rng %d/%d)" % [cfg[0] if cfg[0] != "" else "modern", "OK" if ok else "FAIL", g.turn, g.rng.s, h.rng.s])
		if not ok: failed += 1
	TBSave.delete("test")
	quit(failed)
