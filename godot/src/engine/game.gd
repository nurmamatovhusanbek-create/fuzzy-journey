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
var rules: int = 3                # 0 = legacy behaviour (oracle-exact vs JS reference), 1 = tuned game rules, 2 = districts (several buildings per province, development limited by population)
var difficulty: String
var diff: Dictionary
var turn: int = 1
var year: int
var month_idx: int = 0
var era_id: String
var over: bool = false
var winner: int = 0
var victory_kind: String = ""
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
var intel := PackedFloat32Array()      # covert-ops resource (rules >= 1)
var liberty := PackedFloat32Array()
var era := PackedByteArray()
var regime := PackedByteArray()
var personality := PackedByteArray()
var alive := PackedByteArray()
var human := PackedByteArray()
var cap_lost := PackedByteArray()
var tribute := PackedByteArray()
var infamy := PackedFloat32Array()    # rules >= 1: raised by unjustified wars and conquest; >= 25 forms a coalition (engine/diplomacy.gd)
var coalition := PackedByteArray()
var realm_done := PackedByteArray()   # N1 * TBRealms.count(): 1 = unified (engine/realms.gd)
var trade := PackedByteArray()        # N1*N1 symmetric: 1 = trade deal (engine/trade.gd)
var trade_cnt := PackedByteArray()
var doctrine := PackedByteArray()             # TBDoctrine: 0 none, 1 martial, 2 mercantile, 3 administrative
var dec_until := PackedInt32Array()   # N1 * TBDecisions.LIST.size(): turn when a decision's effect ends
var core := PackedInt32Array()        # province -> original owner (rules >= 1: casus belli 'reclaim')
var capital_of := PackedInt32Array()
var overlord := PackedInt32Array()
var last_war_turn := PackedInt32Array()
var color := PackedInt32Array()
var budget := PackedByteArray()     # N1*4 : tax, goods, research, invest (%)
var rel := PackedByteArray()        # N1*N1
var truce := PackedInt32Array()     # N1*N1 expiry turn
var see_until := PackedInt32Array() # N1*N1: the turn until which nation a sees the armies of nation b (a spy report; rules >= 1, see TBVision)
var war_score := PackedInt32Array() # N1*N1
var war_turns := PackedInt32Array() # N1*N1
var grudge := PackedByteArray()     # N1*N1: grudge[a*N1+b] is how much a resents b (0..100, cools one point a turn)
var _dist_cap := PackedInt32Array()     # per province: the capital its cached distance (below) was measured to; derived, never saved, always exact (same float64 the formula gives)
var _dist_val := PackedFloat64Array()
var net_ema := PackedFloat32Array() # rules >= 3: each nation's net income, smoothed over about 7 turns (0 = no history yet): the 'persistent income' that trade routes need
var vic_hold := {}                  # rules >= 3: consecutive turns a player has held each victory condition ("<nation>:<id>" -> turns)
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
var move_fx: Array = []                       # [from, to, nation] marches the AI made this turn (view only, not saved): the interface shows those in sight
var battle_fx: Array = []                     # [from, to, attacker_won, attacker, defender] this turn, humans involved (view only, not saved)
var gen := PackedInt32Array()                 # generals (rules >= 1): see TBGenerals
var terrain := PackedByteArray()
var building := PackedByteArray()
var b_level := PackedByteArray()
var b_building := PackedByteArray()
var b_turns := PackedByteArray()
var b_lv := PackedByteArray()          # rules >= 2: building levels, NB per province (index p * NB + type - 1). building / b_level then mirror the province's main building for the old single view
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
var offer_cd := PackedInt32Array()      # per nation: the turn a human last had a proposal that asked for an answer (TBDiplo.ai_offer paces them)
var marches: Array = []                 # standing march orders {n, at, to, k}: the army in `at` walks on toward `to`, one stride per end of turn (TBMarch)
var march_fx: Array = []                # [from, to, result, nation] strides made at the last end of turn (view only, not saved)
var asks: Array = []                    # requests to AI courts waiting for next turn's answer (TBAsks)
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
var stats: Array = []                # TBStats samples (statistics screen)
# rulers (rules >= 1): see engine/rulers.gd
var r_name := PackedStringArray()    # "rn:<idx>" (procedural, i18n) or "English|Russian" (historical)
var r_num := PackedByteArray()
var r_born := PackedInt32Array()     # turn of birth (negative = before start)
var r_since := PackedInt32Array()    # turn of accession
var r_adm := PackedByteArray()
var r_dip := PackedByteArray()
var r_mil := PackedByteArray()
var r_trait := PackedByteArray()
var nap_expiry: Dictionary = {}
var occ_rev: int = 0
# rules >= 1 economy / world state (all derived each tick, kept so a save round-trips)
var infl: float = 0.0                # share of every treasury lost to inflation this turn
var world_y: float = 0.0             # gross income of all living nations, last tick
var econ_goal: float = 0.0           # income share Economic Supremacy needs (set from the era's start)
var tech_top: float = 0.0            # best tech level, second best, mean (last tick)
var tech_second: float = 0.0
var tech_avg: float = 0.0
var tech_start_top: float = 0.0      # best tech level when the game began
var aggr_level: int = 1              # TBData.AGGRESSION index: how warlike the AI world is
var reb_age := PackedByteArray()     # turns a province has been held by rebels
var reb_from := PackedInt32Array()   # who it rebelled from
var own_since := PackedInt32Array()  # turn the current owner took the province (conquered land is unruly until it is assimilated)

