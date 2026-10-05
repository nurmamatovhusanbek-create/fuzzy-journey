## Rulers: every nation has a named leader with three skills (1..5) and a trait; they age, die and are succeeded.
## Deterministic without touching the main RNG: all rolls derive from a hash of (seed, nation, turn, salt).
class_name TBRulers
extends RefCounted

const D = preload("res://src/engine/data.gd")
const NAME_POOL := 52                       # i18n keys rn_0 .. rn_51
const TRAITS := ["none", "conqueror", "builder", "scholar", "merchant", "pious", "diplomat", "tyrant", "beloved"]
const HEREDITARY := [0, 1, 2, 4, 8]         # regime ids that pass power by blood: tribal feudal monarchy empire horde
const TERM_TURNS := 16                      # elected leaders face replacement every 8 years
static var _hist: Dictionary = {}           # era id -> Array of {nation, name{en,ru}, age, adm, dip, mil, trait}
static var _hist_loaded := false

static func _h(g: TBGame, n: int, salt: int) -> TBRng:
	var h: int = g.seed_value ^ TBRng.imul(n + 1, 0x9E3779B1) ^ TBRng.imul(g.turn + 7, 0x85EBCA6B) ^ TBRng.imul(salt + 3, 0xC2B2AE35)
	var r := TBRng.new(h)
	r.next()
	return r

static func _load_hist() -> void:
	if _hist_loaded: return
	_hist_loaded = true
	var path := "res://data/rulers.json"
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary: _hist = d

static func is_hereditary(g: TBGame, n: int) -> bool:
	return HEREDITARY.has(int(g.regime[n]))

## allocate and roll a ruler for every living nation (rules >= 1)
static func init(g: TBGame) -> void:
	_load_hist()
	var hist: Array = _hist.get(g.era_id, [])
	for n in range(1, g.N1):
		if n == g.rebel or g.alive[n] == 0: continue
		var done := false
		for h in hist:
			var want := String(h["nation"]).to_lower()
			if want == g.nat_code[n].to_lower() or want == g.nat_name[n].to_lower():
				var nm: Dictionary = h["name"]
				g.r_name[n] = "%s|%s" % [nm.get("en", ""), nm.get("ru", nm.get("en", ""))]
				g.r_num[n] = int(h.get("num", 0))
				g.r_born[n] = g.turn - int(h.get("age", 40)) * 2
				g.r_adm[n] = int(h["adm"]); g.r_dip[n] = int(h["dip"]); g.r_mil[n] = int(h["mil"])
				g.r_trait[n] = maxi(0, TRAITS.find(String(h.get("trait", "none"))))
				g.r_since[n] = g.turn - int(h.get("reign", 5)) * 2
				done = true; break
		if not done: roll(g, n, false)

## create a fresh ruler for n (heir = young; elected = mature)
static func roll(g: TBGame, n: int, heir: bool) -> void:
	var r := _h(g, n, 11)
	var age := (18 + r.randi_n(18)) if (heir and is_hereditary(g, n)) else (38 + r.randi_n(25))
	var prev: String = g.r_name[n]
	var idx := r.randi_n(NAME_POOL)
	g.r_name[n] = "rn:%d" % idx
	var ro := r.next()
	g.r_num[n] = 1 if ro < 0.55 else (2 if ro < 0.85 else 3)
	if prev == g.r_name[n]: g.r_num[n] = mini(9, g.r_num[n] + 1)
	g.r_born[n] = g.turn - age * 2
	g.r_since[n] = g.turn
	# skills: sum is 8..13, never below 1
	g.r_adm[n] = 1 + r.randi_n(5); g.r_dip[n] = 1 + r.randi_n(5); g.r_mil[n] = 1 + r.randi_n(5)
	g.r_trait[n] = r.randi_n(TRAITS.size())

static func age(g: TBGame, n: int) -> int:
	return maxi(0, (g.turn - g.r_born[n]) / 2)

## "Henry II" / "Trajan" in the current language
## i18n key for the ruler's title: republics call theirs "Consul" until the modern age, then "President"
static func title_key(g: TBGame, n: int) -> String:
	var id: String = D.REGIME_ID[g.regime[n]]
	if id == "republic" and g.start_year >= 1750: return "rt_democracy"
	return "rt_" + id

static func display_name(g: TBGame, n: int) -> String:
	return name_of(g.r_name[n], g.r_num[n])

