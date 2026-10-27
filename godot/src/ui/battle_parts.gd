## Battle report parts (Path B4, docs/screens/popup_mocks/sheet_B_battle_treaty_summary_glyphs.png): both armies face to face with bars that drain from "before" to "after" and the
## losses hatched, and the result ribbon. Pure drawing; `t` (0..1) is driven by TBFx.run (Off: 1 at once).
class_name TBBattleParts
extends RefCounted

class Bars extends Control:
	var g: TBGame
	var r: Dictionary
	var t := 1.0
	func _init(game: TBGame, report: Dictionary) -> void:
		g = game; r = report
		custom_minimum_size = Vector2(0, 150); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		TBKit.a11y(self, "%s %d → %d, %s %d → %d" % [g.dname(int(r["me_n"])), int(r["my0"]), maxi(int(r["my0"]) - int(r["my_loss"]), 0), g.dname(int(r["foe_n"])), int(r["foe0"]), maxi(int(r["foe0"]) - int(r["foe_loss"]), 0)], "image")
	func _side(x0: float, cw: float, n: int, before: int, lost: int, scale_max: float, mine: bool, role: String) -> void:
		var e: float = TBFx.smooth(t)
		var after: int = maxi(before - lost, 0)
		var shown: float = lerpf(float(before), float(after), e)
		var c := Vector2(x0 + 28.0, 30.0)
		TBFlags.draw_flag_medal(self, TBFlags.medal_of(g, n), c, 56.0)
		var f := TBKit.tracked(TBKit.wordmark(), 2)
		var nm: String = g.dname(n).to_upper()
		draw_string(f, Vector2(x0 + 66.0, 26.0), nm, HORIZONTAL_ALIGNMENT_LEFT, cw - 66.0, TBTitleParts.fit(f, nm, TBKit.fs(15), cw - 66.0), TBTokens.c("cream"))
		draw_string(TBKit.body_i(), Vector2(x0 + 66.0, 46.0), role, HORIZONTAL_ALIGNMENT_LEFT, cw - 66.0, TBKit.fs(14), TBTokens.c("smoke"))
		var nf := TBKit.mono_b()
		var num := "%s → %s" % [TBKit.fmt(float(before)), TBKit.fmt(roundf(shown))]
		draw_string(nf, Vector2(x0, 84.0), num, HORIZONTAL_ALIGNMENT_LEFT, cw, TBKit.fs(17), TBTokens.c("cream"))
		var by := 96.0
		draw_rect(Rect2(x0, by, cw, 14.0), TBTokens.BZ_TRACK_BG)
		draw_rect(Rect2(x0, by, cw, 14.0), TBTokens.BZ_TRACK_LINE, false, 1.0)
		var wb: float = (cw - 2.0) * float(before) / maxf(scale_max, 1.0)
		var wa: float = (cw - 2.0) * shown / maxf(scale_max, 1.0)
		var tone: Color = TBTokens.BZ_SLIDER_FILL_A if mine else TBTokens.BZ_DNG_A
		draw_rect(Rect2(x0 + 1.0, by + 1.0, wa, 12.0), tone)
		var hx: float = x0 + 1.0 + wa
		while hx < x0 + 1.0 + wb:                                                  # the lost part, hatched
			draw_line(Vector2(hx, by + 13.0), Vector2(minf(hx + 8.0, x0 + 1.0 + wb), by + 1.0), TBTokens.with_a(TBTokens.BZ_BAD, 0.8), 2.0)
			hx += 5.0
		draw_string(TBKit.body(), Vector2(x0, 132.0), "−%s" % TBKit.fmt(float(lost) * e), HORIZONTAL_ALIGNMENT_LEFT, cw, TBKit.fs(15), TBTokens.BZ_NEG_SOFT)
	func _draw() -> void:
		var w := size.x
		var gap := 56.0
		var cw: float = (w - gap) * 0.5
		var mx: float = maxf(float(r["my0"]), float(r["foe0"]))
		_side(0.0, cw, int(r["me_n"]), int(r["my0"]), int(r["my_loss"]), mx, true, TBI18n.T("br_role_att"))
		_side(cw + gap, cw, int(r["foe_n"]), int(r["foe0"]), int(r["foe_loss"]), mx, false, TBI18n.T("br_role_def"))
		TBBzIcons.draw(self, "war", Vector2(w * 0.5, 40.0), 28.0, TBTokens.c("brass_lt"), 1.6)

## the result band: "VICTORY" / "DEFEAT" between two small medals, a brass or rust wash behind
class Ribbon extends Control:
	var g: TBGame
	var win := true
	var text := ""
	var t := 1.0
	func _init(game: TBGame, is_win: bool, label: String) -> void:
		g = game; win = is_win; text = label
		custom_minimum_size = Vector2(0, 54); mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
	func _draw() -> void:
		var w := size.x; var h := size.y
		var tone: Color = TBTokens.c("brass_lt") if win else TBTokens.BZ_NOTICE_BAD
		var a: float = TBFx.smooth(t)
		var cols := PackedColorArray([TBTokens.with_a(tone, 0.0), TBTokens.with_a(tone, 0.28 * a), TBTokens.with_a(tone, 0.28 * a), TBTokens.with_a(tone, 0.0)])
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([cols[0], cols[0], cols[0], cols[0]]))
		for i in 40:                                                                   # a horizontal wash: strongest in the middle
			var x0: float = w * float(i) / 40.0
			var k: float = 1.0 - absf(float(i) / 40.0 - 0.5) * 2.0
			draw_rect(Rect2(x0, 0, w / 40.0 + 1.0, h), TBTokens.with_a(tone, 0.26 * k * a))
		draw_line(Vector2(0, 0.5), Vector2(w, 0.5), TBTokens.with_a(tone, 0.5 * a), 1.0); draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), TBTokens.with_a(tone, 0.5 * a), 1.0)
		var f := TBKit.tracked(TBKit.wordmark(), 7)
		var fsz := TBKit.fs(24)
		var tw: float = f.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x
		draw_string(f, Vector2(roundf((w - tw) * 0.5), roundf(h * 0.5 + f.get_ascent(fsz) * 0.5 - 2.0)), text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, TBTokens.with_a(tone, a))
		var tex: Texture2D = TBFlags.medal_of(g, g.human_id if win else g.human_id)
		if tex != null:
			TBFlags.draw_flag_medal(self, tex, Vector2(w * 0.5 - tw * 0.5 - 34.0, h * 0.5), 34.0)
			TBFlags.draw_flag_medal(self, tex, Vector2(w * 0.5 + tw * 0.5 + 34.0, h * 0.5), 34.0)