func _init(w: TBWorld, era_pack: Dictionary, opts: Dictionary = {}) -> void:
	world = w
	P = w.P
	seed_value = int(opts.get("seed", 1))
	rules = int(opts.get("rules", 3))
	aggr_level = clampi(int(opts.get("aggression", 1)), 0, D.AGGRESSION.size() - 1)
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
	occupier.resize(P); army.resize(P); pop.resize(P); occ_turns.resize(P); gen.resize(P); reb_age.resize(P); reb_from.resize(P); own_since.resize(P)
	for a in [dev, econ, stab, happy, defense, terrain, building, b_level, b_building, b_turns, capital, discoverable, dirty_flag]:
		a.resize(P)
	b_lv.resize(P * NB)
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
	truce.resize(N1 * N1); war_score.resize(N1 * N1); war_turns.resize(N1 * N1); see_until.resize(N1 * N1); offer_cd.resize(N1); offer_cd.fill(-99)
	own_start.resize(N1 + 1); own_list.resize(P); war_cnt.resize(N1)
	intel.resize(N1); intel.fill(5.0)
	trade.resize(N1 * N1); trade_cnt.resize(N1); doctrine.resize(N1); net_ema.resize(N1)
	_dist_cap.resize(P); _dist_cap.fill(-1); _dist_val.resize(P)
	infamy.resize(N1); coalition.resize(N1); dec_until.resize(N1 * TBDecisions.LIST.size())
	r_name.resize(N1); r_born.resize(N1); r_since.resize(N1)
	for a in [r_num, r_adm, r_dip, r_mil, r_trait]:
		a.resize(N1)
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
		color[n] = gen_color(n) if rules == 0 else gen_wash(n)
	nb_off = w.nb_off.duplicate(); nb = w.nb.duplicate(); nb_sea.resize(w.nb.size())
	var have_sea: bool = not w.nbx.is_empty()
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
	# sea links are installed AFTER capitals/eras were set (legacy order: capitals were chosen from land adjacency only)
	if have_sea:
		nb_off = w.nbx_off.duplicate(); nb = w.nbx.duplicate(); nb_sea = w.nbx_sea.duplicate()
	else:
		add_sea_links()
	if rules >= 1:
		core = owner.duplicate()
		TBRegimes.assign(self)
		TBRulers.init(self)
		TBRealms.init(self)
		TBTurn.refresh_world(self)          # world income, tech stats and the era's economic goal

