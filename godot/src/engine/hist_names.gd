## Province names of the era: the world file carries today's names (Leninabad, Leningrad, Istanbul); the game starts in a year, and a province is shown by the name it had then
## (Khujand in 1400, Constantinople in 1492, Petrograd in 1914). data/hist_names.json is written by tools/hist/build_hist_names.py: province id -> {era code: name}; a province with
## no entry for the era keeps its modern name. The Russian and Uzbek forms are data/i18n/hist_ru.json / hist_uz.json (english name -> localised), read by TBI18n.place.
class_name TBHistNames
extends RefCounted

static var ERA_CODES: Dictionary = {-218: "A", 117: "R", 1096: "M", 1300: "G", 1400: "T", 1492: "D", 1700: "U", 1804: "N", 1850: "V", 1914: "W", 1939: "X", 1947: "C"}
static var _rules: Dictionary = {}
static var _loaded := false

static func _load() -> void:
	if _loaded: return
	_loaded = true
	var path := "res://data/hist_names.json"
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary: _rules = d

## the era whose start year is the latest one not after `year` ("" before the first: the modern names)
static func code_for(year: int) -> String:
	var best := ""
	var best_y := -1000000
	for y in ERA_CODES:
		if int(y) <= year and int(y) > best_y: best_y = int(y); best = String(ERA_CODES[y])
	return best

## the names of a world as they were in `year`
static func names_for(world: TBWorld, year: int) -> PackedStringArray:
	_load()
	var out := PackedStringArray(world.name)
	var code := code_for(year)
	if code == "" or _rules.is_empty(): return out
	for p in world.P:
		var r: Variant = _rules.get(world.id[p])
		if r is Dictionary and (r as Dictionary).has(code): out[p] = String((r as Dictionary)[code])
	return out
