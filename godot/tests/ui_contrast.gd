extends SceneTree
## Contrast gate for the interface tokens (art bible 4.2-4.5 and 4.7, A11Y-CON-001/002/005): every registered fg/bg pair of
## TBTokens.PAIRS is measured (WCAG 2.x) for NORMAL, HIGH-CONTRAST LIGHT and HIGH-CONTRAST DARK against its stated minimum
## (the HC column applies to both high-contrast variants). Prints PASS/FAIL, exits 1 on failure.
## Run: godot --headless --path godot -s tests/ui_contrast.gd

func _init() -> void:
	var fails := 0
	var checked := 0
	for it in TBTokens.PAIRS:
		var fg: String = it[0]; var bg: String = it[1]; var role: String = it[4]
		for variant in 3:
			var d: Dictionary = TBTokens.dict(variant)
			var minimum: float = it[2] if variant == 0 else it[3]
			var ratio: float = TBTokens.contrast(d[fg], d[bg])
			checked += 1
			var ok: bool = ratio >= minimum
			if not ok: fails += 1
			print("%s  %-6s %-12s on %-12s %6.2f >= %.1f   %s" % ["PASS" if ok else "FAIL", ["NORMAL", "HC", "HCDARK"][variant], fg, bg, ratio, minimum, role])
	# every token must exist in both dictionaries (HC may not silently miss a key)
	for v in [1, 2]:
		for k in TBTokens.atlas():
			if not TBTokens.dict(v).has(k): print("FAIL  %s dictionary lacks token %s" % [["", "HC", "HC_DARK"][v], k]); fails += 1
		for k in TBTokens.dict(v):
			if not TBTokens.atlas().has(k): print("FAIL  NORMAL dictionary lacks token ", k); fails += 1
	# greyscale hierarchy (art review A-1): the primary slab must differ from the secondary control by luminance, not hue alone
	for v in 3:
		var dd: Dictionary = TBTokens.dict(v)
		var gap: float = TBTokens.contrast(dd["act"], dd["paper_1"])
		var okg: bool = gap >= 3.0
		if not okg: fails += 1
		print("%s  %-6s primary vs secondary control luminance %.2f >= 3.0" % ["PASS" if okg else "FAIL", ["NORMAL", "HC", "HCDARK"][v], gap])
	# the pair table itself must only name real tokens
	for it in TBTokens.PAIRS:
		for i in 2:
			if not TBTokens.atlas().has(it[i]): print("FAIL  unknown token in PAIRS: ", it[i]); fails += 1
	print("%d pairs checked, %d failures" % [checked, fails])
	print("UI CONTRAST PASS" if fails == 0 else "UI CONTRAST FAIL")
	quit(0 if fails == 0 else 1)
