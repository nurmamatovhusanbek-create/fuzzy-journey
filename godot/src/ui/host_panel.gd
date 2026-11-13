## The Host panel (F8; rules 5): everything about the army as a whole, so the province ring keeps only what is about the province in front of you. Two realm orders (Spread: march the
## capital's army out to the front; Muster: raise levies in every front province), the armies with their generals (Appoint), and the levy pools. Orders go through `on_command`.
class_name TBHostPanel
extends RefCounted

const K = preload("res://src/ui/ui_kit.gd")
const CC = preload("res://src/ui/cmd_card.gd")
static var T: Callable = TBI18n.T

## the army the realm orders start from: the biggest one you hold
static func biggest(g: TBGame, me: int) -> int:
	var best := -1
	for p in g.P:
		if g.controller(p) == me and g.army[p] > 0 and (best < 0 or g.army[p] > g.army[best]): best = p
	return best

## rows as data (a test reads them without a screen): armies [[p, men, general skill]], pools [men, cap, provinces], spread / muster = the can() answers
static func data(g: TBGame, me: int) -> Dictionary:
	var armies: Array = []
	var men := 0
	for p in g.P:
		if g.controller(p) == me and g.army[p] > 0:
			armies.append([p, g.army[p], TBGenerals.skill(g, p) if g.gen[p] != 0 else 0]); men += g.army[p]
	armies.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]) if int(a[1]) != int(b[1]) else int(a[0]) < int(b[0]))
	var pool := 0; var cap := 0; var provs := 0
	for p in g.owned(me):
		if g.occupier[p] == 0: pool += TBRaise.pool(g, p); cap += g.levy_cap(p); provs += 1
	var src: int = biggest(g, me)
	var spread: Dictionary = g.can({"cmd": "spread", "p": src}) if src >= 0 else {"ok": false, "reason": "noarmy", "gold": 0, "moves": 0, "men": 0, "dp": 0, "short": {}, "gain": 0}
	var muster: Dictionary = g.can({"cmd": "muster", "pct": TBMass.DEFAULT_PCT})
	return {"armies": armies, "men": men, "pool": pool, "cap": cap, "provs": provs, "src": src, "spread": spread, "muster": muster}

static func open(parent: Control, g: TBGame, on_goto: Callable, on_command: Callable, on_disband: Callable = Callable()) -> TBPanel.Handle:
	var h := TBPanel.open(parent, TBPanel.Kind.PANEL, T.call("dk_host"), "host", {"w": 520, "h": 600, "sub": T.call("host_sub")})
	var me := g.human_id
	var d := data(g, me)
	var again := func(cmd: Dictionary):
		h.close(); on_command.call(cmd); open(parent, g, on_goto, on_command, on_disband)
	h.body.add_child(TBPanel.section(T.call("host_orders")))
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10); row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sp: Dictionary = d["spread"]; var mu: Dictionary = d["muster"]
	var b1 := K.button(T.call("cc_spread"), func(): again.call({"cmd": "spread", "p": int(d["src"])}), true, false, "spread", _detail("spread", sp))
	var b2 := K.button(T.call("cc_muster"), func(): again.call({"cmd": "muster", "pct": TBMass.DEFAULT_PCT}), false, false, "muster", _detail("muster", mu))
	b1.disabled = not bool(sp["ok"]); b2.disabled = not bool(mu["ok"])
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL; b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b1); row.add_child(b2); h.body.add_child(row)
	for cn in [sp, mu]:
		if not bool(cn["ok"]): h.body.add_child(TBPanel.para(_why(cn), 13, K.DIM))
	h.body.add_child(TBPanel.section(T.call("host_armies")))
	h.body.add_child(TBPanel.para(T.call("host_total", {"m": K.fmt(float(d["men"])), "n": (d["armies"] as Array).size()}), 14, K.DIM))
	if (d["armies"] as Array).is_empty(): h.body.add_child(TBPanel.para(T.call("ol_none"), 14, K.DIM))
	for a in (d["armies"] as Array).slice(0, 10):
		var p: int = int(a[0])
		var line := HBoxContainer.new(); line.add_theme_constant_override("separation", 8); line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var lr := K.ListRow.new(T.call("ol_army_row", {"p": TBI18n.place(g.pname(p)), "m": K.fmt(float(a[1]))}) + ("   " + "★".repeat(int(a[2])) if int(a[2]) > 0 else ""), "›", func(): h.close(); on_goto.call(p))
		lr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(lr)
		if g.gen[p] == 0:
			var gc: Dictionary = g.can({"cmd": "appoint", "p": p})
			if bool(gc["ok"]) or String(gc["reason"]) in ["gold", "mp"]:
				var ab := K.button(T.call("host_appoint"), func(): again.call({"cmd": "appoint", "p": p}), false, true, "general", CC.gold(int(gc["gold"])))
				ab.disabled = not bool(gc["ok"])
				line.add_child(ab)
		if on_disband.is_valid() and TBRaise.disband_max(g, p) >= 1:
			var db := K.button(T.call("cc_disband"), func(): h.close(); on_disband.call(p), false, true, "close")
			line.add_child(db)
		h.body.add_child(line)
	h.body.add_child(TBPanel.section(T.call("host_levy")))
	h.body.add_child(TBPanel.para(T.call("host_levy_line", {"m": K.fmt(float(d["pool"])), "c": K.fmt(float(d["cap"])), "n": d["provs"]}), 14, K.DIM))
	return h

static func _detail(kind: String, cn: Dictionary) -> String:
	if not bool(cn["ok"]) and not String(cn["reason"]) in ["gold", "mp"]: return ""
	return String(T.call(kind + "_detail", {"k": int(cn.get("n_targets", 0)), "m": int(cn["gain"])}))

static func _why(cn: Dictionary) -> String:
	var rk := "err_" + String(cn.get("reason", ""))
	return String(T.call(rk)) if TBI18n.has_key(rk) else String(cn.get("reason", ""))