## nation name for display (localised)
func dname(n: int) -> String: return TBI18n.nation(nat_name[n])

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
	if n == rebel and rebel > 0: reb_from[p] = owner[p]; reb_age[p] = 0       # a rebel province remembers who it rose against
	elif owner[p] == rebel: reb_from[p] = 0; reb_age[p] = 0
	owner[p] = n; own_since[p] = turn; own_dirty = true; touch(p)
	if gen[p] != 0: gen[p] = 0
	if n != 0 and not core.is_empty() and core[p] == 0: core[p] = n      # first settlers make it home land

func controller(p: int) -> int:
	return occupier[p] if occupier[p] != 0 else owner[p]

func reassign_capital(n: int) -> void:
	var own := owned(n)
	for p in own:
		if capital[p] != 0: capital[p] = 0
	if own.is_empty():
		capital_of[n] = -1
		return
	var best: int = TBCapitals.pick(self, n)                       # where the capital historically stood (rules >= 1), else the province with most neighbours
	if best < 0:
		best = own[0]
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
		if rules >= 1 and trade[a * N1 + b] != 0: TBTrade.set_deal(self, a, b, false)
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
	var lv2: bool = rules >= 2                                   # the hot loop reads the building levels directly (bl() / job_income() / job_fill() called for every province cost more than the sums)
	for p in own:
		if occupier[p] != 0 and occupier[p] != n:
			tp += pop[p]; hs += happy[p]
			continue
		var stab_p: int = stab[p]
		var pop_p: int = pop[p]
		var happy_p: int = happy[p]
		var stab_mod := 0.5 + stab_p / 200.0
		var dv := clampi(dev[p], 1, 5)
		var ec := clampi(econ[p], 1, 5)
		hs += happy_p; tp += pop_p
		var pop_b := pop_p / 80
		var base_b: int = p * NB
		var b_market: int = (b_lv[base_b + D.B_MARKET - 1] if lv2 else bl(p, D.B_MARKET))
		var mkt := 2 if b_market > 0 else 0
		var dinc: float = job_income(p, dv) if lv2 else float(D.DEV_INCOME[dv])
		var pp := int(floor((3 + dinc + pop_b + era_inc + mkt) * stab_mod * inc_prod))
		pp += int(floor(ec * dv * 0.4 * stab_mod))
		var is_cap: bool = capital[p] != 0
		if is_cap: pp += 3
		var b_work: int = (b_lv[base_b + D.B_WORKSHOP - 1] if lv2 else bl(p, D.B_WORKSHOP))
		if b_work > 0: pp = int(floor(pp * (1.0 + 0.05 * b_work)))
		prod += pp
		tax += int(floor(pop_p / 20.0 * (tax_pct / 100.0) * (happy_p / 100.0) * inc_tax))
		if not is_cap and cap >= 0:
			var dd: float
			if _dist_cap[p] == cap: dd = _dist_val[p]
			else:
				dd = gc_dist(cap_lon, cap_lat, world.lon[p], world.lat[p]); _dist_val[p] = dd; _dist_cap[p] = cap
			admin += int(floor(dd * D.ADMIN_DIST_FACTOR * adm_cost))
		man += int(floor((2 + pop_p / 100 + era_mp) * stab_mod))
		var b_camp: int = (b_lv[base_b + D.B_SUPPLYCAMP - 1] if lv2 else bl(p, D.B_SUPPLYCAMP))
		up_base += army[p] * (0.8 if b_camp > 0 else 1.0)
		var b_lib: int = (b_lv[base_b + D.B_LIBRARY - 1] if lv2 else bl(p, D.B_LIBRARY))
		if b_lib > 0: rb += (pop_p / 750.0) * b_lib
	var gld: int = prod + tax
	if rules >= 1: gld += TBTrade.income(self, n)
	if cap_lost_now: gld = int(floor(gld * 0.5))
	gld = int(floor(gld * float(reg["incMul"]) * tech_inc))
	if rules >= 1: gld = int(floor(gld * TBRulers.gold_mul(self, n)))
	admin = int(floor(admin * tech_admin))
	if rules >= 2: admin = int(floor(admin * (1.0 + OVEREXTEND_STEP * maxf(0.0, float(own.size() - OVEREXTEND_FROM)))))       # the bigger the realm, the dearer every governor
	if rules >= 1: admin = int(floor(admin * TBDecisions.admin_mul(self, n) * TBDoctrine.admin_mul(self, n)))
	var upkeep := int(floor(up_base * (0.25 + era[n] * 0.05) * tech_up * float(reg["upkeep"])))
	if rules >= 1: man = int(floor(man * TBRulers.manpower_mul(self, n)))
	out["gold"] = gld; out["manpower"] = man; out["upkeep"] = upkeep; out["tax"] = tax; out["production"] = prod; out["admin"] = admin
	out["net"] = gld - admin - upkeep
	out["manCap"] = maxi(120 + era[n] * 50, own.size() * 30 + era[n] * 35)
	out["pop"] = tp; out["happyAvg"] = int(round(hs / float(own.size()))); out["researchBonus"] = rb
	return out

