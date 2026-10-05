## Starting government per nation (rules >= 1): era-appropriate and, for well-known states, historical.
## (rules 0 keeps the legacy round-robin assignment so the oracle stays bit-exact.)
class_name TBRegimes
extends RefCounted

# regime ids: 0 tribal 1 feudal 2 monarchy 3 republic 4 empire 5 democracy 6 communism 7 fascism 8 horde 9 citystate
const MODERN_COMMUNIST := ["CHN", "PRK", "CUB", "LAO", "VNM"]
const MODERN_MONARCHY := ["GBR", "SAU", "JOR", "MAR", "OMN", "QAT", "KWT", "BHR", "ARE", "BRN", "BTN", "THA", "NLD", "BEL", "SWE", "NOR", "DNK", "ESP", "LIE", "MCO", "LUX", "JPN", "SWZ", "LSO", "TON", "MYS", "KHM", "AUS", "CAN", "NZL"]
const MODERN_DEMOCRACY := ["USA", "FRA", "DEU", "ITA", "IND", "BRA", "JPN", "AUS", "CAN", "NZL", "GBR", "ESP", "KOR", "TWN", "ISR", "CHE", "SWE", "NOR", "DNK", "FIN", "NLD", "BEL", "AUT", "IRL", "POL", "PRT", "GRC", "CZE", "CHL", "URY", "CRI", "ZAF", "ARG", "MEX", "IDN", "PHL", "HUN", "SVK", "SVN", "EST", "LVA", "LTU", "HRV", "ISL", "LUX", "MLT", "CYP", "BWA", "GHA", "SEN", "JAM", "TTO", "BRB", "BHS", "MUS", "CPV", "PAN", "COL", "PER", "ECU", "DOM", "SGP", "MNG", "LKA", "NPL", "BGD", "ROU", "BGR", "SRB", "UKR", "MDA", "GEO", "ARM", "KEN", "NAM", "ZMB", "MWI", "SLE", "LBR"]
const EXPLICIT := {
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
const PRIMITIVE := ["hunter", "gatherer", "farmers", "pastoral", "nomads", "culture", "cultures", "chiefdom", "tribes", "tribal", "forager", "fisher", "shellfish", "minor", "bison", "reindeer", "manioc", "savanna", "bantou", "bantu", "khoiasan", "pampas", "papuan", "inuit", "aborigin", "polynes", "melanes"]

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
