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
	return 62                                                     # natRow: 46 unit ring + 8 unit padding above and below

## how warmly nation n sees `me`, -100..100 (the demo's `rel`): the state of relations, tempered by grudges, infamy and trade
static func opinion(g: TBGame, me: int, n: int) -> int:
	if me <= 0 or n == me: return 0
	var r := g.get_rel(me, n)
	var v := 0.0
	match r:
		1: v = -70.0
		3: v = 70.0
		4: v = 55.0
		2: v = 28.0
	v -= minf(60.0, float(g.grudge[n * g.N1 + me]) * 1.5)
	if g.rules >= 1:
		v -= maxf(0.0, g.infamy[me] - 10.0) * 0.6
		if TBTrade.has(g, me, n): v += 10.0
	return clampi(int(roundf(v)), -100, 100)

static func rel_color(v: int) -> Color:
	if v <= -60: return TBTokens.BZ_BAD
	if v < -20: return TBTokens.BZ_REL_WARM
	if v < 20: return TBTokens.BZ_DIM
	if v < 60: return TBTokens.BZ_GOOD
	return TBTokens.BZ_INFO

## the line under a nation's name: the state of relations, else how they feel
static func rel_text(g: TBGame, me: int, n: int, op: int) -> String:
	if n == me: return T.call("you")
	match g.get_rel(me, n):
		1: return T.call("rel_war")
		3: return T.call("rel_ally")
		4: return T.call("rel_marriage")
		2: return T.call("rel_nap")
	if op <= -30: return T.call("op_hostile")
	if op < -8: return T.call("op_wary")
	if op >= 35: return T.call("op_friendly")
	return T.call("op_neutral")

