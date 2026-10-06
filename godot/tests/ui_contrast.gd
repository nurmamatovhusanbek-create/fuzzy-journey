extends SceneTree
## Contrast gate for the interface tokens (art bible 4.2-4.5 and 4.7, A11Y-CON-001/002/005): every registered fg/bg pair of
## TBTokens.PAIRS is measured (WCAG 2.x) for NORMAL and HIGH-CONTRAST against its stated minimum. Prints PASS/FAIL, exits 1 on failure.
## Run: godot --headless --path godot -s tests/ui_contrast.gd

func _init() -> void:
	var fails := 0
	var checked := 0
	for it in TBTokens.PAIRS:
		var fg: String = it[0]; var bg: String = it[1]; var role: String = it[4]
		for variant in 2:
			var d: Dictionary = TBTokens.NORMAL if variant == 0 else TBTokens.HC
			var minimum: float = it[2] if variant == 0 else it[3]
			var ratio: float = TBTokens.contrast(d[fg], d[bg])
			checked += 1
			var ok: bool = ratio >= minimum
			if not ok: fails += 1
			print("%s  %-6s %-12s on %-12s %6.2f >= %.1f   %s" % ["PASS" if ok else "FAIL", "NORMAL" if variant == 0 else "HC", fg, bg, ratio, minimum, role])
	# every token must exist in both dictionaries (HC may not silently miss a key)
	for k in TBTokens.NORMAL:
		if not TBTokens.HC.has(k): print("FAIL  HC dictionary lacks token ", k); fails += 1
	for k in TBTokens.HC:
		if not TBTokens.NORMAL.has(k): print("FAIL  NORMAL dictionary lacks token ", k); fails += 1
	# the pair table itself must only name real tokens
	for it in TBTokens.PAIRS:
		for i in 2:
			if not TBTokens.NORMAL.has(it[i]): print("FAIL  unknown token in PAIRS: ", it[i]); fails += 1
	print("%d pairs checked, %d failures" % [checked, fails])
	print("UI CONTRAST PASS" if fails == 0 else "UI CONTRAST FAIL")
	quit(0 if fails == 0 else 1)
