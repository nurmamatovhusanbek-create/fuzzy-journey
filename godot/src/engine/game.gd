## Core simulation state + rules. Pure data (typed arrays), no Nodes, deterministic (seeded RNG).
## Province index p in [0,P). Nation index n in [1,N]; 0 = neutral. ALL mutation goes through apply().
class_name TBGame
extends RefCounted

const D = preload("res://src/engine/data.gd")

var world: TBWorld
var P: int
var N: int
var N1: int
var rng: TBRng
var seed_value: int
var rules: int = 1                # 0 = legacy behaviour (oracle-exact vs JS reference), 1 = tuned game rules
var difficulty: String
var diff: Dictionary
var turn: int = 1
var year: int
var month_idx: int = 0
var era_id: String
var over: bool = false
var winner: int = 0
var human_id: int = 0
var rebel: int

# nations
var nat_name: PackedStringArray
var nat_code: PackedStringArray
var gold := PackedFloat32Array()
var manpower := PackedFloat32Array()
var mp := PackedFloat32Array()
var dp := PackedFloat32Array()
var tech_level := PackedFloat32Array()
var research := PackedFloat32Array()
var liberty := PackedFloat32Array()
var era := PackedByteArray()
var regime := PackedByteArray()
var personality := PackedByteArray()
var alive := PackedByteArray()
var human := PackedByteArray()
var cap_lost := PackedByteArray()
var tribute := PackedByteArray()
var capital_of := PackedInt32Array()
var overlord := PackedInt32Array()
var last_war_turn := PackedInt32Array()
var color := PackedInt32Array()
var budget := PackedByteArray()     # N1*4 : tax, goods, research, invest (%)
var rel := PackedByteArray()        # N1*N1
var truce := PackedInt32Array()     # N1*N1 expiry turn
var war_score := PackedInt32Array() # N1*N1
var war_turns := PackedInt32Array() # N1*N1
var grudge := PackedByteArray()     # N1*N1
var war_cnt := PackedInt32Array()   # per nation: number of ALIVE enemies it is at war with (incremental)

# provinces
var owner := PackedInt32Array()
var occupier := PackedInt32Array()
var occ_turns := PackedByteArray()     # consecutive turns a province has been occupied (rules>=1: long occupation annexes)
var army := PackedInt32Array()
var pop := PackedInt32Array()
var dev := PackedByteArray()
var econ := PackedByteArray()
var stab := PackedByteArray()
var happy := PackedByteArray()
var defense := PackedByteArray()
var terrain := PackedByteArray()
var building := PackedByteArray()
var b_level := PackedByteArray()
var b_building := PackedByteArray()
var b_turns := PackedByteArray()
var capital := PackedByteArray()
var discoverable := PackedByteArray()

# adjacency incl. sea links (CSR)
var nb_off := PackedInt32Array()
var nb := PackedInt32Array()
var nb_sea := PackedByteArray()

# ownership index (CSR) – rebuilt lazily
var own_start := PackedInt32Array()
var own_list := PackedInt32Array()
var own_dirty: bool = true

# events (rules >= 1)
var pending: Array = []                 # prompts awaiting a human choice: {uid, n, kind, id, ...}
var ev_fired: Dictionary = {}           # scheduled event id -> true
var ev_last: Dictionary = {}            # "nation:event" -> turn last fired
var ev_last_any := PackedInt32Array()
var ev_uid: int = 0
var start_year: int = 2024
var start_month: int = 0
var trade_bonus := PackedInt32Array()   # extra gold granted next turn
var combat_bonus := PackedFloat32Array()
var combat_turns := PackedByteArray()

var dirty_flag := PackedByteArray()
var dirty_list := PackedInt32Array()
var rel_dirty := PackedInt32Array()   # canonical (min*N1+max) pairs whose relation changed since last take (net deltas)
var log: Array = []
var nap_expiry: Dictionary = {}
var occ_rev: int = 0