static func name_of(s: String, num: int) -> String:
	if s == "": return ""
	if s.begins_with("rn:"):
		var base: String = TBI18n.T("rn_" + s.substr(3))
		return base if num <= 1 else "%s %s" % [base, _roman(num)]
	var parts := s.split("|")
	var nm: String = parts[1] if TBI18n.lang == "ru" and parts.size() > 1 else parts[0]
	return nm if num <= 1 else "%s %s" % [nm, _roman(num)]

static func _roman(v: int) -> String:
	var out := ""
	var vals := [10, 9, 5, 4, 1]
	var syms := ["X", "IX", "V", "IV", "I"]
	v = clampi(v, 0, 39)
	for i in vals.size():
		while v >= vals[i]:
			out += syms[i]; v -= vals[i]
	return out

# ---------------------------------------------------------------- effects (all neutral when skill == 3 and no trait)
static func _has(g: TBGame, n: int, trait_id: String) -> bool:
	return g.rules >= 1 and g.r_name[n] != "" and TRAITS[g.r_trait[n]] == trait_id

static func gold_mul(g: TBGame, n: int) -> float:
	if g.rules < 1: return 1.0
	if g.r_name[n] == "": return TBDecisions.gold_mul(g, n)
	return TBDecisions.gold_mul(g, n) * (1.0 + 0.04 * (g.r_adm[n] - 3) + (0.06 if _has(g, n, "merchant") else 0.0))

static func combat_mul(g: TBGame, n: int) -> float:
	if g.rules < 1: return 1.0
	if g.r_name[n] == "": return TBDecisions.combat_mul(g, n)
	return TBDecisions.combat_mul(g, n) * (1.0 + 0.03 * (g.r_mil[n] - 3) + (0.06 if _has(g, n, "conqueror") else 0.0))

static func research_mul(g: TBGame, n: int) -> float:
	return (1.0 + (0.15 if _has(g, n, "scholar") else 0.0)) * TBDecisions.research_mul(g, n)

static func manpower_mul(g: TBGame, n: int) -> float:
	return (1.0 + (0.12 if _has(g, n, "tyrant") else 0.0) + (0.02 * (g.r_mil[n] - 3) if g.rules >= 1 and g.r_name[n] != "" else 0.0)) * TBDecisions.manpower_mul(g, n)

static func stab_add(g: TBGame, n: int) -> float:
	return (0.3 if _has(g, n, "pious") else 0.0) + TBDecisions.stab_add(g, n)

static func dp_add(g: TBGame, n: int) -> float:
	if g.rules < 1 or g.r_name[n] == "": return 0.0
	return 0.12 * (g.r_dip[n] - 3) + (0.4 if _has(g, n, "diplomat") else 0.0)

static func happy_add(g: TBGame, n: int) -> float:
	return (4.0 if _has(g, n, "beloved") else 0.0) - (3.0 if _has(g, n, "tyrant") else 0.0) + TBDecisions.happy_add(g, n)

static func rebel_mul(g: TBGame, n: int) -> float:
	return 1.4 if _has(g, n, "tyrant") else 1.0

static func invest_mul(g: TBGame, n: int) -> float:
	return 1.6 if _has(g, n, "builder") else 1.0

# ---------------------------------------------------------------- succession
static func death_chance(years: int) -> float:
	if years < 40: return 0.002
	if years < 55: return 0.006
	if years < 65: return 0.02
	if years < 75: return 0.06
	return 0.15

## per-turn: death of old rulers, elections; new nations (independence, splinters) get a ruler lazily
static func tick(g: TBGame) -> void:
	for n in range(1, g.N1):
		if n == g.rebel: continue
		if g.alive[n] == 0:
			g.r_name[n] = ""; continue          # a fallen nation loses its ruler; a revived one gets a new one
		if g.r_name[n] == "":
			roll(g, n, false); continue
		var died := _h(g, n, 21).next() < death_chance(age(g, n))
		var term_end := not is_hereditary(g, n) and (g.turn - g.r_since[n]) >= TERM_TURNS and _h(g, n, 22).next() < 0.5
		if not died and not term_end: continue
		var crisis := false
		if died and is_hereditary(g, n) and _h(g, n, 23).next() < 0.12:
			crisis = true
			for p in g.owned(n):
				if g.capital[p] == 0: g.stab[p] = maxi(5, g.stab[p] - 8)
		var old_raw: String = g.r_name[n]; var old_num: int = g.r_num[n]
		var major: bool = g.human[n] != 0 or g.own_count(n) >= 20
		roll(g, n, died)
		if major:
			g.log.append({"turn": g.turn, "kind": "ruler", "a": n, "k": ("crisis" if crisis else ("died" if died else "elected")), "old": old_raw, "oldn": old_num, "new": g.r_name[n], "num": g.r_num[n]})
