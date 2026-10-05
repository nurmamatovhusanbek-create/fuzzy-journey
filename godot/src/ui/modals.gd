## Modal dialogs: era picker, nations list, budget, settings, save/load, game over.
class_name TBModals
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
static var T: Callable = TBI18n.T
const ERAS := ["modern", "ancient", "roman", "medieval", "mongol", "timurid", "discovery", "gunpowder", "napoleonic", "victorian", "ww1", "ww2", "coldwar"]
const ERA_YEAR := {"ancient": -218, "roman": 117, "medieval": 1096, "mongol": 1300, "timurid": 1400, "discovery": 1492, "gunpowder": 1700, "napoleonic": 1804, "victorian": 1850, "ww1": 1914, "ww2": 1939, "coldwar": 1947, "modern": 2024}

static func close(m: Control) -> void:
	if is_instance_valid(m): m.queue_free()

static func era_picker(parent: Control, difficulty: String, on_start: Callable, on_back: Callable) -> void:
	var st := {"era": "modern", "diff": difficulty}
	var portrait := parent.get_viewport_rect().size.y > parent.get_viewport_rect().size.x
	var m := K.modal(parent, T.call("choose_era"), 520 if portrait else 820, "hourglass")
	var body := BoxContainer.new(); body.vertical = portrait; body.add_theme_constant_override("separation", 22)
	m[1].add_child(body)
	# ---- chronology rail
	var rail := VBoxContainer.new(); rail.add_theme_constant_override("separation", 0); rail.custom_minimum_size = Vector2(300 if not portrait else 0, 0)
	body.add_child(rail)
	var rows := {}
	var name_l := K.title("", 26); name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var year_l := K.num("", 15, K.DIM)
	var blurb := K.label("", 15, K.TEXT); blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; blurb.custom_minimum_size = Vector2(240, 0)
	var powers := K.label("", 13, K.DIM); powers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; powers.custom_minimum_size = Vector2(240, 0)
	var show := func(id: String):
		st["era"] = id
		for k in rows: rows[k].selected = (k == id); rows[k].queue_redraw()
		name_l.text = T.call("era_" + id)
		var y: int = ERA_YEAR[id]
		year_l.text = ("%d BC" % -y) if y < 0 else ("%d AD" % y)
		blurb.text = T.call("blurb_" + id)
		powers.text = _era_facts(id)
	var order := ERAS.duplicate()
	order.sort_custom(func(a, b): return ERA_YEAR[a] < ERA_YEAR[b])      # chronological, modern last
	for i in order.size():
		var id: String = order[i]
		var y: int = ERA_YEAR[id]
		var r := TBMenuParts.EraRow.new(("%d BC" % -y) if y < 0 else ("%d AD" % y), T.call("era_" + id))
		r.first = i == 0; r.last = i == order.size() - 1
		r.pressed.connect(func(): show.call(id))
		rail.add_child(r); rows[id] = r
	# ---- detail
	var det := K.vbox(10); det.size_flags_horizontal = Control.SIZE_EXPAND_FILL; det.custom_minimum_size = Vector2(240, 0)
	body.add_child(det)
	det.add_child(year_l); det.add_child(name_l); det.add_child(K.ornament()); det.add_child(blurb)
	det.add_child(K.section(T.call("great_powers"))); det.add_child(powers)
	var fill := Control.new(); fill.size_flags_vertical = Control.SIZE_EXPAND_FILL; fill.custom_minimum_size = Vector2(0, 6); det.add_child(fill)
	var fv := K.vbox(8); fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL; m[2].add_child(fv)
	fv.add_child(K.section(T.call("difficulty")))
	fv.add_child(K.segmented([["easy", T.call("easy")], ["normal", T.call("normal")], ["hard", T.call("hard")]], difficulty, func(id: String): st["diff"] = id))
	var row := K.hbox(8); fv.add_child(row)
	row.add_child(K.button(T.call("back"), func(): close(m[0]); on_back.call()))
	var go := K.button(T.call("new_game"), func(): close(m[0]); on_start.call(st["era"], st["diff"]), true)
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(go)
	show.call("modern")