func _init(w: TBWorld, era_pack: Dictionary, opts: Dictionary = {}) -> void:
	world = w
	P = w.P
	seed_value = int(opts.get("seed", 1))
	rules = int(opts.get("rules", 1))
	rng = TBRng.new(seed_value)
	difficulty = String(opts.get("difficulty", "normal"))
	diff = D.DIFFICULTY.get(difficulty, D.DIFFICULTY["normal"])
	var has_era := not era_pack.is_empty()
	year = int(era_pack["year"]) if has_era else 2024
	era_id = String(era_pack["id"]) if has_era else "modern"

	# ---- nations ----
	nat_name = PackedStringArray(["—"])
	nat_code = PackedStringArray([""])
	owner.resize(P)
	if has_era:
		for n in era_pack["nations"]:
			nat_name.append(String(n["name"]))
			nat_code.append(String(n["id"]))
		var eo: Array = era_pack["owner"]
		for i in P:
			owner[i] = int(eo[i])
	else:
		var map := PackedInt32Array()
		map.resize(w.nat_code.size())
		for k in w.nat_code.size():
			if w.nat_code[k] != "":
				nat_name.append(w.nat_name[k]); nat_code.append(w.nat_code[k])
				map[k] = nat_name.size() - 1
		for i in P:
			owner[i] = map[w.prov_nat[i]]
	rebel = nat_name.size()
	nat_name.append("Rebels"); nat_code.append("XRB")
	N = nat_name.size() - 1
	N1 = N + 1

	# ---- provinces ----
	occupier.resize(P); army.resize(P); pop.resize(P); occ_turns.resize(P)
	for a in [dev, econ, stab, happy, defense, terrain, building, b_level, b_building, b_turns, capital, discoverable, dirty_flag]:
		a.resize(P)
	if has_era:
		for p in era_pack.get("discoverable", []):
			discoverable[int(p)] = 1
	for p in P:
		army[p] = 15 + rng.randi_n(25)
		pop[p] = 80 + rng.randi_n(120)
		dev[p] = 1 + rng.randi_n(3)
		econ[p] = 1 + rng.randi_n(3)
		happy[p] = 55 + rng.randi_n(20)
		stab[p] = 70 + rng.randi_n(22)
		var h: int = TBRng.hash_str(w.id[p]) % D.TERRAIN_TOTAL
		var t := 0
		while t < D.TERRAIN_WEIGHT.size() - 1:
			h -= D.TERRAIN_WEIGHT[t]
			if h < 0:
				break
			t += 1
		terrain[p] = t

	# ---- nation arrays ----
	for a in [gold, manpower, mp, dp, tech_level, research, liberty]:
		a.resize(N1)
	for a in [era, regime, personality, alive, human, cap_lost, tribute]:
		a.resize(N1)
	for a in [capital_of, overlord, last_war_turn, color]:
		a.resize(N1)
	capital_of.fill(-1); last_war_turn.fill(-99)
	budget.resize(N1 * 4); rel.resize(N1 * N1); grudge.resize(N1 * N1)
	truce.resize(N1 * N1); war_score.resize(N1 * N1); war_turns.resize(N1 * N1)
	own_start.resize(N1 + 1); own_list.resize(P); war_cnt.resize(N1)
	ev_last_any.resize(N1); ev_last_any.fill(-99); trade_bonus.resize(N1); combat_bonus.resize(N1); combat_turns.resize(N1)
	start_year = year
	for n in range(1, N1):
		gold[n] = 45 + rng.randi_n(35)
		manpower[n] = 55 + rng.randi_n(40)
		mp[n] = 6; dp[n] = 4
		tech_level[n] = 0.1 + rng.next() * 0.3
		regime[n] = D.REGIME_REBELS if n == rebel else D.REGIME_POOL[(n - 1) % D.REGIME_POOL.size()]
		personality[n] = TBRng.hash_str(nat_code[n]) % D.PERSONALITIES.size()
		budget[n * 4] = 50; budget[n * 4 + 1] = 20; budget[n * 4 + 2] = 15; budget[n * 4 + 3] = 15
		color[n] = gen_color(n)
	nb_off = w.nb_off.duplicate(); nb = w.nb.duplicate(); nb_sea.resize(w.nb.size())
	rebuild_owned()
	for n in range(1, N1):
		alive[n] = 1 if (n != rebel and own_count(n) > 0) else 0  # init only (no relations yet)
		if alive[n]:
			reassign_capital(n)
	for n in range(1, N1):
		era[n] = mini(4, int(floor(tech_level[n])))
	if has_era:
		var base: float = D.ERA_TECH_BASE.get(era_id, 0.0)
		for n in range(1, N1):
			tech_level[n] = minf(5.0, base + rng.next() * 0.3)
			era[n] = mini(4, int(floor(tech_level[n])))
	elif rules >= 1:
		# the modern world starts technologically modern (rules 0 kept the legacy ancient-tech baseline)
		for n in range(1, N1):
			tech_level[n] = 3.6 + rng.next() * 0.9
			era[n] = mini(4, int(floor(tech_level[n])))
	add_sea_links()

func set_human(n: int) -> void:
	human.fill(0); human[n] = 1; human_id = n
	gold[n] = diff["startGold"]; manpower[n] = diff["startManpower"]; mp[n] = 10; dp[n] = 6