# ---------------------------------------------------------------- districts: buildings per province (rules >= 2; rules < 2 keeps the single building)
const NB := 9                                  # building types (data.gd BUILDINGS)
const POP_NEED := [0, 40, 80, 130, 200, 300]   # people a province needs to staff each development level; below it the level's extra income is only partly earned
const OVEREXTEND_FROM := 60                    # provinces a court rules without strain; beyond them administration costs 0.4% more for each one
const OVEREXTEND_STEP := 0.004
const SLOT_COST_STEP := 0.20                   # every building already in the province makes the next new one this much dearer

## rules >= 3: where a building may stand: "" = anywhere; "coast" (a port needs the sea), "arid" / "polar" (a farm needs soil and rain: no farms in the great deserts or beyond 66 degrees)
func site_error(p: int, b: int) -> String:
	if rules < 3 or world.geo.size() != P: return ""
	var f: int = world.geo[p]
	if b == D.B_PORT: return "" if (f & 1) != 0 else "coast"
	if b == D.B_FARM:
		if (f & 2) != 0: return "arid"
		if (f & 4) != 0: return "polar"
	return ""

## level of building type b (1..NB, data.gd B_*) in province p; 0 = none
func bl(p: int, b: int) -> int:
	if rules >= 2: return b_lv[p * NB + b - 1]
	return b_level[p] if building[p] == b else 0

## how many different buildings stand in p
func b_used(p: int) -> int:
	if rules < 2: return 1 if building[p] != 0 else 0
	var k := 0
	for i in NB:
		if b_lv[p * NB + i] != 0: k += 1
	return k

## building slots of a province: one, one more per two development levels, one more in the capital (rules < 2: a single slot)
func b_slots(p: int) -> int:
	if rules < 2: return 1
	return 1 + int(dev[p] / 2) + (1 if capital[p] != 0 else 0)

## set the level of one building (rules >= 2) and keep the old single view (the highest level, the lowest type on a tie) in step
func set_bl(p: int, b: int, lv: int) -> void:
	if rules < 2:
		building[p] = b if lv > 0 else 0; b_level[p] = lv; touch(p); return
	b_lv[p * NB + b - 1] = lv
	var best := 0; var bv := 0
	for i in NB:
		var v: int = b_lv[p * NB + i]
		if v > bv: bv = v; best = i + 1
	building[p] = best; b_level[p] = bv
	touch(p)

## the buildings of p as [type, level] pairs
func b_list(p: int) -> Array:
	var out: Array = []
	if rules < 2:
		if building[p] != 0: out.append([int(building[p]), int(b_level[p])])
		return out
	for i in NB:
		var v: int = b_lv[p * NB + i]
		if v != 0: out.append([i + 1, v])
	return out

