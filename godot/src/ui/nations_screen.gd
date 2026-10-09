## Nations: ONE master-detail screen (modal-system.md 5.7): searchable list with filters on the left, the selected nation's card
## (ruler, facts, relations, diplomacy and intel actions) on the right; tab 2 = Rankings (chart + table). Portrait: list page, then detail page.
## Pick mode (new game): the same screen with tier filters and a "Play as X" footer. The UI never mutates the game: actions go through on_cmd.
class_name TBNationsScreen
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T
## per-session memory: only the filter / sort / tab are remembered between openings
static var mem := {"filter": "all", "sort": "prov", "tab": "list", "metric": "p", "table": false}

# ---- data ---------------------------------------------------------------------------------------------------------------------------------
## provinces, army and ranks of every living nation (one pass over the provinces)
static func compute(g: TBGame) -> Dictionary:
	var prov := PackedInt32Array(); prov.resize(g.N1)
	var army := PackedInt32Array(); army.resize(g.N1)
	for p in g.P:
		var o: int = g.owner[p]
		if o > 0: prov[o] += 1; army[o] += g.army[p]
	var ids: Array = []
	for n in range(1, g.N1):
		if g.alive[n] != 0 and n != g.rebel and prov[n] > 0: ids.append(n)
	var rank_p := {}; var rank_a := {}; var rank_t := {}
	var by_p := ids.duplicate(); by_p.sort_custom(func(a: int, b: int) -> bool: return prov[a] > prov[b] if prov[a] != prov[b] else a < b)
	for i in by_p.size(): rank_p[by_p[i]] = i + 1
	var by_a := ids.duplicate(); by_a.sort_custom(func(a: int, b: int) -> bool: return army[a] > army[b] if army[a] != army[b] else a < b)
	for i in by_a.size(): rank_a[by_a[i]] = i + 1
	var by_t := ids.duplicate(); by_t.sort_custom(func(a: int, b: int) -> bool: return g.tech_level[a] > g.tech_level[b] if g.tech_level[a] != g.tech_level[b] else a < b)
	for i in by_t.size(): rank_t[by_t[i]] = i + 1
	return {"ids": ids, "prov": prov, "army": army, "rank_p": rank_p, "rank_a": rank_a, "rank_t": rank_t, "by_p": by_p}

## nations sharing a land border with n -> number of border links
static func land_neighbours(g: TBGame, n: int) -> Dictionary:
	var shared := {}
	for p in g.owned(n):
		for e in range(g.nb_off[p], g.nb_off[p + 1]):
			var o: int = g.owner[g.nb[e]]
			if o != 0 and o != n and g.nb_sea[e] == 0: shared[o] = int(shared.get(o, 0)) + 1
	return shared

## start difficulty proposal (nation-pick.md): threat = land neighbours with army >= 1.3 x yours
static func start_rating(g: TBGame, n: int, st: Dictionary) -> Dictionary:
	var threat := 0
	var mine: int = st["army"][n]
	for o in land_neighbours(g, n):
		if float(st["army"][o]) >= 1.3 * float(maxi(1, mine)): threat += 1
	var rank: int = st["rank_p"].get(n, 999)
	var id := "balanced"
	if rank <= 8 and threat <= 1: id = "easy"
	elif rank > 40 or threat >= 3: id = "hard"
	return {"id": id, "threat": threat, "rank": rank}

static func rating_chip(r: Dictionary) -> Control:
	var id: String = r["id"]
	var tone: String = {"easy": "pos", "balanced": "info", "hard": "warn"}[id]
	var glyph_id: String = {"easy": "check", "balanced": "diamond", "hard": "warning"}[id]          # a rating, not a delta: no up / down triangles
	return K.chip(T.call("sr_" + id), glyph_id, tone)

static func rating_reason(r: Dictionary) -> String:
	var id: String = r["id"]
	var k: int = r["threat"]
	if id == "easy": return T.call("sr_r_easy")
	if id == "hard":
		if int(r["rank"]) > 40: return T.call("sr_r_small") + ((", " + T.call("sr_r_threat", {"k": k})) if k > 0 else "")
		return T.call("sr_r_threat", {"k": k})
	return T.call("sr_r_threat", {"k": k}) if k > 0 else T.call("sr_r_even")

static func tier_of(rank: int) -> String:
	return "powers" if rank <= 8 else ("regional" if rank <= 40 else "minor")

static func relation_chip(g: TBGame, me: int, n: int) -> Control:
	if n == me: return K.chip(T.call("you"), "flag", "own")
	var r := g.get_rel(me, n)
	match r:
		1: return K.chip(T.call("rel_war"), "swords", "neg")
		3: return K.chip(T.call("rel_ally"), "link", "info")
		2: return K.chip(T.call("rel_nap"), "shield", "neutral")
		4: return K.chip(T.call("rel_marriage"), "crown", "info")
	return K.chip(T.call("rel_peace"), "dove", "neutral")

static func row_h(portrait: bool = false) -> int:
	return 52 if portrait else (K.touch() if OS.has_feature("mobile") else 40)