## multiplayer: several human nations (human_id stays the first one, used by SP-centric helpers)
func add_human(n: int) -> void:
	human[n] = 1
	if human_id == 0: human_id = n
	gold[n] = diff["startGold"]; manpower[n] = diff["startManpower"]; mp[n] = 10; dp[n] = 6

func humans() -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in range(1, N1):
		if human[n] != 0: out.append(n)
	return out

# ---------------------------------------------------------------- geometry helpers
static func gc_dist(lon1: float, lat1: float, lon2: float, lat2: float) -> float:
	var dl := deg_to_rad(lon2 - lon1)
	var a := deg_to_rad(lat1)
	var b := deg_to_rad(lat2)
	var x := pow(sin((b - a) / 2.0), 2.0) + cos(a) * cos(b) * pow(sin(dl / 2.0), 2.0)
	return 2.0 * asin(minf(1.0, sqrt(x)))

func add_sea_links() -> void:
	var w := world
	var extra: Array = []
	extra.resize(P)
	for i in P:
		extra[i] = []
	var cells := {}
	for p in P:
		var k: int = int((w.lon[p] + 180.0) / 10.0) * 100 + int((w.lat[p] + 90.0) / 10.0)
		if not cells.has(k):
			cells[k] = []
		cells[k].append(p)
	const MAXD := 0.42
	for p in P:
		if w.nb_off[p + 1] - w.nb_off[p] > 2:
			continue
		var cx: int = int((w.lon[p] + 180.0) / 10.0)
		var cy: int = int((w.lat[p] + 90.0) / 10.0)
		var near: Array = []
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var k: int = posmod(cx + dx, 36) * 100 + (cy + dy)
				if not cells.has(k):
					continue
				for q in cells[k]:
					if q == p:
						continue
					var is_nb := false
					for i in range(w.nb_off[p], w.nb_off[p + 1]):
						if w.nb[i] == q:
							is_nb = true
							break
					if is_nb:
						continue
					near.append([gc_dist(w.lon[p], w.lat[p], w.lon[q], w.lat[q]), q])
		near.sort_custom(func(a, b): return a[0] < b[0] if a[0] != b[0] else a[1] < b[1])
		var added := 0
		for e in near:
			if added < 2 or (e[0] < MAXD and added < 3):
				extra[p].append(e[1]); extra[e[1]].append(p)
				added += 1
			else:
				break
	var off := PackedInt32Array(); off.resize(P + 1)
	var lst := PackedInt32Array(); var sea := PackedByteArray()
	for p in P:
		var land := {}
		for i in range(w.nb_off[p], w.nb_off[p + 1]):
			lst.append(w.nb[i]); sea.append(0); land[w.nb[i]] = true
		var ex: Array = []
		var seen := {}
		for q in extra[p]:
			if not land.has(q) and not seen.has(q):
				seen[q] = true; ex.append(q)
		ex.sort()
		for q in ex:
			lst.append(q); sea.append(1)
		off[p + 1] = lst.size()
	nb_off = off; nb = lst; nb_sea = sea

# ---------------------------------------------------------------- ownership
func rebuild_owned() -> void:
	own_start.fill(0)
	for p in P:
		own_start[owner[p] + 1] += 1
	for n in N1:
		own_start[n + 1] += own_start[n]
	var fill := PackedInt32Array(); fill.resize(N1)
	for p in P:
		var o := owner[p]
		own_list[own_start[o] + fill[o]] = p
		fill[o] += 1
	own_dirty = false

func own_count(n: int) -> int:
	if own_dirty: rebuild_owned()
	return own_start[n + 1] - own_start[n]

func owned(n: int) -> PackedInt32Array:
	if own_dirty: rebuild_owned()
	return own_list.slice(own_start[n], own_start[n + 1])

func touch(p: int) -> void:
	if dirty_flag[p] == 0:
		dirty_flag[p] = 1
		dirty_list.append(p)

func take_dirty() -> PackedInt32Array:
	var l := dirty_list
	for p in l:
		dirty_flag[p] = 0
	dirty_list = PackedInt32Array()
	return l

func set_owner(p: int, n: int) -> void:
	if owner[p] == n: return
	owner[p] = n; own_dirty = true; touch(p)

func controller(p: int) -> int:
	return occupier[p] if occupier[p] != 0 else owner[p]

