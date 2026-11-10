extends SceneTree
## diagnostic: every icon the game draws, big, on the table colour. Usage: -s tests/icon_sheet.gd -- <out png>
class Sheet extends Control:
	var names: Array = []
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0d0f14"))
		var f: Font = ThemeDB.fallback_font
		var cols := 12; var cw := size.x / cols; var ch := 100.0
		for i in names.size():
			var n: Array = names[i]
			var c := Vector2((i % cols) * cw + cw * 0.5, int(i / cols) * ch + 38.0)
			if n[0] == "bz": TBBzIcons.draw(self, n[1], c, 48.0, Color("d9b660"), 1.7)
			else: TBGlyph.draw(self, n[1], c, 40.0, Color("d9b660"))
			draw_string(f, c + Vector2(-cw * 0.5, 46.0), n[1], HORIZONTAL_ALIGNMENT_CENTER, cw, 11, Color("9a9484"))
func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var names: Array = []
	for k in TBBzIcons.IC.keys(): names.append(["bz", k])
	for k in TBGlyph.G.keys(): if not TBBzIcons.IC.has(k): names.append(["gl", k])
	var rows := int(ceil(names.size() / 12.0))
	var w := 1500; var h := rows * 100 + 20
	DisplayServer.window_set_size(Vector2i(w, h)); root.size = Vector2i(w, h)
	var sh := Sheet.new(); sh.names = names; sh.size = Vector2(w, h); root.add_child(sh)
	for i in 6: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("ICON_SHEET ", names.size())
	quit(0)