## gold price of building type b to level lvl in p: a NEW type costs 20% more for each building already there (rules >= 2)
func b_price(p: int, b: int, lvl: int) -> int:
	var base: float = float(D.BUILDINGS[b - 1]["cost"][lvl - 1])
	if rules >= 2 and bl(p, b) == 0: base *= 1.0 + SLOT_COST_STEP * b_used(p)
	return int(ceil(base))

## rules >= 2: income of development level dv in p when the people to staff it are short: the levels below are earned in full, the top level by the share staffed
func job_income(p: int, dv: int) -> float:
	var lo: float = float(D.DEV_INCOME[dv - 1]) if dv > 1 else 0.0
	var step: float = float(D.DEV_INCOME[dv]) - lo
	return lo + step * job_fill(p, dv)

func job_fill(p: int, dv: int) -> float:
	return minf(1.0, pop[p] / float(POP_NEED[clampi(dv, 1, 5)]))

## rules >= 2: roughly what the next development level earns each turn after the multipliers (shown on the Develop verb); 0 at the top
func develop_gain(p: int, n: int) -> int:
	var d := clampi(dev[p], 1, 5)
	if d >= 5: return 0
	var reg: Dictionary = D.REGIMES[regime[n]]
	var stab_mod := 0.5 + stab[p] / 200.0
	var step: float = job_income(p, d + 1) - job_income(p, d)
	var extra: float = clampi(econ[p], 1, 5) * 0.4 * stab_mod
	return int(roundf((step * stab_mod * float(reg["incProd"]) + extra) * float(reg["incMul"]) * (1.0 + tech_level[n] * 0.03)))

## price of the next development step (rules >= 2): about 30 turns to pay itself back
func develop_cost(p: int) -> int:
	if rules < 2: return 80 + dev[p] * 80
	var d := clampi(dev[p], 1, 4)
	return int(ceil(28.0 * float(D.DEV_INCOME[d + 1] - D.DEV_INCOME[d]))) if dev[p] < 5 else 0

# ---------------------------------------------------------------- combat / movement
func def_mul(p: int) -> float:
	var m: float = 1.0 + D.TERRAIN_DEF[terrain[p]]
	var fl := bl(p, D.B_FORTRESS)
	if fl > 0: m += 0.8 if fl >= 2 else 0.5
	if bl(p, D.B_WATCHTOWER) > 0: m += 0.03
	var c := controller(p)
	if c != 0: m += float(D.REGIMES[regime[c]]["defenseBonus"])
	return m + defense[p] / 100.0

func combat_mul(n: int) -> float:
	if n == 0: return 1.0
	var m: float = D.ERAS[era[n]]["combatMul"]
	if combat_turns[n] > 0: m += combat_bonus[n]
	if rules >= 1: m *= TBRulers.combat_mul(self, n)
	return m

## rules >= 1: how many soldiers a province can feed. Armies above this in foreign land waste away.
func supply_limit(p: int) -> int:
	var lim := 18 + 8 * dev[p] + int(pop[p] / 20.0)
	if bl(p, D.B_SUPPLYCAMP) > 0: lim += 40
	if bl(p, D.B_FARM) > 0: lim += 8 * bl(p, D.B_FARM)
	if terrain[p] == 2 or terrain[p] == 4: lim = int(lim * 0.7)       # mountains and marsh
	return lim

func attrition(p: int) -> int:
	if rules < 1: return 0
	var c := controller(p)
	if c == 0 or owner[p] == c or c == rebel: return 0
	var over := army[p] - supply_limit(p)
	return maxi(0, int(ceil(over * 0.07))) if over > 0 else 0

## read-only twin of move_or_attack's checks: "move", "attack", or an error code starting with "!"
func move_check(n: int, from: int, to: int) -> String:
	if controller(from) != n: return "!notyours"
	var se := sea_edge(from, to)
	if se < 0: return "!notadjacent"
	if se == 1 and bl(from, D.B_PORT) == 0: return "!needport"
	if army[from] <= 1: return "!noarmy"
	var ct := controller(to)
	if ct == n: return "move"
	if ct != 0 and friendly(n, ct): return "!friendly"
	if ct != 0 and get_rel(n, ct) != D.REL_WAR: return "!nowar"
	if discoverable[to] != 0 and tech_level[n] < 2 and owner[to] == 0: return "!undiscovered"
	return "attack"