# ---- list row (natRow) ----------------------------------------------------------------------------------------------------------------------
class NationRow extends Button:
	var n := 0
	var rank := 0
	var nm := ""
	var figure := ""
	var cap_text := ""
	var rel := -1                        # state of relations with the player (-1 none)
	var op := 0                          # -100..100 disposition (the ring's arc)
	var st_text := ""
	var me := false
	var seat := ""
	var tex: Texture2D
	var selected := false:
		set(v): selected = v; queue_redraw()
	var _hover := false
	func _init(nation: int, name_text: String, flag: Texture2D, cb: Callable) -> void:
		n = nation; nm = name_text; tex = flag
		flat = true; focus_mode = Control.FOCUS_ALL; action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		custom_minimum_size = Vector2(0, TBNationsScreen.row_h())
		for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]: add_theme_stylebox_override(st, TBKit._empty)
		pressed.connect(cb)
		mouse_entered.connect(func(): _hover = true; queue_redraw())
		mouse_exited.connect(func(): _hover = false; queue_redraw())
	func set_figure(t: String, c: String = "") -> void:
		figure = t; cap_text = c; queue_redraw()
	func _draw() -> void:
		var ci := get_canvas_item()
		var w := size.x; var h := size.y
		if TBTokens.is_hc():
			if selected: draw_rect(Rect2(0, 0, w, h), TBTokens.c("paper_2")); draw_rect(Rect2(0, 0, 4, h), TBTokens.c("ink_0"))
			elif _hover: draw_rect(Rect2(0, 0, w, h), TBTokens.c("paper_hover"))
		elif selected:
			TBBz.poly(ci, TBBzParts.rrect(0, 0, w, h, 3.0), TBTokens.BZ_ROW_ON); draw_rect(Rect2(0, 0, 3, h), TBTokens.c("brass"))
		elif _hover or has_focus():
			TBBz.poly(ci, TBBzParts.rrect(0, 0, w, h, 3.0), TBTokens.BZ_ROW_HOT)
		var cy: float = h * 0.5
		var rc := Vector2(10.0 + 23.0, cy)
		var k: float = 46.0 / 52.0
		# the ring: a 270 degree track, the disposition arc over it, the flag medal inside
		var a0: float = -PI * 0.75 - PI * 0.5
		var a1: float = PI * 0.75 - PI * 0.5
		var col: Color = TBTokens.BZ_TRACK if not TBTokens.is_hc() else TBTokens.c("rule")
		draw_arc(rc, 24.5 * k, a0, a1, 48, col, 3.0 * k, true)
		var fr: float = clampf(float(op + 100) / 200.0, 0.0, 1.0)
		if fr > 0.005 and rel != -2: draw_arc(rc, 24.5 * k, a0, a0 + (a1 - a0) * fr, maxi(8, int(48 * fr)), TBTokens.BZ_GOOD if me else TBNationsScreen.rel_color(op), 3.0 * k, true)
		if tex != null: TBFlags.draw_flag_medal(self, tex, rc, 34.0)
		# the text block: name (Cinzel 700 12.5, tracked .09em), the relation line (Alegreya italic 14), the army figure at the right
		var x0: float = 10.0 + 46.0 + 14.0
		var fn: Font = TBKit.cinzel(700); var fi: Font = TBKit.alegreya(400, true); var fb: Font = TBKit.alegreya(700)
		var nsz := 12.5; var isz := 14.0
		var fcap: Font = TBKit.cinzel(700)
		var fw: float = TBBz.tw(fb, figure, 16.0)
		var cw: float = TBBz.tw(fcap, cap_text.to_upper(), 8.5, 8.5 * 0.2)
		var rw: float = maxf(fw, cw)
		var maxw: float = w - x0 - 10.0 - rw - 12.0
		var up: String = (nm + ((" · " + seat) if seat != "" else "")).to_upper() if TBI18n.lang != "ru" else nm
		while up.length() > 3 and TBBz.tw(fn, up, nsz, nsz * 0.09) > maxw: up = up.substr(0, up.length() - 2)
		if up.length() < (nm + ((" · " + seat) if seat != "" else "")).length() and TBBz.tw(fn, up, nsz, nsz * 0.09) <= maxw: up += "…"
		var h1: float = roundf(TBBz.ascent(fn, nsz)) + roundf(TBBz.descent(fn, nsz))
		var h2: float = roundf(TBBz.ascent(fi, isz)) + roundf(TBBz.descent(fi, isz))
		var top: float = roundf((h - (h1 + h2)) * 0.5)
		TBBz.text(ci, fn, Vector2(x0, top + roundf(TBBz.ascent(fn, nsz))), up, nsz, TBTokens.c("brass_lt") if me else TBTokens.c("ink_0"), nsz * 0.09)
		var tc: Color = TBNationsScreen.rel_color(op) if rel != 3 and rel != 4 else TBTokens.BZ_INFO
		if rel == 1: tc = TBTokens.BZ_BAD
		if me: tc = TBTokens.c("brass_lt")
		TBBz.text(ci, fi, Vector2(x0, top + h1 + roundf(TBBz.ascent(fi, isz))), st_text, isz, tc)
		var fh: float = roundf(TBBz.ascent(fb, 16.0)) + roundf(TBBz.descent(fb, 16.0))
		var ch: float = roundf(TBBz.ascent(fcap, 8.5)) + roundf(TBBz.descent(fcap, 8.5))
		var t2: float = roundf((h - (fh + ch)) * 0.5)
		TBBz.text(ci, fb, Vector2(w - 10.0 - fw, t2 + roundf(TBBz.ascent(fb, 16.0))), figure, 16.0, TBTokens.c("ink_0"))
		TBBz.text(ci, fcap, Vector2(w - 10.0 - cw, t2 + fh + roundf(TBBz.ascent(fcap, 8.5))), cap_text.to_upper(), 8.5, TBTokens.c("ink_1"), 8.5 * 0.2)
		if has_focus() and TBFrame.kbd_nav: draw_style_box(TBFrame.focus(false, 0, 2), Rect2(0, 0, w, h))