# ---- list row -------------------------------------------------------------------------------------------------------------------------------
class NationRow extends Button:
	var n := 0
	var rank := 0
	var nm := ""
	var figure := ""
	var rel := -1
	var me := false
	var seat := ""
	var tex: Texture2D
	var selected := false:
		set(v): selected = v; _dirty = true; queue_redraw()
	var _dirty := true
	var _tl := TextLine.new()
	var _tf := TextLine.new()
	func _init(nation: int, name_text: String, flag: Texture2D, cb: Callable) -> void:
		n = nation; nm = name_text; tex = flag
		flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, TBNationsScreen.row_h())
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		pressed.connect(cb)
	func set_figure(t: String) -> void:
		figure = t; _dirty = true; queue_redraw()
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED: _dirty = true
	func _rebuild() -> void:
		_dirty = false
		_tf.clear(); _tf.add_string(figure, TBKit.mono_b(), TBKit.fs(14))
		var x0 := 92.0
		_tl.clear(); _tl.add_string(nm + ((" · " + seat) if seat != "" else ""), TBKit.body_b(), TBKit.fs(15))
		_tl.width = maxf(size.x - x0 - _tf.get_line_width() - 56.0, 24.0)
		_tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tooltip_text = nm if TBKit.body_b().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, TBKit.fs(15)).x > _tl.width else ""
	func _draw() -> void:
		if _dirty: _rebuild()
		var w := size.x; var h := size.y
		var mode := get_draw_mode()
		if selected: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_2"))
		elif mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_2"))
		elif mode == BaseButton.DRAW_HOVER: draw_rect(Rect2(0, 0, w, h - 1), TBTokens.c("paper_1"))
		if selected: draw_rect(Rect2(0, 0, 3, h - 1), TBTokens.c("oxblood"))
		if not TBTokens.is_hc(): draw_rect(Rect2(0, h - 1, w, 1), TBTokens.c("hair"))
		var cy := roundf((h - 1.0) * 0.5)
		if selected: TBGlyph.draw_filled(self, "check", Vector2(22, cy), 16.0, TBTokens.c("oxblood"))
		else:
			var rf := TBKit.mono()
			var rt := str(rank)
			draw_string(rf, Vector2(10, cy + rf.get_ascent(TBKit.fs(12)) * 0.5 - 1), rt, HORIZONTAL_ALIGNMENT_LEFT, 34, TBKit.fs(12), TBTokens.c("ink_1"))
		if tex != null: draw_texture_rect(tex, Rect2(42, cy - 9, 30, 20), false)
		var lc: Color = TBTokens.c("oxblood") if me else TBTokens.c("ink_0")
		_tl.draw(get_canvas_item(), Vector2(82, roundf((h - 1.0 - _tl.get_size().y) * 0.5)), lc)
		_tf.draw(get_canvas_item(), Vector2(roundf(w - 12.0 - _tf.get_line_width()), roundf((h - 1.0 - _tf.get_size().y) * 0.5)), TBTokens.c("ink_0"))
		var gx: float = w - 12.0 - _tf.get_line_width() - 18.0
		match rel:
			1: TBGlyph.draw(self, "swords", Vector2(gx, cy), 16.0, TBTokens.c("neg"))
			3: TBGlyph.draw(self, "link", Vector2(gx, cy), 16.0, TBTokens.c("info"))
			4: TBGlyph.draw(self, "crown", Vector2(gx, cy), 16.0, TBTokens.c("info"))
			2: TBGlyph.draw(self, "shield", Vector2(gx, cy), 16.0, TBTokens.c("ink_1"))
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(false, 0, 2), Rect2(0, 0, w, h))