func reassign_capital(n: int) -> void:
	var own := owned(n)
	for p in own:
		if capital[p] != 0: capital[p] = 0
	if own.is_empty():
		capital_of[n] = -1
		return
	var best: int = own[0]
	var bd := -1
	for p in own:
		var d := nb_off[p + 1] - nb_off[p]
		if d > bd:
			bd = d; best = p
	capital[best] = 1; capital_of[n] = best; touch(best)

# ---------------------------------------------------------------- relations
func get_rel(a: int, b: int) -> int: return rel[a * N1 + b]

func set_rel(a: int, b: int, v: int) -> void:
	var old: int = rel[a * N1 + b]
	rel[a * N1 + b] = v; rel[b * N1 + a] = v
	if old != v: rel_dirty.append(mini(a, b) * N1 + maxi(a, b))
	if old == D.REL_WAR and v != D.REL_WAR:
		if alive[b] != 0: war_cnt[a] -= 1
		if alive[a] != 0: war_cnt[b] -= 1
	elif old != D.REL_WAR and v == D.REL_WAR:
		if alive[b] != 0: war_cnt[a] += 1
		if alive[a] != 0: war_cnt[b] += 1
	if v == D.REL_WAR:
		war_score[a * N1 + b] = 0; war_score[b * N1 + a] = 0
		war_turns[a * N1 + b] = 0; war_turns[b * N1 + a] = 0

## single choke point for alive flips (keeps war_cnt consistent)
func set_alive(n: int, v: int) -> void:
	if alive[n] == v: return
	alive[n] = v
	var d := 1 if v != 0 else -1
	var base := n * N1
	for o in range(1, N1):
		if rel[base + o] == D.REL_WAR: war_cnt[o] += d

func at_war(n: int) -> bool:
	return war_cnt[n] > 0

func has_truce(a: int, b: int) -> bool: return truce[a * N1 + b] > turn

func friendly(a: int, b: int) -> bool:
	if a == b: return true
	var r := get_rel(a, b)
	return r == D.REL_ALLY or r == D.REL_MARRIAGE or overlord[a] == b or overlord[b] == a

# ---------------------------------------------------------------- economy
func province_value(p: int) -> float:
	var e := clampi(econ[p], 1, 5)
	var d := clampi(dev[p], 1, 5)
	var v := 1.0 + e * 0.1 + d * 2.0 + pop[p] * 0.001
	if capital[p] != 0: v *= (10.0 if rules == 0 else 4.0)
	return v

func income(n: int) -> Dictionary:
	var own := owned(n)
	var out := {"gold": 0, "manpower": 0, "upkeep": 0, "tax": 0, "production": 0, "admin": 0, "net": 0, "manCap": 120, "lands": own.size(), "capLost": false, "pop": 0, "happyAvg": 60, "researchBonus": 0.0}
	if own.is_empty(): return out
	var eraD: Dictionary = D.ERAS[era[n]]
	var reg: Dictionary = D.REGIMES[regime[n]]
	var tax_pct: float = budget[n * 4]
	var tl: float = tech_level[n]
	var tech_inc := 1.0 + tl * 0.03
	var tech_admin := 1.0 / (1.0 + tl * 0.05)
	var tech_up := 1.0 / (1.0 + tl * 0.04)
	var cap := capital_of[n]
	var cap_lost_now: bool = cap >= 0 and controller(cap) != n
	out["capLost"] = cap_lost_now
	var prod := 0; var tax := 0; var admin := 0; var man := 0
	var up_base := 0.0; var hs := 0; var tp := 0; var rb := 0.0
	var cap_lon := world.lon[cap] if cap >= 0 else 0.0
	var cap_lat := world.lat[cap] if cap >= 0 else 0.0
	var inc_prod: float = reg["incProd"]; var inc_tax: float = reg["incTax"]; var adm_cost: float = reg["adminCost"]
	var era_inc: int = eraD["incomeBonus"]; var era_mp: int = eraD["mpBonus"]
	for p in own:
		if occupier[p] != 0 and occupier[p] != n:
			tp += pop[p]; hs += happy[p]
			continue
		var stab_mod := 0.5 + stab[p] / 200.0
		var dv := clampi(dev[p], 1, 5)
		var ec := clampi(econ[p], 1, 5)
		hs += happy[p]; tp += pop[p]
		var pop_b := pop[p] / 80
		var mkt := 2 if building[p] == D.B_MARKET else 0
		var pp := int(floor((3 + D.DEV_INCOME[dv] + pop_b + era_inc + mkt) * stab_mod * inc_prod))
		pp += int(floor(ec * dv * 0.4 * stab_mod))
		if capital[p] != 0: pp += 3
		if building[p] == D.B_WORKSHOP: pp = int(floor(pp * (1.0 + 0.05 * b_level[p])))
		prod += pp
		tax += int(floor(pop[p] / 20.0 * (tax_pct / 100.0) * (happy[p] / 100.0) * inc_tax))
		if capital[p] == 0 and cap >= 0:
			admin += int(floor(gc_dist(cap_lon, cap_lat, world.lon[p], world.lat[p]) * D.ADMIN_DIST_FACTOR * adm_cost))
		man += int(floor((2 + pop[p] / 100 + era_mp) * stab_mod))
		up_base += army[p] * (0.8 if building[p] == D.B_SUPPLYCAMP else 1.0)
		if building[p] == D.B_LIBRARY: rb += (pop[p] / 750.0) * b_level[p]
	var gld: int = prod + tax
	if cap_lost_now: gld = int(floor(gld * 0.5))
	gld = int(floor(gld * float(reg["incMul"]) * tech_inc))
	admin = int(floor(admin * tech_admin))
	var upkeep := int(floor(up_base * (0.25 + era[n] * 0.05) * tech_up * float(reg["upkeep"])))
	out["gold"] = gld; out["manpower"] = man; out["upkeep"] = upkeep; out["tax"] = tax; out["production"] = prod; out["admin"] = admin
	out["net"] = gld - admin - upkeep
	out["manCap"] = maxi(120 + era[n] * 50, own.size() * 30 + era[n] * 35)
	out["pop"] = tp; out["happyAvg"] = int(round(hs / float(own.size()))); out["researchBonus"] = rb
	return out