# ---- the screen ---------------------------------------------------------------------------------------------------------------------------
## opts: select (nation), filter, tab, pick (bool), taken (Array of nation ids), seats (Dictionary n -> "P1"), on_cmd, on_goto, on_play(n), play_as_hint
static func open(parent: Control, g: TBGame, opts: Dictionary = {}) -> TBPanel.Handle:
	var me: int = g.human_id
	var pick: bool = bool(opts.get("pick", false))
	var on_cmd: Callable = opts.get("on_cmd", Callable())
	var on_goto: Callable = opts.get("on_goto", Callable())
	var on_fly: Callable = opts.get("on_fly", Callable())                   # a country name pressed: the map turns to that country (the window stays)
	var on_play: Callable = opts.get("on_play", Callable())
	var taken: Array = opts.get("taken", [])
	var seats: Dictionary = opts.get("seats", {})
	var vs: Vector2 = parent.size if parent.size.x > 1.0 else parent.get_viewport_rect().size
	var portrait: bool = vs.y > vs.x                              # a portrait window: list page, then detail page with a Back arrow (a phone in landscape keeps both columns, like the demo)
	var S := {"sel": int(opts.get("select", -1)), "filter": String(opts.get("filter", mem["filter"] if not pick else "all")), "sort": String(mem["sort"]), "q": "", "tab": String(opts.get("tab", mem["tab"])), "detail": false}
	if pick and S["filter"] in ["near", "war", "ally"]: S["filter"] = "all"
	if not pick and S["filter"] in ["powers", "regional", "minor"]: S["filter"] = "all"
	var ph0: bool = K.is_phone(parent)
	var sub_t: String = T.call("nat_courts") + ((" · %d" % g.year) if not pick else "")
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("nations"), "nations", {"scroll": false, "w": 740 if ph0 else 900, "h": 690, "sub": sub_t})
	var st := compute(g)
	var rows := {}
	var names_l := {}
	var near: Dictionary = land_neighbours(g, me) if (me > 0 and not pick) else {}
	var ui := {}                                                 # widgets shared between closures
	# ---- header chip: the player's own standing
	var body := h.body
	var content := K.vbox(0); content.size_flags_vertical = Control.SIZE_EXPAND_FILL; content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not ph0 and not portrait: content.custom_minimum_size = Vector2(0, 470)             # min-height:470px
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
		lm.add_theme_constant_override("margin_left", 0); lm.add_theme_constant_override("margin_right", 10 if not portrait else 0)
		lm.add_theme_constant_override("margin_top", 0); lm.add_theme_constant_override("margin_bottom", 0)
		lm.add_child(left)
		if portrait: lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else: lm.custom_minimum_size = Vector2((270.0 if ph0 else 290.0) + 18.0, 0)      # the demo's 290 unit column and the 18 unit gap (the list's scrollbar sits in the last 8 units of the gap)
		lm.size_flags_vertical = Control.SIZE_EXPAND_FILL
		split.add_child(lm)
		var srow := K.hbox(8); srow.visible = pick; left.add_child(srow)
		var search := LineEdit.new(); search.placeholder_text = T.call("search"); search.clear_button_enabled = true
		search.custom_minimum_size = Vector2(80, 30); search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search.text = String(S["q"]); search.tooltip_text = T.call("search")
		srow.add_child(search)
		var sort_btn := K.button("", Callable(), false, true)
		if K.text_scale >= 1.4 or TBPanel.is_portrait(vs): sort_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; sort_btn.custom_minimum_size = Vector2(90, 28)      # wraps instead of widening the page
		srow.add_child(sort_btn)
		var fsc := ScrollContainer.new(); fsc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; fsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		fsc.custom_minimum_size = Vector2(0, 34); fsc.visible = pick; left.add_child(fsc)
		var fl := K.hbox(6); fsc.add_child(fl)
		var filters: Array = [["all", T.call("f_all")], ["powers", T.call("tier_powers")], ["regional", T.call("tier_regional")], ["minor", T.call("tier_minor")]] if pick else [["all", T.call("f_all")], ["near", T.call("f_near")], ["war", T.call("f_war")], ["ally", T.call("f_ally")]]
		var fchips := {}
		var cntl := K.label("", 13, K.DIM); cntl.visible = false; left.add_child(cntl)
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
			if nn == me and not pick: continue                    # the demo's list holds the other courts only
			var r := NationRow.new(nn, g.dname(nn), TBFlags.medal_of(g, nn), func(): (ui["select"] as Callable).call(nn, true))
			r.custom_minimum_size.y = row_h(portrait)
			r.rank = int(st["rank_p"][nn]); r.me = nn == me and not pick
			r.rel = g.get_rel(me, nn) if (me > 0 and nn != me and not pick) else (-2 if pick else -1)
			r.op = 100 if (nn == me and not pick) else opinion(g, me, nn)
			r.st_text = "" if pick else rel_text(g, me, nn, r.op)
			if seats.has(nn): r.seat = String(seats[nn])
			r.selected = nn == int(S["sel"])
			rows[nn] = r; names_l[nn] = g.dname(nn).to_lower()
			list.add_child(r)
			K.a11y(r, "%s, %d %s, #%d" % [g.dname(nn), int(st["prov"][nn]), T.call("lands").to_lower(), r.rank], "button")
		# ---- detail column
		var right := ScrollContainer.new(); right.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; right.follow_focus = true; right.scroll_deadzone = 12
		right.size_flags_vertical = Control.SIZE_EXPAND_FILL; right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hide_scrollbar(right)
		var rm := MarginContainer.new()
		rm.add_theme_constant_override("margin_left", 18 if not portrait else 0); rm.add_theme_constant_override("margin_right", 0)
		rm.add_theme_constant_override("margin_top", 0); rm.add_theme_constant_override("margin_bottom", 0)
		rm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dv := K.vbox(0); dv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rm.add_child(dv); right.add_child(rm)
		if not portrait:
			var vr := ColorRect.new(); vr.color = TBTokens.BZ_PANE_LINE if not TBTokens.is_hc() else TBTokens.c("rule"); vr.custom_minimum_size = Vector2(1, 0); vr.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
			if not pick: ord = ord.filter(func(x: int) -> bool: return rows.has(x))
			if key == "army": ord.sort_custom(func(a: int, b: int) -> bool: return st["army"][a] > st["army"][b] if st["army"][a] != st["army"][b] else a < b)
			elif key == "name": ord.sort_custom(func(a: int, b: int) -> bool: return names_l[a] < names_l[b])
			else: ord = st["by_p"].duplicate()
			if not pick and key == "prov":                          # the neighbours first, then the rest by size
				ord = ord.filter(func(x: int) -> bool: return rows.has(x))
				ord.sort_custom(func(a: int, b: int) -> bool:
					var ka: int = (1000000 if near.has(a) else 0) + int(st["prov"][a]); var kb: int = (1000000 if near.has(b) else 0) + int(st["prov"][b])
					return ka > kb if ka != kb else a < b)
			var shown := 0
			for i in ord.size():
				var nn2: int = ord[i]
				var r2: NationRow = rows[nn2]
				list.move_child(r2, i + 1)
				var by_army: bool = key == "army" or not pick                    # the demo's rows always show the army; the pick list shows lands unless sorted by army
				r2.set_figure(K.fmt(float(st["army"][nn2])) if by_army else str(int(st["prov"][nn2])), T.call("cap_army") if by_army else T.call("cap_lands"))
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
			cntl.visible = pick and shown != st["ids"].size()
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
			var first_n: int = int(st["by_p"][0])
			for c in list.get_children():
				if c is NationRow and c.visible: first_n = (c as NationRow).n; break
			(ui["select"] as Callable).call(first_n, false)
	# =========================================================================================================================================
	ui["select"] = func(n: int, push: bool) -> void:
		S["sel"] = n
		if push and on_fly.is_valid(): on_fly.call(n)
		for k in rows: (rows[k] as NationRow).selected = (k == n)
		var dv: VBoxContainer = ui["detail_box"]
		for c in dv.get_children(): c.queue_free()
		_card(dv, g, n, st, {"h": h, "parent": parent, "on_goto": on_goto, "pick": pick, "wide": false, "on_cmd": on_cmd, "taken": taken, "me": me,
			"on_select": func(o: int) -> void:
				(ui["select"] as Callable).call(o, true)
				if rows.has(o): (ui["list_scroll"] as ScrollContainer).ensure_control_visible.call_deferred(rows[o]),
			"refresh": func():
				for k2 in rows:
					var rr: NationRow = rows[k2]
					rr.rel = g.get_rel(me, k2) if (me > 0 and k2 != me and not pick) else (-2 if pick else -1)
					rr.op = 100 if (k2 == me and not pick) else opinion(g, me, k2)
					rr.st_text = "" if pick else rel_text(g, me, k2, rr.op)
					rr.queue_redraw()
				(ui["select"] as Callable).call(S["sel"], false)})
		if portrait and push:
			S["detail"] = true
			(ui["master"] as Control).visible = false; (ui["detail_scroll"] as Control).visible = true
			h.set_title(g.dname(n))
		_footer(h, g, n, pick, taken, on_goto, on_play, opts)
		# the room the columns have: the window's most (TBPanel.avail_h) less what surrounds them (header, tabs, footer, padding); a card taller than that scrolls inside it
		var cap_fn := func() -> float:
			if not h.is_open(): return 100000.0
			return maxf(120.0, TBPanel.avail_h(h) - (h.card.get_combined_minimum_size().y - content.get_combined_minimum_size().y))      # from minimum sizes: it must not change when the columns are resized
		h.on_forced = func(forced: bool) -> void:               # the player set the height: the card scrolls inside it instead of keeping the height of its whole content
			if is_instance_valid(ui["detail_scroll"]): (ui["detail_scroll"] as ScrollContainer).custom_minimum_size.y = 120.0 if forced else minf(maxf(470.0, float(ui.get("full_h", 470.0))), float(cap_fn.call()))
			if not portrait: content.custom_minimum_size = Vector2(0, 120.0 if forced else minf(470.0, float(cap_fn.call())))
		if not ph0:                                             # the panel is as tall as the demo's card (min 470); the extras below it scroll
			var dsc: ScrollContainer = ui["detail_scroll"]
			var dv2: VBoxContainer = ui["detail_box"]
			dv2.get_tree().process_frame.connect(func() -> void:
				if not is_instance_valid(dv2) or not h.is_open(): return
				var de: int = dv2.get_child_count() if not ph0 else int(dv2.get_meta("demo_end", dv2.get_child_count()))       # desktop: the whole card (intel, facts, allies too) is in the room, nothing scrolls
				var hh := 0.0
				for i in mini(de, dv2.get_child_count()): hh += (dv2.get_child(i) as Control).size.y
				ui["full_h"] = hh
				var cap: float = cap_fn.call()
				dsc.custom_minimum_size.y = 120.0 if h.user_size.y > 0.0 else minf(maxf(470.0, hh), cap)
				if not portrait: content.custom_minimum_size = Vector2(0, 120.0 if h.user_size.y > 0.0 else minf(470.0, cap))
				TBPanel._fit_bz(h), CONNECT_ONE_SHOT)
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
	if ph0:                                                      # a phone in landscape: the panel is the full height (the demo's `height:100%`), the columns scroll inside it
		var fit_h := func() -> void:
			if not h.is_open(): return
			var chrome: float = h.card.size.y - content.size.y                      # head, tabs, body padding, footer: everything around the columns
			content.custom_minimum_size = Vector2(0, maxf(120.0, vs.y - 16.0 - 2.0 - chrome))
			TBPanel._fit_bz(h)
		parent.get_tree().process_frame.connect(fit_h, CONNECT_ONE_SHOT)
	h.on_back = func() -> bool:
		if portrait and bool(S["detail"]):
			S["detail"] = false
			(ui["master"] as Control).visible = true; (ui["detail_scroll"] as Control).visible = false
			h.set_title(T.call("nations"))
			h.clear_actions()
			return true
		return false
	build_list.call()
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
		show.queue_free()                                                       # "Show on map" lives in the card header (the demo's nations panel has no footer)

