extends SceneTree
## Token lint (art bible 8.1, review A-11): no raw colour literal in src/ui. A raw literal is `Color(` followed by a number, a string or 0x...
## (`Color("EFE3C6")`, `Color(0.5, 0.9, 0.55)`, `Color(1, 1, 1)`); derived colours (`Color(col.r, ...)`, `Color()`) and the named constants are fine.
## Allow-list: ui_tokens.gd (the token source) and flags.gd (nation flag colours are data). Run: godot --headless --path godot -s tests/ui_lint_tokens.gd
const ALLOW := ["ui_tokens.gd", "flags.gd"]

func _init() -> void:
	var re := RegEx.new()
	re.compile("Color\\(\\s*(-?[0-9.]|\"|'|0x)")
	var fails := 0
	var files := 0
	var d := DirAccess.open("res://src/ui")
	for f in d.get_files():
		if not f.ends_with(".gd") or f in ALLOW: continue
		files += 1
		var lines := FileAccess.get_file_as_string("res://src/ui/" + f).split("\n")
		for i in lines.size():
			var ln: String = lines[i]
			var code: String = ln.split("#")[0]                    # comments may mention Color(
			if re.search(code) != null:
				print("FAIL  src/ui/%s:%d  %s" % [f, i + 1, ln.strip_edges().substr(0, 110)]); fails += 1
	print("%d files scanned, %d raw colour literals" % [files, fails])
	print("UI LINT PASS" if fails == 0 else "UI LINT FAIL")
	quit(0 if fails == 0 else 1)
