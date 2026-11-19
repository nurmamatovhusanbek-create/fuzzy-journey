## Starting government per nation (rules >= 1): era-appropriate and, for well-known states, historical.
## (rules 0 keeps the legacy round-robin assignment so the oracle stays bit-exact.)
class_name TBRegimes
extends RefCounted

# regime ids: 0 tribal 1 feudal 2 monarchy 3 republic 4 empire 5 democracy 6 communism 7 fascism 8 horde 9 citystate
static var MODERN_COMMUNIST: Array = ["CHN", "PRK", "CUB", "LAO", "VNM"]
static var MODERN_MONARCHY: Array = ["GBR", "SAU", "JOR", "MAR", "OMN", "QAT", "KWT", "BHR", "ARE", "BRN", "BTN", "THA", "NLD", "BEL", "SWE", "NOR", "DNK", "ESP", "LIE", "MCO", "LUX", "JPN", "SWZ", "LSO", "TON", "MYS", "KHM", "AUS", "CAN", "NZL"]
static var MODERN_DEMOCRACY: Array = ["USA", "FRA", "DEU", "ITA", "IND", "BRA", "JPN", "AUS", "CAN", "NZL", "GBR", "ESP", "KOR", "TWN", "ISR", "CHE", "SWE", "NOR", "DNK", "FIN", "NLD", "BEL", "AUT", "IRL", "POL", "PRT", "GRC", "CZE", "CHL", "URY", "CRI", "ZAF", "ARG", "MEX", "IDN", "PHL", "HUN", "SVK", "SVN", "EST", "LVA", "LTU", "HRV", "ISL", "LUX", "MLT", "CYP", "BWA", "GHA", "SEN", "JAM", "TTO", "BRB", "BHS", "MUS", "CPV", "PAN", "COL", "PER", "ECU", "DOM", "SGP", "MNG", "LKA", "NPL", "BGD", "ROU", "BGR", "SRB", "UKR", "MDA", "GEO", "ARM", "KEN", "NAM", "ZMB", "MWI", "SLE", "LBR"]
static var EXPLICIT: Dictionary = {
	"ancient": {"rome": 3, "carthage": 3, "han_empire": 4, "seleucid_kingdom": 2, "xiongnu": 8, "scythians": 8, "celts": 0, "norsemen": 0, "mauryan_empire": 4},
	"roman": {"roman_empire": 4, "parthian_empire": 4, "han": 4},
	"medieval": {"byzantine_empire": 4, "holy_roman_empire": 1, "france": 1, "almoravid_dynasty": 2, "seljuk_empire": 4, "fatimid_caliphate": 2, "kievan_rus": 1},
	"mongol": {"mongol_empire": 8, "ilkhanate": 8, "khanate_of_the_golden_horde": 8, "france": 2, "holy_roman_empire": 1, "mamluke_sultanate": 2, "shogun_japan_kamakura": 1},
	"timurid": {"timurid_empire": 8, "mongol_empire": 4, "france": 2, "ottoman_empire": 4, "holy_roman_empire": 1, "shogun_japan_kamakura": 1},
	"discovery": {"ottoman_empire": 4, "holy_roman_empire": 1, "france": 2, "ming_chinese_empire": 4, "inca_empire": 4, "grand_duchy_of_moscow": 2, "japan": 1, "golden_horde": 8},
	"gunpowder": {"france": 2, "ottoman_empire": 4, "spanish_habsburg": 2, "mughal_empire": 4, "manchu_empire": 4, "netherlands": 3, "tokugawa_shogunate": 1, "tsardom_of_muscovy": 2, "polish_lithuanian_commonwealth": 3},
	"napoleonic": {"france": 4, "uk": 2, "united_states_of_america": 3, "russian_empire": 4, "ottoman_empire": 4, "qing_empire": 4, "austrian_empire": 4, "japan": 1},
	"victorian": {"france": 3, "british_empire": 5, "united_states_of_america": 3, "russian_empire": 4, "ottoman_empire": 4, "austria_hungary": 4, "manchu_empire": 4, "netherlands": 2, "italy": 2, "germany": 2},
	"ww1": {"france": 5, "british_empire": 5, "united_states": 5, "russia": 4, "german_empire": 4, "austria_hungary": 4, "ottoman_empire": 4, "italy": 2, "empire_of_japan": 4, "manchu_empire": 3, "spain": 2, "brazil": 3},
	"ww2": {"france": 5, "british_empire": 5, "united_states": 5, "ussr": 6, "germany": 7, "italy": 7, "spain": 7, "empire_of_japan": 4, "turkey": 3, "netherlands": 2, "portugal": 7, "chinese_warlords": 3, "iran": 2, "brazil": 7, "mexico": 3},
	"coldwar": {"france": 5, "british_empire": 5, "usa": 5, "ussr": 6, "turkey": 3, "portugal": 7, "iran": 2, "india": 5, "spain": 7, "china": 3, "italy": 5, "yugoslavia": 6, "indonesia": 3, "mongolia": 6, "argentina": 3, "brazil": 3, "mexico": 3},
}
static var PRIMITIVE: Array = ["hunter", "gatherer", "farmers", "pastoral", "nomads", "culture", "cultures", "chiefdom", "tribes", "tribal", "forager", "fisher", "shellfish", "minor", "bison", "reindeer", "manioc", "savanna", "bantou", "bantu", "khoiasan", "pampas", "papuan", "inuit", "aborigin", "polynes", "melanes"]