# ---- nation card (right pane): nationBody of the demo --------------------------------------------------------------------------------------
## a scroll container that scrolls (wheel, drag, keys) but draws no bar and takes no width
static func _hide_scrollbar(sc: ScrollContainer) -> void:
	var sb: VScrollBar = sc.get_v_scroll_bar()
	for st in ["scroll", "scroll_focus", "grabber", "grabber_highlight", "grabber_pressed"]: sb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	sb.custom_minimum_size = Vector2.ZERO
	sb.modulate.a = 0.0

static func _cap(txt: String, top: float = 14.0, bottom: float = 6.0) -> Control:
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", int(top)); m.add_theme_constant_override("margin_bottom", int(bottom))
	m.add_child(K.wrappable(K.caps(txt))); return m

static func _pad(c: Control, top: float = 0.0, bottom: float = 0.0) -> Control:
	var m := MarginContainer.new(); m.add_theme_constant_override("margin_top", int(top)); m.add_theme_constant_override("margin_bottom", int(bottom))
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL; m.add_child(c); return m

static func _card(v: VBoxContainer, g: TBGame, n: int, st: Dictionary, ctx: Dictionary) -> void:
	var me: int = ctx["me"]
	var pick: bool = ctx["pick"]
	var ph: bool = K.is_phone(v)
	var rel := g.get_rel(me, n) if (n != me and me > 0) else -1
	var op: int = opinion(g, me, n)
	v.add_theme_constant_override("separation", 0)
	# header: the flag medal, the name (Cinzel 21 / 1.05, tracked .06), the ruler in italic, the standing chip
	var top := K.hbox(14); v.add_child(top)
	var medal := TBNationParts.FlagMedal.new(TBFlags.medal_of(g, n), 64.0 if ph else 80.0)
	if not pick and (ctx["on_goto"] as Callable).is_valid():      # tapping the flag shows the nation on the map (the demo has no button for it)
		medal.mouse_filter = Control.MOUSE_FILTER_STOP; medal.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		medal.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT: (ctx["h"] as TBPanel.Handle).close(); (ctx["on_goto"] as Callable).call(n))
		K.a11y(medal, T.call("goto"), "button")
	top.add_child(medal)
	var tv := K.vbox(0); tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER; top.add_child(tv)
	var nsz: int = 17 if ph else 21
	var nl := K.wrappable(K.title(g.dname(n), nsz, Color.TRANSPARENT, 0.06, nsz * 1.05)); tv.add_child(nl)
	if g.rules >= 1 and g.r_name[n] != "":
		tv.add_child(_pad(K.para_bz("[i]%s %s[/i]" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n)], 15.0, 1.25), 3.0))
	var chips := TBPanel.flow(6); tv.add_child(_pad(chips, 7.0))
	if pick:
		var rt := start_rating(g, n, st)
		chips.add_child(rating_chip(rt))
		if (ctx["taken"] as Array).has(n): chips.add_child(K.chip(T.call("taken_other"), "lock", "warn"))
	elif n == me: chips.add_child(K.chip(T.call("you"), "", "own"))
	else:
		var tone: String = "pos" if op > 20 else ("neg" if op < -20 else "neutral")
		chips.add_child(K.chip("%s %s%d" % [rel_text(g, me, n, op), "+" if op > 0 else "", op] if rel != 1 else rel_text(g, me, n, op), "", tone))
	if pick: v.add_child(_pad(K.para_bz("[i]%s[/i]" % rating_reason(start_rating(g, n, st)), 16.0, 1.3), 8.0))
	# relations bar and the three cells
	if not pick and n != me and me > 0:
		v.add_child(_cap(T.call("cap_relations"), 14.0, 2.0))
		v.add_child(TBNationParts.RelBar.new(float(op), rel_color(op)))
	var cells := K.hbox(8); cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cells.add_child(TBNationParts.StatCell.new("army", K.fmt(float(st["army"][n])), T.call("cap_army")))
	cells.add_child(TBNationParts.StatCell.new("gold", K.fmt(float(g.income(n)["gold"])), T.call("cap_economy")))
	var tr_txt := "—"
	if n != me and me > 0 and g.rules >= 1 and TBTrade.has(g, me, n): tr_txt = "+%d" % TBTrade.value(g, n)
	cells.add_child(TBNationParts.StatCell.new("trade", tr_txt, T.call("cap_trade")))
	v.add_child(_pad(cells, 6.0 if (not pick and n != me) else 14.0, 10.0))
	# the one-line note
	var note := ""
	if n != me and me > 0:
		if rel == 1: note = "%s %d%% / %d%%" % [T.call("war_score"), g.war_score[me * g.N1 + n], g.war_score[n * g.N1 + me]]
		elif g.has_truce(me, n): note = T.call("truce_left", {"n": g.truce[me * g.N1 + n] - g.turn})
		elif rel == 3: note = T.call("rel_ally")
	if note == "": note = "%s: %s" % [T.call("attitude"), T.call("pers_" + TBData.PERSONALITIES[g.personality[n]]["id"])]
	v.add_child(K.para_bz("[i]%s[/i]" % note, 16.0, 1.3))
	if not pick and n != me and me > 0: _actions(v, g, n, ctx, rel)
	_facts(v, g, n, st, ctx, rel)