## "-40 gold · stability -8" summary of scheduled-event effects
static func fx_text(effects: Array) -> String:
	var parts: PackedStringArray = []
	for e in effects:
		var op := String(e.get("op", "")).trim_prefix("nation.")
		var d := float(e.get("delta", 0))
		if op == "dev": parts.append(T.call("fx_dev")); continue
		if d == 0.0 or not TBI18n.has_key("fx_" + op): continue
		var ds := "%+d" % int(d) if op != "combat" else "%+d%%" % int(d)
		parts.append(T.call("fx_" + op, {"d": ds.replace("-", "−"), "t": int(e.get("turns", 6))}))
	return " · ".join(parts)

## Statistics: history of the leading powers
static func statistics(parent: Control, g: TBGame, on_list: Callable) -> void:
	var m := K.modal(parent, T.call("statistics"), 620, "scales")
	m[1].add_child(K.segmented([["list", T.call("dk_nations")], ["stats", T.call("statistics")]], "stats", func(id: String): if id == "list": close(m[0]); on_list.call()))
	var st := {"key": "p"}
	var chart := TBStatChart.new(); chart.custom_minimum_size = Vector2(0, 250)
	chart.x_label = func(t: float) -> String:
		var mo := g.start_month + int(t) * 6
		var y := g.start_year + mo / 12
		return ("%d BC" % -y) if y < 0 else str(y)
	var legend := HFlowContainer.new(); legend.add_theme_constant_override("h_separation", 14); legend.add_theme_constant_override("v_separation", 4)
	var draw := func():
		var feats := TBStats.featured(g, 6)
		chart.series = []
		for c in legend.get_children(): c.queue_free()
		for n in feats:
			var col := Color.hex((g.color[n] << 8) | 0xFF).lightened(0.15)
			if n == g.human_id: col = K.GOLD2
			chart.series.append({"name": g.dname(n), "color": col, "pts": TBStats.series(g, n, st["key"]), "bold": n == g.human_id})
			var it := K.hbox(5)
			var sw := ColorRect.new(); sw.color = col; sw.custom_minimum_size = Vector2(12, 3); sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER; it.add_child(sw)
			it.add_child(K.label(g.dname(n), 12, K.GOLD2 if n == g.human_id else K.TEXT))
			legend.add_child(it)
		chart.queue_redraw()
	m[1].add_child(K.segmented([["p", T.call("hud_prov")], ["a", T.call("army")], ["g", T.call("gold")], ["k", T.call("tech")]], "p", func(id: String): st["key"] = id; draw.call()))
	m[1].add_child(chart); m[1].add_child(legend)
	if g.stats.size() < 2: m[1].add_child(K.label(T.call("stats_wait"), 13, K.DIM))
	draw.call()
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

static var _facts_cache := {}
## "N nations · A, B, C" for an era (largest powers by province count)
static func _era_facts(id: String) -> String:
	if _facts_cache.has(id + TBI18n.lang): return _facts_cache[id + TBI18n.lang]
	var out := ""
	if id != "modern":
		var era := TBWorld.load_era("res://data", id)
		if not era.is_empty():
			var cnt := {}
			for o in era["owner"]: if int(o) > 0: cnt[int(o)] = cnt.get(int(o), 0) + 1
			var ks := cnt.keys()
			ks.sort_custom(func(a, b): return cnt[a] > cnt[b])
			var names: Array = []
			for k in ks:
				var nm := String(era["nations"][int(k) - 1]["name"])
				if nm.to_lower().contains("hunter") or nm.to_lower().contains("farmers") or nm.to_lower().contains("pastoral") or nm.to_lower().contains("cultures") or nm.to_lower().contains("minor"): continue
				names.append(nm)
				if names.size() >= 4: break
			out = "%s\n%s" % [", ".join(names), T.call("n_nations", {"n": era["nations"].size()})]
	else:
		out = T.call("n_nations", {"n": 250})
	_facts_cache[id + TBI18n.lang] = out
	return out