# ---------------------------------------------------------------- combat / movement
func def_mul(p: int) -> float:
	var m: float = 1.0 + D.TERRAIN_DEF[terrain[p]]
	var b := building[p]
	if b == D.B_FORTRESS: m += 0.8 if b_level[p] >= 2 else 0.5
	elif b == D.B_WATCHTOWER: m += 0.03
	var c := controller(p)
	if c != 0: m += float(D.REGIMES[regime[c]]["defenseBonus"])
	return m + defense[p] / 100.0

func combat_mul(n: int) -> float:
	if n == 0: return 1.0
	var m: float = D.ERAS[era[n]]["combatMul"]
	if combat_turns[n] > 0: m += combat_bonus[n]
	return m

func sea_edge(from: int, to: int) -> int:
	for i in range(nb_off[from], nb_off[from + 1]):
		if nb[i] == to: return 1 if nb_sea[i] == 1 else 0
	return -1

func move_or_attack(n: int, from: int, to: int, troops: int) -> String:
	if controller(from) != n: return "!notyours"
	var se := sea_edge(from, to)
	if se < 0: return "!notadjacent"
	if se == 1 and building[from] != D.B_PORT: return "!needport"
	if army[from] <= 1: return "!noarmy"
	var ctrl_to := controller(to)
	if ctrl_to == n:
		var k := mini(troops if troops != 0 else army[from] - 1, army[from] - 1)
		if k <= 0: return "!noarmy"
		army[from] -= k; army[to] = mini(65000, army[to] + k); touch(from); touch(to)
		return "move"
	if ctrl_to != 0 and friendly(n, ctrl_to): return "!friendly"
	if ctrl_to != 0 and get_rel(n, ctrl_to) != D.REL_WAR: return "!nowar"
	if discoverable[to] != 0 and tech_level[n] < 2 and owner[to] == 0: return "!undiscovered"
	return resolve_combat(n, from, to, troops)

func resolve_combat(n: int, from: int, to: int, troops: int) -> String:
	var avail := army[from]
	var send := maxi(1, mini(troops if troops != 0 else avail - 1, avail - 1))
	var atk_n := n
	var def_n := controller(to)
	var atk: float = send * combat_mul(atk_n) * float(D.TERRAIN_ATK[terrain[to]])
	var dfn: float = army[to] * combat_mul(def_n) * def_mul(to)
	if atk > dfn:
		var surv := maxi(1, int(round((atk - dfn) / maxf(0.01, combat_mul(atk_n)))))
		var occ := mini(send, surv)
		if owner[to] == 0: set_owner(to, atk_n)
		elif owner[to] == atk_n:
			occupier[to] = 0; occ_rev += 1
		elif atk_n == rebel or def_n == rebel: cede(to, atk_n)
		else:
			occupier[to] = atk_n; occ_turns[to] = 0; occ_rev += 1
		army[to] = occ; defense[to] = 0
		army[from] = maxi(0, avail - occ)
		touch(from); touch(to)
		return "win"
	var atk_loss := int(round(send * minf(0.9, dfn / (atk + dfn))))
	army[from] = maxi(0, avail - atk_loss)
	army[to] = maxi(1, army[to] - int(round(army[to] * (atk / (atk + dfn)) * 0.55)))
	touch(from); touch(to)
	return "loss"