## everything else the game knows about a nation, in the demo's leader rows
static func _facts(v: VBoxContainer, g: TBGame, n: int, st: Dictionary, ctx: Dictionary, rel: int) -> void:
	var me: int = ctx["me"]
	var pick: bool = ctx["pick"]
	var rows: Array = [
		[T.call("lands"), "%d · #%d" % [int(st["prov"][n]), int(st["rank_p"].get(n, 0))], 0],
		[T.call("total_army"), "%s · #%d" % [K.fmt(float(st["army"][n])), int(st["rank_a"].get(n, 0))], 0],
		[T.call("govt"), T.call("g_" + TBData.REGIME_ID[g.regime[n]]), 0],
		[T.call("tech"), "%s %.1f · #%d" % [T.call("era_name_%d" % g.era[n]), g.tech_level[n], int(st["rank_t"].get(n, 0))], 0]]
	if g.rules >= 1 and g.r_name[n] != "":
		rows.append([T.call("skill_adm") + " / " + T.call("skill_dip") + " / " + T.call("skill_mil"), "%d / %d / %d" % [g.r_adm[n], g.r_dip[n], g.r_mil[n]], 0])
	if not pick:
		if n == me: rows.append([T.call("income_net"), K.signed(float(g.income(n)["net"])), 1 if g.income(n)["net"] >= 0 else -1])
		if g.rules >= 1 and g.infamy[n] >= 1.0: rows.append([T.call("infamy"), "%.0f%s" % [g.infamy[n], ("  " + T.call("coalition")) if g.coalition[n] != 0 else ""], -1])
		if n != me and me > 0:
			if g.rules >= 1 and rel != 1:
				var cbk := TBDiplo.cb(g, me, n)
				rows.append([T.call("cb"), T.call("cb_" + cbk) if cbk != "" else "%s (+%d %s)" % [T.call("cb_none"), int(TBDiplo.NO_CB_INFAMY), T.call("infamy")], 1 if cbk != "" else 0])
			rows.append([T.call("grudge"), "%d" % g.grudge[n * g.N1 + me], 0])
	v.add_child(_cap(T.call("facts"), 14.0, 6.0))
	v.add_child(K.fxl(rows, 2 if bool(ctx["wide"]) else 0))
	# who they stand with and against: flag and name, like the list
	TBRealmScreen.add_relations(v, g, n, func(o: int): (ctx["on_select"] as Callable).call(o), 6)