## what resolve_combat would do (combat is deterministic): strengths, winner and losses, without changing anything
func combat_preview(n: int, from: int, to: int, troops: int) -> Dictionary:
	var avail := army[from]
	var send := maxi(1, mini(troops if troops != 0 else avail - 1, avail - 1))
	var def_n := controller(to)
	var rides := rules >= 1 and TBGenerals.follows(self, from, avail - send)
	var atk: float = send * combat_mul(n) * float(D.TERRAIN_ATK[terrain[to]])
	var dfn: float = army[to] * combat_mul(def_n) * def_mul(to)
	if rides: atk *= TBGenerals.mul(self, from)
	if rules >= 1: dfn *= TBGenerals.mul(self, to)
	var out := {"send": send, "defenders": army[to], "atk": atk, "dfn": dfn, "win": atk > dfn, "rides": rides, "mp": D.MP_ATTACK}
	if atk > dfn:
		var surv := maxi(1, int(round((atk - dfn) / maxf(0.01, combat_mul(n)))))
		var occ := mini(send, surv)
		out["hold"] = occ; out["lost"] = send - occ; out["enemy_lost"] = army[to]
	else:
		out["lost"] = int(round(send * minf(0.9, dfn / (atk + dfn))))
		out["enemy_lost"] = int(round(army[to] * (atk / (atk + dfn)) * 0.55))
	return out

func sea_edge(from: int, to: int) -> int:
	for i in range(nb_off[from], nb_off[from + 1]):
		if nb[i] == to: return 1 if nb_sea[i] == 1 else 0
	return -1

func move_or_attack(n: int, from: int, to: int, troops: int) -> String:
	if controller(from) != n: return "!notyours"
	var se := sea_edge(from, to)
	if se < 0: return "!notadjacent"
	if se == 1 and bl(from, D.B_PORT) == 0: return "!needport"
	if army[from] <= 1: return "!noarmy"
	var ctrl_to := controller(to)
	if ctrl_to == n:
		var k := mini(troops if troops != 0 else army[from] - 1, army[from] - 1)
		if k <= 0: return "!noarmy"
		var left := army[from] - k
		army[from] = left; army[to] = mini(65000, army[to] + k); touch(from); touch(to)
		if rules >= 1 and TBGenerals.follows(self, from, left): TBGenerals.transfer(self, from, to)
		if rules >= 1 and human[n] == 0 and move_fx.size() < 160: move_fx.append([from, to, n])
		return "move"
	if ctrl_to != 0 and friendly(n, ctrl_to): return "!friendly"
	if ctrl_to != 0 and get_rel(n, ctrl_to) != D.REL_WAR: return "!nowar"
	if discoverable[to] != 0 and tech_level[n] < 2 and owner[to] == 0: return "!undiscovered"
	if rules >= 1 and human[n] == 0 and move_fx.size() < 160: move_fx.append([from, to, n])
	return resolve_combat(n, from, to, troops)