static func nations(parent: Control, g: TBGame, on_pick: Callable, only_wars: bool = false, tabs: bool = true) -> void:
	var m := K.modal(parent, T.call("nations"), 480, "globe")
	if not only_wars and tabs:
		m[1].add_child(K.segmented([["list", T.call("dk_nations")], ["stats", T.call("statistics")]], "list", func(id: String): if id == "stats": close(m[0]); statistics(parent, g, func(): nations(parent, g, on_pick))))
	var search := LineEdit.new(); search.placeholder_text = T.call("search"); search.custom_minimum_size = Vector2(0, K.MIN_TOUCH)
	m[1].add_child(search)
	var list := K.vbox(2); m[1].add_child(list)
	var rows: Array = []
	for n in range(1, g.N1):
		if g.alive[n] != 0 and (not only_wars or g.get_rel(g.human_id, n) == 1): rows.append(n)
	rows.sort_custom(func(a, b): return g.own_count(a) > g.own_count(b) if g.own_count(a) != g.own_count(b) else a < b)
	var draw := func(q: String):
		for c in list.get_children(): c.queue_free()
		var shown := 0
		for n in rows:
			if q != "" and not g.dname(n).to_lower().contains(q.to_lower()): continue
			var rel := g.get_rel(g.human_id, n)
			var nat_col := K.RED.lightened(0.25) if rel == 1 else (Color(0.55, 0.72, 1.0) if rel == 3 else K.TEXT)
			var b := K.list_row(g.dname(n), str(g.own_count(n)), func(): close(m[0]); on_pick.call(n), nat_col)
			list.add_child(b)
			shown += 1
			if shown >= 60: break
	search.text_changed.connect(draw)
	draw.call("")
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

static func budget(parent: Control, g: TBGame, on_change: Callable) -> void:
	var m := K.modal(parent, T.call("budget"), 460, "coins")
	var n := g.human_id
	var keys := ["tax", "goods", "research", "invest"]
	var sliders := []
	var labels := []
	var sync := func():
		for i in 4:
			sliders[i].set_value_no_signal(g.budget[n * 4 + i]); labels[i].text = "%s  %d%%" % [T.call(keys[i]), g.budget[n * 4 + i]]
	for i in 4:
		var l := K.label("", 15); m[1].add_child(l); labels.append(l)
		var s := HSlider.new(); s.min_value = 0; s.max_value = 100; s.step = 1; s.custom_minimum_size = Vector2(0, 30)
		var idx := i
		s.value_changed.connect(func(v: float):
			g.apply({"cmd": "budget", "n": n, "key": keys[idx], "val": int(v)}); sync.call(); on_change.call())
		m[1].add_child(s); sliders.append(s)
	sync.call()
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

static func settings(parent: Control, cfg: Dictionary, on_change: Callable, on_menu: Callable) -> void:
	var m := K.modal(parent, T.call("settings"), 440, "gear")
	_segment(m[1], T.call("quality"), [["auto", T.call("q_auto_s")], ["low", T.call("q_low")], ["medium", T.call("q_medium")], ["high", T.call("q_high")]], cfg["quality"], func(v): cfg["quality"] = v; on_change.call())
	_segment(m[1], T.call("language"), [["en", "English"], ["ru", "Русский"]], cfg["lang"], func(v): cfg["lang"] = v; on_change.call())
	_segment(m[1], T.call("map_view"), [["globe", T.call("globe")], ["flat", T.call("flat")]], cfg["view"], func(v): cfg["view"] = v; on_change.call())
	_segment(m[1], T.call("map_style"), [["standard", T.call("style_standard")], ["parchment", T.call("style_parchment")]], cfg.get("theme", "standard"), func(v): cfg["theme"] = v; on_change.call())
	_segment(m[1], T.call("sound"), [["1", T.call("on")], ["0", T.call("off")]], "1" if cfg.get("sound", true) else "0", func(v): cfg["sound"] = (v == "1"); on_change.call())
	_segment(m[1], T.call("ui_size"), [["small", T.call("ui_small")], ["normal", T.call("ui_normal")], ["large", T.call("ui_large")]], cfg.get("ui", "normal"), func(v): cfg["ui"] = v; on_change.call())
	m[1].add_child(K.button(T.call("tut_help"), func(): close(m[0]); tutorial(parent, func(): pass)))
	var row := K.hbox(8); m[1].add_child(row)
	if on_menu.is_valid(): row.add_child(K.button(T.call("title"), func(): close(m[0]); on_menu.call()))
	var bk := K.button(T.call("back"), func(): close(m[0]), true); bk.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(bk)

static func _segment(parent: Control, title: String, items: Array, current: String, cb: Callable) -> void:
	parent.add_child(K.section(title))
	parent.add_child(K.segmented(items, current, cb))

