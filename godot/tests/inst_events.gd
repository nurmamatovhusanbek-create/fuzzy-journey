extends SceneTree
## Events tied to the institutions: the conditions read the embraced mask, the effects apply, and every event has its texts in all three languages. Usage: -s tests/inst_events.gd (with timeout)
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
const IDS := {"academy_charter": "printing", "merchant_charter": "joint_stock", "guild_riots": "industry", "salon_season": "enlightenment", "railway_boom": "railways"}
func _init() -> void:
	TBEvents._load()
	var w := TBWorld.load_from("res://data")
	var g := TBGame.new(w, TBWorld.load_era("res://data", "napoleonic"), {"seed": 7})
	var fr := g.nat_code.find("france"); g.set_human(fr); g.pending.clear()
	var by_id := {}
	for e in TBEvents._random: by_id[String(e["id"])] = e
	var langs := {}
	for l in ["en", "ru", "uz"]: langs[l] = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/%s.json" % l))
	for id in list_ids():
		_check(by_id.has(id), "event %s is in random.json" % id)
		if not by_id.has(id): continue
		var ev: Dictionary = by_id[id]
		for l in langs:
			for k in ["ev_%s_t" % id, "ev_%s_f" % id]: _check(langs[l].has(k), "%s has %s" % [l, k])
			for c in ev["choices"].size():
				for k in ["ev_%s_c%d" % [id, c], "ev_%s_d%d" % [id, c]]: _check(langs[l].has(k), "%s has %s" % [l, k])
	# conditions: without the institution the event is not eligible, with it it is (the chance term aside)
	for id in IDS:
		var ev: Dictionary = by_id[id]
		var conds: Array = []
		for c in ev["cond"]: if not c.has("chance"): conds.append(c)
		var i := TBInstitutions.index_of(String(IDS[id]))
		var had := TBInstitutions.embraced(g, fr, i)
		g.inst_ok[fr] &= ~(1 << i)
		_check(not TBEvents._conds_ok(g, fr, conds), "%s: not eligible without %s" % [id, IDS[id]])
		g.inst_ok[fr] |= (1 << i)
		_check(TBEvents._conds_ok(g, fr, conds), "%s: eligible with %s" % [id, IDS[id]])
		if not had: g.inst_ok[fr] &= ~(1 << i)
		# every choice applies without error and moves something
		for ch in ev["choices"]:
			var g0 := g.gold[fr]; var r0 := g.research[fr]; var s0 := 0
			for p in g.owned(fr): s0 += g.stab[p]
			TBEvents.apply_effects(g, fr, ch["effects"])
			var s1 := 0
			for p in g.owned(fr): s1 += g.stab[p]
			_check(g.gold[fr] != g0 or g.research[fr] != r0 or s1 != s0, "%s: a choice moves something" % id)
	# the lag event: only for a nation that is behind
	var rc: Array = []
	for c in by_id["reform_clamour"]["cond"]: if not c.has("chance"): rc.append(c)
	var behind := -1; var ahead := -1
	for n in range(1, g.N1):
		if n == g.rebel or g.alive[n] == 0: continue
		if TBInstitutions.lag(g, n) > 0 and behind < 0: behind = n
		if TBInstitutions.lag(g, n) == 0 and ahead < 0: ahead = n
	_check(behind >= 0, "some nation is behind in 1804")
	if behind >= 0: _check(TBEvents._conds_ok(g, behind, rc), "reform clamour: eligible for a nation that is behind")
	if ahead >= 0: _check(not TBEvents._conds_ok(g, ahead, rc), "reform clamour: not for one that keeps up")
	print("INST_EVENTS OK" if fails == 0 else "INST_EVENTS FAIL %d" % fails)
	quit(fails)
func list_ids() -> Array: return ["academy_charter", "merchant_charter", "guild_riots", "reform_clamour", "salon_season", "railway_boom"]
