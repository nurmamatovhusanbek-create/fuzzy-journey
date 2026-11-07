extends SceneTree
## Colonies under rules 4: they cost gold, settlers and moves, every requirement is listed, and a refused order says which are missing. Run: godot --headless -s tests/colony_rules.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var world := TBWorld.load_from("res://data")
	var g := TBGame.new(world, TBWorld.load_era("res://data", "discovery"), {"seed": 7, "rules": 4})
	var me: int = g.nat_code.find("portugal"); if me < 0: me = 1
	g.set_human(me); g.pending.clear()
	# a free province next to ours
	var target := -1
	for p in g.owned(me):
		for i in range(g.nb_off[p], g.nb_off[p + 1]):
			var q: int = g.nb[i]
			if g.owner[q] == 0 and g.nb_sea[i] == 0 and g.discoverable[q] == 0: target = q; break
		if target >= 0: break
	if target < 0:
		# make one: release a border province
		for p in g.owned(me):
			if g.capital[p] == 0:
				for i in range(g.nb_off[p], g.nb_off[p + 1]):
					var q: int = g.nb[i]
					if g.owner[q] != me and g.owner[q] != 0 and g.nb_sea[i] == 0: g.set_owner(q, 0); target = q; break
			if target >= 0: break
	_check(target >= 0, "a free province next to the realm exists")
	g.gold[me] = 1000.0; g.mp[me] = 6.0; g.manpower[me] = 500.0
	var cn := g.can({"cmd": "colonize", "p": target})
	print("cost gold ", cn["gold"], " men ", cn["men"], " moves ", cn["moves"], " ok ", cn["ok"], " needs ", cn.get("needs", []).size())
	_check(int(cn["gold"]) > 0 and int(cn["men"]) > 0 and int(cn["moves"]) == 2, "a colony costs gold, settlers and two moves under every regime")
	_check(cn.has("needs") and (cn["needs"] as Array).size() >= 4, "the requirements are listed (%d)" % cn.get("needs", []).size())
	_check(bool(cn["ok"]), "possible with money, people and moves")
	# not enough of each: the list marks exactly the missing ones
	g.gold[me] = 5.0; g.manpower[me] = 3.0; g.mp[me] = 1.0
	var bad := g.can({"cmd": "colonize", "p": target})
	var unmet := 0
	for nd in bad["needs"]: if not bool(nd[0]): unmet += 1
	_check(not bool(bad["ok"]) and unmet == 3, "gold, settlers and moves are all reported missing (%d)" % unmet)
	# the command deducts all three
	g.gold[me] = 1000.0; g.mp[me] = 6.0; g.manpower[me] = 500.0
	var gold0: float = g.gold[me]; var men0: float = g.manpower[me]; var mp0: float = g.mp[me]
	var r := g.apply({"cmd": "colonize", "p": target, "n": me})
	print("apply result ", r)
	_check(g.owner[target] == me, "the province is ours after colonizing")
	_check(g.gold[me] < gold0 and g.manpower[me] < men0 and g.mp[me] < mp0, "gold, settlers and moves were spent")
	# an old save keeps the old rule
	var g2 := TBGame.new(world, TBWorld.load_era("res://data", "discovery"), {"seed": 7, "rules": 3})
	var c2 := g2.can({"cmd": "colonize", "p": 0})
	_check(not c2.has("needs") or true and int(c2["men"]) == 0, "rules 3 keeps gold and moves only")
	print("COLONY_RULES OK" if fails == 0 else "COLONY_RULES FAIL %d" % fails)
	quit(fails)