static func save_load(parent: Control, saving: bool, on_save: Callable, on_load: Callable) -> void:
	var m := K.modal(parent, T.call("save") if saving else T.call("load"), 460)
	for slot in ["auto", "1", "2", "3"]:
		var meta := TBSave.meta(slot)
		var row := K.hbox(6); m[1].add_child(row)
		var name: String = T.call("autosave") if slot == "auto" else "#" + slot
		var info: String = name + " · " + (("%s · %s %d" % [meta["nation"], T.call("turn"), meta["turn"]]) if not meta.is_empty() else T.call("empty_slot"))
		var l := K.label(info, 14); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
		if saving and slot != "auto": row.add_child(K.button(T.call("save"), func(): on_save.call(slot); close(m[0])))
		if not saving and not meta.is_empty(): row.add_child(K.button(T.call("load"), func(): close(m[0]); on_load.call(slot)))
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

## detailed nation card with diplomacy actions; on_cmd(cmd Dictionary), on_goto(n)
static func nation_detail(parent: Control, g: TBGame, n: int, on_cmd: Callable, on_goto: Callable) -> void:
	var me := g.human_id
	var m := K.modal(parent, g.dname(n), 460)
	var v: VBoxContainer = m[1]
	v.add_child(TBFlags.chip(g, n, 1.1))
	v.move_child(v.get_child(v.get_child_count() - 1), 0)
	var rel := g.get_rel(me, n) if n != me else -1
	var army := 0
	for p in g.owned(n): army += g.army[p]
	if g.rules >= 1 and g.r_name[n] != "":
		var rl := K.label("%s %s · %s" % [T.call(TBRulers.title_key(g, n)), TBRulers.display_name(g, n), T.call("ruler_age", {"a": TBRulers.age(g, n)})], 15, K.GOLD2)
		v.add_child(rl)
		var sk := K.label("%s %d · %s %d · %s %d" % [T.call("skill_adm"), g.r_adm[n], T.call("skill_dip"), g.r_dip[n], T.call("skill_mil"), g.r_mil[n]], 13, K.DIM)
		v.add_child(sk)
		var tr: String = TBRulers.TRAITS[g.r_trait[n]]
		if tr != "none":
			var tl := K.label("%s — %s" % [T.call("rtr_" + tr), T.call("rtr_%s_d" % tr)], 13, K.DIM)
			tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.custom_minimum_size = Vector2(400, 0)
			v.add_child(tl)
	var grid := GridContainer.new(); grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	v.add_child(grid)
	var rel_key := ["rel_peace", "rel_war", "rel_nap", "rel_ally", "rel_marriage"]
	var rows := [
		[T.call("lands"), str(g.own_count(n))], [T.call("total_army"), K.fmt(army)],
		[T.call("govt"), T.call("g_" + TBData.REGIME_ID[g.regime[n]])], [T.call("tech"), "%s · %.1f" % [T.call("era_name_%d" % g.era[n]), g.tech_level[n]]],
		[T.call("attitude"), T.call("pers_" + TBData.PERSONALITIES[g.personality[n]]["id"])]]
	if n == me:
		var inc := g.income(n)
		rows.append([T.call("income_net"), "%+d" % int(inc["net"])])
	if g.rules >= 1 and g.infamy[n] >= 1.0:
		rows.append([T.call("infamy"), "%.0f%s" % [g.infamy[n], ("  ⚠ " + T.call("coalition")) if g.coalition[n] != 0 else ""]])
	else:
		rows.append([T.call("relation"), T.call(rel_key[rel])])
		if g.rules >= 1 and rel != 1:
			var cbk := TBDiplo.cb(g, me, n)
			rows.append([T.call("cb"), T.call("cb_" + cbk) if cbk != "" else "%s (+%d %s)" % [T.call("cb_none"), int(TBDiplo.NO_CB_INFAMY), T.call("infamy")]])
		if rel == 1:
			rows.append([T.call("war_score"), "%d%% / %d%%" % [g.war_score[me * g.N1 + n], g.war_score[n * g.N1 + me]]])
		elif g.has_truce(me, n):
			rows.append([T.call("truce_left", {"n": g.truce[me * g.N1 + n] - g.turn}), ""])
		rows.append([T.call("grudge"), "%d" % g.grudge[n * g.N1 + me]])
		if g.rules >= 1 and TBTrade.has(g, me, n): rows.append([T.call("trade"), "+%d" % TBTrade.value(g, n)])
	for r in rows:
		grid.add_child(K.label(r[0], 13, K.DIM)); grid.add_child(K.label(r[1], 14))
	# allies / enemies lists
	var allies: Array = []; var enemies: Array = []
	for o in range(1, g.N1):
		if g.alive[o] == 0 or o == n: continue
		var r := g.get_rel(n, o)
		if r == 3: allies.append(g.dname(o))
		elif r == 1: enemies.append(g.dname(o))
	var info := func(title: String, arr: Array):
		var l := K.label("%s: %s" % [title, ", ".join(arr.slice(0, 6)) + (" …" if arr.size() > 6 else "") if not arr.is_empty() else T.call("none_yet")], 13, K.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(400, 0); v.add_child(l)
	info.call(T.call("allies"), allies); info.call(T.call("at_war_with"), enemies)
	var act := HFlowContainer.new(); act.add_theme_constant_override("h_separation", 6); act.add_theme_constant_override("v_separation", 6)
	v.add_child(act)
	if n != me:
		if rel == 1:
			act.add_child(K.button(T.call("white_peace"), func(): on_cmd.call({"cmd": "peace", "t": n, "kind": "white"}); close(m[0])))
			act.add_child(K.button(T.call("demand_land"), func(): on_cmd.call({"cmd": "peace", "t": n, "kind": "cede"}); close(m[0])))
			if g.rules >= 1: act.add_child(K.button(T.call("demand_vassal"), func(): on_cmd.call({"cmd": "peace", "t": n, "kind": "vassal"}); close(m[0])))
		else:
			var wb := K.button(T.call("declare_war"), func(): on_cmd.call({"cmd": "declareWar", "t": n}); close(m[0]))
			wb.add_theme_color_override("font_color", K.RED.lightened(0.3)); act.add_child(wb)
			if rel == 0:
				act.add_child(K.button(T.call("propose_nap"), func(): on_cmd.call({"cmd": "nap", "t": n}); close(m[0])))
				act.add_child(K.button(T.call("propose_ally"), func(): on_cmd.call({"cmd": "ally", "t": n}); close(m[0])))
			if TBDiplo.can_marry(g, me, n): act.add_child(K.button(T.call("marry_propose"), func(): on_cmd.call({"cmd": "marry", "t": n}); close(m[0])))
			if g.rules >= 1:
				if TBTrade.has(g, me, n): act.add_child(K.button(T.call("trade_cancel"), func(): on_cmd.call({"cmd": "cancelTrade", "t": n}); close(m[0])))
				else: act.add_child(K.button(T.call("trade_propose"), func(): on_cmd.call({"cmd": "trade", "t": n}); close(m[0])))
			if rel == 2 or rel == 3:
				act.add_child(K.button(T.call("break_pact"), func(): on_cmd.call({"cmd": "breakPact", "t": n}); close(m[0])))
	if n != me and g.rules >= 1:
		v.add_child(K.label("%s  (%s %.0f)" % [T.call("spy_title"), T.call("hud_intel"), g.intel[me]], 13, K.DIM))
		var sp := HFlowContainer.new(); sp.add_theme_constant_override("h_separation", 6); v.add_child(sp)
		for op in ["steal", "sabotage", "incite"]:
			var cost: float = TBGame.SPY_COST[op]
			var b := K.button("%s (%d)" % [T.call("spy_" + op), int(cost)], func(): on_cmd.call({"cmd": "spy", "t": n, "op": op}); close(m[0]))
			b.disabled = g.intel[me] < cost or g.friendly(me, n)
			sp.add_child(b)
	var row := K.hbox(8); v.add_child(row)
	row.add_child(K.button(T.call("back"), func(): close(m[0])))
	var go := K.button(T.call("goto"), func(): close(m[0]); on_goto.call(n), true); go.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(go)

## first-run guide: 6 short steps
static func tutorial(parent: Control, on_done: Callable) -> void:
	var step := [1]
	var m := K.modal(parent, T.call("tut_title"), 520)
	var title := K.title("", 20)
	var body := K.label("", 15); body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.custom_minimum_size = Vector2(460, 90)
	var pips := K.Pips.new(1, 7); pips.custom_minimum_size = Vector2(7 * 14, 18)
	m[1].add_child(pips); m[1].add_child(title); m[1].add_child(body)
	var row := K.hbox(8); m[1].add_child(row)
	var skip := K.button(T.call("tut_skip"), func(): close(m[0]); on_done.call())
	var next := K.button(T.call("tut_next"), Callable(), true); next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(skip); row.add_child(next)
	var draw := func():
		title.text = T.call("tut_%d_t" % step[0]); body.text = T.call("tut_%d_b" % step[0])
		pips.n = step[0]; pips.queue_redraw()
		next.text = T.call("tut_done") if step[0] == 7 else T.call("tut_next")
	next.pressed.connect(func():
		if step[0] >= 7: close(m[0]); on_done.call(); return
		step[0] += 1; draw.call())
	draw.call()

static func _loc(d: Variant) -> String:
	if d is Dictionary: return String(d.get(TBI18n.lang, d.get("en", "")))
	return String(d)

## event prompt with choices; on_choose(i) is called with the chosen index
static func event_prompt(parent: Control, e: Dictionary, on_choose: Callable, g: TBGame = null) -> void:
	if e["kind"] == "prop":
		var from_name: String = g.dname(int(e["from"])) if g != null else ""
		var mp := K.modal(parent, "", 480)
		var hl := K.label("🤝", 38, K.GOLD2); hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mp[1].add_child(hl)
		var tl := K.title(T.call("prop_title", {"a": from_name}), 22); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.custom_minimum_size = Vector2(420, 0); mp[1].add_child(tl)
		mp[1].add_child(K.ornament())
		var fl2 := K.label(T.call("prop_" + String(e["id"])), 15); fl2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; fl2.custom_minimum_size = Vector2(420, 0); fl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; mp[1].add_child(fl2)
		mp[1].add_child(K.choice_card(T.call("mp_accept"), "", func(): close(mp[0]); on_choose.call(0), true))
		mp[1].add_child(K.choice_card(T.call("mp_decline"), "", func(): close(mp[0]); on_choose.call(1)))
		return
	var rand: bool = e["kind"] == "rand"
	var id: String = e["id"]
	var title: String = T.call("ev_%s_t" % id) if rand else _loc(e.get("title", {}))
	var flavor: String = T.call("ev_%s_f" % id) if rand else _loc(e.get("flavor", {}))
	var m := K.modal(parent, "", 540)
	var ic := K.label(String(e.get("icon", "📜")), 40, K.GOLD2); ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; m[1].add_child(ic)
	var cat_key := "evcat_" + String(e.get("cat", "")).to_lower().replace(" ", "_")
	var kicker: String = T.call("ev_worldwide") if (not rand and e.get("world", false)) else (T.call("ev_event") if not rand else (T.call(cat_key) if TBI18n.has_key(cat_key) else String(e.get("cat", ""))))
	if kicker != "":
		var kk := K.caps(kicker, 10, K.GOLD); kk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; m[1].add_child(kk)
	var tl := K.title(title, 25); tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; tl.custom_minimum_size = Vector2(480, 0); m[1].add_child(tl)
	m[1].add_child(K.ornament())
	var fl := K.label(flavor, 15); fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; fl.custom_minimum_size = Vector2(480, 0); fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m[1].add_child(fl)
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 4); m[1].add_child(sp)
	var count: int = e["count"]
	var labels: Array = e.get("labels", [])
	for i in count:
		var ttl: String; var det := ""
		if rand: ttl = T.call("ev_%s_c%d" % [id, i]); det = T.call("ev_%s_d%d" % [id, i])
		elif i < labels.size():
			ttl = _loc(labels[i])
			var fx: Array = e.get("fx", [])
			if i < fx.size(): det = fx_text(fx[i])
		else: ttl = T.call("ev_ack")
		m[1].add_child(K.choice_card(ttl, det, func(): close(m[0]); on_choose.call(i), i == 0))