# ---- the screen ---------------------------------------------------------------------------------------------------------------------------
## opts: select (nation), filter, tab, pick (bool), taken (Array of nation ids), seats (Dictionary n -> "P1"), on_cmd, on_goto, on_play(n), play_as_hint
static func open(parent: Control, g: TBGame, opts: Dictionary = {}) -> TBPanel.Handle:
	var me: int = g.human_id
	var pick: bool = bool(opts.get("pick", false))
	var on_cmd: Callable = opts.get("on_cmd", Callable())
	var on_goto: Callable = opts.get("on_goto", Callable())
	var on_play: Callable = opts.get("on_play", Callable())
	var taken: Array = opts.get("taken", [])
	var seats: Dictionary = opts.get("seats", {})
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var portrait := TBPanel.stacked(vs)                          # portrait or short landscape (< 480u): list page, then detail page with a Back arrow
	var S := {"sel": int(opts.get("select", -1)), "filter": String(opts.get("filter", mem["filter"] if not pick else "all")), "sort": String(mem["sort"]), "q": "", "tab": String(opts.get("tab", mem["tab"])), "detail": false}
	if pick and S["filter"] in ["near", "war", "ally"]: S["filter"] = "all"
	if not pick and S["filter"] in ["powers", "regional", "minor"]: S["filter"] = "all"
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("nations"), "globe", {"scroll": false, "padded": false})
	var st := compute(g)
	var rows := {}
	var names_l := {}
	var near: Dictionary = land_neighbours(g, me) if (me > 0 and not pick) else {}
	var ui := {}                                                 # widgets shared between closures
	# ---- header chip: the player's own standing
	if me > 0 and not pick and g.alive[me] != 0:
		h.set_chip(K.chip("%d · #%d" % [int(st["prov"][me]), int(st["rank_p"].get(me, 0))], "flag", "own"))
	var body := h.body
	var content := K.vbox(0); content.size_flags_vertical = Control.SIZE_EXPAND_FILL; content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)
	# =========================================================================================================================================
	var build_list := func() -> void:
		for c in content.get_children(): c.queue_free()
		rows.clear()
		var split := BoxContainer.new(); split.vertical = false
		split.add_theme_constant_override("separation", 0)
		split.size_flags_vertical = Control.SIZE_EXPAND_FILL; split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(split)
		# ---- master column
		var left := K.vbox(8)
		left.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var lm := MarginContainer.new()
		lm.add_theme_constant_override("margin_left", h.pad); lm.add_theme_constant_override("margin_right", 12 if not portrait else h.pad)
		lm.add_theme_constant_override("margin_top", 12); lm.add_theme_constant_override("margin_bottom", 0)
		lm.add_child(left)
		if portrait: lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else: lm.custom_minimum_size = Vector2(364, 0)
		lm.size_flags_vertical = Control.SIZE_EXPAND_FILL
		split.add_child(lm)
		var srow := K.hbox(8); left.add_child(srow)
		var search := LineEdit.new(); search.placeholder_text = T.call("search"); search.clear_button_enabled = true
		search.custom_minimum_size = Vector2(80, K.touch()); search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search.text = String(S["q"]); search.tooltip_text = T.call("search")
		srow.add_child(search)
		var sort_btn := K.button("", Callable()); sort_btn.custom_minimum_size = Vector2(0, K.touch())
		if K.text_scale >= 1.4 or TBPanel.is_portrait(vs): sort_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; sort_btn.custom_minimum_size = Vector2(90, K.touch())      # wraps instead of widening the page
		srow.add_child(sort_btn)
		var fl := TBPanel.flow(6); left.add_child(fl)
		var filters: Array = [["all", T.call("f_all")], ["powers", T.call("tier_powers")], ["regional", T.call("tier_regional")], ["minor", T.call("tier_minor")]] if pick else [["all", T.call("f_all")], ["near", T.call("f_near")], ["war", T.call("f_war")], ["ally", T.call("f_ally")]]
		var fchips := {}
		var cntl := K.label("", 13, K.DIM); left.add_child(cntl)
		var scroll := ScrollContainer.new(); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; scroll.follow_focus = true; scroll.scroll_deadzone = 12
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left.add_child(scroll)
		var list := K.vbox(0); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)
		var empty := TBPanel.empty_state("globe", "", "", T.call("clear_search"), func(): search.text = ""; S["q"] = ""; (ui["apply"] as Callable).call())
		empty.visible = false; list.add_child(empty)
		ui["empty"] = empty
		for n in st["ids"]:
			var nn: int = n
			var r := NationRow.new(nn, g.dname(nn), TBFlags.texture(g.nat_code[nn], g.color[nn]), func(): (ui["select"] as Callable).call(nn, true))
			r.custom_minimum_size.y = row_h(portrait)
			r.rank = int(st["rank_p"][nn]); r.me = nn == me and not pick
			r.rel = g.get_rel(me, nn) if (me > 0 and nn != me and not pick) else -1
			if seats.has(nn): r.seat = String(seats[nn])
			r.selected = nn == int(S["sel"])
			rows[nn] = r; names_l[nn] = g.dname(nn).to_lower()
			list.add_child(r)
			K.a11y(r, "%s, %d %s, #%d" % [g.dname(nn), int(st["prov"][nn]), T.call("lands").to_lower(), r.rank], "button")
		# ---- detail column
		var right := ScrollContainer.new(); right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; right.follow_focus = true; right.scroll_deadzone = 12
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL; right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rm := MarginContainer.new()
		rm.add_theme_constant_override("margin_left", 16 if not portrait else h.pad); rm.add_theme_constant_override("margin_right", h.pad)
		rm.add_theme_constant_override("margin_top", 12); rm.add_theme_constant_override("margin_bottom", 12)
		rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dv := K.vbox(10); dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rm.add_child(dv); right.add_child(rm)
		if not portrait:
			var vr := ColorRect.new(); vr.color = TBTokens.c("hair") if not TBTokens.is_hc() else TBTokens.c("rule"); vr.custom_minimum_size = Vector2(1, 0); vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			split.add_child(vr)
		split.add_child(right)
		ui["detail_box"] = dv; ui["detail_scroll"] = right; ui["list_scroll"] = scroll; ui["master"] = lm; ui["count"] = cntl; ui["sort_btn"] = sort_btn
		ui["list"] = list
		# ---- behaviour
		var sort_label := func() -> String: return T.call("sort_" + String(S["sort"]))
		sort_btn.text = T.call("sort_by", {"s": sort_label.call()})
		K.a11y(sort_btn, sort_btn.text, "button")
		var apply := func() -> void:
			var q: String = String(S["q"]).to_lower()
			var key: String = S["sort"]
			var ord: Array = st["ids"].duplicate()
			if key == "army": ord.sort_custom(func(a: int, b: int) -> bool: return st["army"][a] > st["army"][b] if st["army"][a] != st["army"][b] else a < b)
			elif key == "name": ord.sort_custom(func(a: int, b: int) -> bool: return names_l[a] < names_l[b])
			else: ord = st["by_p"].duplicate()
			var shown := 0
			for i in ord.size():
				var nn2: int = ord[i]
				var r2: NationRow = rows[nn2]
				list.move_child(r2, i + 1)
				r2.set_figure(K.fmt(float(st["army"][nn2])) if key == "army" else str(int(st["prov"][nn2])))
				var ok := true
				match String(S["filter"]):
					"near": ok = near.has(nn2)
					"war": ok = me > 0 and g.get_rel(me, nn2) == 1
					"ally": ok = me > 0 and (g.get_rel(me, nn2) == 3 or g.get_rel(me, nn2) == 4)
					"powers", "regional", "minor": ok = tier_of(int(st["rank_p"][nn2])) == String(S["filter"])
				if ok and q != "" and not String(names_l[nn2]).contains(q): ok = false
				r2.visible = ok
				if ok: shown += 1
			cntl.text = T.call("showing_n", {"a": shown, "b": st["ids"].size()})
			cntl.visible = shown != st["ids"].size()
			var emp: Control = ui["empty"]
			emp.visible = shown == 0
			if shown == 0:
				var l1: Label = emp.get_child(1)
				l1.text = T.call("no_match", {"q": String(S["q"])}) if String(S["q"]) != "" else T.call("none_yet")
		ui["apply"] = apply
		for f in filters:
			var fid: String = f[0]
			var cb := TBPanel.chip_button(String(f[1]), fid == String(S["filter"]), func():
				S["filter"] = fid; mem["filter"] = fid
				for k in fchips: (fchips[k] as TBPanel.ChipBtn).set_on(k == fid)
				apply.call())
			fl.add_child(cb); fchips[fid] = cb
		search.text_changed.connect(func(t: String): S["q"] = t; apply.call())
		sort_btn.pressed.connect(func():
			var seq: Array = ["prov", "army", "name"]
			S["sort"] = seq[(seq.find(String(S["sort"])) + 1) % 3]; mem["sort"] = S["sort"]
			sort_btn.text = T.call("sort_by", {"s": sort_label.call()}); apply.call())
		apply.call()
		# portrait: the detail is a second page
		if portrait: right.visible = false
		var sel0: int = int(S["sel"])
		if sel0 > 0 and rows.has(sel0): (ui["select"] as Callable).call(sel0, false)
		elif not portrait:
			var first_n: int = me if (me > 0 and rows.has(me) and not pick) else int(st["by_p"][0])
			(ui["select"] as Callable).call(first_n, false)
	# =========================================================================================================================================
	ui["select"] = func(n: int, push: bool) -> void:
		S["sel"] = n
		for k in rows: (rows[k] as NationRow).selected = (k == n)
		var dv: VBoxContainer = ui["detail_box"]
		for c in dv.get_children(): c.queue_free()
		_card(dv, g, n, st, {"h": h, "parent": parent, "pick": pick, "wide": h.card.size.x >= 800.0 and K.text_scale < 1.4, "on_cmd": on_cmd, "taken": taken, "me": me,
			"on_select": func(o: int) -> void:
				(ui["select"] as Callable).call(o, true)
				if rows.has(o): (ui["list_scroll"] as ScrollContainer).ensure_control_visible.call_deferred(rows[o]),
			"refresh": func():
				for k2 in rows:
					var rr: NationRow = rows[k2]
					rr.rel = g.get_rel(me, k2) if (me > 0 and k2 != me and not pick) else -1
					rr.queue_redraw()
				(ui["select"] as Callable).call(S["sel"], false)})
		if portrait and push:
			S["detail"] = true
			(ui["master"] as Control).visible = false; (ui["detail_scroll"] as Control).visible = true
			h.set_title(g.dname(n))
		_footer(h, g, n, pick, taken, on_goto, on_play, opts)
		if rows.has(n) and not portrait: (ui["list_scroll"] as ScrollContainer).ensure_control_visible.call_deferred(rows[n])
	# ---- rankings tab
	var build_rank := func() -> void:
		for c in content.get_children(): c.queue_free()
		h.clear_actions()
		var sc := ScrollContainer.new(); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; sc.size_flags_vertical = Control.SIZE_EXPAND_FILL; sc.follow_focus = true
		var mg := MarginContainer.new()
		for s in ["left", "right"]: mg.add_theme_constant_override("margin_" + s, h.pad)
		mg.add_theme_constant_override("margin_top", 12); mg.add_theme_constant_override("margin_bottom", 12)
		mg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := K.vbox(10); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mg.add_child(v); sc.add_child(mg); content.add_child(sc)
		_rankings(v, g, st, parent)
	# ---- tabs (not in pick mode)
	if not pick:
		var tabs := K.tabs([["list", T.call("dk_nations")], ["rank", T.call("rankings")]], String(S["tab"]), func(id: String):
			S["tab"] = id; mem["tab"] = id
			if id == "rank": build_rank.call() else: build_list.call())
		h.set_tabs(tabs)
	h.on_back = func() -> bool:
		if portrait and bool(S["detail"]):
			S["detail"] = false
			(ui["master"] as Control).visible = true; (ui["detail_scroll"] as Control).visible = false
			h.set_title(T.call("nations"))
			h.clear_actions()
			return true
		return false
	if String(S["tab"]) == "rank" and not pick: build_rank.call()
	else: build_list.call()
	if portrait and int(S["sel"]) > 0 and rows.has(int(S["sel"])): (ui["select"] as Callable).call(int(S["sel"]), true)
	elif rows.has(int(S["sel"])): h.focus_target = rows[int(S["sel"])]          # keyboard / pad: focus starts on the selected nation row
	return h

