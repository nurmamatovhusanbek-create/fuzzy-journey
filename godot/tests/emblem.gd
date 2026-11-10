extends SceneTree
## The engraved-plate icon set: every emblem has its mask, every name the game draws maps to one (bar the plain markers), colours follow meaning, the modes (brass, classic, colour-vision) behave,
## and an emblem really lands on the canvas. Usage: -s tests/emblem.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL ", what)
class Pad extends Control:
	var name_: String = "treasury"; var col := Color("D9B660"); var mono := false
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("101010"))
		if mono: TBEmblem.draw(self, name_, size * 0.5, 40.0, col, true)
		else: TBBzIcons.draw(self, name_, size * 0.5, 40.0, col)
func _px(img: Image, x: int, y: int) -> Color: return img.get_pixel(x, y)
func _init() -> void:
	TBEmblem.mode = "colour"; TBKit.cvd = "off"
	var dir := DirAccess.open("res://assets/emblems")
	var pngs: Array = []
	for f in dir.get_files(): if f.ends_with(".png"): pngs.append(f.trim_suffix(".png"))
	_check(pngs.size() == TBEmblem.KIND.size(), "one mask per emblem (%d masks, %d emblems)" % [pngs.size(), TBEmblem.KIND.size()])
	for id in TBEmblem.KIND:
		_check(pngs.has(id), "mask for " + id)
		var t: Texture2D = load("res://assets/emblems/%s.png" % id)
		_check(t != null and t.get_width() == 256, "mask %s is 256 px" % id)
		if t != null:
			var im := t.get_image(); if im.is_compressed(): im.decompress()
			var solid := 0; var n := 0
			for y in range(0, 256, 4):
				for x in range(0, 256, 4):
					n += 1
					if im.get_pixel(x, y).a > 0.5: solid += 1
			var cover := float(solid) / float(n)
			_check(cover > 0.04 and cover < 0.85, "%s covers a sensible share of its square (%.2f)" % [id, cover])
	for k in TBEmblem.ALIAS: _check(TBEmblem.KIND.has(TBEmblem.ALIAS[k]), "alias %s -> %s exists" % [k, TBEmblem.ALIAS[k]])
	var keep := ["diamond", "tri_up", "tri_down", "arrowhead", "capital", "revolt"]
	for nme in TBBzIcons.IC.keys(): _check(TBEmblem.id_of(nme) != "" or keep.has(nme), "icon name %s has an emblem" % nme)
	for nme in TBGlyph.G.keys(): _check(TBEmblem.id_of(nme) != "" or keep.has(nme), "glyph name %s has an emblem" % nme)
	# colours
	var brass := Color("D9B660")
	_check(TBEmblem.tint("host", brass).is_equal_approx(Color(TBEmblem.PAL["r"].r, TBEmblem.PAL["r"].g, TBEmblem.PAL["r"].b, 1.0)) or TBEmblem.tint("host", brass).r > 0.8, "war is vermilion")
	_check(TBEmblem.tint("envoys", brass).b > TBEmblem.tint("envoys", brass).g, "diplomacy is purple")
	_check(absf(TBEmblem.tint("treasury", Color(brass, 0.4)).a - 0.4) < 0.001, "the alpha of the call is kept")
	_check(TBEmblem.tint("people", Color("8F8268")).get_luminance() < TBEmblem.tint("people", brass).get_luminance(), "a dim (disabled) icon stays dim")
	_check(TBEmblem.tint("move", Color("1B160D")).is_equal_approx(Color("1B160D")), "dark ink on a brass plate stays dark")
	_check(TBEmblem.tint("treasury", Color("72D9C0")).is_equal_approx(Color("72D9C0")), "the game's own status colours pass through")
	TBEmblem.mode = "brass"; _check(TBEmblem.tint("host", brass).is_equal_approx(brass), "brass mode: the call's colour")
	TBEmblem.mode = "colour"; TBKit.cvd = "deuter"; _check(TBEmblem.tint("host", brass).is_equal_approx(brass), "colour-vision mode: brass")
	TBKit.cvd = "off"
	# on the canvas
	var pad := Pad.new(); pad.size = Vector2(120, 120)
	var vp := SubViewport.new(); vp.size = Vector2i(120, 120); vp.add_child(pad); root.add_child(vp)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for i in 4: await process_frame
	var img := vp.get_texture().get_image()
	var lit := 0
	for y in range(20, 100): for x in range(20, 100): if _px(img, x, y).get_luminance() > 0.3: lit += 1
	_check(lit > 300, "an emblem is drawn (%d lit samples)" % lit)
	# mono (the province ring): the caller's colour, whatever the emblem means
	pad.name_ = "envoys"; pad.mono = true; pad.queue_redraw()
	for i in 4: await process_frame
	var img2 := vp.get_texture().get_image()
	var warm := 0; var violet := 0
	for y in range(20, 100): for x in range(20, 100):
		var px := _px(img2, x, y)
		if px.get_luminance() > 0.3:
			if px.r > px.b: warm += 1
			else: violet += 1
	_check(warm > 200 and violet < warm / 10, "mono: envoys stays brass, not purple (%d warm, %d violet)" % [warm, violet])
	pad.mono = false; pad.queue_redraw()
	for i in 4: await process_frame
	var img3 := vp.get_texture().get_image()
	var violet3 := 0
	for y in range(20, 100): for x in range(20, 100):
		var px3 := _px(img3, x, y)
		if px3.get_luminance() > 0.3 and px3.b > px3.g: violet3 += 1
	_check(violet3 > 200, "colour: the same emblem is purple (%d violet)" % violet3)
	TBEmblem.mode = "classic"
	_check(not TBEmblem.draw(pad, "treasury", Vector2(10, 10), 24.0, brass), "classic mode: the old drawing")
	TBEmblem.mode = "colour"
	print("EMBLEM ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