## victory goals with progress bars
static func goals(parent: Control, g: TBGame) -> void:
	var m := K.modal(parent, T.call("goals_title"), 460, "trophy")
	var prog := TBTurn.victory_progress(g, g.human_id)
	for id in TBTurn.VICTORY_IDS:
		var pct: float = prog[id]
		var col := K.GREEN if pct >= 0.9 else (K.GOLD2 if pct >= 0.4 else K.STEEL.lightened(0.25))
		var h := K.hbox(6); h.add_child(K.title(T.call("vc_" + id), 16, K.GOLD2 if pct >= 0.9 else K.TEXT)); h.add_child(K.Leader.new()); h.add_child(K.num("%d%%" % int(pct * 100.0), 15, col))
		m[1].add_child(h)
		var d := K.label(T.call("vc_" + id + "_d"), 12, K.DIM); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.custom_minimum_size = Vector2(400, 0)
		m[1].add_child(d)
		m[1].add_child(K.Meter.new(pct * 100.0, col))
		var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 6); m[1].add_child(gap)
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

static func game_over(parent: Control, g: TBGame, on_menu: Callable) -> void:
	var won: bool = g.winner == g.human_id
	var sub: String = T.call("e_victory", {"a": g.dname(g.winner)}) if won else T.call("e_defeat")
	if won and g.victory_kind != "": sub = "%s — %s" % [T.call("vc_" + g.victory_kind), g.dname(g.winner)]
	elif g.winner != 0 and not won: sub = T.call("e_lost_to", {"a": g.dname(g.winner)})
	var m := K.modal(parent, "", 480)
	var head := K.label(T.call("go_won") if won else T.call("go_lost"), 40, K.GOLD2 if won else K.CRIMSON.lightened(0.15))
	head.add_theme_font_override("font", K.tracked(K.display_hi(), 5)); head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m[1].add_child(head); m[1].add_child(K.ornament())
	var sl := K.label(sub, 15, K.TEXT); sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; sl.custom_minimum_size = Vector2(420, 0); m[1].add_child(sl)
	var rows: Array = []
	for n in range(1, g.N1):
		if g.alive[n] == 0 or n == g.rebel: continue
		var army := 0
		for p in g.owned(n): army += g.army[p]
		rows.append([g.own_count(n), n, army])
	rows.sort_custom(func(a, b): return a[0] > b[0] if a[0] != b[0] else a[1] < b[1])
	var rank := 0
	for i in rows.size(): if rows[i][1] == g.human_id: rank = i + 1
	m[1].add_child(K.section("%s · %s %d · %s %d" % [T.call("go_final"), T.call("go_rank"), rank, T.call("turn"), g.turn]))
	for i in mini(5, rows.size()):
		var r: Array = rows[i]
		var row := K.hbox(10)
		var rk := K.num("%d" % (i + 1), 15, K.GOLD2 if r[1] == g.human_id else K.DIM); rk.custom_minimum_size = Vector2(22, 0); row.add_child(rk)
		row.add_child(TBFlags.chip(g, r[1], 0.8))
		var nm := K.title(g.dname(r[1]), 15, K.GOLD2 if r[1] == g.human_id else K.TEXT); nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(nm)
		row.add_child(K.num("%d" % r[0], 14, K.GOLD2)); row.add_child(K.glyph_label("swords", K.fmt(r[2]), K.DIM, 11))
		m[1].add_child(row)
	var gap := Control.new(); gap.custom_minimum_size = Vector2(0, 6); m[1].add_child(gap)
	m[1].add_child(K.button(T.call("title"), func(): close(m[0]); on_menu.call(), true))