static func _footer(h: TBPanel.Handle, g: TBGame, n: int, pick: bool, taken: Array, on_goto: Callable, on_play: Callable, opts: Dictionary) -> void:
	h.clear_actions()
	var show := K.button(T.call("goto"), func(): h.close(); if on_goto.is_valid(): on_goto.call(n))
	if pick:
		var go: Button = K.button(T.call("play_as", {"nation": g.dname(n)}), func(): h.close(); on_play.call(n), true)
		if taken.has(n): K.disable(go, T.call("taken_other"))
		h.actions(show, go)
	else:
		h.actions(null, show)
		show.theme_type_variation = &"PrimaryButton"

# ---- nation card (right pane) -----------------------------------------------------------------------------------------------------------------
static func _card(v: VBoxContainer, g: TBGame, n: int, st: Dictionary, ctx: Dictionary) -> void:
	var me: int = ctx["me"]
	var pick: bool = ctx["pick"]
	var wide: bool = ctx["wide"]
	var on_cmd: Callable = ctx["on_cmd"]
	var parent: Control = ctx["parent"]
	var refresh: Callable = ctx["refresh"]
	# header: flag, name, chips
	var top := K.hbox(14); v.add_child(top)
	var fl := TBFlags.chip(g, n, 1.5); top.add_child(fl)
	var tv := K.vbox(6); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(tv)
	var nl := K.title(g.dname(n), 22); nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nl.custom_minimum_size.x = 40
	tv.add_child(nl)
	var chips := TBPanel.flow(6); tv.add_child(chips)
	if not pick: chips.add_child(relation_chip(g, me, n))
	chips.add_child(K.chip(T.call("rank_size", {"n": int(st["rank_p"].get(n, 0))}), "", "neutral"))
	if pick:
		var rt := start_rating(g, n, st)
		chips.add_child(rating_chip(rt))
		v.add_child(TBPanel.para(rating_reason(rt), 13, K.DIM))
		if (ctx["taken"] as Array).has(n):
			chips.add_child(K.chip(T.call("taken_other"), "lock", "warn"))
	# ruler
	if g.rules >= 1 and g.r_name[n] != "":
		var hb := K.hbox(12)
		hb.add_child(TBPortrait.new().setup(g, n, 72))
		var rc := K.vbox(2); rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL; rc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rc.add_child(TBPanel.para("%s %s" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)], 15, K.GOLD2))
		rc.add_child(TBPanel.para("%s · %s %d · %s %d · %s %d" % [T.call("ruler_age", {"a": TBRulers.age(g, n)}), T.call("skill_adm"), g.r_adm[n], T.call("skill_dip"), g.r_dip[n], T.call("skill_mil"), g.r_mil[n]], 13, K.DIM))
		var tr: String = TBRulers.TRAITS[g.r_trait[n]]
		if tr != "none": rc.add_child(TBPanel.para("%s: %s" % [T.call("rtr_" + tr), T.call("rtr_%s_d" % tr)], 13, K.DIM))
		hb.add_child(rc); v.add_child(hb)
	var rel := g.get_rel(me, n) if (n != me and me > 0) else -1
	if not pick and n != me and me > 0: _actions(v, g, n, ctx, rel)
	# facts
	var rows: Array = [
		[T.call("lands"), "%d · #%d" % [int(st["prov"][n]), int(st["rank_p"].get(n, 0))]],
		[T.call("total_army"), "%s · #%d" % [K.fmt(float(st["army"][n])), int(st["rank_a"].get(n, 0))]],
		[T.call("govt"), T.call("g_" + TBData.REGIME_ID[g.regime[n]])],
		[T.call("tech"), "%s %.1f · #%d" % [T.call("era_name_%d" % g.era[n]), g.tech_level[n], int(st["rank_t"].get(n, 0))]],
		[T.call("attitude"), T.call("pers_" + TBData.PERSONALITIES[g.personality[n]]["id"])]]
	if not pick:
		if n == me:
			rows.append([T.call("income_net"), K.signed(float(g.income(n)["net"]))])
		if g.rules >= 1 and g.infamy[n] >= 1.0:
			rows.append([T.call("infamy"), "%.0f%s" % [g.infamy[n], ("  " + T.call("coalition")) if g.coalition[n] != 0 else ""]])
		if n != me and me > 0:
			if g.rules >= 1 and rel != 1:
				var cbk := TBDiplo.cb(g, me, n)
				rows.append([T.call("cb"), T.call("cb_" + cbk) if cbk != "" else "%s (+%d %s)" % [T.call("cb_none"), int(TBDiplo.NO_CB_INFAMY), T.call("infamy")]])
			if rel == 1: rows.append([T.call("war_score"), "%d%% / %d%%" % [g.war_score[me * g.N1 + n], g.war_score[n * g.N1 + me]]])
			elif g.has_truce(me, n): rows.append([T.call("truce_left", {"n": g.truce[me * g.N1 + n] - g.turn}), "—"])
			rows.append([T.call("grudge"), "%d" % g.grudge[n * g.N1 + me]])
			if g.rules >= 1 and TBTrade.has(g, me, n): rows.append([T.call("trade"), "+%d" % TBTrade.value(g, n)])
	v.add_child(TBPanel.section(T.call("facts")))
	v.add_child(TBPanel.facts_grid(rows, 2 if wide else 1))
	# allies / enemies
	var allies: Array = []; var enemies: Array = []
	for o in range(1, g.N1):
		if g.alive[o] == 0 or o == n or o == g.rebel: continue
		var r := g.get_rel(n, o)
		if r == 3: allies.append(o)
		elif r == 1: enemies.append(o)
	for grp in [[T.call("allies"), allies], [T.call("at_war_with"), enemies]]:
		var arr: Array = grp[1]
		v.add_child(TBPanel.section(String(grp[0])))
		if arr.is_empty(): v.add_child(K.label(T.call("none_yet"), 13, K.DIM)); continue
		var fw := TBPanel.flow(6); v.add_child(fw)
		for i in mini(6, arr.size()):
			var o: int = arr[i]
			fw.add_child(TBPanel.nation_button(g, o, func(): (ctx["on_select"] as Callable).call(o)))
		if arr.size() > 6: fw.add_child(K.chip("+%d" % (arr.size() - 6), "", "neutral"))

