extends SceneTree
## Every icon name a window asks for (ring icons, panel headers, glyphs, empty states) resolves to an emblem or a glyph: no plain circle stands in for a missing drawing. Usage: -s tests/ui_icon_names.gd
func _init() -> void:
	var em := FileAccess.get_file_as_string("res://src/ui/emblem.gd")
	var known := {}
	for m in RegEx.create_from_string('"([a-z_0-9]+)":\\s*"[a-z_0-9]+"').search_all(em): known[m.get_string(1)] = true
	var gl := FileAccess.get_file_as_string("res://src/ui/glyphs.gd")
	for m in RegEx.create_from_string('(?m)^\\t"([a-z_0-9]+)":\\s*\\[').search_all(gl): known[m.get_string(1)] = true
	var pats := ['ring_icon\\(\\s*"([a-z_0-9]+)"', 'K\\.glyph\\(\\s*"([a-z_0-9]+)"', 'TBBzIcons\\.draw\\([^,]+,\\s*"([a-z_0-9]+)"', 'empty_state\\(\\s*"([a-z_0-9]+)"', 'TBPanel\\.open\\([^\\n]*?,\\s*"([a-z_0-9]+)",\\s*\\{']
	var bad := {}
	var d := DirAccess.open("res://src/ui")
	for f in d.get_files():
		if not f.ends_with(".gd"): continue
		var s := FileAccess.get_file_as_string("res://src/ui/" + f)
		for pat in pats:
			for m in RegEx.create_from_string(pat).search_all(s):
				if not known.has(m.get_string(1)): bad["%s in %s" % [m.get_string(1), f]] = true
	for k in bad: print("FAIL: no drawing for icon ", k)
	print("UI_ICON_NAMES ", "OK (%d names known)" % known.size() if bad.is_empty() else "FAIL")
	quit(0 if bad.is_empty() else 1)