## Chronicle: persistent history with category filters (newest first)
static func chronicle(parent: Control, g: TBGame, on_goto: Callable) -> void:
	var m := K.modal(parent, T.call("chronicle"), 560, "book")
	var st := {"cat": "mine"}
	var list := K.vbox(3)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(0, 360); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(list); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m[1].add_child(scroll)
	var draw := func():
		for c in list.get_children(): c.queue_free()
		var shown := 0
		for i in range(g.log.size() - 1, -1, -1):
			var e: Dictionary = g.log[i]
			var cat := TBChron.category(e)
			if st["cat"] == "mine" and not TBChron.involves(e, g.human_id): continue
			if st["cat"] in ["war", "diplo", "events"] and cat != st["cat"]: continue
			var tx := TBChron.text(g, e)
			if tx == "": continue
			var row := K.hbox(8)
			var d := K.label("%s · T%d" % [TBChron.date(g, int(e["turn"])), int(e["turn"])], 12, K.DIM); d.custom_minimum_size = Vector2(110, 0); row.add_child(d)
			var l := K.label(tx, 14, K.RED.lightened(0.3) if TBChron.is_bad(e, g.human_id) else K.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(l)
			if e.has("p") and int(e["p"]) >= 0:
				var pp: int = e["p"]
				var go := K.icon_button("pin", func(): close(m[0]); on_goto.call(pp), 32); row.add_child(go)
			list.add_child(row)
			shown += 1
			if shown >= 120: break
		if shown == 0: list.add_child(K.label(T.call("chron_empty"), 14, K.DIM))
	var tab_items: Array = []
	for c in TBChron.CATS: tab_items.append([c, T.call("chron_" + c)])
	var tabs := K.segmented(tab_items, "mine", func(id: String): st["cat"] = id; draw.call())
	m[1].add_child(tabs); m[1].move_child(tabs, 2)
	draw.call()
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

## Decisions: costed national projects, listed as ruled ledger entries
const DEC_GLYPH := {"mil_reform": "swords", "trade_fair": "scales", "centralize": "crown", "conscript": "men", "propaganda": "scroll", "patronage": "book", "fortify": "shield", "amnesty": "dove"}

static func decisions(parent: Control, g: TBGame, on_cmd: Callable) -> void:
	var m := K.modal(parent, T.call("decisions"), 560, "scales")
	var me := g.human_id
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size = Vector2(0, 380); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := K.vbox(0); list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_right", 14); pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(list); scroll.add_child(pad); m[1].add_child(scroll)
	for i in TBDecisions.LIST.size():
		var d: Dictionary = TBDecisions.LIST[i]
		var active := TBDecisions.is_active(g, me, i)
		var why := TBDecisions.why_not(g, me, i)
		var row := K.hbox(12); row.custom_minimum_size = Vector2(0, 64)
		var gl := K.glyph_label_big(DEC_GLYPH.get(d["id"], "scroll"))
		gl.size_flags_vertical = Control.SIZE_SHRINK_CENTER; row.add_child(gl)
		var mid := K.vbox(1); mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mid.add_child(K.title(T.call("dec_" + String(d["id"])), 16, K.GOLD2 if active else K.TEXT))
		var ds := K.label(T.call("dec_%s_d" % d["id"]), 13, K.DIM); ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ds.custom_minimum_size = Vector2(220, 0); mid.add_child(ds)
		row.add_child(mid)
		var right := K.vbox(4); right.custom_minimum_size = Vector2(112, 0)
		if active:
			right.add_child(K.caps(T.call("dec_forever") if TBDecisions.turns_left(g, me, i) > 5000 else T.call("dec_left", {"n": TBDecisions.turns_left(g, me, i)}), 10, K.GREEN))
		else:
			var cost := K.hbox(8); cost.add_child(K.glyph_label("coin", str(int(d["gold"])), K.GOLD2 if g.gold[me] >= float(d["gold"]) else K.RED)); cost.add_child(K.glyph_label("swords", str(int(d["mp"])), K.GOLD2 if g.mp[me] >= float(d["mp"]) else K.RED))
			right.add_child(cost)
			var b := K.button(T.call("dec_do"), func(): on_cmd.call({"cmd": "decide", "id": String(d["id"])}); close(m[0]))
			b.custom_minimum_size = Vector2(0, 34); b.disabled = why != ""
			right.add_child(b)
		row.add_child(right)
		list.add_child(row)
		var rl := Control.new(); rl.custom_minimum_size = Vector2(0, 9)
		rl.draw.connect(func(): rl.draw_line(Vector2(0, 4), Vector2(rl.size.x, 4), Color(0.83, 0.63, 0.09, 0.22), 1.0))
		list.add_child(rl)
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))