## what you can do with this nation (diplomacy, then intel): shown directly under the header and ruler, above the facts (modal-system.md 5.4)
static func _actions(v: VBoxContainer, g: TBGame, n: int, ctx: Dictionary, rel: int) -> void:
	var me: int = ctx["me"]
	var wide: bool = ctx["wide"]
	var on_cmd: Callable = ctx["on_cmd"]
	var parent: Control = ctx["parent"]
	var refresh: Callable = ctx["refresh"]
	var dp: float = g.dp[me]
	var dpw := func(cost: int) -> String: return "" if dp >= float(cost) else T.call("err_dp")
	var cost_chip := func(cost: int, unit: String) -> Array: return [["%d %s" % [cost, unit], "scales" if unit == T.call("hud_dp") else "eye", "neg" if (unit == T.call("hud_dp") and dp < float(cost)) else "neutral"]]
	var done := func(cmd: Dictionary) -> void:
		on_cmd.call(cmd); refresh.call()
	var dpu: String = T.call("hud_dp")
	# what the court makes of the request (the engine's own sums): one verdict chip per request, a disposition meter, the terms
	var ai: bool = g.human[n] == 0
	var vw := {}
	if ai:
		vw = {"nap": TBDipView.pact(g, n, me, D.REL_NAP), "ally": TBDipView.pact(g, n, me, D.REL_ALLY), "trade": TBDipView.trade(g, n, me),
			"white": TBDipView.peace(g, n, me, "white"), "cede": TBDipView.peace(g, n, me, "cede"), "vassal": TBDipView.peace(g, n, me, "vassal")}
	var verdict := func(k: String) -> Array:
		if not ai or not vw.has(k): return []
		return [[T.call("dv_will") if bool(vw[k]["ok"]) else T.call("dv_wont"), "check" if bool(vw[k]["ok"]) else "close", "pos" if bool(vw[k]["ok"]) else "neg"]]
	var ask := func(k: String, what_key: String, cmd: Dictionary) -> void:
		if not ai or not vw.has(k): done.call(cmd); return
		var pre: Dictionary = g.can({"cmd": String(cmd["cmd"]), "n": me, "t": n, "kind": String(cmd.get("kind", ""))})      # a request the engine rejects before asking the court (no points, wrong state) gets no ceremony
		if not bool(pre["ok"]) and String(pre["reason"]) != "refused": done.call(cmd); return
		TBNegotiate.run(parent, what_key, g.dname(n), vw[k], func(): done.call(cmd))
	if ai and rel in [0, 1, 2]:
		var lead: String = "white" if rel == 1 else ("nap" if rel == 0 else "ally")
		v.add_child(TBPanel.section("%s  ·  %s" % [T.call("dv_title"), T.call("dv_for", {"w": T.call({"white": "dv_peace_white", "nap": "dv_pact_nap", "ally": "dv_pact_ally"}[lead])})]))
		v.add_child(TBNegotiate.meter(vw[lead], n * 8 + ["white", "nap", "ally"].find(lead)))
		v.add_child(TBPanel.section(T.call("dv_why")))
		v.add_child(TBNegotiate.why_list(vw[lead]))
	v.add_child(TBPanel.section(T.call("diplomacy")))
	var acts := GridContainer.new(); acts.columns = 2 if wide else 1
	acts.add_theme_constant_override("h_separation", 10); acts.add_theme_constant_override("v_separation", 8); acts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(acts)
	if rel == 1:
		var ws: int = g.war_score[me * g.N1 + n]
		acts.add_child(TBPanel.card("dove", T.call("white_peace"), "", cost_chip.call(D.DP_PEACE, dpu) + verdict.call("white"), func(): ask.call("white", "dv_peace_white", {"cmd": "peace", "t": n, "kind": "white"}), dpw.call(D.DP_PEACE), false, false))
		acts.add_child(TBPanel.card("flag", T.call("demand_land"), "", verdict.call("cede") if ws >= 25 else [], func(): ask.call("cede", "dv_peace_cede", {"cmd": "peace", "t": n, "kind": "cede"}), "" if ws >= 25 else T.call("err_warscore") + " (25%)", false, false))
		if g.rules >= 1: acts.add_child(TBPanel.card("crown", T.call("demand_vassal"), "", verdict.call("vassal") if ws >= 50 else [], func(): ask.call("vassal", "dv_peace_vassal", {"cmd": "peace", "t": n, "kind": "vassal"}), "" if ws >= 50 else T.call("err_warscore") + " (50%)", false, false))
	else:
		if rel == 0:
			acts.add_child(TBPanel.card("shield", T.call("propose_nap"), "", cost_chip.call(D.DP_NAP, dpu) + verdict.call("nap"), func(): ask.call("nap", "dv_pact_nap", {"cmd": "nap", "t": n}), dpw.call(D.DP_NAP), false, false))
			acts.add_child(TBPanel.card("link", T.call("propose_ally"), "", cost_chip.call(D.DP_ALLY, dpu) + verdict.call("ally"), func(): ask.call("ally", "dv_pact_ally", {"cmd": "ally", "t": n}), dpw.call(D.DP_ALLY), false, false))
		if TBDiplo.can_marry(g, me, n):
			acts.add_child(TBPanel.card("crown", T.call("marry_propose"), "", cost_chip.call(TBDiplo.DP_MARRY, dpu) + verdict.call("ally"), func(): ask.call("ally", "dv_marry", {"cmd": "marry", "t": n}), dpw.call(TBDiplo.DP_MARRY), false, false))
		if g.rules >= 1:
			if TBTrade.has(g, me, n): acts.add_child(TBPanel.card("coins", T.call("trade_cancel"), "", [], func(): done.call({"cmd": "cancelTrade", "t": n}), "", false, false))
			else: acts.add_child(TBPanel.card("coins", T.call("trade_propose"), "", cost_chip.call(TBTrade.DP_COST, dpu) + verdict.call("trade"), func(): ask.call("trade", "dv_trade", {"cmd": "trade", "t": n}), dpw.call(TBTrade.DP_COST), false, false))
		if rel == 2 or rel == 3:
			acts.add_child(TBPanel.card("close", T.call("break_pact"), "", [], func():
				TBPanel.confirm(parent, T.call("confirm_break_t", {"a": g.dname(n)}), T.call("confirm_break_b"), T.call("break_pact"), func(): done.call({"cmd": "breakPact", "t": n})), "", false, false))
		# war: separated, red, confirmed
		var wr := K.vbox(4); wr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var why: String = dpw.call(D.DP_WAR)
		var wb: Button = K.danger("%s  (%d %s)" % [T.call("declare_war"), D.DP_WAR, dpu], func():
			var cbk := TBDiplo.cb(g, me, n)
			var body: String = T.call("confirm_war_cb", {"cb": T.call("cb_" + cbk)}) if cbk != "" else T.call("confirm_war_nocb", {"k": int(TBDiplo.NO_CB_INFAMY)})
			TBPanel.confirm(parent, T.call("confirm_war_t", {"a": g.dname(n)}), body + " " + T.call("confirm_war_b", {"dp": D.DP_WAR}), T.call("declare_war_on", {"a": g.dname(n)}), func(): done.call({"cmd": "declareWar", "t": n}), true, "swords"))
		wb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if why != "": K.disable(wb, why)
		wr.add_child(wb)
		if why != "": wr.add_child(TBPanel.para(why, 13, K.RED))
		v.add_child(K.hair())
		v.add_child(wr)
	# intel
	if g.rules >= 1:
		v.add_child(TBPanel.section("%s  ·  %s %.0f" % [T.call("spy_title"), T.call("hud_intel"), g.intel[me]]))
		var sp := GridContainer.new(); sp.columns = 2 if wide else 1
		sp.add_theme_constant_override("h_separation", 10); sp.add_theme_constant_override("v_separation", 8); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
		for op in ["steal", "sabotage", "incite"]:
			var cost: float = TBCommands.SPY_COST[op]
			var reason := ""
			if g.friendly(me, n): reason = T.call("err_ally")
			elif g.intel[me] < cost: reason = T.call("err_intel")
			var o: String = op
			sp.add_child(TBPanel.card("eye", T.call("spy_" + op), "", [["%d %s" % [int(cost), T.call("hud_intel")], "eye", "neg" if g.intel[me] < cost else "neutral"]], func(): done.call({"cmd": "spy", "t": n, "op": o}), reason, false, false))