func resolve_combat(n: int, from: int, to: int, troops: int) -> String:
	var avail := army[from]
	var send := maxi(1, mini(troops if troops != 0 else avail - 1, avail - 1))
	var atk_n := n
	var def_n := controller(to)
	var atk: float = send * combat_mul(atk_n) * float(D.TERRAIN_ATK[terrain[to]])
	var dfn: float = army[to] * combat_mul(def_n) * def_mul(to)
	var rides := rules >= 1 and TBGenerals.follows(self, from, avail - send)
	if rides: atk *= TBGenerals.mul(self, from)
	if rules >= 1: dfn *= TBGenerals.mul(self, to)
	if atk > dfn:
		var surv := maxi(1, int(round((atk - dfn) / maxf(0.01, combat_mul(atk_n)))))
		var occ := mini(send, surv)
		if owner[to] == 0: set_owner(to, atk_n)
		elif owner[to] == atk_n:
			occupier[to] = 0; occ_rev += 1
		elif atk_n == rebel or def_n == rebel: cede(to, atk_n)
		else:
			occupier[to] = atk_n; occ_turns[to] = 0; occ_rev += 1
			if rules >= 1 and (human[atk_n] != 0 or human[def_n] != 0 or capital[to] != 0):
				log.append({"turn": turn, "kind": "occupied", "a": atk_n, "b": def_n, "p": to})
		army[to] = occ; defense[to] = 0
		army[from] = maxi(0, avail - occ)
		touch(from); touch(to)
		if rules >= 1:
			if (human[atk_n] != 0 or human[def_n] != 0) and battle_fx.size() < 60: battle_fx.append([from, to, 1, atk_n, def_n])
			if gen[to] != 0 and def_n != 0 and human[def_n] != 0: log.append({"turn": turn, "kind": "general_fell", "a": def_n, "p": to, "gn": TBGenerals.name_idx(self, to), "sk": TBGenerals.skill(self, to)})
			gen[to] = 0
			if rides:
				TBGenerals.transfer(self, from, to); TBGenerals.win(self, to, atk_n)
		return "win"
	var atk_loss := int(round(send * minf(0.9, dfn / (atk + dfn))))
	army[from] = maxi(0, avail - atk_loss)
	army[to] = maxi(1, army[to] - int(round(army[to] * (atk / (atk + dfn)) * 0.55)))
	touch(from); touch(to)
	if rules >= 1:
		if (human[atk_n] != 0 or human[def_n] != 0) and battle_fx.size() < 60: battle_fx.append([from, to, 0, atk_n, def_n])
		if rides: TBGenerals.lose(self, from, atk_n, atk_loss * 2 > send)
		TBGenerals.win(self, to, def_n)
	return "loss"

func cede(p: int, to: int) -> void:
	var from := owner[p]
	set_owner(p, to); occupier[p] = 0; occ_rev += 1
	TBDiplo.on_land_taken(self, p, from, to)
	if from != 0 and capital[p] != 0:
		capital[p] = 0; capital_of[from] = -1; reassign_capital(from)
		if own_count(from) == 0 and from != rebel: eliminate(from)

func eliminate(n: int) -> void:
	set_alive(n, 0)
	if rules >= 1: TBTrade.cancel_all(self, n)
	for o in range(1, N + 1):
		if rel[n * N1 + o] == D.REL_WAR: set_rel(n, o, D.REL_PEACE)
	log.append({"turn": turn, "kind": "eliminated", "a": n})

# ---------------------------------------------------------------- commands: see commands.gd (the ONLY mutation API)
func apply(c: Dictionary) -> Dictionary: return TBCommands.apply(self, c)

## read-only: would this command pass validation, and what does it cost? {ok, reason, gold, moves, men, dp, short, ...} (engine/can.gd). "n" defaults to the human.
func can(c: Dictionary) -> Dictionary: return TBCan.check(self, c)

# ---------------------------------------------------------------- misc
static func gen_color(n: int) -> int:
	var h := fposmod(n * 137.508, 360.0)
	var s := 0.55 + (n % 3) * 0.1
	var l := 0.45 + (n % 4) * 0.05
	var col := Color.from_hsv(h / 360.0, minf(1.0, s), minf(1.0, l + 0.35))
	return col.to_rgba32() >> 8   # 0xRRGGBB

## rules >= 1: muted inks, like hand-tinted washes on an old chart (still distinct neighbours via the golden angle)
static func gen_wash(n: int) -> int:
	var h := fposmod(n * 137.508, 360.0)
	var s := 0.34 + (n % 3) * 0.07
	var v := 0.58 + (n % 4) * 0.055
	return Color.from_hsv(h / 360.0, s, v).to_rgba32() >> 8

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