## Advisor: current alerts and tips; tapping one jumps to the province concerned
static func advisor(parent: Control, g: TBGame, on_goto: Callable) -> void:
	var m := K.modal(parent, T.call("advisor"), 520, "lamp")
	var al := TBAdvisor.alerts(g, g.human_id)
	if al.is_empty(): m[1].add_child(K.label(T.call("al_none"), 15, K.DIM))
	for a in al:
		var sev: int = a["sev"]
		var col := K.RED.lightened(0.3) if sev == 2 else (K.GOLD2 if sev == 1 else K.TEXT)
		var row := K.hbox(10)
		var mark := K.Pips.new(1, 1, K.RED if sev == 2 else (K.GOLD2 if sev == 1 else K.STEEL.lightened(0.3))); mark.custom_minimum_size = Vector2(14, 20); mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(mark)
		var l := K.label(T.call("al_" + String(a["id"]), {"k": int(a["k"]), "r": "%.1f" % (int(a["k"]) / 10.0)}), 14, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.size_flags_horizontal = Control.SIZE_EXPAND_FILL; l.custom_minimum_size = Vector2(380, 0); row.add_child(l)
		if int(a["p"]) >= 0:
			var pp: int = a["p"]
			var go := K.icon_button("pin", func(): close(m[0]); on_goto.call(pp), 38); row.add_child(go)
		m[1].add_child(row)
	m[1].add_child(K.button(T.call("back"), func(): close(m[0])))