# ---- rankings tab: chart or table of the leading powers ----------------------------------------------------------------------------------------
static func _rankings(v: VBoxContainer, g: TBGame, st: Dictionary, parent: Control) -> void:
	var S := {"hidden": {}}
	var metrics: Array = [["p", T.call("hud_prov")], ["a", T.call("army")], ["g", T.call("gold")], ["k", T.call("tech")]]
	var seg := TBPanel.seg(metrics, String(mem["metric"]), func(id: String): mem["metric"] = id; (S["draw"] as Callable).call())
	v.add_child(seg)
	var view := TBPanel.seg([["chart", T.call("chart")], ["table", T.call("table")]], "table" if bool(mem["table"]) else "chart", func(id: String): mem["table"] = id == "table"; (S["draw"] as Callable).call())
	v.add_child(view)
	var chart := TBStatChart.new(); chart.custom_minimum_size = Vector2(0, 220)
	chart.x_label = func(t: float) -> String:
		var mo: int = g.start_month + int(t) * 6
		var y: int = g.start_year + mo / 12
		return ("%d BC" % -y) if y < 0 else str(y)
	var legend := TBPanel.flow(6)
	var table := K.vbox(0); table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(chart); v.add_child(legend); v.add_child(table)
	var note := TBPanel.para(T.call("stats_wait"), 13, K.DIM); v.add_child(note)
	note.visible = g.stats.size() < 2
	S["draw"] = func() -> void:
		var key: String = mem["metric"]
		var as_table: bool = mem["table"]
		chart.visible = not as_table; legend.visible = not as_table; table.visible = as_table
		for c in legend.get_children(): c.queue_free()
		for c in table.get_children(): c.queue_free()
		if not as_table:
			var feats := TBStats.featured(g, 6)
			chart.series = []
			var idx := 0
			for n in feats:
				var nn: int = n
				var col: Color = TBTokens.c("oxblood") if nn == g.human_id else Color.hex((g.color[nn] << 8) | 0xFF).darkened(0.25)
				var on: bool = not S["hidden"].has(nn)
				if on: chart.series.append({"name": g.dname(nn), "color": col, "pts": TBStats.series(g, nn, key), "bold": nn == g.human_id, "dash": idx})
				var cb := TBPanel.chip_button(g.dname(nn), on, func():
					if S["hidden"].has(nn): S["hidden"].erase(nn)
					else: S["hidden"][nn] = true
					(S["draw"] as Callable).call())
				legend.add_child(cb)
				idx += 1
			chart.queue_redraw()
		else:
			var ids: Array = st["ids"].duplicate()
			var val := func(n: int) -> float:
				match key:
					"a": return float(st["army"][n])
					"g": return g.gold[n]
					"k": return g.tech_level[n]
				return float(st["prov"][n])
			ids.sort_custom(func(a: int, b: int) -> bool: return val.call(a) > val.call(b) if val.call(a) != val.call(b) else a < b)
			var shown := ids.slice(0, 12)
			if g.human_id > 0 and ids.has(g.human_id) and not shown.has(g.human_id): shown.append(g.human_id)
			for n in shown:
				var nn2: int = n
				var rk: int = ids.find(nn2) + 1
				var txt: String = "%.1f" % val.call(nn2) if key == "k" else K.fmt(val.call(nn2))
				var row := K.ListRow.new(g.dname(nn2), txt, Callable())
				row.focus_mode = Control.FOCUS_NONE
				row.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.left = "%d.  %s" % [rk, g.dname(nn2)]
				if nn2 == g.human_id: row.left_col = TBTokens.c("oxblood")
				table.add_child(row)
			if ids.size() > shown.size(): table.add_child(TBPanel.para(T.call("showing_n", {"a": shown.size(), "b": ids.size()}), 13, K.DIM))
	(S["draw"] as Callable).call()