func cede(p: int, to: int) -> void:
	var from := owner[p]
	set_owner(p, to); occupier[p] = 0; occ_rev += 1
	if from != 0 and capital[p] != 0:
		capital[p] = 0; capital_of[from] = -1; reassign_capital(from)
		if own_count(from) == 0 and from != rebel: eliminate(from)

func eliminate(n: int) -> void:
	set_alive(n, 0)
	for o in range(1, N + 1):
		if rel[n * N1 + o] == D.REL_WAR: set_rel(n, o, D.REL_PEACE)
	log.append({"turn": turn, "kind": "eliminated", "a": n})

# ---------------------------------------------------------------- commands (the ONLY mutation API)
func apply(c: Dictionary) -> Dictionary:
	var cmd: String = c.get("cmd", "")
	var n: int = int(c.get("n", 0))
	if cmd != "noop" and (n <= 0 or n >= N1 or alive[n] == 0): return {"ok": false, "err": "dead"}
	match cmd:
		"move": return _c_move(c)
		"recruit": return _c_recruit(c)
		"declareWar": return _c_declare_war(c)
		"peace": return _c_peace(c)
		"ally": return _c_ally(c)
		"nap": return _c_nap(c)
		"breakPact": return _c_break_pact(c)
		"build": return _c_build(c)
		"budget": return _c_budget(c)
		"colonize": return _c_colonize(c)
		"relocate": return _c_relocate(c)
		"regime": return _c_regime(c)
		"develop": return _c_develop(c)
		"hire": return _c_hire(c)
		"eventChoice": return TBEvents.resolve_choice(self, n, int(c.get("uid", 0)), int(c.get("i", 0)))
		"noop": return {"ok": true}
	return {"ok": false, "err": "unknown"}

func _err(e: String) -> Dictionary: return {"ok": false, "err": e}