static func assign(g: TBGame) -> void:
	var modern := g.era_id == "modern"
	var year := g.start_year
	var table: Dictionary = EXPLICIT.get(g.era_id, {})
	for n in range(1, g.N1):
		if n == g.rebel: continue
		var code := String(g.nat_code[n])
		var id := code.to_lower()
		var r := -1
		if modern:
			if MODERN_COMMUNIST.has(code): r = 6
			elif MODERN_MONARCHY.has(code) and code not in ["JPN", "AUS", "CAN", "NZL", "GBR", "ESP", "SWE", "NOR", "DNK", "NLD", "BEL", "LUX"]: r = 2
			elif MODERN_DEMOCRACY.has(code) or MODERN_MONARCHY.has(code): r = 5
			else: r = 3
		elif table.has(id): r = int(table[id])
		else:
			var h := TBRng.hash_str(id)
			var prim := false
			for k in PRIMITIVE:
				if id.contains(k): prim = true; break
			if prim: r = 0
			elif id.contains("empire") or id.contains("imperial"): r = 4
			elif id.contains("khanate") or id.contains("horde") or id.contains("khagan"): r = 8
			elif id.contains("caliphate") or id.contains("sultanate") or id.contains("emirate") or id.contains("kingdom") or id.contains("dynasty"): r = 2 if year > 1000 else 1
			elif year < 600: r = [1, 2, 3, 9][h % 4] if h % 3 != 0 else 1
			elif year < 1500: r = [1, 1, 2, 9, 1][h % 5]
			elif year < 1800: r = [2, 2, 1, 3, 2, 9][h % 6]
			elif year < 1914: r = [2, 2, 3, 2, 5][h % 5]
			else: r = [3, 5, 5, 2, 3, 7][h % 6] if year < 1945 else [3, 5, 5, 2, 3, 6][h % 6]
		g.regime[n] = r

# ---------------------------------------------------------------------------------------------- reform of the government (rules >= 5)
## A state can change its form of government: an order that costs two turns of income and two moves, shakes the land, and moves the estates (the order that gains from the new
## form is pleased, the one that leads the old form is not). One reform in REFORM_COOLDOWN turns. It is what opens the next name of a line (Empire -> Russia, USSR).
const REFORM_COOLDOWN := 10
const REFORM_STAB := 12
const REFORM_MOVES := 2.0
const REFORM_SHIFT := 12.0
static var TARGETS: Array = [2, 3, 4, 5, 6, 7]                    # monarchy republic empire democracy communism fascism
static var YEAR_FROM: Dictionary = {5: 1776, 6: 1900, 7: 1919}   # democracy, communism, fascism: not before their time

static func reform_cost(g: TBGame, n: int) -> int: return int(float(g.income(n)["gold"]) * 2.0)

