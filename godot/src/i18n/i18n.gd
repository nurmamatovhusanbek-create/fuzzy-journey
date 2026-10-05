## Tiny i18n: JSON dictionaries in res://data/i18n/<lang>.json. T("key", {var: value}).
class_name TBI18n
extends RefCounted

static var lang := "en"
static var _dicts := {}

static func load_lang(l: String) -> void:
	if not _dicts.has("en"):
		_dicts["en"] = _read("en")
	if l != "en" and not _dicts.has(l):
		_dicts[l] = _read(l)
	lang = l if _dicts.has(l) else "en"

static func _read(l: String) -> Dictionary:
	var path := "res://data/i18n/%s.json" % l
	if not FileAccess.file_exists(path): return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}

static func T(key: String, vars: Dictionary = {}) -> String:
	var s: String = _dicts.get(lang, {}).get(key, _dicts.get("en", {}).get(key, key))
	for k in vars:
		s = s.replace("{" + String(k) + "}", str(vars[k]))
	return s

static func has_key(key: String) -> bool:
	return _dicts.get(lang, {}).has(key) or _dicts.get("en", {}).has(key)