## the demo's actBtns(): relations, the court's reasons, then the diplomacy buttons (two columns, war in red across both), then intel
static func _actions(v: VBoxContainer, g: TBGame, n: int, ctx: Dictionary, rel: int) -> void:
	var me: int = ctx["me"]
	var on_cmd: Callable = ctx["on_cmd"]
	var parent: Control = ctx["parent"]
	var refresh: Callable = ctx["refresh"]
	var dp: float = g.dp[me]
	var dpw := func(cost: int) -> String: return "" if dp >= float(cost) else T.call("err_dp")
	var done := func(cmd: Dictionary) -> void:
		on_cmd.call(cmd); refresh.call()
	var ai: bool = g.human[n] == 0
	var vw := {}
	if ai:
		vw = {"nap": TBDipView.pact(g, n, me, D.REL_NAP), "ally": TBDipView.pact(g, n, me, D.REL_ALLY), "trade": TBDipView.trade(g, n, me),
			"white": TBDipView.peace(g, n, me, "white"), "cede": TBDipView.peace(g, n, me, "cede"), "vassal": TBDipView.peace(g, n, me, "vassal")}
	# a request to an AI court (rules >= 1): one press sends it, the likelihood is on the button, the answer comes with the next turn (TBAsks)
	var asking: bool = ai and g.rules >= 1
	var pend: Dictionary = TBAsks.find(g, me, n) if asking else {}
	var pend_spy: bool = not TBAsks.find(g, me, n, true).is_empty() if asking else false
	# why they feel this way: the terms of the court's sum for the request that matters most right now
	if ai and rel in [0, 1, 2]:
		var lead: String = "white" if rel == 1 else ("nap" if rel == 0 else "ally")
		var view: Dictionary = vw[lead]
		v.add_child(_cap(T.call("dv_why"), 12.0, 6.0))
		var items: Array = []
		var cum := 0.0; var shown_cum := 0
		for term in view["terms"]:
			cum += float(term[1])
			var cur: int = int(roundf(cum * 100.0)); var step: int = cur - shown_cum; shown_cum = cur
			if step != 0: items.append([T.call(String(term[0])), "%s%d" % ["+" if step > 0 else "−", absi(step)], 1 if step > 0 else -1])
		if String(view["blocked"]) != "": items.append([T.call("dvb_" + String(view["blocked"])), "✕", -1])
		items.append([T.call("dv_total"), "%s / %s" % [TBNegotiate._fmt(float(view["score"]), float(view["need"])), TBNegotiate._fmt(float(view["need"]))], 1 if bool(view["ok"]) else -1])
		v.add_child(K.fxl(items))
	v.add_child(_cap(T.call("diplomacy"), 14.0, 6.0))
	var narrow: bool = (parent.size.x if parent.size.x > 1.0 else parent.get_viewport_rect().size.x) < 480.0          # a portrait phone: one button per row, two would be wider than the screen
	var acts := GridContainer.new(); acts.columns = 1 if narrow else 2
	acts.add_theme_constant_override("h_separation", 8); acts.add_theme_constant_override("v_separation", 8); acts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(acts)
	var add_btn := func(label: String, icon: String, sub: String, cb: Callable, reason: String = "", tip: String = "") -> void:
		var b: Button = K.button(label, cb, false, false, icon, sub)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if tip != "": b.tooltip_text = tip
		if reason != "": K.disable(b, reason)
		acts.add_child(b)
	## a diplomatic request: `cmd` is the plain command (human courts, rules 0); an AI court gets an "ask" with its likelihood on the button
	var req := func(label: String, icon: String, kind: String, op: String, cost: int, off: String, cmd: Dictionary) -> void:
		if not asking:
			add_btn.call(label, icon, "%d ✉" % cost if cost > 0 else "", func(): done.call(cmd), off); return
		var mine: bool = not pend.is_empty() and String(pend["kind"]) == kind and String(pend["op"]) == op
		var reason: String = off
		if mine: reason = T.call("ask_wait")
		elif not pend.is_empty(): reason = T.call("ask_other")
		elif reason == "":
			var chk: Dictionary = TBAsks.check(g, me, kind, n, op)
			if not bool(chk["ok"]) and String(chk["reason"]) != "":
				var ek: String = "err_" + String(chk["reason"])
				reason = T.call(ek) if TBI18n.has_key(ek) else String(chk["reason"])
		var pc: int = TBAsks.chance(g, me, kind, n, op)
		if reason == "" and pc == 0: reason = T.call("dvb_" + String(TBAsks.view(g, me, kind, n, op).get("blocked", "grudge")))
		add_btn.call(T.call("ask_proposed") if mine else label, icon, T.call("ask_next") if mine else "%d%%" % pc,
			func(): done.call({"cmd": "ask", "kind": kind, "t": n, "op": op}), reason, "" if reason != "" else T.call("ask_tip", {"c": cost}))
	if rel == 1:
		var ws: int = g.war_score[me * g.N1 + n]
		req.call(T.call("dip_peace"), "flag", "peace", "white", D.DP_PEACE, dpw.call(D.DP_PEACE), {"cmd": "peace", "t": n, "kind": "white"})
		req.call(T.call("dip_land"), "flag", "peace", "cede", 0, "" if ws >= 25 else T.call("err_warscore") + " (25%)", {"cmd": "peace", "t": n, "kind": "cede"})
		if g.rules >= 1: req.call(T.call("dip_vassal"), "crown", "peace", "vassal", 0, "" if ws >= 50 else T.call("err_warscore") + " (50%)", {"cmd": "peace", "t": n, "kind": "vassal"})
	else:
		if rel == 0:
			req.call(T.call("dip_nap"), "pact", "nap", "", D.DP_NAP, dpw.call(D.DP_NAP), {"cmd": "nap", "t": n})
			req.call(T.call("dip_ally"), "star", "ally", "", D.DP_ALLY, dpw.call(D.DP_ALLY), {"cmd": "ally", "t": n})
		if TBDiplo.can_marry(g, me, n):
			req.call(T.call("dip_marry"), "heart", "marry", "", TBDiplo.DP_MARRY, dpw.call(TBDiplo.DP_MARRY), {"cmd": "marry", "t": n})
		if g.rules >= 1:
			if TBTrade.has(g, me, n): add_btn.call(T.call("dip_close"), "trade", "", func(): done.call({"cmd": "cancelTrade", "t": n}))
			else: req.call(T.call("dip_trade"), "trade", "trade", "", TBTrade.DP_COST, dpw.call(TBTrade.DP_COST), {"cmd": "trade", "t": n})
		if rel == 2 or rel == 3:
			add_btn.call(T.call("dip_break"), "close", "", func():
				TBPanel.confirm(parent, T.call("confirm_break_t", {"a": g.dname(n)}), T.call("confirm_break_b"), T.call("break_pact"), func(): done.call({"cmd": "breakPact", "t": n})))
	if rel != 1:
		var why: String = dpw.call(D.DP_WAR)
		var wb: Button = K.danger(T.call("dip_war"), func():
			TBModals.war_confirm(parent, g, n, func(): done.call({"cmd": "declareWar", "t": n})), "war")
		(wb as TBBz.Btn).sub = "%d ✉" % D.DP_WAR
		wb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if why != "": K.disable(wb, why)
		var wrap := K.vbox(0); wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL; wrap.add_child(wb)
		v.add_child(_pad(wrap, 8.0))
	v.set_meta("demo_end", v.get_child_count())                     # everything above is the demo's card; what follows (intel, facts, allies) scrolls below it
	# intel
	if g.rules >= 1:
		v.add_child(_cap("%s  ·  %s %.0f" % [T.call("spy_title"), T.call("hud_intel"), g.intel[me]], 14.0, 6.0))
		var sp := GridContainer.new(); sp.columns = 1 if narrow else 2
		sp.add_theme_constant_override("h_separation", 8); sp.add_theme_constant_override("v_separation", 8); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(sp)
		for op in ["steal", "sabotage", "incite"]:
			var cost: float = TBCommands.SPY_COST[op]
			var reason := ""
			if g.friendly(me, n): reason = T.call("err_ally")
			elif g.intel[me] < cost: reason = T.call("err_intel")
			var o: String = op
			var sub: String = "%d" % int(cost)
			if asking:
				sub += " · %d%%" % TBAsks.chance(g, me, "spy", n, o)
				if pend_spy: reason = T.call("ask_spy_wait")
			var sb: Button = K.button(T.call("spy_" + op), func(): done.call({"cmd": "ask", "kind": "spy", "t": n, "op": o} if asking else {"cmd": "spy", "t": n, "op": o}), false, false, "spy", sub)
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if reason != "": K.disable(sb, reason)
			sp.add_child(sb)


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