## the lineage stages (indices) a government would open for a nation that is otherwise ready for them
static func opens(g: TBGame, n: int, r: int) -> Array:
	var out: Array = []
	TBLineage.ensure()
	for si in TBLineage.options(g, n):
		if (TBLineage.STAGES[si]["regimes"] as Array).has(r) and not (TBLineage.STAGES[si]["regimes"] as Array).has(g.regime[n]): out.append(si)
	return out

static func can_reform(g: TBGame, n: int, r: int) -> Dictionary:
	var out := {"ok": true, "reason": "", "gold": 0, "moves": REFORM_MOVES, "short": {}}
	if g.rules < 5 or n <= 0 or g.alive[n] == 0 or n == g.rebel or not TARGETS.has(r): out["ok"] = false; out["reason"] = "unknown"; return out
	out["gold"] = reform_cost(g, n)
	if g.regime[n] == r: out["ok"] = false; out["reason"] = "reg_same"
	elif g.era[n] < int(TBData.REGIMES[r]["sinceEra"]) or g.year < int(YEAR_FROM.get(r, -9999)): out["ok"] = false; out["reason"] = "reg_era"
	elif g.turn - g.reg_last[n] < REFORM_COOLDOWN: out["ok"] = false; out["reason"] = "reg_recent"
	elif g.gold[n] < float(out["gold"]): out["ok"] = false; out["reason"] = "gold"; out["short"]["gold"] = int(out["gold"]) - int(g.gold[n])
	elif g.mp[n] < REFORM_MOVES: out["ok"] = false; out["reason"] = "mp"; out["short"]["moves"] = 1
	return out

static func reform(g: TBGame, n: int, r: int) -> Dictionary:
	var c := can_reform(g, n, r)
	if not bool(c["ok"]): return {"ok": false, "err": String(c["reason"])}
	var old_top := _top_estate(String(TBData.REGIME_ID[g.regime[n]]))
	var new_top := _top_estate(String(TBData.REGIME_ID[r]))
	g.gold[n] -= float(c["gold"]); g.mp[n] -= REFORM_MOVES
	var old := g.regime[n]
	g.regime[n] = r; g.reg_last[n] = g.turn
	for p in g.owned(n): g.stab[p] = maxi(5, g.stab[p] - REFORM_STAB); g.touch(p)
	if old_top != new_top:
		TBEstates.shift(g, n, TBEstates.IDS[new_top], REFORM_SHIFT)
		TBEstates.shift(g, n, TBEstates.IDS[old_top], -REFORM_SHIFT)
	g.log.append({"turn": g.turn, "kind": "reform", "a": n, "r": r, "o": old})
	g.occ_rev += 1
	g.ident_rev += 1
	return {"ok": true}

static func _top_estate(regime_id: String) -> int:
	TBEstates.ensure()
	var w: Array = TBEstates._w.get(regime_id, [25, 25, 25, 25])
	var best := 0
	for e in 4: if float(w[e]) > float(w[best]): best = e
	return best

## the AI reforms when a name of its line is within reach but for the government, and it can pay twice over
static func ai_step(g: TBGame, n: int) -> void:
	if g.rules < 5 or g.human[n] != 0 or (g.turn + n) % 4 != 2: return
	TBLineage.ensure()
	var best := -1; var best_w := -1
	for si in TBLineage.options(g, n):
		if (TBLineage.STAGES[si]["regimes"] as Array).has(g.regime[n]): continue
		var ready := true
		for c in TBLineage.conditions(g, n, si):
			if String(c["key"]) in ["year", "core"] and not bool(c["ok"]): ready = false
		if ready and int(TBLineage.STAGES[si]["w"]) > best_w: best = si; best_w = int(TBLineage.STAGES[si]["w"])      # the strongest name first, as in forming
	if best < 0: return
	for r in (TBLineage.STAGES[best]["regimes"] as Array):
		var cr := can_reform(g, n, int(r))
		if bool(cr["ok"]) and g.gold[n] >= 2.0 * float(cr["gold"]): reform(g, n, int(r)); return
