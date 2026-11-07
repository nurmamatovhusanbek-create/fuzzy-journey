## The peace table (rules 4, docs/WAR_DESIGN.md section 9): the winner ticks what to ask for, every demand shows its price in points of the war score, the window shows what you may spend and what the other side
## would accept, and the offer goes out only when it fits. Land you hold, gold, a vassal, disarmament. The deal is one `peaceDeal` command and is answered at once (the limit is shown, so nothing is hidden).
class_name TBPeaceTable
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
const D = preload("res://src/engine/data.gd")
static var T: Callable = TBI18n.T

static func open(parent: Control, g: TBGame, enemy: int, opts: Dictionary = {}) -> TBPanel.Handle:
	var me: int = g.human_id
	var on_cmd: Callable = opts.get("on_cmd", Callable())
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("terms_title"), "flag", {"w": 560, "h": 760, "key": "terms",
		"sub": T.call("terms_sub", {"a": g.dname(enemy), "k": g.war_turns[me * g.N1 + enemy]})})
	var body: VBoxContainer = h.body
	body.add_theme_constant_override("separation", 10)
	var st := {"provs": [], "gold": 0, "vassal": 0, "disarm": 0}
	var cells := K.hbox(8); cells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var c_budget := TBNationParts.StatCell.new("war", "", T.call("terms_budget"))
	var c_limit := TBNationParts.StatCell.new("war", "", T.call("terms_limit"))
	cells.add_child(c_budget); cells.add_child(c_limit)
	body.add_child(cells)
	body.add_child(K.para_bz(T.call("terms_table_hint"), 15.0, 1.3))
	var offs: Array = TBPeace.offers(g, me, enemy)
	var cost_of := {}
	for o in offs: cost_of[int(o["p"])] = float(o["cost"])
	var marks_fn: Callable = opts.get("marks", Callable())
	var pick_on: bool = marks_fn.is_valid() and not h.modal                     # the window leaves the map free: the land is picked on the map, each province carrying its price
	var chosen := K.label("", 15)
	var total := K.label("", 16)
	var why := K.label("", 14, TBTokens.BZ_BAD_TXT); why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; why.visible = false
	var ui := {}                                                          # the Offer button, reached through a dictionary: a lambda copies plain variables when it is made
	var refresh := func() -> void:
		var cmd := {"cmd": "peaceDeal", "n": me, "t": enemy, "provs": st["provs"], "gold": st["gold"], "vassal": st["vassal"], "disarm": st["disarm"]}
		var c := g.can(cmd)
		var pts: float = float(c.get("pts", 0.0)); var bud: float = float(c.get("budget", 0.0)); var lim: float = float(c.get("limit", 0.0))
		c_budget.value = "%d" % int(floor(bud)); c_budget.queue_redraw()
		c_limit.value = "%d" % int(floor(lim)); c_limit.queue_redraw()
		total.text = T.call("terms_total", {"n": int(ceil(pts)), "m": int(floor(lim))})
		total.add_theme_color_override("font_color", TBTokens.BZ_BAD_TXT if not bool(c.get("ok", false)) and pts > 0.0 else TBTokens.BZ_IVORY)
		var empty: bool = (st["provs"] as Array).is_empty() and int(st["gold"]) == 0 and int(st["vassal"]) == 0 and int(st["disarm"]) == 0
		(ui["offer"] as Button).disabled = not bool(c.get("ok", false)) or empty
		var rk: String = "err_" + String(c.get("reason", ""))
		why.text = "" if (bool(c.get("ok", false)) or empty) else (T.call(rk) if TBI18n.has_key(rk) else String(c.get("reason", "")))
		why.visible = why.text != ""
		var sel_pts := 0.0
		for pv0 in st["provs"]: sel_pts += float(cost_of.get(int(pv0), 0.0))
		chosen.text = T.call("terms_chosen", {"n": (st["provs"] as Array).size(), "pts": "%.1f" % sel_pts})
		if marks_fn.is_valid():
			var mk: Array = []
			for o2 in offs: mk.append({"p": int(o2["p"]), "text": "%.1f" % float(o2["cost"]), "on": (st["provs"] as Array).has(int(o2["p"]))})
			marks_fn.call(mk, (st["provs"] as Array).duplicate())
	ui["refresh"] = refresh
	# ---- land you hold: on the map (a price on every province you hold, tap one to ask for it) or, where the window covers the map, a list of switches
	body.add_child(K.caps(T.call("terms_land"), 12, K.GOLD))
	var flip := func(pv: int) -> void:
		if not cost_of.has(pv): return
		var arr: Array = st["provs"]
		if arr.has(pv): arr.erase(pv)
		else: arr.append(pv)
		ui["refresh"].call()
	ui["flip"] = flip
	if offs.is_empty():
		body.add_child(K.para_bz(T.call("terms_no_land"), 15.0, 1.3))
	elif pick_on:
		body.add_child(K.para_bz(T.call("terms_pick_hint"), 15.0, 1.3))
		body.add_child(chosen)
		var fit := func() -> void:
			var cap: float = float(g.can({"cmd": "peaceDeal", "n": me, "t": enemy}).get("limit", 0.0))
			st["provs"] = (TBPeace.auto_deal(g, me, enemy, cap)["provs"] as Array).duplicate()
			ui["refresh"].call()
		var clr := func() -> void:
			st["provs"] = []
			ui["refresh"].call()
		var prow := K.hbox(8)
		var b_fit := K.button(T.call("terms_fit"), fit, false, false, "flag"); b_fit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		prow.add_child(b_fit); prow.add_child(K.button(T.call("terms_clear"), clr))
		body.add_child(prow)
	else:
		for o in offs:
			var pv: int = int(o["p"])
			var label := "%s · %s" % [TBI18n.place(g.pname(pv)), T.call("pts_n", {"n": "%.1f" % float(o["cost"])})]
			var pick := func(_on: bool) -> void: flip.call(pv)
			body.add_child(K.toggle(label, false, pick, 0.0))
	# ---- gold, a vassal, disarmament
	var room: int = TBPeace.gold_room(g, enemy)
	if room > 0:
		body.add_child(K.caps(T.call("terms_gold_row"), 12, K.GOLD))
		var per: float = TBPeace.gold_per_point(g, enemy)
		body.add_child(K.slider_row(T.call("gold"), 0.0, float(room), 1.0, 0.0, func(v: float) -> void:
			st["gold"] = int(v); refresh.call(),
			func(v: float) -> String: return "%d" % int(round(v * per))))
	var set_vassal := func(on: bool) -> void:
		st["vassal"] = 1 if on else 0
		refresh.call()
	var set_disarm := func(on: bool) -> void:
		st["disarm"] = 1 if on else 0
		refresh.call()
	body.add_child(K.toggle("%s · %s" % [T.call("terms_vassal"), T.call("pts_n", {"n": int(TBPeace.VASSAL_PTS)})], false, set_vassal, 0.0))
	body.add_child(K.toggle("%s · %s" % [T.call("terms_disarm"), T.call("pts_n", {"n": int(TBPeace.DISARM_PTS)})], false, set_disarm, 0.0))
	var row := K.hbox(8)
	var white := K.button(T.call("terms_white"), func() -> void:
		if on_cmd.is_valid(): on_cmd.call({"cmd": "peaceDeal", "t": enemy})
		h.close(), false, false, "flag")
	var offer: Button = K.button(T.call("terms_offer"), func() -> void:
		var cmd := {"cmd": "peaceDeal", "t": enemy, "provs": (st["provs"] as Array).duplicate(), "gold": st["gold"], "vassal": st["vassal"], "disarm": st["disarm"]}
		if on_cmd.is_valid(): on_cmd.call(cmd)
		h.close(), true, false, "envoys")
	ui["offer"] = offer
	offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(white); row.add_child(offer)
	body.add_child(total); body.add_child(why); body.add_child(row)
	body.move_child(row, 1); body.move_child(why, 1); body.move_child(total, 1)          # the verdict and the two buttons sit right under the scores, always in view
	var reg: Callable = opts.get("register", Callable())
	if pick_on and reg.is_valid():
		reg.call(flip)                                                       # a tap on the map reaches the window, never the province card or the ring
		h.root.tree_exiting.connect(func() -> void:
			reg.call(Callable())
			if marks_fn.is_valid(): marks_fn.call([], []))
	refresh.call()
	return h