func _c_move(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var to: int = c["to"]
	var att := controller(to) != n
	var need: float = D.MP_ATTACK if att else D.MP_MOVE
	if mp[n] < need: return _err("mp")
	var r := move_or_attack(n, int(c["from"]), to, int(c.get("troops", 0)))
	if r.begins_with("!"): return _err(r.substr(1))
	mp[n] -= need
	return {"ok": true, "result": r}

func _c_recruit(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if controller(p) != n or owner[p] != n: return _err("notyours")
	var reg: Dictionary = D.REGIMES[regime[n]]
	var amount := clampi(int(c.get("amount", 15)), 5, 30)
	var gold_cost := int(ceil((D.COST_RECRUIT_GOLD + amount * 0.6) * float(reg["recruitCost"]) * (0.5 if building[p] == D.B_ARMORY else 1.0)))
	var man_cost: int = D.COST_RECRUIT_MAN + amount
	if gold[n] < gold_cost: return _err("gold")
	if manpower[n] < man_cost: return _err("manpower")
	if mp[n] < D.MP_RECRUIT: return _err("mp")
	gold[n] -= gold_cost; manpower[n] -= man_cost; mp[n] -= D.MP_RECRUIT
	army[p] = mini(65000, army[p] + amount); touch(p)
	return {"ok": true}

func _c_declare_war(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	if n == t or t <= 0 or t >= N1 or alive[t] == 0: return _err("target")
	if get_rel(n, t) == D.REL_WAR: return _err("already")
	if has_truce(n, t): return _err("truce")
	if dp[n] < D.DP_WAR: return _err("dp")
	if overlord[n] == t or overlord[t] == n: return _err("vassal")
	var was := get_rel(n, t)
	dp[n] -= D.DP_WAR; set_rel(n, t, D.REL_WAR); last_war_turn[n] = turn
	var gi := t * N1 + n
	grudge[gi] = mini(100, grudge[gi] + (80 if was == D.REL_ALLY else (60 if was == D.REL_NAP else 40)))
	log.append({"turn": turn, "kind": "war", "a": n, "b": t})
	for o in range(1, N + 1):
		if o != n and o != t and alive[o] != 0 and get_rel(t, o) == D.REL_ALLY and not friendly(n, o) and get_rel(n, o) != D.REL_WAR and not has_truce(n, o):
			set_rel(n, o, D.REL_WAR)
			log.append({"turn": turn, "kind": "war", "a": o, "b": n, "ally": 1})
	return {"ok": true}

func _c_peace(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	if get_rel(n, t) != D.REL_WAR: return _err("notwar")
	var ws := war_score[n * N1 + t]
	var kind: String = c.get("kind", "white")
	if human[t] == 0 and not c.get("_force", false) and not TBAI.accepts_peace(self, t, n, kind): return _err("refused")
	if kind == "cede":
		if ws < 25: return _err("warscore")
		var budget_pts := ws * 0.9
		var taken := 0
		var prov: Array = []
		for p in owned(t):
			if occupier[p] == n: prov.append(p)
		prov.sort_custom(func(a, b):
			var va := province_value(a); var vb := province_value(b)
			return a < b if va == vb else va < vb)
		var total_val := 0.0
		for p in owned(t): total_val += province_value(p)
		if total_val == 0.0: total_val = 1.0
		for p in prov:
			var pct := province_value(p) / total_val * 100.0
			if pct > budget_pts: continue
			budget_pts -= pct; cede(p, n); taken += 1
		log.append({"turn": turn, "kind": "ceded", "a": n, "b": t, "k": taken})
	for p in owned(t):
		if occupier[p] == n:
			occupier[p] = 0; touch(p)
	for p in owned(n):
		if occupier[p] == t:
			occupier[p] = 0; touch(p)
	occ_rev += 1
	set_rel(n, t, D.REL_PEACE)
	var tt: int = D.TRUCE_TURNS if rules == 0 else 12
	truce[n * N1 + t] = turn + tt; truce[t * N1 + n] = turn + tt
	dp[n] = maxf(0.0, dp[n] - D.DP_PEACE)
	log.append({"turn": turn, "kind": "peace", "a": n, "b": t})
	return {"ok": true}

func _c_ally(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	if get_rel(n, t) == D.REL_WAR: return _err("war")
	if dp[n] < D.DP_ALLY: return _err("dp")
	if human[t] == 0 and not TBAI.accepts_pact(self, t, n, D.REL_ALLY): return _err("refused")
	dp[n] -= D.DP_ALLY; set_rel(n, t, D.REL_ALLY)
	log.append({"turn": turn, "kind": "ally", "a": n, "b": t})
	return {"ok": true}

func _c_nap(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	if get_rel(n, t) != D.REL_PEACE: return _err("state")
	if dp[n] < D.DP_NAP: return _err("dp")
	if human[t] == 0 and not TBAI.accepts_pact(self, t, n, D.REL_NAP): return _err("refused")
	dp[n] -= D.DP_NAP; set_rel(n, t, D.REL_NAP)
	nap_expiry[mini(n, t) * N1 + maxi(n, t)] = turn + 20
	return {"ok": true}

func _c_break_pact(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var t: int = c["t"]
	var r := get_rel(n, t)
	if r != D.REL_ALLY and r != D.REL_NAP: return _err("state")
	set_rel(n, t, D.REL_PEACE)
	var gi := t * N1 + n
	grudge[gi] = mini(100, grudge[gi] + 25)
	return {"ok": true}

func _c_build(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]; var b: int = int(c["b"])
	if b < 1 or b > D.BUILDINGS.size(): return _err("type")
	var bt: Dictionary = D.BUILDINGS[b - 1]
	if owner[p] != n or occupier[p] != 0: return _err("notyours")
	if b_building[p] != 0: return _err("busy")
	var cur: int = b_level[p] if building[p] == b else 0
	if building[p] != 0 and building[p] != b: return _err("occupied")
	var lvl := cur + 1
	if lvl > int(bt["maxLevel"]): return _err("max")
	if tech_level[n] < float(bt["tech"][lvl - 1]): return _err("tech")
	var reg: Dictionary = D.REGIMES[regime[n]]
	var mpc := maxi(1, int(round(float(bt["mp"][lvl - 1]) * float(reg["moveCost"]))))
	if gold[n] < float(bt["cost"][lvl - 1]): return _err("gold")
	if mp[n] < mpc: return _err("mp")
	gold[n] -= float(bt["cost"][lvl - 1]); mp[n] -= mpc
	b_building[p] = b; b_turns[p] = int(bt["buildTime"][lvl - 1]); touch(p)
	return {"ok": true}

func _c_budget(c: Dictionary) -> Dictionary:
	var i: int = ["tax", "goods", "research", "invest"].find(c.get("key", ""))
	if i < 0: return _err("key")
	var o: int = int(c["n"]) * 4
	var v := clampi(int(c.get("val", 0)), 0, 100)
	budget[o + i] = v
	var sum: int = budget[o] + budget[o + 1] + budget[o + 2] + budget[o + 3]
	var guard := 8
	while sum != 100 and guard > 0:
		guard -= 1
		var d := 100 - sum
		var k := -1; var best := -1
		for j in 4:
			if j != i and ((budget[o + j] > 0) if d < 0 else (budget[o + j] < 100)):
				var wgt: int = budget[o + j] if d < 0 else 100 - budget[o + j]
				if wgt > best:
					best = wgt; k = j
		if k < 0: break
		budget[o + k] = clampi(budget[o + k] + d, 0, 100)
		sum = budget[o] + budget[o + 1] + budget[o + 2] + budget[o + 3]
	return {"ok": true}

func _c_colonize(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if owner[p] != 0: return _err("taken")
	if discoverable[p] != 0 and tech_level[n] < 2: return _err("tech")
	var adj := false
	for i in range(nb_off[p], nb_off[p + 1]):
		var q := nb[i]
		if owner[q] == n and (nb_sea[i] == 0 or building[q] == D.B_PORT):
			adj = true; break
	if not adj: return _err("notadjacent")
	var reg: Dictionary = D.REGIMES[regime[n]]
	var cost: int = 0 if reg["colonyFree"] else 60 + own_count(n) * 2
	if gold[n] < cost: return _err("gold")
	if mp[n] < 2: return _err("mp")
	gold[n] -= cost; mp[n] -= 2; set_owner(p, n); army[p] = maxi(army[p], 8); discoverable[p] = 0
	return {"ok": true}

func _c_relocate(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if owner[p] != n: return _err("notyours")
	if gold[n] < 80: return _err("gold")
	gold[n] -= 80
	var old := capital_of[n]
	if old >= 0:
		capital[old] = 0; touch(old)
	capital[p] = 1; capital_of[n] = p; touch(p)
	return {"ok": true}

func _c_regime(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var r: int = int(c["r"])
	if r < 0 or r >= D.REGIMES.size() or r == D.REGIME_REBELS: return _err("type")
	if era[n] < int(D.REGIMES[r]["sinceEra"]): return _err("era")
	if gold[n] < 120: return _err("gold")
	gold[n] -= 120; regime[n] = r
	for p in owned(n):
		stab[p] = maxi(5, stab[p] - 15)
	return {"ok": true}

## mercenaries: converts gold directly into troops (no manpower), pricey
func _c_hire(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if controller(p) != n or owner[p] != n: return _err("notyours")
	var amount := clampi(int(c.get("amount", 30)), 10, 60)
	var cost := int(ceil(amount * 5.0 * float(D.REGIMES[regime[n]]["recruitCost"])))
	if gold[n] < cost: return _err("gold")
	if mp[n] < 1: return _err("mp")
	gold[n] -= cost; mp[n] -= 1
	army[p] = mini(65000, army[p] + amount); touch(p)
	return {"ok": true}

func _c_develop(c: Dictionary) -> Dictionary:
	var n: int = c["n"]; var p: int = c["p"]
	if owner[p] != n or occupier[p] != 0: return _err("notyours")
	var cap := clampi(int(floor(tech_level[n])) + 1, 1, 5)
	if dev[p] >= cap: return _err("max")
	var cost := 80 + dev[p] * 80
	if gold[n] < cost: return _err("gold")
	if mp[n] < 2: return _err("mp")
	gold[n] -= cost; mp[n] -= 2
	dev[p] += 1; stab[p] = mini(100, stab[p] + 4); pop[p] = mini(2000, pop[p] + 20); touch(p)
	return {"ok": true}

# ---------------------------------------------------------------- misc
static func gen_color(n: int) -> int:
	var h := fposmod(n * 137.508, 360.0)
	var s := 0.55 + (n % 3) * 0.1
	var l := 0.45 + (n % 4) * 0.05
	var col := Color.from_hsv(h / 360.0, minf(1.0, s), minf(1.0, l + 0.35))
	return col.to_rgba32() >> 8   # 0xRRGGBB

func end_turn() -> PackedInt32Array:
	return TBTurn.end_turn(self)

func state_checksum() -> int:
	# order-sensitive integer checksum over key arrays (used for oracle comparison with the JS reference)
	var h: int = 2166136261
	for arr in [owner, occupier, army, pop]:
		for i in arr.size():
			h = TBRng.imul(h ^ (arr[i] & 0xFFFF), 16777619)
	for i in gold.size():
		h = TBRng.imul(h ^ (int(gold[i]) & 0xFFFF), 16777619)
	for i in rel.size():
		h = TBRng.imul(h ^ rel[i], 16777619)
	h = TBRng.imul(h ^ turn, 16777619)
	return h
