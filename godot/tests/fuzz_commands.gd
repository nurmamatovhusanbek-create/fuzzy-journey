extends SceneTree
## Command fuzzer: random, malformed and hostile commands against the engine (the one mutation API every client path uses). No command may crash the engine (a runtime error prints
## "SCRIPT ERROR" and fails the run) or break the state: sizes, ranges, finiteness, no resource from nothing. Usage: -s tests/fuzz_commands.gd -- [iterations=4000] [seed=1] [era=napoleonic]   (run headless)
const CMDS := ["move", "recruit", "declareWar", "peace", "ally", "nap", "breakPact", "build", "budget", "colonize", "relocate", "regime", "develop", "demolish", "hire", "spy", "eventChoice", "decide",
	"trade", "marry", "cancelTrade", "appoint", "doctrine", "ultimatum", "ask", "noop", "nope", "", "__proto__"]
const HEAVY := ["move", "recruit", "build", "budget", "develop", "hire", "declareWar", "peace"]
var rng := RandomNumberGenerator.new()
var fails := 0
var g: TBGame
var sizes := {}

func _check(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		if fails <= 25: print("FAIL: ", what)

func _junk() -> Variant:
	match rng.randi() % 14:
		0: return -1
		1: return 1 << 40
		2: return -(1 << 31)
		3: return NAN
		4: return INF
		5: return "x".repeat(rng.randi() % 40)
		6: return null
		7: return [1, 2, 3]
		8: return {"a": 1}
		9: return 0.5
		10: return true
		11: return g.P
		12: return g.N1
		_: return rng.randi_range(-5, 5)

func _val(kind: String) -> Variant:
	if rng.randf() < 0.12: return _junk()
	match kind:
		"p", "from", "to": return rng.randi() % g.P
		"t": return 1 + rng.randi() % (g.N1 - 1)
		"amount", "troops": return rng.randi_range(-50, 200)
		"b": return rng.randi() % 14
		"r": return rng.randi() % 8
		"uid": return rng.randi() % 30
		"i": return rng.randi() % 4
		"val": return rng.randi_range(-100, 100)
		"key": return ["tax", "admin", "research", "provinces", "army", "x"][rng.randi() % 6]
		"kind": return ["white", "land", "tribute", "gold", "x"][rng.randi() % 5]
		"op": return ["steal", "sabotage", "incite", "intel", "x"][rng.randi() % 5]
		"id": return ["tax_reform", "conscription", "x", ""][rng.randi() % 4]
	return rng.randi() % 10

func _cmd() -> Dictionary:
	var name: String = CMDS[rng.randi() % CMDS.size()]
	var c := {"cmd": name}
	var n_roll := rng.randf()
	c["n"] = g.human_id if n_roll < 0.7 else (1 + rng.randi() % (g.N1 - 1) if n_roll < 0.95 else _junk())
	if TBCommands.SCHEMA.has(name):                                           # mostly well-formed: fill the listed fields so the handlers themselves get exercised
		for key in TBCommands.SCHEMA[name]:
			var k: String = String(key).trim_prefix("?")
			if String(key).begins_with("?") and rng.randf() < 0.4: continue
			c[k] = _val(k)
		if rng.randf() < 0.15: c.erase(c.keys()[rng.randi() % c.size()])
	var extra := ["_force", "_ult", "deal", "x"]
	for k in extra:
		if rng.randf() < 0.15: c[k] = _junk()
	return c

func _snap() -> void:
	sizes = {"owner": g.owner.size(), "army": g.army.size(), "gold": g.gold.size(), "rel": g.rel.size(), "manpower": g.manpower.size(), "stab": g.stab.size()}

func _invariants(tag: String) -> void:
	for k in sizes: _check(g.get(k).size() == sizes[k], "%s: %s changed size" % [tag, k])
	for p in g.P:
		var o: int = g.owner[p]
		if o < 0 or o >= g.N1: _check(false, "%s: owner[%d] = %d" % [tag, p, o]); return
		var oc: int = g.occupier[p]
		if oc < 0 or oc >= g.N1: _check(false, "%s: occupier[%d] = %d" % [tag, p, oc]); return
		var a: int = g.army[p]
		if a < 0 or a > 65000: _check(false, "%s: army[%d] = %d" % [tag, p, a]); return
	for n in range(1, g.N1):
		var gd: float = g.gold[n]; var mn: float = g.manpower[n]
		if not is_finite(gd) or absf(gd) > 1.0e9: _check(false, "%s: gold[%d] = %s" % [tag, n, str(gd)]); return
		if not is_finite(mn) or mn < -0.5 or mn > 1.0e9: _check(false, "%s: manpower[%d] = %s" % [tag, n, str(mn)]); return
		if not is_finite(g.mp[n]) or g.mp[n] < -0.001: _check(false, "%s: mp[%d] = %s" % [tag, n, str(g.mp[n])]); return
		if not is_finite(g.infamy[n]) or g.infamy[n] < -0.001: _check(false, "%s: infamy[%d] = %s" % [tag, n, str(g.infamy[n])]); return
		if g.alive[n] == 1 and g.capital_of[n] >= g.P: _check(false, "%s: capital_of[%d] = %d" % [tag, n, g.capital_of[n]]); return

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var iters: int = int(a[0]) if a.size() > 0 else 1200
	rng.seed = int(a[1]) if a.size() > 1 else 1
	var era: String = a[2] if a.size() > 2 else "napoleonic"
	TBI18n.load_lang("en")
	var w := TBWorld.load_from("res://data")
	var pack := TBWorld.load_era("res://data", era) if era != "modern" else {}
	g = TBGame.new(w, pack, {"seed": 5, "rules": 2})
	var fr := 1
	for n in range(1, g.N1):
		if g.alive[n] == 1: fr = n; break
	g.add_human(fr); g.human_id = fr
	g.gold[fr] = 800.0; g.manpower[fr] = 300.0; g.mp[fr] = 20.0; g.dp[fr] = 20.0
	_snap()
	var ok_cnt := 0; var bad_cnt := 0
	for i in iters:
		var c := _cmd()
		var before_gold: float = g.gold[fr]; var before_mp: float = g.mp[fr]; var before_man: float = g.manpower[fr]
		var r = g.apply(c)
		_check(r is Dictionary and r.has("ok"), "apply returned %s for %s" % [str(r), str(c)])
		if r is Dictionary:
			if bool(r.get("ok", false)):
				ok_cnt += 1
				var nm: String = String(c.get("cmd", ""))
				if int(c.get("n", 0)) == fr:
					if not nm in ["spy", "eventChoice", "decide", "trade", "peace", "cancelTrade", "doctrine", "ask", "ultimatum", "marry"]:
						_check(g.gold[fr] <= before_gold + 0.01, "%s raised gold %.1f -> %.1f: %s" % [nm, before_gold, g.gold[fr], str(c)])
					_check(g.mp[fr] <= before_mp + 0.01, "%s raised move points: %s" % [nm, str(c)])
					if nm != "eventChoice" and nm != "decide": _check(g.manpower[fr] <= before_man + 0.01, "%s raised manpower: %s" % [nm, str(c)])
			else: bad_cnt += 1
		if i % 40 == 39:
			_invariants("after %d commands" % (i + 1))
		if i % 150 == 149:
			g.end_turn(); g.pending.clear()
			g.gold[fr] = maxf(g.gold[fr], 300.0); g.manpower[fr] = maxf(g.manpower[fr], 150.0); g.mp[fr] = 20.0; g.dp[fr] = 20.0
			_invariants("after turn %d" % g.turn)
	print("fuzz: %d commands, %d accepted, %d refused, turn %d" % [iters, ok_cnt, bad_cnt, g.turn])
	print("FUZZ_COMMANDS OK" if fails == 0 else "FUZZ_COMMANDS FAIL %d" % fails)
	quit(fails)
