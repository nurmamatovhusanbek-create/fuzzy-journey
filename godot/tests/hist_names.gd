extends SceneTree
## Province names of the era: Khujand in 1400, Leninabad in 1947, Constantinople before 1930, Petrograd in 1914; modern names where no rule names the era; every historical name has a Russian and an Uzbek form.
## Run: godot --headless -s tests/hist_names.gd
var fails := 0
func _check(ok: bool, what: String) -> void:
	if not ok: fails += 1; print("FAIL: ", what)
func _init() -> void:
	var w := TBWorld.load_from("res://data")
	var idx := {}
	for i in w.P: idx[w.id[i]] = i
	var l: int = idx["tjk_leninabad"]
	_check(TBHistNames.names_for(w, 1400)[l] == "Khujand", "Timurid era: Khujand (%s)" % TBHistNames.names_for(w, 1400)[l])
	_check(TBHistNames.names_for(w, 1947)[l] == "Leninabad", "1947: Leninabad stays (%s)" % TBHistNames.names_for(w, 1947)[l])
	_check(TBHistNames.names_for(w, 1914)[idx["rus_leningrad"]] == "Petrograd", "1914: Petrograd")
	_check(TBHistNames.names_for(w, 1492)[idx["tur_istanbul"]] == "Constantinople", "1492: Constantinople")
	_check(TBHistNames.names_for(w, 1947)[idx["tur_istanbul"]] == "Istanbul", "1947: Istanbul (the modern name)")
	_check(TBHistNames.names_for(w, 1947)[idx["usa_texas"]] == w.name[idx["usa_texas"]], "a province with no rule keeps its name")
	# every historical name is localised
	var names := {}
	for era in TBHistNames.ERA_CODES:
		var arr := TBHistNames.names_for(w, int(era))
		for i in w.P: if arr[i] != w.name[i]: names[arr[i]] = true
	var ru = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/hist_ru.json"))
	var uz = JSON.parse_string(FileAccess.get_file_as_string("res://data/i18n/hist_uz.json"))
	var miss := 0
	for n in names: if not ru.has(n) or not uz.has(n): miss += 1; print("  no ru/uz form: ", n)
	_check(miss == 0, "every historical name has a Russian and an Uzbek form (%d missing of %d)" % [miss, names.size()])
	# the game shows the era's name
	var g := TBGame.new(w, TBWorld.load_era("res://data", "timurid"), {"seed": 1, "rules": 4})
	_check(g.pname(l) == "Khujand", "TBGame.pname follows the era (%s)" % g.pname(l))
	TBI18n.load_lang("ru")
	_check(TBI18n.place("Khujand") == "Худжанд", "Russian: Худжанд (%s)" % TBI18n.place("Khujand"))
	TBI18n.load_lang("uz")
	_check(TBI18n.place("Khujand") == "Xo‘jand", "Uzbek: Xo‘jand (%s)" % TBI18n.place("Khujand"))
	print("covered provinces: ", names.size(), " historical names")
	print("HIST_NAMES OK" if fails == 0 else "HIST_NAMES FAIL %d" % fails)
	quit(fails)
